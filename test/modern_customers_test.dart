// The Modern layout's Customers page: tinted stat cards, the filter card
// (search, Customer Type ▾, Columns ▾ and the chips; sort by the Name /
// Outstanding headings; Hide stats and the currency in ⋯), the
// table (avatar, contact, GST / VAT No, type, outstanding; eye, statement,
// edit, ⋮), ticks with Delete selected, "Showing x to y" and page numbers.
// Title, Import / Export / ⋯ and "+ New Customer" are in the top bar.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/layouts/modern/modern_shell.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/models/user.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/customer_management_screen_v2.dart';
import 'package:invoiceo/services/backend_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    tmp = Directory.systemTemp.createTempSync('invoiceo_modern_customers');
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
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  final admin = User(id: 'u', username: 'admin', password: '', userType: 'admin');

  /// Arun Stores (business, GSTIN), Madhan (owes 100), Ravi.
  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('modern_customers_${dbCounter++}.db');
      await CustomerService.insertCustomer(Customer(
          id: 'c1', name: 'Madhan', email: 'madhan@shop.in', phone: '9025537550',
          address: '1, Main Road', gstin: ''));
      await CustomerService.insertCustomer(Customer(
          id: 'c2', name: 'Arun', email: '', phone: '9000000002', address: '',
          gstin: '33AAAAA0000A1Z5', businessName: 'Arun Stores'));
      await CustomerService.insertCustomer(Customer(
          id: 'c3', name: 'Ravi', email: '', phone: '', address: '', gstin: ''));
      final p = Product(id: 'p', name: 'Rice', description: '', price: 100, stock: 0,
          hsncode: '1', tax_rate: 0, unlimitedStock: true);
      await InvoiceService.insertInvoice(Invoice(
          id: '00000001', invoiceNumber: '00000001', type: 'Invoice',
          customer: Customer(id: 'c1', name: 'Madhan', email: '', phone: '9025537550',
              address: '', gstin: ''),
          items: [InvoiceItem(product: p, quantity: 1)], date: DateTime(2026, 10, 5),
          taxRate: 0, taxMode: TaxMode.none, currencyCode: 'INR', currencySymbol: 'Rs.'));
    });
  }

  Future<void> pumpPage(WidgetTester tester,
      {Size size = const Size(1500, 1000),
      Locale? locale,
      bool inFrame = false,
      void Function(Customer)? onStatement}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final header = ValueNotifier<ModernPageHeader?>(null);
    addTearDown(header.dispose);
    final page = CustomerManagementScreenV2(
        key: UniqueKey(), user: admin, modern: true, onViewCustomerStatement: onStatement);
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: !inFrame
              ? page
              : Column(children: [
                  ModernTopBar(
                    username: 'admin',
                    isAdmin: true,
                    onSearch: () {},
                    onCreate: (_) {},
                    onUserAction: (_) {},
                    page: 5,
                    pageTitle: 'Customers',
                    header: header,
                  ),
                  Expanded(child: ModernHeaderScope(page: 5, notifier: header, child: page)),
                ]),
        ),
      ),
    ));
    await settle(tester);
    await settle(tester);
  }

  Finder row(String id) => find.byKey(ValueKey('custRow_$id'));
  Finder inStats(String t) => find.descendant(
      of: find.byKey(const ValueKey('modernCustomerStats')), matching: find.text(t));

  Future<void> pick(WidgetTester tester, String button, String item) async {
    await tester.tap(find.byKey(ValueKey(button)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await settle(tester);
  }

  testWidgets('stat cards, filter card with chips, table and footer', (tester) async {
    await seed(tester);
    await pumpPage(tester, onStatement: (_) {});
    expect(tester.takeException(), isNull);

    expect(inStats('Total Customers'), findsOneWidget);
    expect(inStats('3'), findsOneWidget);
    expect(inStats('Businesses'), findsOneWidget);
    expect(inStats('2'), findsOneWidget, reason: 'individuals');
    expect(inStats('1'), findsNWidgets(2), reason: 'businesses, tax registered');
    expect(find.textContaining('vs last month'), findsNothing, reason: 'no trend');

    for (final k in ['modernCustomerSearch', 'modernCustomerType', 'modernCustomerColumns']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    for (final k in ['modernCustomerFilterMenu', 'modernCustomerSort', 'modernCustomerStatsToggle']) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: '$k is gone');
    }
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('Businesses (1)'), findsOneWidget);
    expect(find.text('Individuals (2)'), findsOneWidget);
    expect(find.text('With Outstanding (1)'), findsOneWidget);

    for (final id in ['c1', 'c2', 'c3']) {
      expect(row(id), findsOneWidget);
    }
    expect(find.descendant(of: row('c2'), matching: find.text('Business')), findsOneWidget);
    expect(find.descendant(of: row('c2'), matching: find.text('Arun Stores')), findsOneWidget);
    expect(find.descendant(of: row('c1'), matching: find.text('Individual')), findsNWidgets(2),
        reason: 'under the name and the Type pill');
    expect(find.descendant(of: row('c1'), matching: find.text('Rs. 100.00')), findsOneWidget);
    expect(find.descendant(of: row('c1'), matching: find.text('madhan@shop.in')), findsOneWidget);
    expect(find.text('Status'), findsNothing, reason: 'no Status column');
    for (final k in ['custView_c1', 'custStatement_c1', 'custEdit_c1', 'custMenu_c1']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    expect(find.text('Showing 1 to 3 of 3 customers'), findsOneWidget);
    expect(find.byKey(const ValueKey('custPage_1')), findsOneWidget);
  });

  testWidgets('⋯ > Hide stat cards hides the cards and remembers it', (tester) async {
    await seed(tester);
    await pumpPage(tester, inFrame: true);
    final stats = find.byKey(const ValueKey('modernCustomerStats'));
    final more = find.byKey(const ValueKey('modernCustomerMore'));
    expect(stats, findsOneWidget);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide stat cards'));
    await settle(tester);
    expect(stats, findsNothing);
    expect(await tester.runAsync(() =>
            SqliteSettingsRepository().getSetting(SettingKey.showCustomerStatsCards)),
        'false');
    await pumpPage(tester, inFrame: true);
    expect(stats, findsNothing, reason: 'remembered');
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show stat cards'));
    await settle(tester);
    expect(stats, findsOneWidget);
  });

  testWidgets('chips, Customer Type ▾ and search filter the table', (tester) async {
    await seed(tester);
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('modernCustChip_1')));
    await settle(tester);
    expect(row('c2'), findsOneWidget);
    expect(row('c1'), findsNothing);

    await pick(tester, 'modernCustomerType', 'Individuals');
    expect(row('c1'), findsOneWidget);
    expect(row('c3'), findsOneWidget);
    expect(row('c2'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('modernCustChip_5')));
    await settle(tester);
    expect(row('c1'), findsOneWidget, reason: 'with outstanding');
    expect(row('c3'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('modernCustChip_0')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('modernCustomerSearch')), 'ravi');
    await settle(tester);
    expect(row('c3'), findsOneWidget);
    expect(row('c1'), findsNothing);
  });

  testWidgets('the Name header sorts; Columns ▾ hides a column and remembers it', (tester) async {
    await seed(tester);
    await pumpPage(tester);
    double y(String id) => tester.getTopLeft(row(id)).dy;
    expect(y('c2'), lessThan(y('c3')), reason: 'A-Z: Arun before Ravi');
    await tester.tap(find.byKey(const ValueKey('modernCustSortName')));
    await settle(tester);
    expect(y('c3'), lessThan(y('c2')), reason: 'Z-A');

    final table = find.byKey(const ValueKey('modernCustomerTable'));
    expect(find.descendant(of: table, matching: find.text('Contact')), findsOneWidget);
    await pick(tester, 'modernCustomerColumns', 'Contact');
    expect(find.descendant(of: table, matching: find.text('Contact')), findsNothing);
    expect(await tester.runAsync(() =>
            SqliteSettingsRepository().getSetting(SettingKey.customerListHiddenColumns)),
        contains('contact'));
    await pumpPage(tester);
    expect(find.descendant(of: table, matching: find.text('Contact')), findsNothing,
        reason: 'remembered');
  });

  testWidgets('row buttons: view, statement, edit, ⋮ with Receive Payment and Delete',
      (tester) async {
    await seed(tester);
    final statements = <String>[];
    await pumpPage(tester, onStatement: (c) => statements.add(c.id));
    await tester.tap(find.byKey(const ValueKey('custStatement_c1')));
    expect(statements, ['c1']);

    await tester.tap(find.byKey(const ValueKey('custView_c1')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(Dialog))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('custMenu_c1')));
    await tester.pumpAndSettle();
    expect(find.text('Receive Payment'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('ticked rows: "2 selected" and Delete selected', (tester) async {
    await seed(tester);
    await pumpPage(tester);
    await tester.tap(find.descendant(of: row('c2'), matching: find.byType(Checkbox)));
    await tester.tap(find.descendant(of: row('c3'), matching: find.byType(Checkbox)));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('custDeleteSelected')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('custDeleteSelectedOk')));
    await settle(tester);
    expect(row('c2'), findsNothing);
    expect(row('c3'), findsNothing);
    expect(row('c1'), findsOneWidget);
    expect(find.text('Showing 1 to 1 of 1 customers'), findsOneWidget);
  });

  testWidgets('in the app frame: title, Import / Export / ⋯ and "+ New Customer" in the top bar',
      (tester) async {
    await seed(tester);
    await pumpPage(tester, inFrame: true);
    expect(tester.takeException(), isNull);
    final topBar = find.byKey(const ValueKey('modernTopBar'));
    Finder inBar(Finder f) => find.descendant(of: topBar, matching: f);
    expect(inBar(find.text('Customer Management')), findsOneWidget);
    expect(inBar(find.text('Manage your customers and contact details')), findsOneWidget);
    expect(inBar(find.byKey(const ValueKey('modernCustomerImport'))), findsOneWidget);
    expect(inBar(find.byKey(const ValueKey('modernCustomerExport'))), findsOneWidget);
    expect(inBar(find.byKey(const ValueKey('modernCustomerMore'))), findsOneWidget);
    expect(find.byType(PopupMenuButton<ModernCreate>), findsNothing);
    await tester.tap(inBar(find.byKey(const ValueKey('modernNewCustomer'))));
    await settle(tester);
    expect(find.text('Save Customer'), findsOneWidget, reason: 'the New Customer panel');
  });

  testWidgets('no overflow: narrow window and Tamil', (tester) async {
    await seed(tester);
    for (final (size, locale) in [
      (const Size(900, 800), null),
      (const Size(600, 900), null),
      (const Size(1366, 800), const Locale('ta')),
    ]) {
      await pumpPage(tester, size: size, locale: locale);
      expect(tester.takeException(), isNull, reason: '$size $locale');
      expect(find.byKey(const ValueKey('modernCustomerTable')), findsOneWidget);
    }
  });
}
