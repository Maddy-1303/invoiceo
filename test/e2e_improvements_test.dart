// End-to-end check of every improvement, on the real screens:
//   scan (any focus) -> quantity prompt -> same item again = +1 ->
//   save the invoice -> database -> PDFs in all 7 templates (Indic text
//   shaped as images) -> thermal receipt decision.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/models/company_info.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/screens/create_invoice_screen_v2.dart';
import 'package:invoiceo/services/pdf/pdf_service.dart';
import 'package:invoiceo/services/pdf/pdf_settings.dart';
import 'package:invoiceo/services/pdf/shaped_text_rasterizer.dart';
import 'package:invoiceo/services/thermal_printer_service_v1.dart';

import 'test_pdf_font_service.dart';

const _digitKeys = {
  '0': LogicalKeyboardKey.digit0, '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2, '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4, '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6, '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8, '9': LogicalKeyboardKey.digit9,
};

const _out = String.fromEnvironment('OUT_DIR');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Exactly what main() does before runApp: the save path and the PDF
    // code reach the database through BackendServices.
    BackendServices.configure(
      settings: SqliteSettingsRepository(),
      companyInfo: SqliteCompanyInfoRepository(),
      invoices: SqliteInvoiceRepository(),
      payments: SqlitePaymentRepository(),
      installation: SqliteInstallationRepository(),
    );
    tmp = Directory.systemTemp.createTempSync('invoiceo_e2e_test');
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
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  // Scanner: key goes to the app first; if unhandled it is typed into the
  // focused box ([box] null = nothing focused). Ends with Enter.
  Future<void> scan(WidgetTester tester, String code, {Finder? box}) async {
    for (final ch in code.split('')) {
      final key = _digitKeys[ch]!;
      final handled = await tester.sendKeyDownEvent(key, character: ch);
      if (!handled && box != null) {
        final cur = tester.widget<TextField>(box).controller!.text;
        await tester.enterText(box, cur + ch);
      }
      await tester.sendKeyUpEvent(key);
      await tester.pump(const Duration(milliseconds: 5));
    }
    final handled = await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    if (!handled && box != null) {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
  }

  String? openPrompt(List<String> names) {
    for (final n in names) {
      if (find
          .descendant(
              of: find.byType(AlertDialog), matching: find.textContaining('$n (Rs.'))
          .evaluate()
          .isNotEmpty) {
        return n;
      }
    }
    return null;
  }

  Finder promptQty() => find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(TextField))
      .first;

  Future<void> pressAdd(WidgetTester tester) async {
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Add')));
    await tester.pump();
    await settle(tester);
  }

  PdfGenerationSettings pdfSettings(
          pw.ThemeData theme, InvoiceTemplate t, PageSize ps) =>
      PdfGenerationSettings(
        company: CompanyInfo(
            name: 'Madhan test', address: '123 Street', phone: '9876543210',
            email: '', website: '', gstin: '', country: 'India'),
        template: t, invoicePrefix: 'INV-', showGst: true, showQuantity: true,
        showDiscount: true, showTypeTag: true, businessType: BusinessType.both,
        upiEntries: const [], showQrStr: 'false', showBankDetails: false,
        bankAccounts: const [], logoPosition: LogoPosition.left,
        logoSizePx: 80, logoBytes: null, signatureBytes: null,
        thankYouNote: '', datePattern: 'dd/MM/yyyy', showFooterBranding: true,
        themeColor: null, showPreviousBalance: false,
        pageFormat: PDFService.pageSizeToFormat(ps), pageSize: ps,
        showTotalQuantity: false, pdfTheme: theme, watermarkBytes: null,
        watermarkOpacity: 0.05, signaturePosition: 'left',
        descriptionNewLine: false, showCgstSgst: false, showDescription: false,
        landscape: false, fontSizeScale: 1.0, companyNameScale: 1.0,
        docTitleScale: 1.0, tableHeaderScale: 1.0, tableItemsScale: 1.0,
        totalsScale: 1.0,
      );

  PageSize pageFor(InvoiceTemplate t) => switch (t) {
        InvoiceTemplate.compact => PageSize.a6,
        InvoiceTemplate.thermal => PageSize.thermal80,
        _ => PageSize.a4,
      };

  testWidgets('cashier flow: scan -> prompt -> save -> database -> PDFs -> print',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Tamil, Malayalam and English products; the barcode is the HSN code.
    const tamilA = 'காபி தூள் 100கி';
    const tamilB = 'ஆச்சி மிளகாய் தூள் 100கி';
    const malayalam = 'മലയാളം ഭാഷ';
    const english = 'Coffee Powder 100g';
    const names = [tamilA, tamilB, malayalam, english];
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('e2e.db');
      for (final p in [
        ['A', tamilA, '9001', 90.0, 50],
        ['B', tamilB, '9002', 45.0, 80],
        ['C', malayalam, '9003', 10.0, 30],
        ['D', english, '9004', 90.0, 20],
      ]) {
        await ProductService.insertProduct(Product(
            id: p[0] as String, name: p[1] as String, description: '',
            price: p[3] as double, stock: p[4] as int, hsncode: p[2] as String,
            tax_rate: 18));
      }
    });

    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CreateInvoiceScreenV2()),
      ),
    ));
    await settle(tester);

    // A customer with a Tamil name, typed by a person.
    final customer = find.widgetWithText(TextField, 'Customer Name *');
    await tester.enterText(customer, 'மதன்');
    await tester.pump();

    // 1) Product A, scanned with NOTHING focused.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await scan(tester, '9001');
    expect(openPrompt(names), tamilA);
    await pressAdd(tester);

    // 2) Product B scanned twice while its prompt is open -> quantity 2.
    await scan(tester, '9002');
    expect(openPrompt(names), tamilB);
    await scan(tester, '9002', box: promptQty());
    expect(openPrompt(names), tamilB);
    expect(tester.widget<TextField>(promptQty()).controller!.text, '2');
    await pressAdd(tester);

    // 3) Product C scanned while the CUSTOMER box has focus: the digits must
    //    not end up in the customer name.
    await tester.tap(customer);
    await tester.pump();
    await scan(tester, '9003', box: customer);
    expect(openPrompt(names), malayalam);
    expect(tester.widget<TextField>(customer).controller!.text, 'மதன்');
    await pressAdd(tester);

    // 4) English product D.
    await scan(tester, '9004');
    expect(openPrompt(names), english);
    await pressAdd(tester);

    // 5) A code that is not in the catalogue adds nothing.
    await scan(tester, '5555');
    expect(find.byType(AlertDialog), findsNothing);

    // Save the invoice.
    // The "No products found" message sits over the bottom bar for a few
    // seconds; wait for it to go like a cashier would, then press Create.
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .clearSnackBars();
    await tester.pump(const Duration(seconds: 1));
    final createButton = find.textContaining('Create Invoice (Ctrl+S)');
    await tester.ensureVisible(createButton); // it sits below the fold
    await tester.pump();
    await tester.tap(createButton);
    await tester.pump();
    await settle(tester);
    await settle(tester);


    // ---- database ----
    late Invoice saved;
    late Map<String, int> stock;
    await tester.runAsync(() async {
      final all = await InvoiceService.getAllInvoices();
      expect(all, hasLength(1), reason: 'exactly one invoice saved');
      saved = (await InvoiceService.getInvoiceById(all.single.id))!;
      stock = {
        for (final id in ['A', 'B', 'C', 'D'])
          id: (await ProductService.getProductById(id))!.stock,
      };
    });
    expect(saved.customer.name, 'மதன்');
    final qty = {for (final i in saved.items) i.product.id: i.quantity};
    expect(qty, {'A': 1.0, 'B': 2.0, 'C': 1.0, 'D': 1.0},
        reason: 'B scanned twice = 2, nothing like 9002');
    expect(saved.items, hasLength(4), reason: 'unknown code added nothing');
    expect(stock, {'A': 49, 'B': 78, 'C': 29, 'D': 19},
        reason: 'stock is reduced by the quantities sold');

    // Turning text into an image needs real async time, not the fake clock.
    await tester.runAsync(() async {
      // ---- PDFs: every template, Indic text shaped as images ----
      final theme = await TestPdfFontService.loadTheme();
      for (final t in InvoiceTemplate.values) {
        final s = pdfSettings(theme, t, pageFor(t));
        final doc = await ShapedTextRasterizer.buildWithShaping(() =>
            PDFService.generateInvoicePDFWithSettings(saved, s,
                previousBalanceDue: 0));
        final bytes = await doc.save();
        expect(bytes.length, greaterThan(5000), reason: '${t.name} produced a PDF');
        expect(String.fromCharCodes(bytes), contains('Subtype/Image'),
            reason: '${t.name}: Tamil/Malayalam must be drawn shaped (as images)');
        if (_out.isNotEmpty) {
          await File('$_out/e2e_${t.name}.pdf').writeAsBytes(bytes);
        }
      }

      // ---- an English-only invoice keeps plain text everywhere ----
      final englishOnly = Invoice(
        id: 'EN1', invoiceNumber: '9',
        customer: Customer(
            id: 'c9', name: 'Madan', email: '', phone: '', address: '', gstin: ''),
        items: [
          InvoiceItem(
              product: Product(
                  id: 'D', name: english, description: '', price: 90, stock: 19,
                  hsncode: '9004', tax_rate: 18),
              quantity: 1),
        ],
        date: DateTime(2026, 10, 5), type: 'Invoice', taxRate: 0.18,
        taxMode: TaxMode.perItem, notes: '',
        currencyCode: 'INR', currencySymbol: 'Rs.', // what the app stores
      );
      for (final t in InvoiceTemplate.values) {
        final s = pdfSettings(theme, t, pageFor(t));
        final bytes = await (await ShapedTextRasterizer.buildWithShaping(() =>
                PDFService.generateInvoicePDFWithSettings(englishOnly, s,
                    previousBalanceDue: 0)))
            .save();
        expect(String.fromCharCodes(bytes), isNot(contains('Subtype/Image')),
            reason: '${t.name}: English-only must stay plain text');
      }

      // ---- thermal printer: which path each receipt takes ----
      final thermal = pdfSettings(theme, InvoiceTemplate.thermal, PageSize.thermal80);
      expect(ThermalPrinterService.invoiceNeedsImageReceipt(saved, thermal), isTrue,
          reason: 'Tamil receipt is sent to the printer as an image');
      expect(ThermalPrinterService.invoiceNeedsImageReceipt(englishOnly, thermal),
          isFalse, reason: 'English receipt keeps the original text path');
    });
  }, timeout: const Timeout(Duration(minutes: 3)));
}
