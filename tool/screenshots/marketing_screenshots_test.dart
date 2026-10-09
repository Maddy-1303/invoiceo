// Makes the website's app screenshots from the real Modern screens, with a
// sample shop (never your own data; phone numbers start with 1, which no
// Indian mobile does, so they cannot reach a real person). Run:
//   flutter test tool/screenshots/marketing_screenshots_test.dart
// Output: ../invoiceo-website/assets/images/screens/*.png (override with
// --dart-define=SCREENS_OUT=/some/folder). For the Tamil page add
// --dart-define=SHOT_LOCALE=ta, which writes *-ta.png with the app in Tamil.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/company_info_service.dart';
import 'package:invoiceo/database/company_registry_service.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_draft_service.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/database/payment_service.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/ui_layout.dart';
import 'package:invoiceo/models/company_info.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_draft.dart';
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
import 'package:invoiceo/theme/app_theme.dart';

const _outDefault = '../invoiceo-website/assets/images/screens';
const _out = String.fromEnvironment('SCREENS_OUT', defaultValue: _outDefault);
const _locale = String.fromEnvironment('SHOT_LOCALE');
const _suffix = _locale == '' ? '' : '-$_locale';

Future<void> _loadFont(String family, List<String> files,
    {String? dir}) async {
  dir ??= '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File('$dir/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    BackendServices.configure(
      settings: SqliteSettingsRepository(),
      companyInfo: SqliteCompanyInfoRepository(),
      invoices: SqliteInvoiceRepository(),
      payments: SqlitePaymentRepository(),
      installation: SqliteInstallationRepository(),
    );
    tmp = Directory.systemTemp.createTempSync('invoiceo_screens');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
    await _loadFont('Roboto', [
      'Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf',
    ]);
    await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
    await _loadFont('NotoSansTamil', ['NotoSansTamil-Regular.ttf', 'NotoSansTamil-Bold.ttf'],
        dir: 'assets/fonts');
    // The greeting's wave; a test has no system fonts to fall back on.
    final emoji = File('/System/Library/Fonts/Apple Color Emoji.ttc');
    if (emoji.existsSync()) {
      final loader = FontLoader('ShotEmoji')
        ..addFont(Future.value(ByteData.view(emoji.readAsBytesSync().buffer)));
      await loader.load();
    }
    Directory(_out).createSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester, [int rounds = 14]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shotRoot')));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_out/$name$_suffix.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
    // ignore: avoid_print
    print('saved $_out/$name$_suffix.png');
  }

  Future<void> seed() async {
    await DatabaseHelper().switchToFile('invoice_manager.db');
    // A new database already has a placeholder row: fill that one in.
    final existing = await CompanyInfoService.getCompanyInfo();
    final save = existing == null
        ? CompanyInfoService.insertCompanyInfo
        : CompanyInfoService.updateCompanyInfo;
    await save(CompanyInfo(
        id: existing?.id,
        name: 'Sri Murugan Traders', address: '12, Big Bazaar Street, Madurai 625001',
        phone: '12345 00010', email: 'billing@srimurugan.example', website: '',
        gstin: '33ABCDE1234F1Z5'));
    await BackendServices.settings.setSetting(SettingKey.uiLayout, UiLayout.modern.name);
    await CompanyRegistryService.ensureDefaultCompanyRegistered();

    final customers = [
      Customer(id: 'c1', name: 'Kannan', businessName: 'Kannan Stores', phone: '12345 00011',
          email: 'kannan@stores.example', address: '4, East Masi Street, Madurai', gstin: '33AAKCK1122L1Z9'),
      Customer(id: 'c2', name: 'Meena', businessName: 'Meena Textiles', phone: '12345 00012',
          email: '', address: 'Town Hall Road, Madurai', gstin: '33AAMCM3344N1Z2'),
      Customer(id: 'c3', name: 'Ravi Kumar', phone: '12345 00013', email: 'ravi@mail.example',
          address: 'Anna Nagar, Madurai', gstin: ''),
      Customer(id: 'c4', name: 'Anbu', businessName: 'Anbu Bakery', phone: '12345 00014',
          email: '', address: 'KK Nagar, Madurai', gstin: '33AAACA5566P1Z4'),
      Customer(id: 'c5', name: 'Lakshmi', phone: '12345 00015', email: '', address: '', gstin: ''),
      Customer(id: 'c6', name: 'Selvam', businessName: 'Selvam Hardware', phone: '12345 00016',
          email: '', address: 'Simmakkal, Madurai', gstin: ''),
      Customer(id: 'c7', name: 'Priya', phone: '12345 00017', email: 'priya@mail.example',
          address: 'Tallakulam, Madurai', gstin: ''),
    ];
    for (final c in customers) {
      await CustomerService.insertCustomer(c);
    }

    Product p(String id, String name, double price, double stock,
            {String hsn = '0902', int tax = 5, double cost = 0, String type = 'product',
            bool unlimited = false, String unit = 'pcs'}) =>
        Product(id: id, name: name, description: '', price: price, stock: stock, hsncode: hsn,
            tax_rate: tax, purchasePrice: cost, type: type, unlimitedStock: unlimited, unit: unit);
    final products = [
      p('p1', '3 Roses Tea 250g', 145, 42, hsn: '0902', cost: 118),
      p('p2', 'Aachi Chilli Powder 100g', 45, 6, hsn: '0904', cost: 34),
      p('p3', 'Sakthi Turmeric Powder 100g', 38, 35, hsn: '0910', cost: 29),
      p('p4', 'Ponni Rice 25kg', 1450, 18, hsn: '1006', cost: 1290, tax: 0),
      p('p5', 'Gold Winner Sunflower Oil 1L', 165, 0, hsn: '1512', cost: 148),
      p('p6', 'Aavin Ghee 500ml', 340, 9, hsn: '0405', cost: 305, tax: 12),
      p('p7', 'Toor Dal 1kg', 168, 54, hsn: '0713', cost: 150, tax: 0),
      p('p8', 'Sugar 1kg', 46, 80, hsn: '1701', cost: 41),
      p('s1', 'Home Delivery', 40, 0, hsn: '9968', tax: 18, type: 'service', unlimited: true),
      p('s2', 'Gift Packing', 60, 0, hsn: '9985', tax: 18, type: 'service', unlimited: true),
    ];
    for (final x in products) {
      await ProductService.insertProduct(x);
    }
    await ProductService.upsertProductMetadata(
        ProductMetadata(productId: 'p1', skuCode: 'TRS-250'));

    final now = DateTime.now();
    Future<Invoice> invoice(Customer c, List<(int, double)> lines, int daysAgo,
        {double paid = 0, int? dueDays, String type = 'Invoice'}) async {
      final id = await InvoiceService.generateNextId();
      final number = await InvoiceService.generateNextInvoiceNumber(type);
      final inv = Invoice(
        id: id, invoiceNumber: number, customer: c, type: type,
        items: [for (final (i, q) in lines) InvoiceItem(product: products[i], quantity: q)],
        date: now.subtract(Duration(days: daysAgo)),
        dueDate: dueDays == null ? null : now.subtract(Duration(days: daysAgo - dueDays)),
        taxMode: TaxMode.perItem, currencyCode: 'INR', currencySymbol: 'Rs.',
      );
      await InvoiceService.insertInvoice(inv);
      final saved = (await InvoiceService.getInvoiceById(id))!;
      if (paid > 0) {
        await PaymentService.addPayment(
            invoice: saved, amountPaid: paid, datePaid: saved.date.add(const Duration(days: 2)));
      }
      return saved;
    }

    Future<void> paidInFull(Customer c, List<(int, double)> lines, int daysAgo) async {
      final inv = await invoice(c, lines, daysAgo);
      await PaymentService.addPayment(invoice: inv, amountPaid: inv.total, datePaid: inv.date);
    }

    // Six months of a growing shop: May → October.
    final k = customers;
    await paidInFull(k[0], [(3, 1), (6, 5), (7, 10)], 150);
    await paidInFull(k[1], [(3, 1), (0, 4)], 115);
    await paidInFull(k[3], [(5, 3), (7, 10)], 105);
    await paidInFull(k[0], [(3, 2), (6, 3)], 90);
    await paidInFull(k[5], [(0, 6), (1, 10), (2, 6)], 75);
    await paidInFull(k[1], [(3, 2), (5, 4), (0, 4)], 60);
    await paidInFull(k[3], [(6, 10), (7, 10)], 50);
    await paidInFull(k[6], [(4, 6), (0, 2)], 42);
    await paidInFull(k[0], [(3, 3), (6, 5)], 35);
    await invoice(k[1], [(3, 4), (5, 2)], 28, paid: 3000, dueDays: 15);
    await invoice(k[3], [(0, 12), (2, 10), (9, 1)], 28, dueDays: 10);
    await paidInFull(k[2], [(0, 10), (1, 12), (6, 5)], 20);
    await paidInFull(k[5], [(4, 6), (7, 12)], 12);
    await paidInFull(k[0], [(3, 4), (0, 6), (6, 8)], 7);
    await invoice(k[0], [(3, 2), (6, 8), (0, 6)], 6, paid: 2000, dueDays: 21);
    await paidInFull(k[4], [(7, 5), (0, 2)], 5);
    await paidInFull(k[1], [(3, 3), (5, 2)], 4);
    await paidInFull(k[6], [(5, 4), (8, 1)], 3);
    await invoice(k[2], [(5, 3), (1, 6)], 2, dueDays: 15);
    await paidInFull(k[5], [(6, 4), (7, 6)], 1);
    await invoice(k[3], [(0, 20), (3, 1)], 0, dueDays: 30);
    await invoice(k[1], [(3, 5), (5, 4)], 3, type: 'Quotation');
    await invoice(k[6], [(0, 6), (9, 2)], 1, type: 'Quotation');

    // Stock as a real shop would have it now: two low, one out.
    final db = await DatabaseHelper().database;
    for (final (id, stock) in [
      ('p1', 42), ('p2', 6), ('p3', 35), ('p4', 18),
      ('p5', 0), ('p6', 9), ('p7', 54), ('p8', 80),
    ]) {
      await db.update('products', {'stock': stock}, where: 'id = ?', whereArgs: [id]);
    }

    // A draft to open on the Create Invoice screen.
    await InvoiceDraftService.saveDraft(InvoiceDraft(
      id: 'draft-1',
      updatedAt: now,
      invoice: Invoice(
        id: '', customer: customers[0], type: 'Invoice', date: now,
        items: [
          InvoiceItem(product: products[0], quantity: 10),
          InvoiceItem(product: products[3], quantity: 2),
          InvoiceItem(product: products[6], quantity: 5),
          InvoiceItem(product: products[1], quantity: 12),
        ],
        taxMode: TaxMode.perItem, currencyCode: 'INR', currencySymbol: 'Rs.',
      ),
    ));
  }

  testWidgets('Invoiceo marketing screenshots', (tester) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(seed);

    final container = ProviderContainer(overrides: sqliteRepositoryOverrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: const ValueKey('shotRoot'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light.copyWith(
              textTheme: AppTheme.light.textTheme
                  .apply(fontFamilyFallback: const ['NotoSansTamil', 'ShotEmoji'])),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: _locale == '' ? null : Locale(_locale),
          home: DashboardScreen(
              User(id: 'u1', username: 'Madhan', password: 'x', userType: 'admin')),
        ),
      ),
    ));
    await settle(tester, 30);
    await shot(tester, 'dashboard');

    // The sidebar keys carry the label in the app's language.
    final l10n = lookupAppLocalizations(Locale(_locale == '' ? 'en' : _locale));
    Future<void> open(String nav) async {
      await tester.tap(find.byKey(ValueKey('modernNav_$nav')));
      await settle(tester, 20);
    }

    await open(l10n.navInvoices);
    await shot(tester, 'invoices');

    // The draft, opened on the Create Invoice screen.
    await tester.tap(find.byKey(const ValueKey('modernTabDrafts')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('draftContinue_draft-1')));
    await settle(tester, 30);
    await shot(tester, 'create-invoice');

    await open(l10n.navCustomers);
    await shot(tester, 'customers');
    await open(l10n.navProducts);
    await shot(tester, 'products');
    await open(l10n.navReports);
    await shot(tester, 'reports');
  });
}
