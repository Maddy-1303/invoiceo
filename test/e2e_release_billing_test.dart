// Release QA: the BILLING flow end to end, on the REAL screens, starting
// from a fresh, empty database each test.
//
// Modern layout (the default) through DashboardScreen: Products, Services,
// Customers, New Invoice / Quotation / Receipt, Created screen, drafts,
// Invoices list. A smoke pass in the Standard layout. Lifecycle steps that
// live behind list menus (payments, decline, trash, restore, delete) also
// run against the repositories the screens call, and every money figure is
// checked against InvoiceTotalsCalculator, the Dashboard and Reports.
//
// A test that shows a real app bug is kept with `skip: 'BUG: ...'` so the
// suite stays green; the bug is described in the skip reason.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_draft_service.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/database/payment_service.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/database/report_service.dart';
import 'package:invoiceo/domain/invoice_totals_calculator.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_shell.dart';
import 'package:invoiceo/layouts/ui_layout.dart';
import 'package:invoiceo/models/additional_cost.dart';
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
import 'package:invoiceo/screens/dashboard_screen.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/services/customer_statement_pdf_service.dart';
import 'package:invoiceo/services/invoice_pdf_services.dart';
import 'package:invoiceo/services/payment_receipt_service.dart';
import 'package:invoiceo/services/pdf/pdf_service.dart';

/// Hands the import screens a CSV file instead of opening the OS dialog.
class _FakePicker extends FilePicker {
  String? path;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final p = path;
    if (p == null) return null;
    return FilePickerResult(
        [PlatformFile(path: p, name: p.split('/').last, size: File(p).lengthSync())]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  var dbCounter = 0;
  final picker = _FakePicker();

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
    tmp = Directory.systemTemp.createTempSync('invoiceo_e2e_release');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
    FilePicker.platform = picker;
  });
  tearDownAll(() async {
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });
  setUp(() {
    // Nothing is ever sent to a printer or a preview window.
    InvoicePdfServices.printHook = (c, i) async {};
    InvoicePdfServices.previewHook = (c, i) async {};
  });
  tearDown(() {
    InvoicePdfServices.printHook = null;
    InvoicePdfServices.previewHook = null;
    picker.path = null;
  });

  Future<void> settle(WidgetTester tester, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<T> db<T>(WidgetTester tester, Future<T> Function() fn) async =>
      (await tester.runAsync(fn)) as T;

  final admin = User(id: 'u1', username: 'admin', password: 'x', userType: 'admin');

  /// A fresh, empty database, then the whole app (DashboardScreen) on top.
  Future<void> openApp(WidgetTester tester,
      {UiLayout layout = UiLayout.modern,
      Size size = const Size(1700, 1050),
      Future<void> Function()? seed}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('e2e_release_${dbCounter++}.db');
      await BackendServices.settings.setSetting(SettingKey.uiLayout, layout.name);
      if (seed != null) await seed();
    });
    final container = ProviderContainer(overrides: sqliteRepositoryOverrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DashboardScreen(admin),
      ),
    ));
    await settle(tester);
  }

  Future<void> nav(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(ValueKey('modernNav_$label')));
    await settle(tester);
  }

  Finder tff(String label) => find.widgetWithText(TextFormField, label);
  Finder tf(String label) => find.widgetWithText(TextField, label);

  Future<void> clearSnacks(WidgetTester tester) async {
    for (final e in find.byType(Scaffold).evaluate()) {
      ScaffoldMessenger.maybeOf(e)?.clearSnackBars();
    }
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  // Sync: real file IO never completes inside testWidgets' fake clock.
  String writeCsv(String name, String content) {
    final f = File('${tmp.path}/$name');
    f.writeAsBytesSync(utf8.encode(content));
    return f.path;
  }

  Product prod(String id, String name, double price,
          {double stock = 100,
          int tax = 0,
          String hsn = '',
          bool unlimited = false,
          bool incl = false,
          double purchase = 0,
          String type = 'product',
          String unit = ''}) =>
      Product(
          id: id,
          name: name,
          description: '',
          price: price,
          stock: stock,
          hsncode: hsn,
          tax_rate: tax,
          unlimitedStock: unlimited,
          priceIncludesTax: incl,
          purchasePrice: purchase,
          type: type,
          unit: unit);

  /// A test that shows a real app bug: kept skipped (with the bug in the
  /// reason) so the suite stays green. `--run-skipped` runs it.
  void bugWidgets(String name, String bug, WidgetTesterCallback body,
          {Timeout? timeout}) =>
      group(name, () => testWidgets('repro', body, timeout: timeout), skip: bug);

  /// A bug repro whose bug is fixed: runs every time now.
  void fixedWidgets(String name, String bug, WidgetTesterCallback body,
          {Timeout? timeout}) =>
      testWidgets(name, body, timeout: timeout);

  /// The test font draws every letter 1em wide, so the long menu labels of
  /// the list's ⋮ menu overflow their 256 px row in tests only (real fonts
  /// fit). Those layout warnings are dropped while [body] runs; everything
  /// else still fails the test.
  Future<void> ignoringTestFontOverflow(Future<void> Function() body) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      prev?.call(d);
    };
    try {
      await body();
    } finally {
      FlutterError.onError = prev;
    }
  }

  Future<double> stockOf(WidgetTester tester, String id) async =>
      (await db<dynamic>(tester, () => ProductService.getProductById(id)))!.stock;


  // ── New Invoice page helpers ───────────────────────────────────────────────
  final searchBox = find.widgetWithText(TextField, 'Search & add a product or service (Ctrl+F)');
  final customerName = find.byKey(const ValueKey('modernCustomerName'));
  final money = NumberFormat('#,##0.00', 'en_US');

  /// Types [query] in the product search, presses Enter, fills the add
  /// prompt (quantity [qty] when given) and presses Add (and "Add Anyway"
  /// when the stock is short).
  Future<void> addItem(WidgetTester tester, String query, {String? qty}) async {
    await tester.tap(searchBox);
    await tester.pump();
    await tester.enterText(searchBox, query);
    await settle(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget, reason: 'the add prompt for "$query"');
    if (qty != null) {
      await tester.enterText(
          find.descendant(of: dialog, matching: find.byType(TextField)).first, qty);
      await tester.pump();
    }
    await tester.tap(find.descendant(of: dialog, matching: find.bySubtype<ButtonStyleButton>()).last);
    await tester.pump();
    await settle(tester);
    final anyway = find.text('Add Anyway');
    if (anyway.evaluate().isNotEmpty) {
      await tester.tap(anyway);
      await settle(tester);
    }
  }

  Future<void> pickCustomer(WidgetTester tester, String typed, String name) async {
    await tester.tap(customerName);
    await tester.enterText(customerName, typed);
    await settle(tester);
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('customerSuggestionList')), matching: find.text(name)));
    await settle(tester);
  }

  Future<void> walkIn(WidgetTester tester, String name) async {
    await tester.tap(customerName);
    await tester.enterText(customerName, name);
    await tester.pump();
  }

  Future<void> cell(WidgetTester tester, String key, String value) async {
    await tester.enterText(find.byKey(ValueKey(key)), value);
    await tester.pump();
  }

  Future<void> openAdvanced(WidgetTester tester) async {
    if (find.text('Tax settings').evaluate().isEmpty &&
        find.text('TAX SETTINGS').evaluate().isEmpty) {
      await tester.ensureVisible(find.byKey(const ValueKey('modernAdvancedOptions')));
      await tester.tap(find.byKey(const ValueKey('modernAdvancedOptions')));
      await tester.pump();
    }
  }

  Future<void> perItemTax(WidgetTester tester) async {
    await openAdvanced(tester);
    await tester.ensureVisible(find.byTooltip('Per item rate'));
    await tester.tap(find.byTooltip('Per item rate'));
    await tester.pump();
  }

  Future<void> interState(WidgetTester tester) async {
    await openAdvanced(tester);
    final sw = find.descendant(
        of: find.ancestor(of: find.text('Interstate supply (IGST)'), matching: find.byType(Row)).first,
        matching: find.byType(Switch));
    await tester.ensureVisible(sw);
    await tester.tap(sw);
    await tester.pump();
  }

  Future<void> openCharges(WidgetTester tester) async {
    if (find.text('Add Row').evaluate().isEmpty) {
      await tester.ensureVisible(find.byKey(const ValueKey('modernCharges')));
      await tester.tap(find.byKey(const ValueKey('modernCharges')));
      await tester.pump();
    }
  }

  Future<void> addCharge(WidgetTester tester, String label, String amount) async {
    await openCharges(tester);
    await tester.ensureVisible(find.text('Add Row'));
    await tester.tap(find.text('Add Row'));
    await tester.pump();
    final labels = find.widgetWithText(TextField, 'Label');
    final amounts = find.widgetWithText(TextField, 'Amount');
    if (label.isNotEmpty) await tester.enterText(labels.last, label);
    await tester.enterText(amounts.last, amount);
    await tester.pump();
  }

  Future<void> invoiceDiscount(WidgetTester tester, String value) async {
    await openCharges(tester);
    final f = find.widgetWithText(TextField, 'Invoice Discount');
    await tester.ensureVisible(f);
    await tester.enterText(f, value);
    await tester.pump();
  }

  Future<void> create(WidgetTester tester) async {
    await clearSnacks(tester);
    final b = find.byKey(const ValueKey('modernCreate'));
    await tester.ensureVisible(b);
    await tester.tap(b);
    await settle(tester);
    await settle(tester);
  }

  Future<Invoice> onlyInvoice(WidgetTester tester, {String type = 'Invoice'}) async {
    final all = (await db(tester, InvoiceService.getAllInvoices)).where((i) => i.type == type);
    expect(all, hasLength(1));
    return (await db<dynamic>(tester, () => InvoiceService.getInvoiceById(all.single.id)))!;
  }

  /// The totals the way every report computes them, from the saved rows.
  InvoiceTotals calc(Invoice inv) => InvoiceTotalsCalculator.totals(
        lines: inv.items.map((i) => InvoiceTotalsCalculator.line(
            price: i.effectivePrice,
            quantity: i.quantity,
            discount: i.discount,
            discountPerUnit: i.discountPerUnit,
            extraCost: i.extraCost ?? 0,
            taxRatePercent: i.product.tax_rate.toDouble(),
            priceIncludesTax: i.product.priceIncludesTax,
            taxMode: inv.taxMode,
            globalTaxRatePercent: inv.taxRate * 100)),
        taxMode: inv.taxMode,
        globalTaxRate: inv.taxRate,
        additionalCostsTotal: inv.additionalCosts.fold(0.0, (s, c) => s + c.amount),
        invoiceDiscountType: inv.invoiceDiscountType,
        invoiceDiscountValue: inv.invoiceDiscountValue,
      );

  Future<void> seedShop() async {
    await ProductService.insertProduct(
        prod('rice', 'Basmati Rice', 100, stock: 50, tax: 18, hsn: '1006', purchase: 80, unit: 'kg'));
    await ProductService.insertProduct(
        prod('dal', 'Toor Dal', 118, stock: 20, tax: 18, hsn: '0713', incl: true, purchase: 90));
    await ProductService.insertProduct(prod('cut', 'Haircut', 200,
        tax: 18, hsn: '9997', unlimited: true, type: 'service'));
    await ProductService.insertProduct(prod('oil', 'Sunflower Oil', 150, stock: 2, tax: 5, hsn: '1512'));
    await CustomerService.insertCustomer(Customer(
        id: 'c1', name: 'Arun Kumar', email: '', phone: '9000000001',
        address: '12, Bazaar Street', gstin: '29AAAAA0000A1Z5', businessName: 'Arun Traders'));
  }

  // ════════════════════════════════════════════════════════════════════════
  group('Products (Modern, through the dashboard)', () {
    testWidgets('add a product with every field, then a service; both are saved exactly',
        (tester) async {
      await openApp(tester);
      await nav(tester, 'Products');
      expect(find.text('Add your first product to get started'), findsOneWidget,
          reason: 'empty database');
      await tester.tap(find.byKey(const ValueKey('modernNewProduct')));
      await settle(tester);
      await tester.enterText(tff('Name'), 'Basmati Rice 5kg');
      await tester.enterText(tff('Alias Name (for invoice PDF)'), 'BR5');
      await tester.enterText(tff('HSN/SAC'), '01006');
      await tester.enterText(tff('Sale Price'), '590');
      await tester.enterText(tff('Purchase Price'), '450');
      await tester.enterText(tff('Tax (%)'), '18');
      await tester.enterText(tff('Stock'), '40');
      // The "Price includes tax" box: the checkbox nearest to its label.
      final label = tester.getCenter(find.text('Price includes tax'));
      final boxes = find.byType(Checkbox).evaluate().toList()
        ..sort((a, b) => (tester.getCenter(find.byWidget(a.widget)) - label).distance
            .compareTo((tester.getCenter(find.byWidget(b.widget)) - label).distance));
      await tester.ensureVisible(find.byWidget(boxes.first.widget));
      await tester.pump();
      await tester.tap(find.byWidget(boxes.first.widget));
      await tester.pump();
      final unit = find.byWidgetPredicate((w) => w is DropdownButtonFormField<String>);
      await tester.ensureVisible(unit.first);
      await tester.tap(unit.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('KG').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Product'));
      await tester.tap(find.text('Save Product'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      final all = await db(tester, ProductService.getAllProducts);
      final p = all.singleWhere((p) => p.name == 'Basmati Rice 5kg');
      expect(p.aliasName, 'BR5');
      expect(p.hsncode, '01006', reason: 'leading zero kept');
      expect(p.price, 590);
      expect(p.purchasePrice, 450);
      expect(p.tax_rate, 18);
      expect(p.stock, 40);
      expect(p.unit, 'kg');
      expect(p.priceIncludesTax, isTrue);
      expect(p.unlimitedStock, isFalse);
      expect(p.type, 'product');
      expect(find.byKey(ValueKey('prodRow_${p.id}')), findsOneWidget);

      // A service on the Services page.
      await nav(tester, 'Services');
      await tester.tap(find.byKey(const ValueKey('modernNewProduct')));
      await settle(tester);
      await tester.enterText(tff('Name'), 'Home Delivery');
      await tester.enterText(tff('Sale Price'), '50');
      await tester.tap(find.text('Save Service'));
      await settle(tester);
      final svc = (await db(tester, ProductService.getAllProducts))
          .singleWhere((p) => p.name == 'Home Delivery');
      expect(svc.type, 'service');
      expect(svc.unlimitedStock, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('duplicate, edit and delete a product; stock status chips', (tester) async {
      await openApp(tester, seed: () async {
        await ProductService.insertProduct(prod('p1', 'Sugar', 45, stock: 50));
        await ProductService.insertProduct(prod('p2', 'Salt', 20, stock: 3));
        await ProductService.insertProduct(prod('p3', 'Ghee', 600, stock: 0));
      });
      await nav(tester, 'Products');
      Finder row(String id) => find.byKey(ValueKey('prodRow_$id'));
      expect(find.descendant(of: row('p2'), matching: find.text('Low Stock')), findsOneWidget);
      expect(find.descendant(of: row('p3'), matching: find.text('Out of Stock')), findsOneWidget);
      expect(find.text('Low Stock (1)'), findsOneWidget);
      expect(find.text('Out of Stock (1)'), findsOneWidget);
      expect(find.text('In Stock (1)'), findsOneWidget);

      // Duplicate opens the copy's edit form.
      await tester.tap(find.byKey(const ValueKey('prodDuplicate_p1')));
      await settle(tester);
      final copy = (await db(tester, ProductService.getAllProducts))
          .singleWhere((p) => p.name == 'Sugar (copy)');
      expect(copy.stock, 0);
      expect(copy.price, 45);
      Navigator.of(tester.element(find.text('Edit Product').first)).pop();
      await settle(tester);

      // Edit Sugar's price.
      await tester.tap(find.byKey(const ValueKey('prodEdit_p1')));
      await settle(tester);
      await tester.enterText(find.descendant(of: find.byType(Dialog), matching: tf('Price')), '48');
      await tester.tap(find.text('Save Changes'));
      await settle(tester);
      expect((await db<dynamic>(tester, () => ProductService.getProductById('p1')))!.price, 48);

      // Delete the copy.
      await tester.tap(find.byKey(ValueKey('prodDelete_${copy.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Delete')));
      await settle(tester);
      expect(await db<dynamic>(tester, () => ProductService.getProductById(copy.id)), isNull);
      expect(row(copy.id), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CSV import: Windows line ends, leading zeros, quoted commas', (tester) async {
      await openApp(tester);
      await nav(tester, 'Products');
      picker.path = writeCsv(
          'products.csv',
          'name,price,hsn_code,tax_rate,stock,unit,purchase_price,alias_name\r\n'
          '"Rice, Premium",120,01006,5,30,kg,100,"RP, 1"\r\n'
          'Milk 500ml,28,0401,0,12,pcs,24,\r\n'
          'Paneer,90,0406,5,0,pcs,70,\r\n');
      await tester.tap(find.byKey(const ValueKey('modernProductImport')));
      await settle(tester);
      await tester.tap(find.text('Choose File'));
      await settle(tester);
      await tester.tap(find.text('Import 3'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      final all = await db(tester, ProductService.getAllProducts);
      expect(all, hasLength(3), reason: 'CRLF rows did not merge');
      final rice = all.singleWhere((p) => p.name == 'Rice, Premium');
      expect(rice.hsncode, '01006');
      expect(rice.tax_rate, 5);
      expect(rice.stock, 30);
      expect(rice.unit, 'kg');
      expect(rice.aliasName, 'RP, 1');
      expect(all.singleWhere((p) => p.name == 'Milk 500ml').hsncode, '0401');
      final paneer = all.singleWhere((p) => p.name == 'Paneer');
      expect(paneer.stock, 0);
      expect(find.text('Out of Stock (1)'), findsOneWidget);
    });

    fixedWidgets('CSV import: a decimal tax rate like "18.0" keeps 18%',
        'BUG: CSV tax_rate "18.0" (as written by Excel/Sheets) is parsed with '
            'int.tryParse and silently imported as 0% tax '
            '(product_management_screen_v2.dart _importFromCSV)', (tester) async {
      await openApp(tester);
      await nav(tester, 'Products');
      picker.path = writeCsv('decimal_tax.csv', 'name,price,tax_rate,stock\nSoap,40,18.0,10\n');
      await tester.tap(find.byKey(const ValueKey('modernProductImport')));
      await settle(tester);
      await tester.tap(find.text('Choose File'));
      await settle(tester);
      await tester.tap(find.text('Import 1'));
      await settle(tester);
      final soap = (await db(tester, ProductService.getAllProducts)).single;
      expect(soap.tax_rate, 18);
    });

    testWidgets('CSV import: a decimal stock like "12.5" is kept; 0.5 is Low Stock',
        (tester) async {
      await openApp(tester);
      await nav(tester, 'Products');
      picker.path = writeCsv('decimal_stock.csv',
          'name,price,stock,unit\nRice,60,12.5,kg\nGhee,600,0.5,kg\nSalt,20,30,pcs\n');
      await tester.tap(find.byKey(const ValueKey('modernProductImport')));
      await settle(tester);
      await tester.tap(find.text('Choose File'));
      await settle(tester);
      await tester.tap(find.text('Import 3'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      final all = await db(tester, ProductService.getAllProducts);
      final rice = all.singleWhere((p) => p.name == 'Rice');
      final ghee = all.singleWhere((p) => p.name == 'Ghee');
      final salt = all.singleWhere((p) => p.name == 'Salt');
      expect(rice.stock, 12.5);
      expect(ghee.stock, 0.5);
      expect(salt.stock, 30);
      Finder inRow(Product p, String text) => find.descendant(
          of: find.byKey(ValueKey('prodRow_${p.id}')), matching: find.text(text));
      expect(inRow(rice, '12.5'), findsOneWidget);
      expect(inRow(ghee, '0.5'), findsOneWidget);
      expect(inRow(ghee, 'Low Stock'), findsOneWidget, reason: '0 < 0.5 <= 10');
      expect(inRow(salt, '30'), findsOneWidget, reason: 'whole stock without ".0"');
      expect(find.text('Low Stock (1)'), findsOneWidget);
      expect(find.text('In Stock (2)'), findsOneWidget);
    });

    bugWidgets('CSV import: the same new name twice in one file makes one product',
        'BUG: two rows with the same new product name in one CSV are both '
            'inserted (duplicates are only looked up in the database, not within '
            'the file) — product_management_screen_v2.dart _importFromCSV', (tester) async {
      await openApp(tester);
      await nav(tester, 'Products');
      picker.path = writeCsv('dupe.csv', 'name,price,stock\nTea,10,5\nTea,12,6\n');
      await tester.tap(find.byKey(const ValueKey('modernProductImport')));
      await settle(tester);
      await tester.tap(find.text('Choose File'));
      await settle(tester);
      await tester.tap(find.textContaining('Import ').last);
      await settle(tester);
      final teas = (await db(tester, ProductService.getAllProducts))
          .where((p) => p.name == 'Tea');
      expect(teas, hasLength(1));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  group('Customers (Modern, through the dashboard)', () {
    testWidgets('add a business and an individual, edit one, CSV import', (tester) async {
      await openApp(tester);
      await nav(tester, 'Customers');
      Future<void> add(Map<String, String> fields) async {
        await tester.tap(find.byKey(const ValueKey('modernNewCustomer')));
        await settle(tester);
        for (final e in fields.entries) {
          await tester.enterText(tff(e.key), e.value);
        }
        await tester.tap(find.text('Save Customer'));
        await settle(tester);
      }

      await add({
        'Name': 'Arun Kumar',
        'Business Name': 'Arun Traders',
        'Phone': '9000000001',
        'GST / VAT Number': '33AAAAA0000A1Z5',
        'Address': '12, Bazaar Street, Madurai',
      });
      await add({'Name': 'Kavya', 'Phone': '9000000002'});
      expect(tester.takeException(), isNull);
      var all = await db(tester, CustomerService.getAllCustomers);
      expect(all.map((c) => c.name).toSet(), {'Arun Kumar', 'Kavya'});
      final arun = all.singleWhere((c) => c.name == 'Arun Kumar');
      expect(arun.businessName, 'Arun Traders');
      expect(arun.gstin, '33AAAAA0000A1Z5');

      // Edit Kavya's address.
      final kavya = all.singleWhere((c) => c.name == 'Kavya');
      await tester.tap(find.byKey(ValueKey('custEdit_${kavya.id}')));
      await settle(tester);
      await tester.enterText(
          find.descendant(of: find.byType(Dialog), matching: tff('Address')), '4, Lake View');
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Update')));
      await settle(tester);
      expect((await db<dynamic>(tester, () => CustomerService.getCustomerById(kavya.id)))!.address,
          '4, Lake View');

      // CSV import: CRLF, a phone with a leading 0, a quoted comma.
      picker.path = writeCsv(
          'customers.csv',
          'name,phone,email,address,business_name,tax_number\r\n'
          'Selvi,04522345678,,"7, Car Street, Madurai",,\r\n'
          'Ravi,9000000003,ravi@x.in,,Ravi & Co,\r\n');
      await tester.tap(find.byKey(const ValueKey('modernCustomerImport')));
      await settle(tester);
      await tester.tap(find.text('Choose File'));
      await settle(tester);
      await tester.tap(find.text('Import 2'));
      await settle(tester);
      all = await db(tester, CustomerService.getAllCustomers);
      expect(all, hasLength(4));
      final selvi = all.singleWhere((c) => c.name == 'Selvi');
      expect(selvi.phone, '04522345678');
      expect(selvi.address, '7, Car Street, Madurai');
      expect(tester.takeException(), isNull);
    });

    fixedWidgets('adding a customer with a phone that is already saved is refused',
        'BUG: the Customers page "New Customer" panel saves a second customer '
            'with the same phone (no duplicate check; the invoice screen does check) — '
            'customer_management_screen_v2.dart _handleAddOrUpdateCustomer', (tester) async {
      await openApp(tester, seed: () async {
        await CustomerService.insertCustomer(Customer(
            id: 'c1', name: 'Arun', email: '', phone: '9000000001', address: '', gstin: ''));
      });
      await nav(tester, 'Customers');
      await tester.tap(find.byKey(const ValueKey('modernNewCustomer')));
      await settle(tester);
      await tester.enterText(tff('Name'), 'Arun Again');
      await tester.enterText(tff('Phone'), '9000000001');
      await tester.tap(find.text('Save Customer'));
      await settle(tester);
      expect(await db(tester, CustomerService.getAllCustomers), hasLength(1));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  group('Invoice (Modern, through the dashboard)', () {
    testWidgets(
        'mixed invoice: customer, search, table edits, custom item, charges, per-item tax, '
        'IGST; stock, number, totals; Created screen; Create New resets everything',
        (tester) async {
      await openApp(tester, seed: seedShop);
      await nav(tester, 'New Invoice');
      expect(find.text('Create New Invoice'), findsWidgets);

      await pickCustomer(tester, 'Arun', 'Arun Kumar');
      await perItemTax(tester);
      await interState(tester);

      await addItem(tester, 'Basmati');
      await cell(tester, 'qty_0', '3');
      await cell(tester, 'price_0', '110');
      await cell(tester, 'disc_0', '10');
      await addItem(tester, 'Toor', qty: '2');
      await addItem(tester, 'Haircut');

      // Custom item: Gift Wrap, 25 x 2, no tax.
      await tester.ensureVisible(find.byKey(const ValueKey('modernCustomItem')));
      await tester.tap(find.byKey(const ValueKey('modernCustomItem')));
      await tester.pumpAndSettle();
      final dlg = find.byType(AlertDialog);
      await tester.enterText(find.descendant(of: dlg, matching: tf('Item Name')), 'Gift Wrap');
      await tester.enterText(find.descendant(of: dlg, matching: tf('Unit Price')), '25');
      await tester.enterText(find.descendant(of: dlg, matching: tf('Quantity')), '2');
      await tester.tap(find.descendant(of: dlg, matching: find.text('Add')));
      await settle(tester);
      expect(find.byKey(const ValueKey('itemRow3')), findsOneWidget);

      await addCharge(tester, 'Packing', '20');
      await addCharge(tester, '', '15'); // no label
      expect(tester.takeException(), isNull);

      // Per item: rice 300 (+54), dal 236 incl -> 200 (+36), haircut 200 (+36),
      // wrap 50 (+0); charges 35 -> 750 + 126 + 35 = 911.
      final totals = find.byKey(const ValueKey('modernTotals'));
      expect(find.descendant(of: totals, matching: find.textContaining('911.00')), findsWidgets);

      await create(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('modernSuccess')), findsOneWidget);
      final inv = await onlyInvoice(tester);
      expect(inv.invoiceNumber, '00000001');
      // The number as the PDF prints it: the default "INV-" prefix.
      await settle(tester);
      expect(find.descendant(of: find.byKey(const ValueKey('modernSuccessId')),
          matching: find.text('INV-00000001')), findsOneWidget);
      expect(inv.customer.id, 'c1', reason: 'linked to the picked customer');
      expect(inv.customer.gstin, '29AAAAA0000A1Z5');
      expect(inv.taxMode, TaxMode.perItem);
      expect(inv.isInterState, isTrue);
      expect(inv.items.map((i) => i.product.name).toList(),
          ['Basmati Rice', 'Toor Dal', 'Haircut', 'Gift Wrap']);
      final rice = inv.items[0];
      expect(rice.quantity, 3);
      expect(rice.effectivePrice, 110);
      expect(rice.discount, 10);
      expect(inv.additionalCosts.map((c) => '${c.label}=${c.amount}').toList(),
          ['Packing=20.0', 'Extra Cost=15.0'], reason: 'a charge with no label still counts');
      final t = calc(inv);
      expect(t.subtotal, closeTo(750, 0.001));
      expect(t.tax, closeTo(126, 0.001));
      expect(t.total, closeTo(911, 0.001));
      expect(inv.total, closeTo(t.total, 0.001));
      expect(inv.subtotal, closeTo(t.subtotal, 0.001));
      expect(inv.tax, closeTo(t.tax, 0.001));

      expect(await stockOf(tester, 'rice'), 47);
      expect(await stockOf(tester, 'dal'), 18);
      expect(await stockOf(tester, 'cut'), 100, reason: 'unlimited: untouched');
      expect((await db(tester, ProductService.getAllProducts)).length, 4,
          reason: 'the custom item is not added to the catalogue');

      // Created screen -> Create New Invoice: a blank form, defaults back.
      await tester.tap(find.byKey(const ValueKey('modernSuccessNewInvoice')));
      await settle(tester);
      expect(find.byKey(const ValueKey('modernSuccess')), findsNothing);
      expect(find.byKey(const ValueKey('itemRow0')), findsNothing);
      expect(tester.widget<TextField>(customerName).controller!.text, isEmpty);
      await openAdvanced(tester);
      final seg = tester.widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>));
      expect(seg.selected, {false}, reason: 'back to the global rate');
      final igst = tester.widget<Switch>(find.descendant(
          of: find.ancestor(of: find.text('Interstate supply (IGST)'), matching: find.byType(Row)).first,
          matching: find.byType(Switch)));
      expect(igst.value, isFalse, reason: 'IGST off again');
      expect(find.text('Packing'), findsNothing);
      expect(find.widgetWithText(TextField, 'Label'), findsNothing, reason: 'no charge rows');

      // Second invoice: global 18% (the default), 10% invoice discount.
      await walkIn(tester, 'Counter Sale');
      await addItem(tester, 'Basmati');
      await invoiceDiscount(tester, '10');
      await create(tester);
      final all = await db(tester, InvoiceService.getAllInvoices);
      final second = (await db<dynamic>(tester, () => InvoiceService.getInvoiceById(
          all.singleWhere((i) => i.invoiceNumber == '00000002').id)))!;
      expect(second.taxMode, TaxMode.global);
      expect(second.taxRate, closeTo(0.18, 1e-9));
      expect(second.invoiceDiscountValue, 10);
      expect(second.total, closeTo(106.2, 0.001), reason: '(100 + 18) - 10%');
      expect(calc(second).total, closeTo(second.total, 0.001));
      expect(await stockOf(tester, 'rice'), 46);

      // Create New after a discount: the discount box is empty again.
      await tester.tap(find.byKey(const ValueKey('modernSuccessNewInvoice')));
      await settle(tester);
      await openCharges(tester);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Invoice Discount'))
          .controller!.text, isEmpty);

      // Dashboard: nothing collected, both invoices outstanding.
      await nav(tester, 'Dashboard');
      await settle(tester);
      expect(find.textContaining(money.format(911 + 106.2)), findsWidgets,
          reason: 'outstanding on the dashboard');
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  // ════════════════════════════════════════════════════════════════════════
  group('Invoice lifecycle (Invoices list menus)', () {
    Future<void> quickInvoice(WidgetTester tester, String customer, String item, String qty) async {
      await nav(tester, 'New Invoice');
      await walkIn(tester, customer);
      await addItem(tester, item, qty: qty);
      await create(tester);
      expect(find.byKey(const ValueKey('modernSuccess')), findsOneWidget);
    }

    Future<void> rowMenu(WidgetTester tester, String id, String action) =>
        ignoringTestFontOverflow(() async {
          await tester.tap(find.byKey(ValueKey('rowMenu_$id')));
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          await tester.tap(find.text(action).last);
          await settle(tester);
        });

    Future<void> confirmDialog(WidgetTester tester, String label) async {
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(label)).last);
      await settle(tester);
    }

    testWidgets('edit takes stock once; partial then full payment; decline returns stock; '
        'trash returns it, restore takes it again; delete for good', (tester) async {
      await openApp(tester, seed: seedShop);
      await quickInvoice(tester, 'Meena', 'Basmati', '5');
      expect(await stockOf(tester, 'rice'), 45);

      // Edit from the Invoices list: 5 -> 7 takes 2 more, not 7.
      await nav(tester, 'Invoices');
      expect(find.text('#00000001'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rowEdit_00000001')));
      await settle(tester);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('qty_0'))).controller!.text, '5');
      await cell(tester, 'qty_0', '7');
      await create(tester);
      expect(tester.takeException(), isNull);
      expect(await stockOf(tester, 'rice'), 43, reason: 'stock adjusted once');
      var inv = (await db<dynamic>(tester, () => InvoiceService.getInvoiceById('00000001')))! as Invoice;
      expect(inv.items.single.quantity, 7);
      expect(inv.total, closeTo(826, 0.001), reason: '7 x 100 + 18%');
      expect((await db(tester, InvoiceService.getAllInvoices)).length, 1, reason: 'no copy made');

      // Partial payment through the Apply Payment dialog.
      await nav(tester, 'Invoices');
      await rowMenu(tester, '00000001', 'Apply Payment');
      final dlg = find.byType(Dialog);
      await tester.enterText(find.descendant(of: dlg, matching: find.byType(TextFormField)).first, '300');
      await tester.pump();
      await tester.tap(find.descendant(of: dlg, matching: find.text('Record Payment')).last);
      await settle(tester);
      expect(tester.takeException(), isNull);
      inv = (await db<dynamic>(tester, () => InvoiceService.getInvoiceById('00000001')))! as Invoice;
      expect(inv.amountPaid, 300);
      expect(inv.paymentStatus, PaymentStatus.partial);
      var fin = await db(tester, InvoiceService.getDashboardFinancials);
      expect(fin.revenue, closeTo(300, 0.001));
      expect(fin.outstanding, closeTo(526, 0.001));
      // The rest (the dialog fills in what is still owed).
      await tester.enterText(find.descendant(of: dlg, matching: find.byType(TextFormField)).first, '526');
      await tester.pump();
      await tester.tap(find.descendant(of: dlg, matching: find.text('Record Payment')).last);
      await settle(tester);
      Navigator.of(tester.element(dlg)).pop();
      await settle(tester);
      inv = (await db<dynamic>(tester, () => InvoiceService.getInvoiceById('00000001')))! as Invoice;
      expect(inv.paymentStatus, PaymentStatus.paid);
      fin = await db(tester, InvoiceService.getDashboardFinancials);
      expect(fin.revenue, closeTo(826, 0.001));
      expect(fin.outstanding, closeTo(0, 0.001));

      // A paid invoice cannot be edited below what was paid.
      Object? err;
      await tester.runAsync(() async {
        try {
          final cut = (await InvoiceService.getInvoiceById('00000001'))!;
          cut.items.single.quantity = 1;
          await InvoiceService.updateInvoice(cut);
        } catch (e) {
          err = e;
        }
      });
      expect(err, isA<StateError>());
      expect(await stockOf(tester, 'rice'), 43, reason: 'a refused edit moves no stock');

      // Decline a second invoice: its stock comes back.
      await quickInvoice(tester, 'Ravi', 'Basmati', '2');
      expect(await stockOf(tester, 'rice'), 41);
      await nav(tester, 'Invoices');
      await rowMenu(tester, '00000002', 'Mark as declined');
      await confirmDialog(tester, 'Mark as declined');
      expect(await stockOf(tester, 'rice'), 43, reason: 'declined: stock back');
      expect((await db<dynamic>(tester, () => InvoiceService.getInvoiceById('00000002')))!.status,
          'declined');
      // declining again (a second click) gives nothing back twice
      await db(tester, () => InvoiceService.declineInvoice('00000002'));
      expect(await stockOf(tester, 'rice'), 43);

      // Trash a third: stock back; restore: taken again; trash + delete for good.
      await quickInvoice(tester, 'Selvi', 'Toor', '3');
      expect(await stockOf(tester, 'dal'), 17);
      await nav(tester, 'Invoices');
      await rowMenu(tester, '00000003', 'Move to Trash');
      await confirmDialog(tester, 'Move to Trash');
      expect(await stockOf(tester, 'dal'), 20, reason: 'trashed: stock back');
      expect(find.text('#00000003'), findsNothing);
      await db(tester, () => InvoiceService.restoreInvoice('00000003'));
      expect(await stockOf(tester, 'dal'), 17, reason: 'restored: taken again');
      await db(tester, () => InvoiceService.softDeleteInvoice('00000003'));
      await db(tester, () => InvoiceService.softDeleteInvoice('00000003')); // twice: no-op
      expect(await stockOf(tester, 'dal'), 20);
      await db(tester, () => InvoiceService.permanentDeleteInvoice('00000003'));
      expect(await stockOf(tester, 'dal'), 20, reason: 'deleting from Trash gives nothing back twice');
      expect(await db<dynamic>(tester, () => InvoiceService.getInvoiceById('00000003')), isNull);

      // Deleting the newest invoice for good frees its number again.
      expect(await db(tester, () => InvoicePdfServices.peekNextInvoiceNumber('Invoice')), '00000003');
      fin = await db(tester, InvoiceService.getDashboardFinancials);
      expect(fin.count, 1, reason: 'declined and deleted invoices are not counted');
      expect(fin.revenue, closeTo(826, 0.001));

      // The Dashboard and Reports pages show the same money.
      await nav(tester, 'Dashboard');
      expect(find.textContaining(money.format(826)), findsWidgets, reason: 'collected');
      await nav(tester, 'Reports');
      await settle(tester);
      expect(find.textContaining(money.format(826)), findsWidgets, reason: 'Reports revenue');
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  // ════════════════════════════════════════════════════════════════════════
  group('Quotation, Receipt, drafts, walk-in (Modern)', () {
    Future<void> newDoc(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(const ValueKey('modernCreateMenu')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(PopupMenuItem<ModernCreate>), matching: find.text(label)));
      await settle(tester);
    }

    Future<void> rowMenu(WidgetTester tester, String id, String action) =>
        ignoringTestFontOverflow(() async {
          await tester.tap(find.byKey(ValueKey('rowMenu_$id')));
          for (var i = 0; i < 4; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          await tester.tap(find.text(action).last);
          await settle(tester);
        });

    testWidgets('quotation: no stock; sent, accepted; convert once (GST title); '
        'no second convert', (tester) async {
      await openApp(tester, seed: () async {
        await seedShop();
        await BackendServices.settings.setSetting(SettingKey.defaultInvoiceTitle, 'Tax Invoice');
      });
      await newDoc(tester, 'New Quotation');
      expect(find.text('Quotation Details'), findsOneWidget);
      await pickCustomer(tester, 'Arun', 'Arun Kumar');
      await addItem(tester, 'Basmati', qty: '4');
      await create(tester);
      final q = await onlyInvoice(tester, type: 'Quotation');
      expect(q.invoiceNumber, '00000001');
      expect(q.invoiceTitle, isNull, reason: 'a quotation has no GST title');
      expect(await stockOf(tester, 'rice'), 50, reason: 'a quotation takes no stock');

      await nav(tester, 'Quotations');
      await rowMenu(tester, q.id, 'Mark as sent');
      expect((await db<dynamic>(tester, () => InvoiceService.getInvoiceById(q.id)))!.status, 'sent');
      await rowMenu(tester, q.id, 'Mark as accepted');
      expect((await db<dynamic>(tester, () => InvoiceService.getInvoiceById(q.id)))!.status, 'accepted');

      await rowMenu(tester, q.id, 'Convert to Invoice');
      expect(find.byKey(const ValueKey('itemRow0')), findsOneWidget, reason: 'items carried over');
      await create(tester);
      expect(tester.takeException(), isNull);
      final inv = await onlyInvoice(tester);
      expect(inv.convertedFromInvoiceId, q.id);
      expect(inv.invoiceTitle, 'Tax Invoice', reason: 'the GST title default');
      expect(inv.invoiceNumber, '00000001', reason: 'invoices have their own sequence');
      expect(inv.customer.id, 'c1');
      expect(inv.total, closeTo(q.total, 0.001));
      expect(await stockOf(tester, 'rice'), 46, reason: 'stock taken once, at conversion');
      final converted = (await db<dynamic>(tester, () => InvoiceService.getInvoiceById(q.id)))! as Invoice;
      expect(converted.status, 'converted');
      expect(converted.convertedToInvoiceId, inv.id);

      // Create New on the Created screen: the next invoice is not linked to
      // the quotation and has the default title again.
      await tester.tap(find.byKey(const ValueKey('modernSuccessNewInvoice')));
      await settle(tester);
      expect(find.byKey(const ValueKey('itemRow0')), findsNothing);
      await walkIn(tester, 'Next Customer');
      await addItem(tester, 'Haircut');
      await create(tester);
      final next = (await db(tester, InvoiceService.getAllInvoices))
          .singleWhere((i) => i.invoiceNumber == '00000002' && i.type == 'Invoice');
      final nextFull = (await db<dynamic>(tester, () => InvoiceService.getInvoiceById(next.id)))! as Invoice;
      expect(nextFull.convertedFromInvoiceId, isNull, reason: 'no quotation link carried over');
      expect(nextFull.invoiceTitle, 'Tax Invoice');
      expect(nextFull.customer.id, isNot('c1'));
      final stillLinked = (await db<dynamic>(tester, () => InvoiceService.getInvoiceById(q.id)))! as Invoice;
      expect(stillLinked.convertedToInvoiceId, inv.id);

      // A converted quotation has no "Convert to Invoice" any more.
      await nav(tester, 'Quotations');
      await ignoringTestFontOverflow(() async {
        await tester.tap(find.byKey(ValueKey('rowMenu_${q.id}')));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('Convert to Invoice'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await settle(tester);
      });
      expect((await db(tester, InvoiceService.getAllInvoices)).where((i) => i.type == 'Invoice'),
          hasLength(2));
      expect(await stockOf(tester, 'rice'), 46);
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets(
        'a converted quotation cannot be converted into a second invoice', (tester) async {
      await openApp(tester, seed: seedShop);
      await newDoc(tester, 'New Quotation');
      await walkIn(tester, 'Meena');
      await addItem(tester, 'Basmati', qty: '4');
      await create(tester);
      final q = await onlyInvoice(tester, type: 'Quotation');
      await nav(tester, 'Quotations');
      await rowMenu(tester, q.id, 'Convert to Invoice');
      await create(tester);
      // The menu no longer offers it, and the database refuses a second one.
      final dup = Invoice(
          id: 'second', customer: q.customer,
          items: [for (final it in q.items) InvoiceItem(product: it.product, quantity: it.quantity)],
          date: DateTime.now(),
          type: 'Invoice', convertedFromInvoiceId: q.id);
      Object? err;
      await tester.runAsync(() async {
        try {
          await InvoiceService.insertInvoice(dup);
        } catch (e) {
          err = e;
        }
      });
      expect(err, isA<StateError>());
      expect((await db(tester, InvoiceService.getAllInvoices)).where((i) => i.type == 'Invoice'),
          hasLength(1));
      expect(await stockOf(tester, 'rice'), 46);
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('quotation draft round trip: Save Draft, Drafts tab, Continue, Create',
        (tester) async {
      await openApp(tester, seed: seedShop);
      await newDoc(tester, 'New Quotation');
      await walkIn(tester, 'Draft Devi');
      await addItem(tester, 'Toor', qty: '3');
      await tester.tap(find.byKey(const ValueKey('modernSaveDraft')));
      await settle(tester);
      expect(find.text('Draft saved'), findsOneWidget);
      final drafts = await db(tester, () => InvoiceDraftService.getDrafts('Quotation'));
      expect(drafts, hasLength(1));
      expect(drafts.single.invoice.items.single.quantity, 3);
      expect(await db(tester, InvoiceService.getAllInvoices), isEmpty, reason: 'a draft is not saved');
      expect(await stockOf(tester, 'dal'), 20);

      await nav(tester, 'Quotations');
      expect(find.byType(AlertDialog), findsNothing, reason: 'saved: no unsaved-changes prompt');
      await tester.tap(find.byKey(const ValueKey('modernTabDrafts')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('draftContinue_${drafts.single.id}')));
      await settle(tester);
      expect(tester.widget<TextField>(customerName).controller!.text, 'Draft Devi');
      expect(find.text('Quotation Details'), findsOneWidget, reason: 'still a quotation');
      expect(tester.widget<TextField>(find.byKey(const ValueKey('qty_0'))).controller!.text, '3');
      await create(tester);
      final q = await onlyInvoice(tester, type: 'Quotation');
      expect(q.items.single.quantity, 3);
      expect(await db(tester, () => InvoiceDraftService.countDrafts('Quotation')), 0);
      expect(await stockOf(tester, 'dal'), 20);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('an invoice draft with a picked customer stays linked to that customer',
        (tester) async {
      await openApp(tester, seed: seedShop);
      await nav(tester, 'New Invoice');
      await pickCustomer(tester, 'Arun', 'Arun Kumar');
      await addItem(tester, 'Basmati');
      await tester.tap(find.byKey(const ValueKey('modernSaveDraft')));
      await settle(tester);
      final d = (await db(tester, () => InvoiceDraftService.getDrafts('Invoice'))).single;
      await nav(tester, 'Invoices');
      await tester.tap(find.byKey(const ValueKey('modernTabDrafts')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('draftContinue_${d.id}')));
      await settle(tester);
      await create(tester);
      final inv = await onlyInvoice(tester);
      expect(inv.customer.id, 'c1');
      expect(await db(tester, () => InvoiceService.getOpenInvoicesForCustomer('c1')), hasLength(1));
    });

    testWidgets('receipt: takes stock, is paid, never outstanding, counts as revenue; '
        'receipts list shows it paid', (tester) async {
      await openApp(tester, seed: seedShop);
      await newDoc(tester, 'New Receipt');
      await walkIn(tester, 'Cash Customer');
      await addItem(tester, 'Basmati', qty: '2');
      await create(tester);
      expect(find.byKey(const ValueKey('modernSuccessNewReceipt')), findsOneWidget);
      final r = await onlyInvoice(tester, type: 'Receipt');
      expect(r.invoiceNumber, '00000001');
      expect(r.total, closeTo(236, 0.001));
      expect(r.paymentStatus, PaymentStatus.paid);
      expect(r.balanceDue, 0);
      expect(await stockOf(tester, 'rice'), 48);

      final fin = await db(tester, InvoiceService.getDashboardFinancials);
      expect(fin.revenue, closeTo(236, 0.001));
      expect(fin.outstanding, 0);
      expect(fin.count, 0, reason: 'invoices only');
      final now = DateTime.now();
      final kpi = await db(tester, () => ReportService.getRevenueSummary(
          DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0)));
      expect(kpi.collected, closeTo(236, 0.001));
      expect(kpi.outstanding, 0);
      expect(kpi.billed, closeTo(236, 0.001));

      await nav(tester, 'Receipts');
      expect(find.text('#00000001'), findsOneWidget);
      final row = find.ancestor(of: find.text('#00000001'), matching: find.byType(Row)).first;
      expect(find.descendant(of: row, matching: find.textContaining('Unpaid')), findsNothing);
      await nav(tester, 'Dashboard');
      expect(find.textContaining(money.format(236)), findsWidgets, reason: 'revenue on the dashboard');
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('unsaved changes prompt: Keep Editing, Discard, Save Draft, Save', (tester) async {
      await openApp(tester, seed: seedShop);
      await nav(tester, 'New Invoice');
      await walkIn(tester, 'Prompt Pandi');
      await addItem(tester, 'Basmati');

      await nav(tester, 'Dashboard');
      expect(find.text('Unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Keep Editing'));
      await settle(tester);
      expect(find.byKey(const ValueKey('itemRow0')), findsOneWidget, reason: 'still on the form');

      await nav(tester, 'Dashboard');
      await tester.tap(find.byKey(const ValueKey('leaveSaveDraft')));
      await settle(tester);
      expect(find.byKey(const ValueKey('modernDashboard')), findsOneWidget);
      final drafts = await db(tester, () => InvoiceDraftService.getDrafts('Invoice'));
      expect(drafts, hasLength(1));

      // Continue the draft, change it, Discard: the draft keeps its copy.
      await nav(tester, 'Invoices');
      await tester.tap(find.byKey(const ValueKey('modernTabDrafts')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('draftContinue_${drafts.single.id}')));
      await settle(tester);
      await cell(tester, 'qty_0', '9');
      await nav(tester, 'Dashboard');
      await tester.tap(find.text('Discard'));
      await settle(tester);
      expect((await db(tester, () => InvoiceDraftService.getDrafts('Invoice'))).single
          .invoice.items.single.quantity, 1);
      expect(await db(tester, InvoiceService.getAllInvoices), isEmpty);

      // Continue again, change it, Save: an invoice, and the draft is gone.
      await nav(tester, 'Invoices');
      await tester.tap(find.byKey(const ValueKey('modernTabDrafts')));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('draftContinue_${drafts.single.id}')));
      await settle(tester);
      await cell(tester, 'qty_0', '4');
      await nav(tester, 'Dashboard');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Save')).last);
      await settle(tester);
      await settle(tester);
      final inv = await onlyInvoice(tester);
      expect(inv.items.single.quantity, 4);
      expect(await db(tester, () => InvoiceDraftService.countDrafts('Invoice')), 0);
      expect(await stockOf(tester, 'rice'), 46);
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('walk-in customer saved from the Created screen is linked to the invoice',
        (tester) async {
      await openApp(tester, seed: seedShop);
      await nav(tester, 'New Invoice');
      await walkIn(tester, 'Lakshmi');
      await tester.enterText(find.byKey(const ValueKey('modernCustomerPhone')), '9888877777');
      await tester.pump();
      await addItem(tester, 'Basmati');
      await create(tester);
      expect(find.text('Save "Lakshmi" to your customer list for future use?'), findsOneWidget);
      final prompt = find.ancestor(
          of: find.text('Save "Lakshmi" to your customer list for future use?'),
          matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: prompt, matching: find.widgetWithText(TextButton, 'Save')));
      await settle(tester);
      final customers = await db(tester, CustomerService.getAllCustomers);
      final lakshmi = customers.singleWhere((c) => c.name == 'Lakshmi');
      expect(lakshmi.phone, '9888877777');
      final inv = await onlyInvoice(tester);
      expect(inv.customer.id, lakshmi.id, reason: 'the invoice points at the saved customer');
      final open = await db(tester, () => InvoiceService.getOpenInvoicesForCustomer(lakshmi.id));
      expect(open.map((i) => i.id), [inv.id]);
      expect(tester.takeException(), isNull);
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  group('Edge cases on the New Invoice page', () {
    testWidgets('no negative price, zero or empty quantity from the table; huge and '
        'very long values do not break the page', (tester) async {
      final longName = 'Extra Long Product Name ' * 12;
      await openApp(tester, seed: () async {
        await seedShop();
        await ProductService.insertProduct(
            prod('big', 'Gold Bar 1kg', 100000000, stock: 10, tax: 3, hsn: '7108'));
        await ProductService.insertProduct(prod('long', longName.trim(), 10, stock: 10, hsn: '4444'));
      });
      await nav(tester, 'New Invoice');
      await walkIn(tester, 'Customer ${'With A Very Long Name ' * 8}');
      await addItem(tester, 'Basmati');
      await cell(tester, 'price_0', '-5');
      await cell(tester, 'qty_0', '0');
      await cell(tester, 'qty_0', '');
      await addItem(tester, 'Gold Bar', qty: '3');
      await addItem(tester, '4444'); // the long one, by its HSN
      expect(tester.takeException(), isNull, reason: 'no overflow with long names / 10 crore');
      await create(tester);
      final inv = await onlyInvoice(tester);
      expect(inv.items[0].effectivePrice, 5,
          reason: 'a minus sign cannot be typed in the price cell: "-5" is 5, never negative');
      expect(inv.items[0].quantity, 1, reason: '0 or empty quantity is not taken');
      // Global 18% (the default mode): (3 x 10 crore + 5 + 10) x 1.18.
      expect(inv.total, closeTo((300000000 + 5 + 10) * 1.18, 0.01));
      expect(calc(inv).total, closeTo(inv.total, 0.01));
      expect(await stockOf(tester, 'big'), 7);
      expect(tester.takeException(), isNull);
      await nav(tester, 'Dashboard');
      expect(tester.takeException(), isNull);
    });

    fixedWidgets(
        'a per-unit discount bigger than the price cannot make a negative line',
        'BUG: the discount cell accepts any amount, so a discount of 150 on a 100 item '
            'saves a line of -50 (negative subtotal and negative tax that reduce the '
            "other lines) — create_invoice_screen_modern.dart _discountCell / _createInvoice",
        (tester) async {
      await openApp(tester, seed: seedShop);
      await nav(tester, 'New Invoice');
      await walkIn(tester, 'Discount');
      await addItem(tester, 'Basmati');
      await addItem(tester, 'Toor');
      await cell(tester, 'disc_0', '150');
      await create(tester);
      final all = await db(tester, InvoiceService.getAllInvoices);
      for (final i in all) {
        final full = (await db<dynamic>(tester, () => InvoiceService.getInvoiceById(i.id)))! as Invoice;
        expect(full.items.every((it) => it.total >= 0), isTrue);
        expect(full.tax, greaterThanOrEqualTo(0));
      }
    });

    fixedWidgets(
        'a quantity of 0 typed in the add prompt is refused',
        'BUG: the add-item prompt accepts quantity "0" (int.tryParse("0") = 0, no check) and '
            'Create saves an invoice line with quantity 0 — '
            'create_invoice_screen_modern.dart addInvoiceProductPrompt / _createInvoice '
            '(the table cell already ignores 0)', (tester) async {
      await openApp(tester, seed: seedShop);
      await nav(tester, 'New Invoice');
      await walkIn(tester, 'Zero');
      await addItem(tester, 'Basmati', qty: '0');
      await create(tester);
      final all = await db(tester, InvoiceService.getAllInvoices);
      expect(all.every((i) => i.items.every((it) => it.quantity > 0)), isTrue);
    });

    fixedWidgets(
        'fractional quantities take fractional stock',
        'BUG: products.stock is an int and every stock change rounds the quantity '
            '(item.quantity.round()): with "fractional quantity" on, selling 0.4 kg takes '
            'nothing and 2.5 kg takes 3 — invoice_service.dart insertInvoice / updateInvoice / '
            '_adjustStock', (tester) async {
      await openApp(tester, seed: () async {
        await seedShop();
        await BackendServices.settings.setSetting(SettingKey.fractionalQuantity, 'true');
      });
      await nav(tester, 'New Invoice');
      await walkIn(tester, 'Loose Sale');
      await addItem(tester, 'Basmati', qty: '0.4');
      await create(tester);
      final inv = await onlyInvoice(tester);
      expect(inv.items.single.quantity, 0.4);
      expect(await stockOf(tester, 'rice'), 49.6, reason: '0.4 kg sold, exactly');
      // The Products list shows the decimal as written (no 49.60000001).
      await nav(tester, 'Products');
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('prodRow_rice')), matching: find.text('49.6')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('prodRow_dal')), matching: find.text('20')),
          findsOneWidget,
          reason: 'whole stock without ".0"');
      expect(tester.takeException(), isNull);
    });

    testWidgets('non-INR currency: the invoice keeps USD and the dashboard counts it',
        (tester) async {
      await openApp(tester, seed: () async {
        await seedShop();
        await BackendServices.settings.setCurrency('USD');
      });
      await nav(tester, 'New Invoice');
      await walkIn(tester, 'John');
      await addItem(tester, 'Basmati', qty: '2');
      final totals = find.byKey(const ValueKey('modernTotals'));
      expect(find.descendant(of: totals, matching: find.textContaining('\$ 236.00')), findsWidgets);
      await create(tester);
      final inv = await onlyInvoice(tester);
      expect(inv.currencyCode, 'USD');
      expect(inv.currencySymbol, '\$');
      await nav(tester, 'Dashboard');
      expect(find.textContaining('\$ 236.00'), findsWidgets, reason: 'outstanding in dollars');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a product deleted after it was sold: the invoice still opens, edits and '
        'declines', (tester) async {
      await openApp(tester, seed: seedShop);
      await nav(tester, 'New Invoice');
      await walkIn(tester, 'Gone Product');
      await addItem(tester, 'Sunflower', qty: '1');
      await create(tester);
      await db(tester, () => ProductService.deleteProduct('oil'));
      await nav(tester, 'Invoices');
      await tester.tap(find.byKey(const ValueKey('rowEdit_00000001')));
      await settle(tester);
      expect(find.text('Sunflower Oil'), findsOneWidget, reason: 'the saved line keeps its name');
      await cell(tester, 'qty_0', '2');
      await create(tester);
      expect(tester.takeException(), isNull);
      final inv = (await db<dynamic>(tester, () => InvoiceService.getInvoiceById('00000001')))! as Invoice;
      expect(inv.items.single.quantity, 2);
      expect(inv.items.single.product.name, 'Sunflower Oil');
      await db(tester, () => InvoiceService.declineInvoice('00000001'));
      expect(await db<dynamic>(tester, () => ProductService.getProductById('oil')), isNull,
          reason: 'declining does not bring the deleted product back');
    });

    testWidgets('an invoice with 120 lines opens for editing without errors', (tester) async {
      await openApp(tester, seed: () async {
        await seedShop();
        await InvoiceService.insertInvoice(Invoice(
            id: '00000001', invoiceNumber: '00000001', type: 'Invoice',
            customer: Customer(id: '', name: 'Bulk Buyer', email: '', phone: '', address: '', gstin: ''),
            items: [
              for (var i = 0; i < 120; i++)
                InvoiceItem(product: prod('custom-$i', 'Line item $i', 1.5 + i, tax: 5), quantity: 2)
            ],
            date: DateTime.now(), taxMode: TaxMode.perItem, currencySymbol: 'Rs.'));
      });
      await nav(tester, 'Invoices');
      await tester.tap(find.byKey(const ValueKey('rowEdit_00000001')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('itemRow0')), findsOneWidget);
      final inv = (await db<dynamic>(tester, () => InvoiceService.getInvoiceById('00000001')))! as Invoice;
      expect(inv.items, hasLength(120));
      // sum over i of 2 * (1.5 + i) = 2 * (180 + 7140) = 14640, + 5%
      expect(inv.total, closeTo(14640 * 1.05, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  group('Standard layout smoke', () {
    testWidgets('Standard: dashboard, new invoice (scan, create), customers, products, reports',
        (tester) async {
      await openApp(tester, layout: UiLayout.standard, seed: seedShop);
      expect(find.text('Dashboard Overview'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.receipt_outlined));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Customer Name *'), 'Standard Sam');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      const keys = {
        '0': LogicalKeyboardKey.digit0, '1': LogicalKeyboardKey.digit1,
        '6': LogicalKeyboardKey.digit6,
      };
      for (final ch in '1006'.split('')) {
        await tester.sendKeyDownEvent(keys[ch]!, character: ch);
        await tester.sendKeyUpEvent(keys[ch]!);
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')));
      await settle(tester);
      await clearSnacks(tester);
      final createBtn = find.textContaining('Create Invoice (Ctrl+S)');
      await tester.ensureVisible(createBtn);
      await tester.pump();
      await tester.tap(createBtn);
      await settle(tester);
      await settle(tester);
      final inv = await onlyInvoice(tester);
      expect(inv.customer.name, 'Standard Sam');
      expect(inv.invoiceNumber, '00000001');
      expect(await stockOf(tester, 'rice'), 49);
      for (final icon in [Icons.people_outline, Icons.inventory_2_outlined,
          Icons.receipt_long_outlined, Icons.bar_chart_outlined]) {
        await tester.tap(find.byIcon(icon));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: '$icon');
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // PDFs through the app's own PDF service (settings read from the database,
  // Tamil drawn by ShapedTextRasterizer). Plain tests: real async time.
  group('PDF output', () {
    setUpAll(() {
      // Serve assets from the project folder so the real PdfFontService
      // loads every font (flutter_test's handler fails on parallel loads).
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
        final key = Uri.decodeFull(utf8.decode(
            message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes)));
        final file = File(key);
        if (!file.existsSync()) return null;
        return ByteData.sublistView(file.readAsBytesSync());
      });
    });
    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    const tamilCustomer = 'மதன் ஸ்டோர்ஸ்';
    const tamilProduct = 'ஆச்சி மிளகாய் தூள் 100கி';

    Invoice tamilInvoice({int lines = 6}) => Invoice(
          id: '00000001',
          invoiceNumber: '00000001',
          type: 'Invoice',
          invoiceTitle: 'Tax Invoice',
          customer: Customer(
              id: 'c1', name: tamilCustomer, email: '', phone: '',
              address: 'சென்னை 600001', gstin: '33AAAAA0000A1Z5'),
          items: [
            InvoiceItem(
                product: prod('p1', tamilProduct, 45, tax: 5, hsn: '0904', unit: 'pcs'),
                quantity: 3, discount: 2, discountPerUnit: true),
            InvoiceItem(
                product: prod('p2', 'Toor Dal', 118, tax: 18, incl: true, hsn: '0713'),
                quantity: 2.5),
            InvoiceItem(product: prod('p3', 'Gold Bar 1kg', 100000000, tax: 3), quantity: 1),
            for (var i = 0; i < lines - 3; i++)
              InvoiceItem(
                  product: prod('x$i', 'Item $i ${'with a long description ' * 3}', 10.0 + i, tax: 12),
                  quantity: 1),
          ],
          date: DateTime(2026, 10, 8),
          dueDate: DateTime(2026, 10, 22),
          taxMode: TaxMode.perItem,
          isInterState: true,
          currencySymbol: 'Rs.',
          additionalCosts: [AdditionalCost(label: 'Packing', amount: 20), AdditionalCost(label: 'Extra Cost', amount: 5)],
          invoiceDiscountType: InvoiceDiscountType.amount,
          invoiceDiscountValue: 10,
          notes: 'நன்றி, மீண்டும் வருக',
        );

    bool shaped(Uint8List bytes) => String.fromCharCodes(bytes).contains('Subtype/Image');

    test('invoice PDF: every template on every page size, Tamil shaped, nothing throws',
        () async {
      await DatabaseHelper().switchToFile('e2e_release_pdf_${dbCounter++}.db');
      await BackendServices.settings.setSetting(SettingKey.invoicePrefix, 'INV-');
      final inv = tamilInvoice();
      final failures = <String>[];
      final sizes = <int>{};
      for (final size in PageSize.values) {
        for (final t in InvoiceTemplate.values) {
          await BackendServices.settings.setPageSize(size);
          await BackendServices.settings.setInvoiceTemplate(t);
          try {
            final doc = await PDFService.generateInvoicePDF(inv);
            final bytes = await doc.save();
            sizes.add(bytes.length);
            if (bytes.length < 2000) failures.add('${t.name}/${size.name}: tiny PDF');
            if (!shaped(bytes)) failures.add('${t.name}/${size.name}: Tamil not shaped');
          } catch (e) {
            failures.add('${t.name}/${size.name}: $e');
          }
        }
      }
      expect(failures, isEmpty);
      expect(sizes.length, greaterThan(5), reason: 'the template / page size really changed');
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('invoice PDF: 120 lines on A4 classic and thermal 80 (multi-page, no throw)', () async {
      await DatabaseHelper().switchToFile('e2e_release_pdf_${dbCounter++}.db');
      final inv = tamilInvoice(lines: 120);
      for (final (t, size) in [
        (InvoiceTemplate.classic, PageSize.a4),
        (InvoiceTemplate.gridClassic, PageSize.a5),
        (InvoiceTemplate.thermal, PageSize.thermal80),
        (InvoiceTemplate.thermal, PageSize.thermal58),
      ]) {
        await BackendServices.settings.setPageSize(size);
        await BackendServices.settings.setInvoiceTemplate(t);
        final bytes = await (await PDFService.generateInvoicePDF(inv)).save();
        expect(bytes.length, greaterThan(5000), reason: '${t.name}/${size.name}');
      }
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('payment receipt PDF and customer statement PDF (Tamil) from real data', () async {
      await DatabaseHelper().switchToFile('e2e_release_pdf_${dbCounter++}.db');
      await CustomerService.insertCustomer(Customer(
          id: 'c1', name: tamilCustomer, email: '', phone: '', address: '', gstin: ''));
      final inv = tamilInvoice();
      await InvoiceService.insertInvoice(inv);
      final saved = (await InvoiceService.getInvoiceById(inv.id))!;
      final pay = await PaymentService.addPayment(
          invoice: saved, amountPaid: 500, datePaid: DateTime(2026, 10, 9), paymentMethod: 'UPI');
      final receipt = await (await PaymentReceiptService.generatePDF(saved, pay)).save();
      expect(receipt.length, greaterThan(1000));
      expect(shaped(receipt), isTrue);

      final statements = await ReportService.getCustomerStatements(
          'c1', DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(statements, isNotEmpty);
      final st = statements.single;
      expect(st.invoiced, closeTo(saved.total, 0.01));
      expect(st.paid, closeTo(500, 0.01));
      expect(st.closingBalance, closeTo(saved.total - 500, 0.01));
      final pdf = await CustomerStatementPdfService.export(statements);
      expect(pdf.length, greaterThan(1000));
      expect(shaped(pdf), isTrue);
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  // ════════════════════════════════════════════════════════════════════════
  group('Totals, Dashboard and Reports agree with the documents', () {
    test('mixed documents: subtotal / tax / total match the calculator; dashboard and reports '
        'count only live invoices and receipts', () async {
      await DatabaseHelper().switchToFile('e2e_release_totals_${dbCounter++}.db');
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day, 10);
      final c = Customer(id: 'c1', name: 'Arun', email: '', phone: '', address: '', gstin: '');
      final noPhone = Customer(id: '', name: 'No Phone Walk-in', email: '', phone: '', address: '', gstin: '');
      Invoice doc(String id, String type, List<InvoiceItem> items,
              {TaxMode mode = TaxMode.global, double rate = 0.18, Customer? cust,
              List<AdditionalCost> costs = const [], double disc = 0}) =>
          Invoice(id: id, invoiceNumber: id, type: type, customer: cust ?? c, items: items,
              date: day, taxMode: mode, taxRate: rate, additionalCosts: costs,
              invoiceDiscountType: InvoiceDiscountType.percent, invoiceDiscountValue: disc,
              currencySymbol: 'Rs.');
      final rice = prod('rice', 'Rice', 100, stock: 100, tax: 18);
      final dal = prod('dal', 'Dal', 118, stock: 100, tax: 18, incl: true);
      final zero = prod('salt', 'Salt', 20, stock: 100, tax: 0);
      for (final p in [rice, dal, zero]) {
        await ProductService.insertProduct(p);
      }
      // A: per item, mixed incl/excl/0%, discounts, charges, 5% invoice discount.
      final a = doc('00000001', 'Invoice', [
        InvoiceItem(product: rice, quantity: 3, unitPrice: 110, discount: 10, discountPerUnit: true),
        InvoiceItem(product: dal, quantity: 2, discount: 6, discountPerUnit: false),
        InvoiceItem(product: zero, quantity: 5),
      ], mode: TaxMode.perItem, costs: [AdditionalCost(label: 'Freight', amount: 50)], disc: 5);
      // B: global 18%, unpaid, customer without a phone.
      final b = doc('00000002', 'Invoice', [InvoiceItem(product: rice, quantity: 1)], cust: noPhone);
      // C: receipt (cash sale), D: quotation, E: declined, F: trashed.
      final cDoc = doc('00000003', 'Receipt', [InvoiceItem(product: zero, quantity: 10)]);
      final d = doc('00000004', 'Quotation', [InvoiceItem(product: rice, quantity: 50)]);
      final e = doc('00000005', 'Invoice', [InvoiceItem(product: rice, quantity: 4)]);
      final f = doc('00000006', 'Invoice', [InvoiceItem(product: dal, quantity: 4)]);
      for (final x in [a, b, cDoc, d, e, f]) {
        await InvoiceService.insertInvoice(x);
      }
      await InvoiceService.declineInvoice('00000005');
      await InvoiceService.softDeleteInvoice('00000006');

      // A by hand: rice (110-10)*3 = 300 +54; dal 236-6 = 230 incl -> 194.915 +35.085;
      // salt 100 +0 -> subtotal 594.915, tax 89.085, +50 = 734, -5% = 697.30.
      final savedA = (await InvoiceService.getInvoiceById('00000001'))!;
      final ta = calc(savedA);
      expect(ta.subtotal, closeTo(594.915, 0.001));
      expect(ta.tax, closeTo(89.085, 0.001));
      expect(ta.total, closeTo(697.30, 0.001));
      expect(savedA.subtotal, closeTo(ta.subtotal, 1e-9));
      expect(savedA.tax, closeTo(ta.tax, 1e-9));
      expect(savedA.total, closeTo(ta.total, 1e-9));
      final savedB = (await InvoiceService.getInvoiceById('00000002'))!;
      expect(savedB.total, closeTo(118, 1e-9));
      final receipt = (await InvoiceService.getInvoiceById('00000003'))!;
      expect(receipt.total, closeTo(236, 1e-9), reason: 'global 18% on a 0% product');

      await PaymentService.addPayment(invoice: savedA, amountPaid: 300, datePaid: day);

      // stock: rice 3+1 (A,B), declined E gave back 4, quotation none; dal A 2, F trashed;
      // salt 5 (A) + 10 (receipt).
      expect((await ProductService.getProductById('rice'))!.stock, 96);
      expect((await ProductService.getProductById('dal'))!.stock, 98);
      expect((await ProductService.getProductById('salt'))!.stock, 85);

      final fin = await InvoiceService.getDashboardFinancials();
      expect(fin.count, 2, reason: 'A and B');
      expect(fin.revenue, closeTo(300 + 236, 0.001));
      expect(fin.outstanding, closeTo(697.30 - 300 + 118, 0.001));

      final kpi = await ReportService.getRevenueSummary(
          DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0),
          currencyCode: 'INR');
      expect(kpi.invoiceCount, 2);
      expect(kpi.billed, closeTo(697.30 + 118 + 236, 0.001));
      expect(kpi.collected, closeTo(fin.revenue, 0.001));
      expect(kpi.outstanding, closeTo(fin.outstanding, 0.001));

      // The customer without a phone still has a statement.
      final custs = await ReportService.getStatementCustomers();
      expect(custs.map((x) => x.name), containsAll(['Arun', 'No Phone Walk-in']));
    });

    test('0% tax and global tax off: total is the plain sum', () async {
      await DatabaseHelper().switchToFile('e2e_release_totals_${dbCounter++}.db');
      final p = prod('p', 'Water', 20, tax: 0);
      final inv = Invoice(id: '00000001', invoiceNumber: '00000001', type: 'Invoice',
          customer: Customer(id: '', name: 'X', email: '', phone: '', address: '', gstin: ''),
          items: [InvoiceItem(product: p, quantity: 3)], date: DateTime.now(),
          taxMode: TaxMode.none, taxRate: 0.18);
      await InvoiceService.insertInvoice(inv);
      final saved = (await InvoiceService.getInvoiceById('00000001'))!;
      expect(saved.tax, 0);
      expect(saved.total, 60);
      final perItem = Invoice(id: '1', type: 'Invoice', customer: inv.customer,
          items: [InvoiceItem(product: p, quantity: 3)], date: DateTime.now(),
          taxMode: TaxMode.perItem);
      expect(perItem.total, 60);
    });

    test('numbering: INV prefix on the PDF, per-type sequences, starting number', () async {
      await DatabaseHelper().switchToFile('e2e_release_numbers_${dbCounter++}.db');
      await BackendServices.settings.setSetting(SettingKey.invoiceStartingNumber, '1001');
      expect(await InvoiceService.generateNextInvoiceNumber('Invoice'), '00001001');
      expect(await InvoiceService.generateNextInvoiceNumber('Quotation'), '00000001');
      final cust = Customer(id: '', name: 'X', email: '', phone: '', address: '', gstin: '');
      final p = prod('p', 'P', 1, unlimited: true);
      final first = Invoice(id: await InvoiceService.generateNextId(),
          invoiceNumber: await InvoiceService.generateNextInvoiceNumber('Invoice'),
          type: 'Invoice', customer: cust, items: [InvoiceItem(product: p, quantity: 1)],
          date: DateTime.now());
      await InvoiceService.insertInvoice(first);
      expect(first.invoiceNumber, '00001001');
      expect(first.pdfNumberText('INV-'), 'INV-00001001');
      expect(first.pdfNumberText('INV-', showLeadingZeros: false), 'INV-1001');
      expect(await InvoiceService.generateNextInvoiceNumber('Invoice'), '00001002');
      final q = Invoice(id: await InvoiceService.generateNextId(),
          invoiceNumber: await InvoiceService.generateNextInvoiceNumber('Quotation'),
          type: 'Quotation', customer: cust, items: [InvoiceItem(product: p, quantity: 1)],
          date: DateTime.now());
      await InvoiceService.insertInvoice(q);
      expect(q.invoiceNumber, '00000001');
      expect(await InvoiceService.generateNextInvoiceNumber('Invoice'), '00001002',
          reason: 'a quotation does not move the invoice sequence');
    });
  });

}
