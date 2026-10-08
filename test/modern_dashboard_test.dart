// The Modern layout's dashboard: one design (no Default / Classic / Bento /
// Simple choice), with real numbers from the database.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/database/payment_service.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_dashboard.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/models/report_models.dart';
import 'package:invoiceo/models/user.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/services/backend_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── pure helpers ──────────────────────────────────────────────────────────
  group('helpers', () {
    test('a whole month compares with the whole month before', () {
      final oct = modernMonthRange(DateTime(2026, 10, 17));
      expect(oct.start, DateTime(2026, 10, 1));
      expect(oct.end, DateTime(2026, 10, 31));
      expect(modernIsWholeMonth(oct), isTrue);
      final sep = modernPreviousRange(oct);
      expect(sep.start, DateTime(2026, 9, 1));
      expect(sep.end, DateTime(2026, 9, 30));
      // January goes back to the December before
      final dec = modernPreviousRange(modernMonthRange(DateTime(2026, 1, 5)));
      expect(dec.start, DateTime(2025, 12, 1));
      expect(dec.end, DateTime(2025, 12, 31));
    });

    test('any other range compares with the same number of days before it', () {
      final r = DateTimeRange(start: DateTime(2026, 10, 11), end: DateTime(2026, 10, 20));
      expect(modernIsWholeMonth(r), isFalse);
      final p = modernPreviousRange(r);
      expect(p.start, DateTime(2026, 10, 1));
      expect(p.end, DateTime(2026, 10, 10));
    });

    test('percent change', () {
      expect(modernPercentChange(112, 100)!.round(), 12);
      expect(modernPercentChange(92, 100)!.round(), -8);
      expect(modernPercentChange(0, 0), 0);
      expect(modernPercentChange(50, 0), isNull, reason: 'nothing to compare with');
    });

    test('status counts: overdue counts only as overdue', () {
      InvoiceStatusRow row(String status, bool overdue) => InvoiceStatusRow(
          id: 'x', date: '2026-10-01', customerName: 'c', total: 1, paid: 0,
          outstanding: 1, daysOverdue: overdue ? 3 : 0, hasNoDueDate: false,
          status: status, isOverdue: overdue);
      final c = ModernStatusCounts.fromRows([
        row('Paid', false), row('Paid', false), row('Unpaid', false),
        row('Partial', false), row('Unpaid', true), row('Partial', true),
      ]);
      expect([c.paid, c.unpaid, c.partial, c.overdue, c.total], [2, 1, 1, 2, 6]);
    });

    test('months without data are filled with zero', () {
      final pts = modernFillMonths(DateTime(2026, 5, 1), DateTime(2026, 8, 31), const [
        MonthlyPoint(month: '2026-06', billed: 0, collected: 500, outstanding: 40),
        MonthlyPoint(month: '2026-08', billed: 0, collected: 10),
      ]);
      expect(pts.map((p) => p.month.month), [5, 6, 7, 8]);
      expect(pts.map((p) => p.collected), [0, 500, 0, 10]);
      expect(pts.map((p) => p.outstanding), [0, 40, 0, 0]);
    });
  });

  // ── the page with real data ───────────────────────────────────────────────
  late Directory tmp;
  var dbCounter = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    BackendServices.configure(
      settings: SqliteSettingsRepository(),
      companyInfo: SqliteCompanyInfoRepository(),
      invoices: SqliteInvoiceRepository(),
      payments: SqlitePaymentRepository(),
      installation: SqliteInstallationRepository(),
    );
    tmp = Directory.systemTemp.createTempSync('invoiceo_modern_dashboard');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });
  tearDownAll(() async {
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 14; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  final customer = Customer(
      id: 'c1', name: 'Test Customer', email: '', phone: '', address: '', gstin: '');

  Product product(String id, String name, int stock, {bool unlimited = false}) => Product(
      id: id, name: name, description: '', price: 100, stock: stock, hsncode: '',
      tax_rate: 0, unlimitedStock: unlimited);

  // This month: one paid (200), one partly paid (300, 100 paid), one unpaid
  // (400, due later), one overdue (500, due yesterday). Last month: one paid
  // (100). Stock: Camphor 6, Dal 8 (low), Oil 0 (out), Soap unlimited.
  Future<void> seed() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final lastMonth = DateTime(now.year, now.month - 1, 5);
    await CustomerService.insertCustomer(customer);
    final rice = product('p1', 'Rice', 500);
    await ProductService.insertProduct(rice);
    await ProductService.insertProduct(product('p2', 'Camphor', 6));
    await ProductService.insertProduct(product('p3', 'Dal', 8));
    await ProductService.insertProduct(product('p4', 'Oil', 0));
    await ProductService.insertProduct(product('p5', 'Soap', 0, unlimited: true));
    // A service with tracked stock at 0: not a product, so not in the
    // Products count or the low-stock card.
    await ProductService.insertProduct(Product(
        id: 's1', name: 'Repair', description: '', price: 500, stock: 0,
        hsncode: '', tax_rate: 0, type: 'service'));

    Future<Invoice> inv(String id, double qty, DateTime date, DateTime due) async {
      final i = Invoice(
          id: id, customer: customer, items: [InvoiceItem(product: rice, quantity: qty)],
          date: date, dueDate: due, type: 'Invoice');
      await InvoiceService.insertInvoice(i);
      return i;
    }

    final i0 = await inv('i0', 1, lastMonth, lastMonth.add(const Duration(days: 10)));
    await PaymentService.addPayment(invoice: i0, amountPaid: 100, datePaid: lastMonth);
    final i1 = await inv('i1', 2, monthStart, now.add(const Duration(days: 20)));
    await PaymentService.addPayment(invoice: i1, amountPaid: 200, datePaid: monthStart);
    final i2 = await inv('i2', 3, monthStart, now.add(const Duration(days: 20)));
    await PaymentService.addPayment(invoice: i2, amountPaid: 100, datePaid: monthStart);
    await inv('i3', 4, monthStart, now.add(const Duration(days: 20)));
    await inv('i4', 5, monthStart, DateTime(now.year, now.month, now.day - 1));
  }

  Future<List<String>> open(WidgetTester tester,
      {Size size = const Size(1600, 1400), bool withData = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('modern_dashboard_${dbCounter++}.db');
      if (withData) await seed();
    });
    final calls = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ModernDashboard(
            user: User(id: 'u1', username: 'admin', password: 'x', userType: 'admin'),
            onEditInvoice: (i) => calls.add('edit ${i.id}'),
            onCloneInvoice: (i, t) => calls.add('clone ${i.id} $t'),
            onCreateDocument: (t) => calls.add('create $t'),
            onOpenPage: (p) => calls.add('page $p'),
            onAddCustomer: () => calls.add('add customer'),
            onAddProduct: () => calls.add('add product'),
          ),
        ),
      ),
    ));
    await settle(tester);
    return calls;
  }

  group('page', () {
    testWidgets('header: title, greeting, and this month as the range', (tester) async {
      await open(tester, withData: false);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.textContaining('admin'), findsWidgets);
      expect(find.textContaining('👋'), findsOneWidget);
      expect(find.text("Here's what's happening with your business today."), findsOneWidget);
      final now = DateTime.now();
      final first = DateTime(now.year, now.month, 1);
      expect(find.textContaining(
              '${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][now.month - 1]} 01, ${now.year}'),
          findsOneWidget);
      expect(first.day, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('only one design: no dashboard layout choices', (tester) async {
      await open(tester, withData: false);
      for (final t in ['Classic', 'Bento', 'Simple Feed', 'Default']) {
        expect(find.text(t), findsNothing, reason: t);
      }
    });

    testWidgets('the four cards show this month, compared with last month', (tester) async {
      await open(tester);
      expect(find.textContaining('300.00'), findsWidgets, reason: 'collected 200 + 100');
      expect(find.textContaining('1,100.00'), findsWidgets, reason: 'outstanding 200 + 400 + 500');
      expect(find.text('200%'), findsOneWidget, reason: 'collected 300 vs 100 last month');
      expect(find.text('vs last month'), findsWidgets);
      expect(find.text('5'), findsWidgets, reason: 'five products');
      expect(find.text('3 low stock'), findsOneWidget, reason: 'Camphor, Dal low; Oil out');
      expect(find.text('Repair'), findsNothing, reason: 'a service is not a low-stock product');
      expect(tester.takeException(), isNull);
    });

    testWidgets('invoice status: paid, partial, unpaid, overdue add up', (tester) async {
      await open(tester);
      final status = find.byKey(const ValueKey('modernDashStatus'));
      expect(tester.widget<Text>(find.byKey(const ValueKey('modernDashStatusTotal'))).data, '4');
      for (final label in ['Paid', 'Unpaid', 'Partial', 'Overdue']) {
        expect(find.descendant(of: status, matching: find.text(label)), findsOneWidget);
      }
      expect(find.descendant(of: status, matching: find.text('25%')), findsNWidgets(4));
    });

    testWidgets('recent invoices list the latest five with their status', (tester) async {
      await open(tester);
      final recent = find.byKey(const ValueKey('modernDashRecent'));
      expect(find.descendant(of: recent, matching: find.text('Test Customer')), findsNWidgets(5));
      expect(find.descendant(of: recent, matching: find.text('Overdue')), findsOneWidget);
      expect(find.descendant(of: recent, matching: find.text('Partial')), findsOneWidget);
    });

    testWidgets('low stock: out of stock first, then the lowest; unlimited never',
        (tester) async {
      final calls = await open(tester);
      final low = find.byKey(const ValueKey('modernDashLowStock'));
      double y(String name) => tester.getTopLeft(find.descendant(of: low, matching: find.text(name))).dy;
      expect(y('Oil'), lessThan(y('Camphor')));
      expect(y('Camphor'), lessThan(y('Dal')));
      expect(find.descendant(of: low, matching: find.text('Soap')), findsNothing);
      expect(find.descendant(of: low, matching: find.text('Rice')), findsNothing);
      await tester.tap(find.descendant(of: low, matching: find.text('View all')));
      expect(calls, ['page 6']);
    });

    testWidgets('update stock from the low-stock list', (tester) async {
      await open(tester);
      final low = find.byKey(const ValueKey('modernDashLowStock'));
      final camphorRow = find.ancestor(
          of: find.descendant(of: low, matching: find.text('Camphor')),
          matching: find.byType(Row)).first;
      final rowY = tester.getCenter(camphorRow).dy;
      final editButtons = find.descendant(of: low, matching: find.byIcon(Icons.edit_outlined));
      final edit = editButtons.evaluate().map((e) => find.byWidget(e.widget)).firstWhere(
          (f) => (tester.getCenter(f).dy - rowY).abs() < 20);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('modernDashStockField')), '25');
      await tester.tap(find.text('Save'));
      await settle(tester);
      final p = await tester.runAsync(() => ProductService.getProductById('p2'));
      expect(p!.stock, 25);
      expect(find.descendant(of: low, matching: find.text('Camphor')), findsNothing,
          reason: 'no longer low');
    });

    testWidgets('quick actions', (tester) async {
      final calls = await open(tester, withData: false);
      final quick = find.byKey(const ValueKey('modernDashQuickActions'));
      for (final label in ['New Invoice', 'New Quotation', 'Add Customer', 'Add Product', 'View Reports', 'Settings']) {
        await tester.tap(find.descendant(of: quick, matching: find.text(label)));
      }
      expect(calls, [
        'create Invoice', 'create Quotation', 'add customer', 'add product', 'page 7', 'page 8',
      ]);
    });

    testWidgets('narrow window: everything stacks without overflow', (tester) async {
      await open(tester, size: const Size(700, 2600));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('modernDashSales')), findsOneWidget);
      expect(find.byKey(const ValueKey('modernDashStatus')), findsOneWidget);
    });
  });
}
