// Release QA (1.0.0): Settings, Backup / Restore, Reports and Languages /
// Layouts, end to end on the real screens from a fresh empty database.
//
//  * Settings take effect: Invoice Settings -> a NEW invoice made afterwards
//    (screen + the PDF made by the app's PDF service); PDF Settings save /
//    reset / live preview; Product Details columns; Accessibility layout
//    switch; Company Info (name, logo checks, business type -> sidebar).
//  * Backup: create, list, restore (asks first), import (asks first), the
//    pre-restore copy, JSON restore of drafts and product metadata, corrupt
//    files fail without touching the data.
//  * Reports: every section with data and with an empty database, the
//    numbers against a known seed, every PDF export (Tamil names too),
//    "All currencies".
//  * Languages: every page and settings section in en, ta, hi, ne, fr, es,
//    zh, bo at 1280x720 and 1440x900 (Modern), plus Standard in en and ta.
//
// Real bugs found are kept as tests with `skip: 'BUG: ...'`.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/backup/backup_manager.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/company_registry_service.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_draft_service.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/database/payment_service.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/database/report_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/layouts/modern/modern_shell.dart';
import 'package:invoiceo/layouts/ui_layout.dart';
import 'package:invoiceo/models/backup_info.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_draft.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/models/user.dart';
import 'package:invoiceo/providers/locale_provider.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/create_invoice_screen_modern.dart';
import 'package:invoiceo/screens/dashboard_screen.dart';
import 'package:invoiceo/screens/product_management_screen_v2.dart';
import 'package:invoiceo/screens/reports_screen.dart';
import 'package:invoiceo/screens/settings/backup_management_screen.dart';
import 'package:invoiceo/screens/settings/invoice_settings_screen_v2.dart';
import 'package:invoiceo/screens/settings/pdf_settings_screen_v2.dart';
import 'package:invoiceo/screens/settings/product_columns_settings_screen.dart';
import 'package:invoiceo/screens/settings/settings_screen.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/services/customer_statement_pdf_service.dart';
import 'package:invoiceo/services/invoice_pdf_services.dart';
import 'package:invoiceo/services/pdf/pdf_font_service.dart';
import 'package:invoiceo/services/pdf/pdf_service.dart';
import 'package:invoiceo/services/pdf/pdf_settings.dart';
import 'package:invoiceo/theme/app_theme.dart';

import 'test_pdf_font_service.dart';

/// Stands in for the system file dialogs: [pick] is what "Open" returns,
/// [saveTo] is the path "Save as" returns.
class FakeFilePicker extends FilePicker {
  String? pick;
  String? saveTo;
  final saved = <String>[];
  int pickCalls = 0;

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
    pickCalls++;
    final p = pick;
    if (p == null) return null;
    return FilePickerResult(
        [PlatformFile(path: p, name: p.split('/').last, size: File(p).lengthSync())]);
  }

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    final dir = saveTo;
    if (dir == null) return null;
    final path = '$dir/${fileName ?? 'out'}';
    saved.add(path);
    return path;
  }
}

/// Known bugs are skipped; run with --dart-define=RUN_BUGS=true to see them fail.
const _runBugs = bool.fromEnvironment('RUN_BUGS');

const _printingChannel = MethodChannel('net.nfet.printing');

const _tamilCustomer = 'மதன் ஸ்டோர்ஸ்';
const _tamilProduct = 'ஆச்சி மிளகாய் தூள் 100கி';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  // path_provider answers with this folder: a fresh one per test, so
  // backups made by one test never show up in another's list.
  late String supportDir;
  var dbCounter = 0;
  final picker = FakeFilePicker();
  final en = lookupAppLocalizations(const Locale('en'));
  final admin = User(id: 'u1', username: 'admin', password: 'x', userType: 'admin');

  setUpAll(() async {
    // Real fonts, so text is measured as on a real screen (flutter_test's
    // own font draws every letter as a wide square and over-reports
    // overflow): Roboto for Latin, the app's bundled Tamil / Devanagari /
    // Tibetan fonts for those scripts.
    Future<void> loadFont(String family, List<String> paths) async {
      final loader = FontLoader(family);
      for (final path in paths) {
        final f = File(path);
        if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
      await loader.load();
    }
    final material = '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';
    await loadFont('Roboto', [
      '$material/Roboto-Regular.ttf', '$material/Roboto-Medium.ttf', '$material/Roboto-Bold.ttf']);
    await loadFont('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
    await loadFont('NotoSansTamil',
        ['assets/fonts/NotoSansTamil-Regular.ttf', 'assets/fonts/NotoSansTamil-Bold.ttf']);
    await loadFont('NotoSansDevanagari',
        ['assets/fonts/NotoSansDevanagari-Regular.ttf', 'assets/fonts/NotoSansDevanagari-Bold.ttf']);
    await loadFont('NotoSerifTibetan',
        ['assets/fonts/NotoSerifTibetan-Regular.ttf', 'assets/fonts/NotoSerifTibetan-Bold.ttf']);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackNumberSymbols();
    BackendServices.configure(
      settings: SqliteSettingsRepository(),
      companyInfo: SqliteCompanyInfoRepository(),
      invoices: SqliteInvoiceRepository(),
      payments: SqlitePaymentRepository(),
      installation: SqliteInstallationRepository(),
    );
    root = Directory.systemTemp.createTempSync('invoiceo_release_qa');
    supportDir = root.path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => supportDir);
    // A printing plugin that can draw PDF pages (the PDF Settings preview).
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_printingChannel, (call) async {
      switch (call.method) {
        case 'printingInfo':
          return <String, dynamic>{'canPrint': true, 'canShare': true, 'canRaster': true};
        case 'rasterPdf':
          final args = call.arguments as Map<dynamic, dynamic>;
          final job = args['job'];
          Future(() async {
            const codec = StandardMethodCodec();
            await messenger.handlePlatformMessage(
                _printingChannel.name,
                codec.encodeMethodCall(MethodCall('onPageRasterized', {
                  'job': job,
                  'width': 4,
                  'height': 6,
                  'image': Uint8List.fromList(List.filled(4 * 6 * 4, 255)),
                })),
                (_) {});
            await messenger.handlePlatformMessage(_printingChannel.name,
                codec.encodeMethodCall(MethodCall('onPageRasterEnd', {'job': job})), (_) {});
          });
          return null;
      }
      return null;
    });
    PdfFontService.loadThemeHook = TestPdfFontService.loadTheme;
    FilePicker.platform = picker;
  });
  tearDownAll(() async {
    PdfFontService.loadThemeHook = null;
    await DatabaseHelper().close();
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });
  setUp(() {
    picker
      ..pick = null
      ..saveTo = null
      ..saved.clear()
      ..pickCalls = 0;
    InvoicePdfServices.printHook = (context, invoice) async {};
  });
  tearDown(() => InvoicePdfServices.printHook = null);

  Future<void> settle(WidgetTester tester, {int rounds = 12}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> settleUntil(WidgetTester tester, bool Function() done,
      {int max = 150}) async {
    for (var i = 0; i < max && !done(); i++) {
      await settle(tester, rounds: 1);
    }
    await settle(tester, rounds: 2);
  }

  /// A fresh database (and a fresh app-support folder) for this test.
  Future<void> freshDb(WidgetTester tester, String name) async {
    SharedPreferences.setMockInitialValues({});
    supportDir = Directory('${root.path}/${name}_${dbCounter++}').path;
    Directory(supportDir).createSync(recursive: true);
    await tester.runAsync(() => DatabaseHelper().switchToFile('$name.db'));
  }

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home, {Locale? locale, ProviderContainer? container}) {
    final material = MaterialApp(
      locale: locale,
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FallbackLocalizationsDelegate<MaterialLocalizations>(
            GlobalMaterialLocalizations.delegate),
        FallbackLocalizationsDelegate<WidgetsLocalizations>(
            GlobalWidgetsLocalizations.delegate),
        FallbackLocalizationsDelegate<CupertinoLocalizations>(
            GlobalCupertinoLocalizations.delegate),
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
    if (container != null) {
      return UncontrolledProviderScope(container: container, child: material);
    }
    return ProviderScope(overrides: sqliteRepositoryOverrides, child: material);
  }

  /// [page] inside the Modern frame (top bar + header scope).
  Widget framed(Widget page, {int index = 8, String title = 'Settings'}) {
    final header = ValueNotifier<ModernPageHeader?>(null);
    return Scaffold(
      body: Column(children: [
        ModernTopBar(
          username: 'admin',
          isAdmin: true,
          onSearch: () {},
          onCreate: (_) {},
          onUserAction: (_) {},
          page: index,
          pageTitle: title,
          header: header,
        ),
        Expanded(child: ModernHeaderScope(page: index, notifier: header, child: page)),
      ]),
    );
  }

  // ── seed data ──────────────────────────────────────────────────────────────
  final customer = Customer(
      id: 'c1', name: 'Test Customer', email: '', phone: '', address: '', gstin: '');
  final tamilCustomer = Customer(
      id: 'c2', name: _tamilCustomer, email: '', phone: '9876543210', address: 'சென்னை', gstin: '');
  final widgetProduct = Product(
      id: 'p1', name: 'Widget', description: '', price: 100, stock: 100,
      hsncode: '', tax_rate: 0, purchasePrice: 60);
  final tamilProductP = Product(
      id: 'p2', name: _tamilProduct, description: '', price: 45, stock: 50,
      hsncode: '0904', tax_rate: 0, purchasePrice: 30);

  final now = DateTime.now();
  final day1 = DateTime(now.year, now.month, 1);
  final day2 = DateTime(now.year, now.month, 2);
  final pastDue = DateTime(now.year, now.month, now.day - 3);

  Invoice doc(String id, String type, double qty, DateTime date,
          {String currency = 'INR', Customer? who, Product? what}) =>
      Invoice(
        id: id,
        invoiceNumber: id.replaceAll(RegExp(r'\D'), '').padLeft(8, '0'),
        customer: who ?? customer,
        items: [InvoiceItem(product: what ?? widgetProduct, quantity: qty)],
        date: date,
        dueDate: pastDue,
        type: type,
        taxRate: 0.10,
        currencyCode: currency,
        currencySymbol: currency == 'INR' ? '₹' : r'$',
      );

  /// i1: invoice 2 x 100 + 10% = 220, 100 paid. i2 declined, q1 quotation,
  /// r1 receipt 110, r2 trashed receipt, r3 USD receipt 110, t1 Tamil
  /// customer + product invoice (4 x 45 + 10% = 198, unpaid) on day 2.
  Future<void> seedReports() async {
    await CustomerService.insertCustomer(customer);
    await CustomerService.insertCustomer(tamilCustomer);
    await ProductService.insertProduct(widgetProduct);
    await ProductService.insertProduct(tamilProductP);
    final i1 = doc('i1', 'Invoice', 2, day1);
    await InvoiceService.insertInvoice(i1);
    await PaymentService.addPayment(invoice: i1, amountPaid: 100, datePaid: day1);
    await InvoiceService.insertInvoice(doc('i2', 'Invoice', 3, day1));
    await InvoiceService.declineInvoice('i2');
    await InvoiceService.insertInvoice(doc('q1', 'Quotation', 5, day1));
    await InvoiceService.insertInvoice(doc('r1', 'Receipt', 1, day2));
    await InvoiceService.insertInvoice(doc('r2', 'Receipt', 4, day2));
    await InvoiceService.softDeleteInvoice('r2');
    await InvoiceService.insertInvoice(doc('r3', 'Receipt', 1, day2, currency: 'USD'));
    await InvoiceService.insertInvoice(
        doc('t1', 'Invoice', 4, day2, who: tamilCustomer, what: tamilProductP));
  }

  bool isPdf(List<int> bytes) =>
      bytes.length > 500 && String.fromCharCodes(bytes.take(5)) == '%PDF-';

  // ════════════════════════════════════════════════════════════════════════
  // SETTINGS TAKE EFFECT
  // ════════════════════════════════════════════════════════════════════════
  group('Settings take effect', () {
    final soap = Product(
        id: 'a', name: 'Alpha Soap', description: '', price: 11, stock: 0,
        hsncode: '1001', tax_rate: 5, unlimitedStock: true);

    Future<void> openInvoiceSettings(WidgetTester tester) async {
      setSize(tester, const Size(820, 1000)); // narrow: chips + Save at the bottom
      await tester.pumpWidget(app(Scaffold(
          body: InvoiceSettingsScreenV2(onNavigateToCustomization: () {}))));
      await settle(tester);
    }

    Future<void> chip(WidgetTester tester, String label) async {
      final c = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(c);
      await tester.tap(c);
      await settle(tester, rounds: 3);
    }

    Future<void> toggle(WidgetTester tester, String title) async {
      final t = find.widgetWithText(SwitchListTile, title);
      await tester.ensureVisible(t);
      await tester.pump();
      await tester.tap(t);
      await tester.pump();
    }

    Future<void> field(WidgetTester tester, String label, String text) async {
      final f = find.widgetWithText(TextField, label);
      await tester.ensureVisible(f);
      await tester.enterText(f, text);
      await tester.pump();
    }

    Future<void> dropdown(WidgetTester tester, Finder dd, String item) async {
      await tester.ensureVisible(dd);
      await tester.pump();
      await tester.tap(dd);
      await settle(tester, rounds: 3);
      await tester.tap(find.text(item).last);
      await settle(tester, rounds: 3);
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('invoiceSettingsSaveBar')),
          matching: find.text(en.actionSave)));
      await settle(tester);
      expect(find.text(en.invoiceSettingsSavedMessage), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
      await tester.pump();
    }

    // Opens a fresh Modern Create Invoice screen, types a customer and adds
    // the soap by scanning its code.
    Future<void> openCreate(WidgetTester tester) async {
      setSize(tester, const Size(1800, 1400));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(const Scaffold(body: CreateInvoiceScreenModern())));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('modernCustomerName')), 'mad');
      await tester.pump();
      for (final ch in '1001'.split('')) {
        final key = {'0': LogicalKeyboardKey.digit0, '1': LogicalKeyboardKey.digit1}[ch]!;
        await tester.sendKeyDownEvent(key, character: ch);
        await tester.sendKeyUpEvent(key);
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(en.actionAdd)));
      await tester.pump();
      await settle(tester);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<Invoice> pressCreate(WidgetTester tester) async {
      final create = find.byKey(const ValueKey('modernCreate'));
      await tester.ensureVisible(create);
      await tester.pump();
      await tester.tap(create);
      await tester.pump();
      await settle(tester);
      await settle(tester);
      return (await tester.runAsync(() async {
        final all = await InvoiceService.getAllInvoices();
        all.sort((a, b) => a.id.compareTo(b.id));
        return InvoiceService.getInvoiceById(all.last.id);
      }))!;
    }

    testWidgets('Invoice Settings (prefix, start number, no leading zeros, USD, date, '
        '12h time, qty label, per-item tax, GST title, custom field) -> the next '
        'invoice and its PDF use them', (tester) async {
      await freshDb(tester, 'set_invoice');
      await tester.runAsync(() => ProductService.insertProduct(soap));
      await openInvoiceSettings(tester);
      expect(tester.takeException(), isNull);

      // General
      await field(tester, en.invoiceSettingsPrefixLabel, 'QA');
      await field(tester, en.onboardingInvoiceStartingNumberLabel, '1001');
      await toggle(tester, en.onboardingLeadingZerosLabel);
      final currency = find.widgetWithText(TextField, en.onboardingCurrencyLabel);
      await tester.ensureVisible(currency);
      await tester.tap(currency);
      await tester.enterText(currency, 'USD');
      await settle(tester, rounds: 3);
      await tester.tap(find.text('USD').last);
      await settle(tester, rounds: 3);
      await dropdown(tester, find.byType(DropdownButtonFormField<DateFormatOption>),
          en.dateFormatYyyymmddLabel);
      await dropdown(tester, find.widgetWithText(DropdownButtonFormField<String>,
          en.invoiceSettingsTimeFormatLabel), en.invoiceSettingsTimeFormat12);
      await field(tester, en.invoiceSettingsQuantityColumnLabel, 'Hrs');
      // Tax: per item, "Bill of Supply" title
      await chip(tester, en.invoiceSettingsSectionTax);
      await tester.tap(find.text(en.invoiceSettingsTaxModePerItem));
      await tester.pump();
      await dropdown(tester, find.byType(DropdownButtonFormField<String?>), en.gstTitleBillOfSupplyLabel);
      // Custom fields: on, "Vehicle No"
      await chip(tester, en.customizationCustomFieldsTitle);
      await toggle(tester, en.invoiceSettingsEnableCustomFieldsLabel);
      await settle(tester, rounds: 2);
      await field(tester, en.invoiceSettingsNewCustomFieldLabel, 'Vehicle No');
      await tester.tap(find.text(en.actionAdd).last);
      await tester.pump();
      await save(tester);
      expect(tester.takeException(), isNull);

      final saved = (await tester.runAsync(() async {
        final r = BackendServices.settings;
        return {
          'prefix': await r.getSetting(SettingKey.invoicePrefix),
          'start': await r.getSetting(SettingKey.invoiceStartingNumber),
          'zeros': await r.getSetting(SettingKey.invoiceLeadingZeros),
          'currency': (await r.getCurrency()).code,
          'date': (await r.getDateFormat()).key,
          'time': await r.getPdfTimeFormat(),
          'qty': await r.getQuantityLabel(),
          'tax': await r.getSetting(SettingKey.defaultTaxMode),
          'title': await r.getDefaultInvoiceTitle(),
          'cf': (await r.getCustomFieldDefs()).map((d) => d.label).join(','),
          'cfOn': await r.getSetting(SettingKey.customFieldsEnabled),
        };
      }))!;
      expect(saved, {
        'prefix': 'QA', 'start': '1001', 'zeros': 'false', 'currency': 'USD',
        'date': 'yyyy-MM-dd', 'time': '12', 'qty': 'Hrs', 'tax': 'perItem',
        'title': 'Bill of Supply', 'cf': saved['cf'], 'cfOn': 'true',
      });
      expect((saved['cf'] as String).split(',').last, 'Vehicle No',
          reason: 'the new field is added after the built-in ones');

      // A NEW invoice made afterwards.
      await openCreate(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Hrs'), findsWidgets, reason: 'quantity column label');
      // Custom fields (under Advanced options): fill "Vehicle No".
      await tester.ensureVisible(find.byKey(const ValueKey('modernAdvancedOptions')));
      await tester.tap(find.byKey(const ValueKey('modernAdvancedOptions')));
      await settle(tester, rounds: 2);
      expect(find.text(en.customizationCustomFieldsTitle.toUpperCase()), findsOneWidget,
          reason: 'custom fields card');
      final addCf = find.ancestor(
          of: find.text(en.actionAdd), matching: find.byWidgetPredicate((w) => w is OutlinedButton));
      await tester.ensureVisible(addCf.first);
      await tester.tap(addCf.first);
      await settle(tester, rounds: 3);
      final vehicle = find.widgetWithText(TextField, 'Vehicle No');
      await tester.ensureVisible(vehicle);
      await tester.enterText(vehicle, 'TN-01-1234');
      await tester.tap(find.widgetWithText(FilledButton, en.actionSave).last);
      await settle(tester, rounds: 6);
      expect(find.text('TN-01-1234'), findsWidgets);
      final inv = await pressCreate(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('modernSuccessId')), findsOneWidget);
      expect(inv.invoiceNumber, '00001001');
      expect(inv.currencyCode, 'USD');
      expect(inv.currencySymbol, r'$');
      expect(inv.quantityLabel, 'Hrs');
      expect(inv.taxMode, TaxMode.perItem);
      expect(inv.invoiceTitle, 'Bill of Supply');
      expect(inv.hideInvoiceNumber, isFalse);
      expect(inv.customFields.map((c) => '${c.label}=${c.value}'), ['Vehicle No=TN-01-1234']);

      // The PDF, made by the app's own PDF service.
      final (pdf, s) = (await tester.runAsync(() async {
        final fmt = await BackendServices.settings.getDateFormat();
        final s = await PDFService.fetchPdfSettings(datePattern: fmt.key);
        final doc = await PDFService.generateInvoicePDF(inv, datePattern: fmt.key);
        return (await doc.save(), s);
      }))!;
      expect(isPdf(pdf), isTrue);
      expect(s.invoicePrefix, 'QA-');
      expect(s.showLeadingZeros, isFalse);
      expect(s.datePattern, 'yyyy-MM-dd');
      expect(s.pdfTimeFormat, '12');
      expect(inv.pdfNumberText(s.invoicePrefix, showLeadingZeros: s.showLeadingZeros), 'QA-1001');

      // With an invoice made, the starting number is locked.
      await openInvoiceSettings(tester);
      final start = tester.widget<TextField>(
          find.widgetWithText(TextField, en.onboardingInvoiceStartingNumberLabel));
      expect(start.enabled, isFalse);
      expect(find.text(en.invoiceSettingsStartingNumberLockedMessage), findsOneWidget);
    }, timeout: const Timeout(Duration(minutes: 3)));

    // The Modern create screen does not follow two Invoice Settings:
    //  * the "created" card shows "#00001001" (raw stored number) while the
    //    PDF prints "QA-1001" (prefix, leading zeros off);
    //  * the date chip in the header is always "dd MMM yyyy", whatever the
    //    chosen date format.
    testWidgets('BUG: Modern create screen shows the number and date the way the settings say',
        (tester) async {
      await freshDb(tester, 'set_display');
      await tester.runAsync(() async {
        await ProductService.insertProduct(soap);
        final r = BackendServices.settings;
        await r.setSetting(SettingKey.invoicePrefix, 'QA');
        await r.setSetting(SettingKey.invoiceStartingNumber, '1001');
        await r.setSetting(SettingKey.invoiceLeadingZeros, 'false');
        await r.setDateFormat(DateFormatOption.yyyymmdd);
      });
      await openCreate(tester);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final chipShows = find.text(DateFormat('dd MMM yyyy').format(DateTime.now())).evaluate().isNotEmpty;
      await pressCreate(tester);
      final shown = (tester.widget<Text>(find.descendant(
              of: find.byKey(const ValueKey('modernSuccessId')),
              matching: find.textContaining('#'))))
          .data;
      expect(shown, '#QA-1001', reason: 'the PDF prints QA-1001');
      expect(chipShows, isFalse, reason: 'date chip should use $today, not dd MMM yyyy');
    }, skip: !_runBugs);

    testWidgets('hide invoice number + tax off -> the new invoice hides its number and has '
        'no tax; the PDF prints no number', (tester) async {
      await freshDb(tester, 'set_hide');
      await tester.runAsync(() => ProductService.insertProduct(soap));
      await openInvoiceSettings(tester);
      await toggle(tester, en.invoiceSettingsHideInvoiceNumberLabel);
      await chip(tester, en.invoiceSettingsSectionTax);
      await toggle(tester, en.invoiceSettingsTaxEnabledLabel);
      await save(tester);
      await openCreate(tester);
      final inv = await pressCreate(tester);
      expect(tester.takeException(), isNull);
      expect(inv.hideInvoiceNumber, isTrue);
      expect(inv.taxMode, TaxMode.none);
      expect(inv.tax, 0);
      expect(inv.pdfNumberText('INV-'), isNull);
      final pdf = await tester.runAsync(() async => (await PDFService.generateInvoicePDF(inv)).save());
      expect(isPdf(pdf!), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('PDF Settings: template / page size / colour -> Save; Reset to Default -> '
        'Save; the live preview builds without errors', (tester) async {
      await freshDb(tester, 'set_pdf');
      final built = <PdfGenerationSettings>[];
      PdfSettingsScreenV2.onPreviewPdfBuilt = built.add;
      addTearDown(() => PdfSettingsScreenV2.onPreviewPdfBuilt = null);
      setSize(tester, const Size(1500, 900));
      await tester.pumpWidget(app(framed(SettingsScreen(currentUser: admin))));
      await settle(tester);
      await tester.tap(find.descendant(
          of: find.byType(NavigationRail), matching: find.text(en.pdfSettingsTitle)));
      await settleUntil(tester, () => built.isNotEmpty);
      expect(tester.takeException(), isNull);
      expect(built, isNotEmpty, reason: 'the live preview made a sample PDF');

      final modernTile = find.text(en.pdfTemplateModernName);
      await tester.ensureVisible(modernTile.first);
      await tester.tap(modernTile.first);
      await settle(tester, rounds: 3);
      await tester.tap(find.byTooltip('#047857'));
      await settle(tester, rounds: 3);
      final n = built.length;
      await settleUntil(tester, () => built.length > n);
      expect(built.last.template, InvoiceTemplate.modern, reason: 'the preview follows the choice');
      await tester.tap(find.byKey(const ValueKey('pdfSettingsSave')));
      await settle(tester);
      expect(find.text(en.pdfSettingsSavedSnackbar), findsOneWidget);
      Future<(InvoiceTemplate, PageSize, String?)> read() async => (await tester.runAsync(() async => (
            await BackendServices.settings.getInvoiceTemplate(),
            await BackendServices.settings.getPageSize(),
            await BackendServices.settings.getPdfThemeColor(),
          )))!;
      var saved = await read();
      expect(saved.$1, InvoiceTemplate.modern);
      expect(saved.$2, PageSize.a4);
      expect(saved.$3?.toUpperCase(), contains('047857'));

      // Page size A5: the template follows to one that supports A5.
      await tester.tap(find.byType(DropdownButtonFormField<PageSize>));
      await settle(tester, rounds: 3);
      await tester.tap(find.text(en.pageSizeA5Label).last);
      await settle(tester, rounds: 3);
      await tester.tap(find.byKey(const ValueKey('pdfSettingsSave')));
      await settle(tester);
      saved = await read();
      expect(saved.$2, PageSize.a5);
      expect(saved.$1.supportsPageSize(PageSize.a5), isTrue);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('pdfSettingsReset')));
      await settle(tester, rounds: 3);
      await tester.tap(find.byKey(const ValueKey('pdfSettingsSave')));
      await settle(tester);
      saved = await read();
      expect(saved.$1, InvoiceTemplate.classic);
      expect(saved.$2, PageSize.a4);
      expect(saved.$3, isNull);
      await settleUntil(tester, () => built.last.template == InvoiceTemplate.classic);
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    // Product Details > "Extra Cost" off hides the Extra column, but
    // "Default Discount" off does not hide the Discount column on a
    // normal-width window: in _itemColumns
    // (create_invoice_screen_modern.dart) `showDisc` ends with `|| !dropEmpty`,
    // which is true for the full and compact layouts whatever the setting.
    testWidgets('BUG: Default Discount off -> no Discount column on the create screen '
        'while no item has a discount', (tester) async {
      await freshDb(tester, 'set_disc');
      await tester.runAsync(() async {
        await ProductService.insertProduct(soap);
        final r = BackendServices.settings;
        await r.setProductColumnsConfig(
            (await r.getProductColumnsConfig()).copyWith(defaultDiscount: false, extraCost: false));
      });
      await openCreate(tester);
      expect(find.text(en.productColumnsExtraCostLabel), findsNothing, reason: 'Extra follows the setting');
      expect(find.text(en.fieldDiscountLabel), findsNothing, reason: 'Discount should follow it too');
    }, skip: !_runBugs);

    testWidgets('Product Details: HSN and Purchase Price off -> gone from the product form '
        'and the create screen; on again -> back', (tester) async {
      await freshDb(tester, 'set_cols');
      await tester.runAsync(() => ProductService.insertProduct(soap));

      Future<void> setCols(bool on) async {
        setSize(tester, const Size(1300, 1000));
        await tester.pumpWidget(app(const Scaffold(body: ProductColumnsSettingsScreen())));
        await settle(tester);
        for (final t in [en.productColumnsHsnSacLabel, en.productColumnsPurchasePriceLabel]) {
          final tile = find.widgetWithText(SwitchListTile, t);
          await tester.ensureVisible(tile);
          if (tester.widget<SwitchListTile>(tile).value != on) {
            await tester.tap(tile);
            await tester.pump();
          }
        }
        await tester.tap(find.text(en.actionSave).last);
        await settle(tester);
        expect(find.text(en.productColumnsSavedMessage), findsOneWidget);
      }

      Future<void> check(bool on) async {
        setSize(tester, const Size(1400, 1000));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app(Scaffold(
            body: ProductManagementScreenV2(user: admin, modern: true, startWithAddPanel: true))));
        await settle(tester);
        expect(tester.takeException(), isNull);
        final m = on ? findsWidgets : findsNothing;
        expect(find.widgetWithText(TextField, en.productMgmtHsnSacLabel), m, reason: 'form HSN on=$on');
        expect(find.widgetWithText(TextField, en.productMgmtPurchasePriceLabel), m,
            reason: 'form purchase price on=$on');
        await openCreate(tester);
        expect(find.text(en.productColumnsHsnSacLabel), on ? findsWidgets : findsNothing,
            reason: 'create screen HSN column on=$on');
      }

      await setCols(false);
      await check(false);
      await setCols(true);
      await check(true);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  // ════════════════════════════════════════════════════════════════════════
  // SETTINGS INSIDE THE APP (Dashboard frame)
  // ════════════════════════════════════════════════════════════════════════
  group('Settings in the app frame', () {
    Future<ProviderContainer> openDashboard(WidgetTester tester,
        {UiLayout layout = UiLayout.modern,
        Size size = const Size(1500, 900),
        Locale locale = const Locale('en'),
        String db = 'dash'}) async {
      setSize(tester, size);
      await freshDb(tester, db);
      await tester.runAsync(() async {
        await CompanyRegistryService.ensureDefaultCompanyRegistered();
        await BackendServices.settings.setSetting(SettingKey.uiLayout, layout.name);
      });
      final container = ProviderContainer(overrides: sqliteRepositoryOverrides);
      addTearDown(container.dispose);
      await tester.pumpWidget(app(DashboardScreen(admin), locale: locale, container: container));
      await settle(tester);
      return container;
    }

    Future<void> nav(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(ValueKey('modernNav_$label')));
      await settle(tester);
    }

    Future<void> rail(WidgetTester tester, String label) async {
      final f = find.descendant(of: find.byType(NavigationRail), matching: find.text(label));
      await tester.ensureVisible(f);
      await tester.tap(f);
      await settle(tester);
    }

    final topBar = find.byKey(const ValueKey('modernTopBar'));
    Finder saveButton() => find
        .ancestor(
            of: find.text(en.actionSave),
            matching: find.byWidgetPredicate((w) => w is ButtonStyleButton))
        .first;

    testWidgets('Accessibility: Modern -> Standard -> Modern keeps the Settings section open',
        (tester) async {
      final c = await openDashboard(tester, db: 'acc');
      await nav(tester, en.navSettings);
      await rail(tester, en.settingsNavAccessibilityLabel);
      expect(find.descendant(of: topBar, matching: find.text(en.settingsNavAccessibilityLabel)),
          findsOneWidget);

      await tester.tap(find.text(en.accessibilityStandardLabel));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(c.read(uiLayoutProvider), UiLayout.standard);
      expect(find.byKey(const ValueKey('modernSidebar')), findsNothing);
      expect(find.byType(SegmentedButton<UiLayout>), findsOneWidget,
          reason: 'still on Settings > Accessibility after the switch');
      final saved = await tester.runAsync(() => BackendServices.settings.getSetting(SettingKey.uiLayout));
      expect(saved, uiLayoutToKey(UiLayout.standard));

      await tester.tap(find.descendant(
          of: find.byType(SegmentedButton<UiLayout>), matching: find.text(en.pdfTemplateModernName)));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(c.read(uiLayoutProvider), UiLayout.modern);
      expect(find.byKey(const ValueKey('modernSidebar')), findsOneWidget);
      expect(find.byType(SegmentedButton<UiLayout>), findsOneWidget);
      expect(find.descendant(of: topBar, matching: find.text(en.settingsNavAccessibilityLabel)),
          findsOneWidget);
    });

    testWidgets('Company Info: rename -> sidebar; business type product / service / both -> '
        'sidebar Products / Services', (tester) async {
      await openDashboard(tester, db: 'company');
      await nav(tester, en.navSettings);
      final name = find.widgetWithText(TextField, en.onboardingCompanyNameLabel);
      await tester.enterText(name, 'Release QA Stores');
      await tester.pump();

      Future<void> saveCompany() async {
        await tester.tap(saveButton());
        await settle(tester);
        expect(find.text(en.companyInfoSavedSuccessMessage), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
        await tester.pump();
      }

      Future<void> businessType(String label) async {
        final seg = find.descendant(
            of: find.byType(SegmentedButton<BusinessType>), matching: find.text(label));
        await tester.ensureVisible(seg);
        await tester.tap(seg);
        await tester.pump();
        await saveCompany();
      }

      await saveCompany();
      final info = await tester.runAsync(() => BackendServices.companyInfo.getCompanyInfo());
      expect(info!.name, 'Release QA Stores');
      await nav(tester, en.navDashboard);
      expect(find.descendant(
              of: find.byKey(const ValueKey('modernSidebar')),
              matching: find.text('Release QA Stores')),
          findsOneWidget, reason: 'the company pill shows the new name');

      final products = find.byKey(ValueKey('modernNav_${en.navProducts}'));
      final services = find.byKey(ValueKey('modernNav_${en.navServices}'));
      for (final (label, p, sv) in [
        (en.labelProduct, true, false),
        (en.labelService, false, true),
        (en.labelBoth, true, true),
      ]) {
        await nav(tester, en.navSettings);
        await businessType(label);
        await nav(tester, en.navDashboard);
        expect(products, p ? findsOneWidget : findsNothing, reason: '$label: Products');
        expect(services, sv ? findsOneWidget : findsNothing, reason: '$label: Services');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Company Info logo: not an image / too big / too large in pixels are refused '
        'with a message; a good logo is taken', (tester) async {
      await openDashboard(tester, db: 'logo');
      await nav(tester, en.navSettings);
      final dir = Directory('$supportDir/logos')..createSync();
      final notImage = File('${dir.path}/logo.png')..writeAsStringSync('hello, not a picture');
      final tooBig = File('${dir.path}/big.png')
        ..writeAsBytesSync(Uint8List(2 * 1024 * 1024 + 10));
      final wide = File('${dir.path}/wide.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 1200, height: 20)));
      final good = File('${dir.path}/good.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 64, height: 64)));

      Future<void> pickLogo(File f) async {
        picker.pick = f.path;
        await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
        await settle(tester);
      }

      Future<void> expectMessage(String m) async {
        expect(find.text(m), findsOneWidget);
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
        await settle(tester, rounds: 3);
      }

      await pickLogo(notImage);
      await expectMessage(en.companyInfoInvalidImageMessage);
      await pickLogo(tooBig);
      await expectMessage(en.companyInfoImageTooLargeMessage);
      await pickLogo(wide);
      await expectMessage(en.companyInfoImageDimensionsMessage);
      expect(tester.takeException(), isNull);
      await pickLogo(good);
      expect(find.byIcon(Icons.add_photo_alternate_outlined), findsNothing, reason: 'logo shown');
      await tester.tap(saveButton());
      await settle(tester);
      final logo = await tester.runAsync(() => BackendServices.settings.getCompanyLogo());
      expect(logo, isNotEmpty);
      expect(tester.takeException(), isNull);
    });

    // A PNG whose header is fine but whose data is cut off (a half-copied file).
    testWidgets('a truncated PNG logo shows "Invalid image file" (no uncaught error)',
        (tester) async {
      await openDashboard(tester, db: 'logo_trunc');
      await nav(tester, en.navSettings);
      final full = img.encodePng(img.Image(width: 64, height: 64));
      final f = File('$supportDir/trunc.png')..writeAsBytesSync(full.sublist(0, 60));
      picker.pick = f.path;
      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(en.companyInfoInvalidImageMessage), findsOneWidget);
    });

    // Company Info has no check on the name: a blank (or spaces-only) name is
    // saved with "Company info saved successfully", and every PDF, report
    // header and the sidebar then show no company name.
    testWidgets('Company Info refuses a blank company name', (tester) async {
      await openDashboard(tester, db: 'company_empty');
      await nav(tester, en.navSettings);
      await tester.enterText(find.widgetWithText(TextField, en.onboardingCompanyNameLabel), '   ');
      await tester.pump();
      await tester.tap(saveButton());
      await settle(tester);
      final info = await tester.runAsync(() => BackendServices.companyInfo.getCompanyInfo());
      expect(tester.takeException(), isNull);
      expect(info!.name.trim(), isNotEmpty, reason: 'saved as "${info.name}"');
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // LANGUAGES / LAYOUTS
  // ════════════════════════════════════════════════════════════════════════
  group('Languages and layouts', () {
    Map<String, String> arb(String code) {
      final raw = jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;
      return {
        for (final e in raw.entries)
          if (!e.key.startsWith('@') && e.value is String) e.key: e.value as String,
      };
    }

    final enArb = arb('en');
    final taArb = arb('ta');
    // English strings that have a different Tamil translation: seeing one of
    // these on a Tamil screen means the screen does not use the translation.
    final enOnly = <String, String>{
      for (final e in enArb.entries)
        if (taArb[e.key] != null && taArb[e.key] != e.value && !e.value.contains('{'))
          e.value: e.key,
    };
    final englishOnTamil = <String, Set<String>>{}; // text -> pages
    final latinOnTamil = <String, Set<String>>{};

    void collectEnglish(WidgetTester tester, String page) {
      for (final e in find.byType(Text).evaluate()) {
        final t = (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText();
        if (t == null) continue;
        final text = t.trim();
        if (text.isEmpty) continue;
        if (RegExp(r'[஀-௿]').hasMatch(text)) continue;
        if (enOnly.containsKey(text)) {
          englishOnTamil.putIfAbsent('$text  [${enOnly[text]}]', () => {}).add(page);
        } else if (RegExp(r'[A-Za-z]{4,}').hasMatch(text) &&
            !RegExp(r'^(Invoiceo|admin|Admin|My Company|PDF|GSTIN.*|UPI.*|Madhan Prasath|v?\d.*)$')
                .hasMatch(text)) {
          latinOnTamil.putIfAbsent(text, () => {}).add(page);
        }
      }
    }

    Future<void> sweep(WidgetTester tester, Locale locale, UiLayout layout) async {
      final l = lookupAppLocalizations(locale);
      final errors = <String>[];
      final old = FlutterError.onError;
      String where = '';
      FlutterError.onError = (d) {
        final msg = d.exceptionAsString().split('\n').first;
        final ctx = d.informationCollector == null
            ? ''
            : d.informationCollector!().map((n) => n.toString()).where((x) => x.contains('.dart:')).take(1).join();
        errors.add('$where: $msg ${ctx.trim()}');
      };
      try {
        for (final size in const [Size(1280, 720), Size(1440, 900)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          await freshDb(tester, 'lang_${locale.languageCode}_${layout.name}');
          await tester.runAsync(() async {
            await CompanyRegistryService.ensureDefaultCompanyRegistered();
            await BackendServices.settings.setSetting(SettingKey.uiLayout, layout.name);
          });
          final container = ProviderContainer(overrides: sqliteRepositoryOverrides);
          container.read(localeProvider.notifier).state = locale;
          await tester.pumpWidget(const SizedBox());
          where = '${locale.languageCode} ${layout.name} ${size.width.toInt()}x${size.height.toInt()} Dashboard';
          // As applyAppLocale() does once the app has started (the
          // framework's localizations load the date data first).
          await tester.pumpWidget(app(const SizedBox(), locale: locale, container: container));
          final key = locale.toString();
          DateFormat.useNativeDigitsByDefaultFor('ne', false);
          Intl.defaultLocale =
              DateFormat.localeExists(key) && NumberFormat.localeExists(key) ? key : 'en';
          await tester.pumpWidget(app(DashboardScreen(admin), locale: locale, container: container));
          await settle(tester, rounds: 8);
          if (locale.languageCode == 'ta') collectEnglish(tester, '${layout.name} Dashboard');

          Future<void> go(String label, String page) async {
            where = '${locale.languageCode} ${layout.name} ${size.width.toInt()}x${size.height.toInt()} $page';
            // Standard: the item in the left sidebar (the same word can also
            // be on the page).
            final f = layout == UiLayout.modern
                ? find.byKey(ValueKey('modernNav_$label'))
                : find.byWidgetPredicate((w) {
                    if (w is! Text || w.data != label) return false;
                    return true;
                  }).evaluate().where((e) {
                    final box = e.renderObject as RenderBox?;
                    return box != null && box.hasSize && box.localToGlobal(Offset.zero).dx < 260;
                  }).isEmpty
                    ? find.text('__none__')
                    : find.byWidgetPredicate((w) => w is Text && w.data == label).at(
                        find.byWidgetPredicate((w) => w is Text && w.data == label)
                            .evaluate()
                            .toList()
                            .indexWhere((e) {
                          final box = e.renderObject as RenderBox?;
                          return box != null && box.hasSize && box.localToGlobal(Offset.zero).dx < 260;
                        }));
            if (f.evaluate().isEmpty) {
              errors.add('$where: nav item "$label" not found');
              return;
            }
            await tester.ensureVisible(f);
            await tester.pump();
            await tester.tap(f);
            await settle(tester, rounds: 8);
            if (locale.languageCode == 'ta') collectEnglish(tester, '${layout.name} $page');
          }

          final pages = <String, String>{
            l.navNewInvoice: 'New Invoice',
            l.navInvoices: 'Invoices',
            l.navQuotations: 'Quotations',
            l.navReceipts: 'Receipts',
            l.navCustomers: 'Customers',
            l.navProducts: 'Products',
            if (layout == UiLayout.modern) l.navServices: 'Services',
            l.navReports: 'Reports',
            l.navDashboard: 'Dashboard',
            l.navSettings: 'Settings',
          };
          for (final e in pages.entries) {
            await go(e.key, e.value);
          }
          // Every settings section (rail labels, in rail order).
          final sections = {
            l.settingsNavCompaniesLabel: 'Companies',
            l.settingsNavCompanyInfoLabel: 'Company Info',
            l.settingsNavBackupLabel: 'Backup',
            l.settingsNavUsersLabel: 'Users',
            l.pdfSettingsTitle: 'PDF Settings',
            l.invoiceSettingsAppBarTitle: 'Invoice Settings',
            l.settingsNavProductDetailsLabel: 'Product Details',
            l.settingsNavCustomizeLabel: 'Customize',
            l.settingsNavAccessibilityLabel: 'Accessibility',
            l.settingsNavSoftwareInfoLabel: 'Software Info',
          };
          for (final e in sections.entries) {
            where = '${locale.languageCode} ${layout.name} ${size.width.toInt()}x${size.height.toInt()} Settings > ${e.value}';
            final f = find.descendant(of: find.byType(NavigationRail), matching: find.text(e.key));
            if (f.evaluate().isEmpty) {
              errors.add('$where: rail item "${e.key}" not found');
              continue;
            }
            await tester.ensureVisible(f.first);
            await tester.tap(f.first);
            await settle(tester, rounds: 8);
            if (locale.languageCode == 'ta') collectEnglish(tester, '${layout.name} Settings > ${e.value}');
          }
          await tester.pumpWidget(const SizedBox());
          container.dispose();
        }
      } finally {
        FlutterError.onError = old;
        Intl.defaultLocale = 'en';
        tester.view.reset();
      }
      final unique = errors.toSet().toList();
      expect(unique, isEmpty, reason: unique.take(40).join('\n'));
    }

    for (final code in ['en', 'ta', 'hi', 'ne', 'fr', 'es', 'zh', 'bo']) {
      testWidgets('$code Modern: every page and settings section at 1280x720 and 1440x900, '
          'no exceptions or overflow', (tester) async {
        await sweep(tester, Locale(code), UiLayout.modern);
      }, timeout: const Timeout(Duration(minutes: 6)));
    }
    for (final code in ['en', 'ta']) {
      testWidgets('$code Standard: every page and settings section, no exceptions or overflow',
          (tester) async {
        await sweep(tester, Locale(code), UiLayout.standard);
      }, timeout: const Timeout(Duration(minutes: 6)));
    }

    tearDownAll(() {
      // Low-severity report: English left on Tamil screens.
      // ignore: avoid_print
      print('ENGLISH (has a Tamil translation) seen on Tamil screens: ${englishOnTamil.length}\n'
          '${englishOnTamil.entries.map((e) => '  "${e.key}" on ${e.value.take(4).join(', ')}').join('\n')}');
      // ignore: avoid_print
      print('OTHER LATIN TEXT on Tamil screens (hard-coded or data): ${latinOnTamil.length}\n'
          '${latinOnTamil.entries.map((e) => '  "${e.key}" on ${e.value.take(3).join(', ')}').join('\n')}');
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // REPORTS
  // ════════════════════════════════════════════════════════════════════════
  group('Reports', () {
    final from = DateTime(now.year, now.month, 1);
    final to = now;

    testWidgets('numbers match the seeded invoices / receipts / quotations / declined / trashed',
        (tester) async {
      await freshDb(tester, 'rep_numbers');
      await tester.runAsync(seedReports);
      final r = (await tester.runAsync(() async => (
            inr: await ReportService.getRevenueSummary(from, to, currencyCode: 'INR'),
            all: await ReportService.getRevenueSummary(from, to),
            tax: await ReportService.getTaxByRate(from, to, currencyCode: 'INR'),
            products: await ReportService.getTopProducts(from, to, currencyCode: 'INR'),
            customers: await ReportService.getTopCustomers(from, to, currencyCode: 'INR'),
            daily: await ReportService.getDailyRevenueTrend(from, to, currencyCode: 'INR'),
            quot: await ReportService.getQuotationStats(from, to, currencyCode: 'INR'),
            status: await ReportService.getInvoiceStatusList(from, to, currencyCode: 'INR'),
            aged: await ReportService.getAgedReceivables(currencyCode: 'INR'),
            currencies: await ReportService.getInvoiceCurrencies(),
          )))!;
      // INR: i1 220 (100 paid) + r1 110 (paid) + t1 198 (unpaid).
      expect(r.inr.billed, closeTo(528, 0.001));
      expect(r.inr.collected, closeTo(210, 0.001));
      expect(r.inr.outstanding, closeTo(318, 0.001));
      expect(r.inr.invoiceCount, 2, reason: 'i1 and t1; not the declined, quotation, receipts');
      // All currencies adds the USD receipt (110).
      expect(r.all.billed, closeTo(638, 0.001));
      expect(r.all.collected, closeTo(320, 0.001));
      expect(r.all.outstanding, closeTo(318, 0.001));
      // Tax 10%: 20 + 10 + 18 on 200 + 100 + 180.
      expect(r.tax.single.rate, 10);
      expect(r.tax.single.taxCollected, closeTo(48, 0.001));
      expect(r.tax.single.taxableAmount, closeTo(480, 0.001));
      final byName = {for (final p in r.products) p.name: p};
      expect(byName['Widget']!.unitsSold, 3);
      expect(byName['Widget']!.revenue, closeTo(300, 0.001));
      expect(byName[_tamilProduct]!.unitsSold, 4);
      expect(byName[_tamilProduct]!.revenue, closeTo(180, 0.001));
      expect(r.customers.map((c) => c.name).toSet(), {'Test Customer', _tamilCustomer});
      final days = {for (final d in r.daily) d.date: d};
      expect(days[day1.toIso8601String().substring(0, 10)]!.billed, closeTo(200, 0.001));
      expect(days[day2.toIso8601String().substring(0, 10)]!.billed, closeTo(280, 0.001));
      expect(r.quot.quotationsIssued, 1);
      expect(r.status.map((x) => x.id).toSet(), {'i1', 't1'},
          reason: 'invoice status: no declined, no receipts');
      expect(r.aged.map((a) => a.invoiceId).toSet(), {'i1', 't1'});
      expect(r.currencies, ['INR'], reason: 'outstanding picker: receipts (USD) are never outstanding');
    });

    Future<void> openReports(WidgetTester tester) async {
      setSize(tester, const Size(1500, 1000));
      await tester.pumpWidget(app(framed(const ReportsScreen(), index: 7, title: 'Reports')));
      await settle(tester);
      await settle(tester);
    }

    final sidebar = find.byKey(const ValueKey('reportsSidebarScroll'));
    Future<void> openSection(WidgetTester tester, String label) async {
      final f = find.descendant(of: sidebar, matching: find.text(label));
      await tester.ensureVisible(f.first);
      await tester.tap(f.first);
      await settle(tester);
    }

    final sections = [
      en.reportsNavRevenueLabel, en.reportsNavReceivablesLabel, en.reportsNavTaxLabel,
      en.navCustomers, en.navProducts, en.navQuotations, en.reportsNavInvoiceStatusLabel,
      en.reportsNavDailyReportLabel, en.reportsNavInventoryLabel,
    ];

    /// Taps every "Export PDF" on the open section; returns the files saved.
    Future<List<String>> exportAll(WidgetTester tester, String section) async {
      final btn = find.text(en.customerMgmtExportPdfMenuLabel);
      final n = btn.evaluate().length;
      final out = <String>[];
      for (var i = 0; i < n; i++) {
        final before = picker.saved.length;
        await tester.ensureVisible(btn.at(i));
        await tester.pump();
        await tester.tap(btn.at(i));
        await settleUntil(tester, () {
          if (picker.saved.length == before) return false;
          final f = File(picker.saved.last);
          return f.existsSync() && f.lengthSync() > 0;
        });
        expect(picker.saved.length, before + 1, reason: '$section: export #$i saved a file');
        out.add(picker.saved.last);
        ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
        await tester.pump();
      }
      return out;
    }

    testWidgets('every section opens with data, shows the seeded numbers, and every PDF '
        'export builds (Tamil names); All currencies too', (tester) async {
      await freshDb(tester, 'rep_ui');
      await tester.runAsync(seedReports);
      picker.saveTo = (Directory('$supportDir/exports')..createSync()).path;
      await openReports(tester);
      expect(tester.takeException(), isNull);
      // Revenue (this currency): 528 billed, 210 collected, 318 outstanding.
      expect(find.textContaining('528.00'), findsWidgets);
      expect(find.textContaining('210.00'), findsWidgets);
      expect(find.textContaining('318.00'), findsWidgets);

      final exported = <String, List<String>>{};
      for (final s in sections) {
        await openSection(tester, s);
        expect(tester.takeException(), isNull, reason: s);
        exported[s] = await exportAll(tester, s);
        expect(tester.takeException(), isNull, reason: '$s export');
      }
      // Tax: 48.00 collected. Products: the Tamil product is listed.
      await openSection(tester, en.reportsNavTaxLabel);
      expect(find.textContaining('48.00'), findsWidgets);
      await openSection(tester, en.navProducts);
      expect(find.text(_tamilProduct), findsWidgets);

      for (final e in exported.entries) {
        for (final path in e.value) {
          expect(isPdf(File(path).readAsBytesSync()), isTrue, reason: '${e.key}: $path');
        }
      }
      final total = exported.values.expand((x) => x).length;
      expect(total, greaterThanOrEqualTo(7), reason: 'exports: $exported');

      // All currencies: the USD receipt joins the totals.
      await openSection(tester, en.reportsNavRevenueLabel);
      await tester.tap(find.descendant(of: sidebar, matching: find.text(en.reportsAllCurrenciesLabel)));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('638.00'), findsWidgets);
      for (final s in sections) {
        await openSection(tester, s);
        expect(tester.takeException(), isNull, reason: 'All currencies: $s');
      }
      await openSection(tester, en.reportsNavRevenueLabel);
      final allExports = await exportAll(tester, 'Revenue (all currencies)');
      expect(isPdf(File(allExports.single).readAsBytesSync()), isTrue);
      // ignore: avoid_print
      print('report exports: ${exported.map((k, v) => MapEntry(k, v.length))}');
    }, timeout: const Timeout(Duration(minutes: 6)));

    testWidgets('every section opens on an EMPTY database and its exports still build',
        (tester) async {
      await freshDb(tester, 'rep_empty');
      picker.saveTo = (Directory('$supportDir/exports')..createSync()).path;
      await openReports(tester);
      expect(tester.takeException(), isNull);
      for (final s in sections) {
        await openSection(tester, s);
        expect(tester.takeException(), isNull, reason: s);
        final files = await exportAll(tester, s);
        for (final f in files) {
          expect(isPdf(File(f).readAsBytesSync()), isTrue, reason: '$s: $f');
        }
      }
      await openSection(tester, en.reportsNavRevenueLabel);
      await tester.tap(find.descendant(of: sidebar, matching: find.text(en.reportsAllCurrenciesLabel)));
      await settle(tester);
      for (final s in sections) {
        await openSection(tester, s);
        expect(tester.takeException(), isNull, reason: 'All currencies (empty): $s');
      }
    }, timeout: const Timeout(Duration(minutes: 6)));

    testWidgets('report PDFs straight from the service: Tamil customer / product names',
        (tester) async {
      await freshDb(tester, 'rep_pdf');
      await tester.runAsync(seedReports);
      final bytes = (await tester.runAsync(() async {
        final kpi = await ReportService.getRevenueSummary(from, to, currencyCode: 'INR');
        final trend = await ReportService.getMonthlyRevenueTrend(from, to, currencyCode: 'INR');
        final st = await ReportService.getCustomerStatements('c2', from, to, currencyCode: 'INR');
        return <String, Uint8List>{
          'revenue': await ReportService.exportRevenueReportPdf(trend, kpi,
              currencySymbol: 'Rs.', dateRangeLabel: 'x'),
          'aged': await ReportService.exportAgedReceivablesPdf(
              await ReportService.getAgedReceivableSummary(currencyCode: 'INR'),
              await ReportService.getAgedReceivables(currencyCode: 'INR'),
              currencySymbol: 'Rs.', asOfLabel: 'x'),
          'tax': await ReportService.exportTaxReportPdf(
              await ReportService.getTaxByRate(from, to), currencySymbol: '', dateRangeLabel: 'x'),
          'customers': await ReportService.exportTopCustomersPdf(
              await ReportService.getTopCustomers(from, to), currencySymbol: '', dateRangeLabel: 'x'),
          'products': await ReportService.exportTopProductsPdf(
              await ReportService.getTopProducts(from, to), currencySymbol: '', dateRangeLabel: 'x'),
          'status': await ReportService.exportInvoiceStatusPdf(
              await ReportService.getInvoiceStatusList(from, to), currencySymbol: '', dateRangeLabel: 'x'),
          'daily': await ReportService.exportDailyReportPdf(
              await ReportService.getDailyRevenueTrend(from, to), currencySymbol: '', dateRangeLabel: 'x'),
          'inventory': await ReportService.exportInventoryValuationPdf(
              await ReportService.getInventoryValuationRows(),
              await ReportService.getInventoryValuationSummary(), currencySymbol: 'Rs.'),
          'statement': await CustomerStatementPdfService.export(st),
        };
      }))!;
      for (final e in bytes.entries) {
        expect(isPdf(e.value), isTrue, reason: e.key);
      }
      // Tamil names are drawn shaped (as images) where they appear.
      for (final k in ['customers', 'products', 'status', 'statement', 'aged']) {
        expect(String.fromCharCodes(bytes[k]!), contains('Subtype/Image'),
            reason: '$k: Tamil text shaped');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  // ════════════════════════════════════════════════════════════════════════
  // BACKUP / RESTORE
  // ════════════════════════════════════════════════════════════════════════
  group('Backup', () {
    Future<void> openBackup(WidgetTester tester) async {
      setSize(tester, const Size(1300, 900));
      await tester.pumpWidget(app(const BackupManagementScreen()));
      await settleUntil(tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty);
    }

    Future<void> tapDialog(WidgetTester tester, String label) async {
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(label)));
      await settle(tester);
    }

    Future<int> customerCount(WidgetTester tester) async => (await tester.runAsync(
        () async => (await (await DatabaseHelper().database).query('customers')).length))!;

    testWidgets('create a DB backup and a JSON export; both are listed', (tester) async {
      await freshDb(tester, 'bk_create');
      await tester.runAsync(() => CustomerService.insertCustomer(customer));
      await openBackup(tester);
      expect(find.text(en.backupNoBackupsFoundMessage), findsOneWidget);

      await tester.tap(find.text(en.backupCreateDbButton));
      await settle(tester);
      expect(find.text(en.backupCreatedSuccessMessage), findsOneWidget);
      await tapDialog(tester, en.actionOk);
      expect(find.textContaining('.invoicedb'), findsOneWidget);

      await tester.tap(find.text(en.backupExportJsonButton));
      await settle(tester);
      await tapDialog(tester, en.actionOk);
      expect(find.textContaining('.json'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('restore asks first; Cancel keeps the data, Confirm restores it and '
        'lists the pre-restore copy', (tester) async {
      await freshDb(tester, 'bk_restore');
      await tester.runAsync(() => CustomerService.insertCustomer(customer));
      await openBackup(tester);
      await tester.tap(find.text(en.backupCreateDbButton));
      await settle(tester);
      await tapDialog(tester, en.actionOk);

      // Change the data after the backup.
      await tester.runAsync(() => CustomerService.insertCustomer(tamilCustomer));
      expect(await customerCount(tester), 2);

      Future<void> chooseRestore() async {
        await tester.tap(find.byType(PopupMenuButton<String>).first);
        await settle(tester, rounds: 4);
        await tester.tap(find.text(en.actionRestore).last);
        await settle(tester);
      }

      await chooseRestore();
      expect(find.text(en.backupRestoreConfirmTitle), findsOneWidget);
      await tapDialog(tester, en.actionCancel);
      expect(await customerCount(tester), 2, reason: 'Cancel restores nothing');

      await chooseRestore();
      await tapDialog(tester, en.actionConfirm);
      await settleUntil(tester, () => find.text(en.backupRestoreSuccessTitle).evaluate().isNotEmpty);
      expect(find.text(en.backupRestoreSuccessTitle), findsOneWidget);
      expect(await customerCount(tester), 1, reason: 'the backup had one customer');

      final list = (await tester.runAsync(() => BackupManager().getBackupList(defaultCompanyId)))!;
      expect(list.where((b) => b.fileName.contains('pre_restore')), hasLength(1),
          reason: 'the data from before the restore is kept as a listed backup');
      // The pre-restore copy really holds the two customers.
      final pre = list.firstWhere((b) => b.fileName.contains('pre_restore'));
      final res = await tester.runAsync(() => BackupManager().restoreBackup(backupPath: pre.filePath));
      expect(res!.success, isTrue, reason: res.message);
      expect(await customerCount(tester), 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Import Backup asks before replacing; Cancel = no change', (tester) async {
      await freshDb(tester, 'bk_import');
      await tester.runAsync(() => CustomerService.insertCustomer(customer));
      final made = await tester.runAsync(() => BackupManager()
          .createBackup(companyId: defaultCompanyId, companyName: 'X', type: BackupType.json));
      expect(made!.success, isTrue);
      await tester.runAsync(() => CustomerService.insertCustomer(tamilCustomer));
      await openBackup(tester);

      picker.pick = made.filePath;
      await tester.tap(find.text(en.backupImportButton));
      await settle(tester);
      expect(picker.pickCalls, 1);
      expect(find.text(en.backupRestoreConfirmTitle), findsOneWidget, reason: 'asks first');
      await tapDialog(tester, en.actionCancel);
      expect(await customerCount(tester), 2);

      await tester.tap(find.text(en.backupImportButton));
      await settle(tester);
      await tapDialog(tester, en.actionConfirm);
      await settleUntil(tester, () => find.text(en.backupRestoreSuccessTitle).evaluate().isNotEmpty);
      expect(find.text(en.backupRestoreSuccessTitle), findsOneWidget);
      expect(await customerCount(tester), 1);

      // Picking nothing does nothing.
      picker.pick = null;
      expect(tester.takeException(), isNull);
    });

    // Leaving Settings > Backup while a backup is being made: _createBackup
    // (backup_management_screen.dart) calls setState in `finally` without a
    // `mounted` check (so do _restoreBackup, _deleteBackup, _downloadBackup
    // and _loadBackups' first setState after its await).
    testWidgets('leaving the Backup page while a backup is made raises no error',
        (tester) async {
      await freshDb(tester, 'bk_leave');
      await openBackup(tester);
      await tester.tap(find.text(en.backupCreateDbButton));
      await tester.pump();
      await tester.pumpWidget(app(const SizedBox()));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('JSON restore brings back drafts and product metadata, and drops rows '
        'made after the backup', (tester) async {
      await freshDb(tester, 'bk_json');
      final draftId = (await tester.runAsync(() async {
        await ProductService.insertProduct(widgetProduct);
        await ProductService.upsertProductMetadata(
            ProductMetadata(productId: 'p1', batchNumber: 'B-42', skuCode: 'SKU1'));
        return InvoiceDraftService.saveDraft(InvoiceDraft(
            id: 'd1', invoice: doc('x', 'Invoice', 1, day1), updatedAt: DateTime.now()));
      }))!;
      final made = (await tester.runAsync(() => BackupManager()
          .createBackup(companyId: defaultCompanyId, companyName: 'X', type: BackupType.json)))!;
      expect(made.success, isTrue);
      final json = jsonDecode(File(made.filePath!).readAsStringSync()) as Map<String, dynamic>;
      expect(json.containsKey('users'), isFalse, reason: 'passwords never leave in a JSON export');

      await tester.runAsync(() async {
        await InvoiceDraftService.deleteDraft(draftId);
        await ProductService.deleteProductMetadata('p1');
        await ProductService.insertProduct(tamilProductP);
      });
      final res = (await tester.runAsync(() => BackupManager().restoreBackup(backupPath: made.filePath!)))!;
      expect(res.success, isTrue, reason: res.message);
      final after = await tester.runAsync(() async => (
            draft: await InvoiceDraftService.getDraft(draftId),
            meta: await ProductService.getProductMetadata('p1'),
            extra: await ProductService.getProductById('p2'),
          ));
      expect(after!.draft, isNotNull, reason: 'draft restored');
      expect(after.draft!.invoice.items.single.product.name, 'Widget');
      expect(after.meta?.batchNumber, 'B-42');
      expect(after.meta?.skuCode, 'SKU1');
      expect(after.extra, isNull, reason: '"replace all": rows made after the backup go');
      // Users survive a JSON restore (the export has none).
      final users = await tester.runAsync(
          () async => (await (await DatabaseHelper().database).query('users')).length);
      expect(users, greaterThan(0), reason: 'the admin login is not wiped by a JSON restore');
    });

    testWidgets('corrupt / wrong backups fail cleanly and keep every row', (tester) async {
      await freshDb(tester, 'bk_corrupt');
      await tester.runAsync(() async {
        await CustomerService.insertCustomer(customer);
        await ProductService.insertProduct(widgetProduct);
        await InvoiceService.insertInvoice(doc('i1', 'Invoice', 2, day1));
      });
      final dir = Directory('$supportDir/incoming')..createSync();
      final real = (await tester.runAsync(() => BackupManager()
          .createBackup(companyId: defaultCompanyId, companyName: 'X', customPath: dir.path)))!;
      final realBytes = File(real.filePath!).readAsBytesSync();
      final cases = <String, List<int>>{
        'garbage.invoicedb': utf8.encode('this is not a database at all'),
        'truncated.invoicedb': realBytes.sublist(0, 2048),
        'garbage.json': utf8.encode('{not json'),
        'list.json': utf8.encode('[1,2,3]'),
        'newer.json': utf8.encode(jsonEncode({
          '_metadata': {'version': '9.9'},
          'customers': [],
        })),
        'unknown_table.json': utf8.encode(jsonEncode({
          'customers': [],
          'no_such_table': [
            {'a': 1}
          ],
        })),
        'bad_column.json': utf8.encode(jsonEncode({
          'customers': [
            {'id': 'zz', 'no_such_column': 1}
          ],
        })),
        'backup.txt': utf8.encode('{}'),
      };
      final outcome = <String, String>{};
      for (final e in cases.entries) {
        final f = File('${dir.path}/${e.key}')..writeAsBytesSync(e.value);
        final res = (await tester.runAsync(() => BackupManager().restoreBackup(backupPath: f.path)))!;
        final counts = (await tester.runAsync(() async {
          final db = await DatabaseHelper().database;
          return [
            (await db.query('customers')).length,
            (await db.query('products')).length,
            (await db.query('invoices')).length,
          ];
        }))!;
        outcome[e.key] = '${res.success ? 'OK' : 'FAIL'} $counts ${res.message}';
        expect(counts, [1, 1, 1], reason: '${e.key}: data must be untouched (${res.message})');
        expect(res.success, isFalse, reason: '${e.key} must not report success');
      }
      // ignore: avoid_print
      print('corrupt restore outcomes:\n${outcome.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}');
    });

    // A 0-byte .invoicedb (a failed download, a cloud-sync placeholder) or
    // any SQLite file that is not an Invoiceo database passes verifyBackup
    // (it only opens the file), is copied over the live database and the
    // app re-creates an EMPTY database: "Backup restored successfully" and
    // every customer, product and invoice is gone (only the pre-restore copy
    // still has them).
    for (final kind in ['empty', 'foreign_sqlite'])
      testWidgets('restoring a $kind .invoicedb fails and keeps the data',
          (tester) async {
        await freshDb(tester, 'bk_$kind');
        await tester.runAsync(() async {
          await CustomerService.insertCustomer(customer);
          await ProductService.insertProduct(widgetProduct);
        });
        final f = File('$supportDir/$kind.invoicedb');
        if (kind == 'empty') {
          f.writeAsBytesSync(const []);
        } else {
          await tester.runAsync(() async {
            final other = await databaseFactoryFfi.openDatabase(f.path);
            await other.execute('CREATE TABLE notes (id TEXT)');
            await other.close();
          });
        }
        final res = (await tester.runAsync(() => BackupManager().restoreBackup(backupPath: f.path)))!;
        final counts = (await tester.runAsync(() async {
          final db = await DatabaseHelper().database;
          return [(await db.query('customers')).length, (await db.query('products')).length];
        }))!;
        expect(res.success, isFalse, reason: res.message);
        expect(counts, [1, 1]);
      },
          // BUG: an empty / non-Invoiceo .invoicedb restores "successfully" and wipes all data.
          
      );
  });
}
