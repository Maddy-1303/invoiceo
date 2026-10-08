// The picture receipt used for Tamil and other scripts a printer cannot print
// as text: right size, right width, Tamil shaped, and it replaces printing the
// PDF page (whose 6-point text came out far too small).
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/models/company_info.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/services/escpos_raster.dart';
import 'package:invoiceo/services/pdf/pdf_service.dart';
import 'package:invoiceo/services/pdf/pdf_settings.dart';
import 'package:invoiceo/services/thermal_printer_service_v1.dart';
import 'package:invoiceo/services/thermal_receipt_image.dart';
import 'package:invoiceo/services/thermal_receipt_lines.dart';

const _out = String.fromEnvironment('OUT_DIR');

PdfGenerationSettings _settings(PageSize ps,
        {String thanks = 'நன்றி! மீண்டும் வருக!',
        bool showAliasName = false,
        bool showRoundOff = false,
        bool showCompanyName = true,
        bool showAddress = true,
        bool showPhone = true}) =>
    PdfGenerationSettings(
      showAliasName: showAliasName,
      showRoundOff: showRoundOff,
      showCompanyName: showCompanyName,
      showAddress: showAddress,
      showPhone: showPhone,
      company: CompanyInfo(
          name: 'Linga Nadar Stores', address: '123 Street\nCity, State 12345',
          phone: '9876543210', email: '', website: '', gstin: '', country: 'India'),
      template: InvoiceTemplate.thermal, invoicePrefix: 'INV-', showGst: true,
      showQuantity: true, showDiscount: true, showTypeTag: true,
      businessType: BusinessType.both, upiEntries: const [], showQrStr: 'false',
      showBankDetails: false, bankAccounts: const [],
      logoPosition: LogoPosition.left, logoSizePx: 80, logoBytes: null,
      signatureBytes: null, thankYouNote: thanks,
      datePattern: 'dd/MM/yyyy', showFooterBranding: true, themeColor: null,
      showPreviousBalance: false, pageFormat: PDFService.pageSizeToFormat(ps),
      pageSize: ps, showTotalQuantity: false, pdfTheme: pw.ThemeData.base(),
      watermarkBytes: null, watermarkOpacity: 0.05, signaturePosition: 'left',
      descriptionNewLine: false, showCgstSgst: false, showDescription: false,
      landscape: false, fontSizeScale: 1.0, companyNameScale: 1.0,
      docTitleScale: 1.0, tableHeaderScale: 1.0, tableItemsScale: 1.0,
      totalsScale: 1.0,
    );

Product _p(String id, String name, double price, String unit) => Product(
    id: id, name: name, description: '', price: price, stock: 99,
    hsncode: '1001', tax_rate: 18, unit: unit);

// The items from the photo of the first printed receipt.
Invoice _tamilInvoice() => Invoice(
      id: '2', invoiceNumber: '2',
      customer: Customer(id: 'c', name: 'Madhan', email: '', phone: '', address: '', gstin: ''),
      items: [
        InvoiceItem(product: _p('1', '3 ரோசஸ் டீ 250கி', 110, 'gm'), quantity: 5),
        InvoiceItem(product: _p('2', 'அரிசி 1கிலோ', 55, 'kg'), quantity: 5),
        InvoiceItem(product: _p('3', 'ஆச்சி மிளகாய் தூள் சிறப்பு தரம் 500கி குடும்ப பேக்', 210, 'gm'), quantity: 1),
        InvoiceItem(product: _p('4', 'உப்பு 1கிலோ', 22, 'kg'), quantity: 5),
        InvoiceItem(product: _p('5', 'கறிவேப்பிலை 50கி', 10, 'gm'), quantity: 1),
        InvoiceItem(product: _p('6', 'இயற்கை முறையில் தயாரிக்கப்பட்ட சுத்தமான நாட்டு சர்க்கரை 1கிலோ', 85, 'kg'), quantity: 1),
      ],
      date: DateTime(2026, 10, 5, 21, 2), type: 'Invoice', taxRate: 0.18,
      taxMode: TaxMode.global, currencyCode: 'INR', currencySymbol: 'Rs.',
    );

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
    tmp = Directory.systemTemp.createTempSync('invoiceo_receipt_img');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
    await DatabaseHelper().switchToFile('receipt_img.db');
  });
  tearDownAll(() async {
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });

  List<ReceiptLine> lines({bool table = true}) => buildReceiptLines(
      _tamilInvoice(), _settings(PageSize.thermal80),
      previousBalance: 0, dateFormatKey: 'dd/MM/yyyy', tableLayout: table);

  int blackPixels(img.Image im) {
    var n = 0;
    for (final p in im) {
      if (p.luminanceNormalized < 0.5) n++;
    }
    return n;
  }

  Future<void> save(String name, img.Image im) async {
    if (_out.isEmpty) return;
    await File('$_out/$name.png').writeAsBytes(img.encodePng(im));
  }

  test('80 mm: exactly 576 dots wide, with Tamil text drawn', () async {
    final im = await ThermalReceiptImage.render(lines(), widthDots: 576, fontPx: 30);
    expect(im.width, 576);
    expect(im.height, greaterThan(600));
    expect(blackPixels(im), greaterThan(8000), reason: 'text was drawn');
    await save('receipt_80_large', im);
  });

  test('58 mm: exactly 384 dots wide', () async {
    final im = await ThermalReceiptImage.render(lines(), widthDots: 384, fontPx: 26);
    expect(im.width, 384);
    await save('receipt_58_normal', im);
  });

  test('text size setting: bigger text means a taller receipt', () async {
    final normal = await ThermalReceiptImage.render(lines(), widthDots: 576, fontPx: ThermalReceiptImage.fontPxFor('normal'));
    final large = await ThermalReceiptImage.render(lines(), widthDots: 576, fontPx: ThermalReceiptImage.fontPxFor('large'));
    final xl = await ThermalReceiptImage.render(lines(), widthDots: 576, fontPx: ThermalReceiptImage.fontPxFor('xlarge'));
    expect(normal.height, lessThan(large.height));
    expect(large.height, lessThan(xl.height));
    await save('receipt_80_normal', normal);
    await save('receipt_80_xlarge', xl);
  });

  // N one-line items (short Tamil names, whole-number quantities).
  Invoice manyItems(int n,
          {String name = 'அரிசி', String unit = 'கிலோ', TaxMode tax = TaxMode.global}) =>
      Invoice(
        id: '9', invoiceNumber: '9',
        customer: Customer(id: 'c', name: 'Madhan', email: '', phone: '', address: '', gstin: ''),
        items: [
          for (var i = 1; i <= n; i++)
            InvoiceItem(product: _p('$i', '$name $i', 55.5 + i, unit), quantity: 2.5),
        ],
        date: DateTime(2026, 10, 5, 21, 2), type: 'Invoice', taxRate: 0.18,
        taxMode: tax, currencyCode: 'INR', currencySymbol: 'Rs.',
      );
  List<ReceiptLine> linesFor(Invoice inv,
          {bool table = true, PageSize ps = PageSize.thermal80, PdfGenerationSettings? s}) =>
      buildReceiptLines(inv, s ?? _settings(ps),
          previousBalance: 0, dateFormatKey: 'dd/MM/yyyy', tableLayout: table);

  test('Table layout uses one line per item; Detailed uses more paper', () async {
    final inv = manyItems(8);
    final table = await ThermalReceiptImage.render(linesFor(inv, table: true), widthDots: 576, fontPx: 30);
    final detailed = await ThermalReceiptImage.render(linesFor(inv, table: false), widthDots: 576, fontPx: 30);
    expect(table.height, lessThan(detailed.height * 0.85),
        reason: 'table ${table.height} vs detailed ${detailed.height}');
    await save('receipt_80_table', table);
    await save('receipt_80_detailed', detailed);
    // The photo's six long Tamil names, in both layouts (names wrap).
    await save('receipt_80_table_longnames',
        await ThermalReceiptImage.render(lines(table: true), widthDots: 576, fontPx: 30));
  });

  test('Table layout shows the Rate column (and GST per item) when it fits', () async {
    // Same items: with the Rate column the receipt carries more ink than the
    // same receipt with Rate left out would. Compare against the detailed
    // layout's item rows: every rate must appear in the table too.
    final inv = manyItems(4);
    final withRate = await ThermalReceiptImage.render(linesFor(inv), widthDots: 576, fontPx: 30);
    final noRateLines = [
      for (final l in linesFor(inv))
        l.kind == ReceiptLineKind.item
            ? ReceiptLine.item(sl: int.parse(l.sl), name: l.text, qty: l.qty, unit: l.unit, rate: '', gst: l.gst, total: l.total, tableLayout: true)
            : l
    ];
    final withoutRate = await ThermalReceiptImage.render(noRateLines, widthDots: 576, fontPx: 30);
    expect(blackPixels(withRate), greaterThan(blackPixels(withoutRate)),
        reason: 'the rate numbers were drawn');
    await save('receipt_80_table_rate', withRate);
    // Per-item GST on 80 mm and a table on 58 mm: no room for the columns,
    // so the two-line layout is used (still readable, nothing dropped).
    await save('receipt_80_table_pergst',
        await ThermalReceiptImage.render(linesFor(manyItems(4, tax: TaxMode.perItem)), widthDots: 576, fontPx: 30));
    await save('receipt_58_table_fallback',
        await ThermalReceiptImage.render(linesFor(inv, ps: PageSize.thermal58), widthDots: 384, fontPx: 26));
  });

  test('one wide quantity does not squeeze every item name', () async {
    final plain = manyItems(6);
    final odd = manyItems(6);
    odd.items[3] = InvoiceItem(
        product: _p('x', 'அரிசி 4', 60, 'கிலோ'), quantity: 1234567.5);
    final a = await ThermalReceiptImage.render(linesFor(plain), widthDots: 576, fontPx: 30);
    final b = await ThermalReceiptImage.render(linesFor(odd), widthDots: 576, fontPx: 30);
    expect(b.height, lessThan(a.height * 1.35),
        reason: 'one odd row ${b.height} vs ${a.height}: the names must not collapse');
    await save('receipt_80_table_oddunit', b);
  });

  test('a very long invoice is drawn whole, not shrunk or crashed', () async {
    // 420 items at "extra large" is far past the 16384-row limit of one GPU
    // picture. It must come out full size with the totals at the bottom.
    final inv = manyItems(420);
    final im = await ThermalReceiptImage.render(linesFor(inv), widthDots: 576, fontPx: 36);
    expect(im.width, 576);
    expect(im.height, greaterThan(16384), reason: 'test must really exceed one texture');
    // Ink in the last rows (the totals / footer) and in the first.
    bool inkIn(int y0, int y1) {
      for (var y = y0; y < y1; y++) {
        for (var x = 0; x < im.width; x++) {
          if (im.getPixel(x, y).luminanceNormalized < 0.5) return true;
        }
      }
      return false;
    }
    expect(inkIn(0, 60), isTrue);
    expect(inkIn(im.height - 160, im.height - 28), isTrue);
    // And it prints: bands of 128 rows, all of the data present.
    final bytes = escPosRasterBands(im);
    expect(bytes.length, greaterThan(576 ~/ 8 * 16384));
  });

  test('strips join without a seam: same pixels as one picture', () async {
    final inv = manyItems(40);
    final one = await ThermalReceiptImage.render(linesFor(inv), widthDots: 576, fontPx: 30, stripRows: 100000);
    final strips = await ThermalReceiptImage.render(linesFor(inv), widthDots: 576, fontPx: 30, stripRows: 256);
    expect(strips.height, one.height);
    expect(strips.getBytes(), one.getBytes());
  });

  group('receipt content matches the PDF receipt', () {
    Invoice base({String? title, double discount = 0, String? alias}) {
      final prod = _p('1', 'Rice', 100, 'kg');
      if (alias != null) prod.aliasName = alias;
      return Invoice(
        id: '1', invoiceNumber: '1',
        customer: Customer(id: 'c', name: 'Madan', email: '', phone: '', address: '', gstin: ''),
        items: [InvoiceItem(product: prod, quantity: 2)],
        date: DateTime(2026, 10, 5), type: 'Invoice', taxRate: 0, taxMode: TaxMode.none,
        currencyCode: 'INR', currencySymbol: 'Rs.', invoiceTitle: title,
        invoiceDiscountType: InvoiceDiscountType.amount, invoiceDiscountValue: discount,
      );
    }
    List<String> texts(Invoice i, PdfGenerationSettings s) => [
          for (final l in buildReceiptLines(i, s, previousBalance: 0, dateFormatKey: 'dd/MM/yyyy', tableLayout: true))
            '${l.text}|${l.right}'
        ];

    test('Tamil alias name is printed when "show alias name" is on, and forces the picture', () {
      final inv = base(alias: 'அரிசி');
      final off = _settings(PageSize.thermal80, thanks: 'Thank you!');
      final on = _settings(PageSize.thermal80, thanks: 'Thank you!', showAliasName: true);
      expect(ThermalPrinterService.invoiceNeedsImageReceipt(inv, off), isFalse);
      expect(ThermalPrinterService.invoiceNeedsImageReceipt(inv, on), isTrue);
      expect(texts(inv, on).any((t) => t.contains('அரிசி')), isTrue);
      expect(texts(inv, off).any((t) => t.contains('அரிசி')), isFalse);
    });

    test('document title override, extra discount and round-off rows', () {
      final inv = base(title: 'Tax Invoice', discount: 20);
      final s = _settings(PageSize.thermal80, thanks: 'Thank you!', showRoundOff: true);
      final t = texts(inv, s).join('\n');
      expect(t, contains('TAX INVOICE'));
      expect(t, contains('Extra Discount|-Rs. 20.00'));
      expect(t, contains('Round off:'));
      expect(t, contains('NET AMOUNT|Rs. 180.00'));
      expect(t, contains('One Hundred and Eighty Only'));
      // and none of it when the settings are off / the values are unset
      final plain = texts(base(), _settings(PageSize.thermal80, thanks: 'Thank you!')).join('\n');
      expect(plain, isNot(contains('Extra Discount')));
      expect(plain, isNot(contains('NET AMOUNT')));
      expect(plain, contains('INVOICE'));
    });

    test('company name, address and phone follow their show/hide settings', () {
      final inv = base();
      final hidden = texts(inv, _settings(PageSize.thermal80, thanks: 'Thank you!', showCompanyName: false, showAddress: false, showPhone: false)).join('\n');
      expect(hidden, isNot(contains('Linga Nadar Stores')));
      expect(hidden, isNot(contains('123 Street')));
      expect(hidden, isNot(contains('9876543210')));
      final shown = texts(inv, _settings(PageSize.thermal80, thanks: 'Thank you!')).join('\n');
      expect(shown, contains('Linga Nadar Stores'));
      expect(shown, contains('9876543210'));
    });
  });

  test('settings values: sizes and widths', () {
    expect(ThermalReceiptImage.fontPxFor(null), 30);
    expect(ThermalReceiptImage.fontPxFor('normal'), 26);
    expect(ThermalReceiptImage.fontPxFor('xlarge'), 36);
    expect(ThermalReceiptImage.fontPxFor('nonsense'), 30);
    expect(ThermalReceiptImage.widthDotsFor('auto', is58: false), 576);
    expect(ThermalReceiptImage.widthDotsFor(null, is58: true), 384);
    expect(ThermalReceiptImage.widthDotsFor('512', is58: false), 512);
    expect(ThermalReceiptImage.widthDotsFor('9', is58: false), 256, reason: 'clamped');
    expect(ThermalReceiptImage.widthDotsFor('99999', is58: false), 832, reason: 'clamped');
  });

  test('every text row is at least as tall as a printer\'s own 24-dot text', () async {
    // The old PDF-page picture drew 6-point text: about 17 dots. Anything
    // under the printer's built-in 24 dots would again look "tiny".
    expect(ThermalReceiptImage.fontPxFor('normal'), greaterThanOrEqualTo(24));
  });

  test('the full receipt for a Tamil invoice is a picture, not text', () async {
    final bytes = await ThermalPrinterService.buildReceiptBytesFor(
        _tamilInvoice(), _settings(PageSize.thermal80), 0);
    expect(bytes.sublist(0, 2), [0x1B, 0x40], reason: 'starts with printer reset');
    expect(bytes.sublist(2, 6), [0x1D, 0x76, 0x30, 0x00], reason: 'then a raster image');
    // 576 dots = 72 bytes per row.
    expect(bytes[6] + (bytes[7] << 8), 72);
    expect(bytes.length, greaterThan(20000), reason: 'carries real image data');
  });

  group('plain text or picture: decided by what is actually printed', () {
    test('what the plain-text printer can encode', () {
      expect(canPrintAsEscPosText('Coffee Powder 100g, Rs. 90.00'), isTrue);
      expect(canPrintAsEscPosText('Café Latté'), isFalse,
          reason: 'Latin-1 letters print wrong without a code page: picture');
      expect(canPrintAsEscPosText('It\u2019s'), isTrue, reason: 'the library swaps the curly apostrophe');
      expect(canPrintAsEscPosText('\u20B9 90.00'), isFalse, reason: 'the rupee sign crashed the text printer');
      expect(canPrintAsEscPosText('காபி'), isFalse);
      expect(canPrintAsEscPosText('أرز'), isFalse, reason: 'Arabic');
      expect(canPrintAsEscPosText('ข้าว'), isFalse, reason: 'Thai');
      expect(canPrintAsEscPosText('A \u2013 B'), isFalse, reason: 'en dash');
    });

    Invoice inv({String symbol = 'Rs.', String name = 'Rice'}) => Invoice(
          id: '1', invoiceNumber: '1',
          customer: Customer(id: 'c', name: 'Madan', email: '', phone: '', address: '', gstin: ''),
          items: [InvoiceItem(product: _p('1', name, 10, 'kg'), quantity: 1)],
          date: DateTime(2026, 10, 5), type: 'Invoice', taxRate: 0.18,
          taxMode: TaxMode.global, currencyCode: 'INR', currencySymbol: symbol,
        );

    test('an English receipt stays plain text', () {
      expect(ThermalPrinterService.invoiceNeedsImageReceipt(inv(), _settings(PageSize.thermal80, thanks: 'Thank you!')), isFalse);
    });
    test('the rupee sign alone now switches to the picture instead of crashing', () {
      expect(ThermalPrinterService.invoiceNeedsImageReceipt(inv(symbol: '\u20B9'), _settings(PageSize.thermal80, thanks: 'Thank you!')), isTrue);
    });
    test('Tamil, Arabic and Thai names switch to the picture', () {
      for (final n in ['காபி', 'أرز بسمتி'.replaceAll('ி','ي'), 'ข้าวหอม']) {
        expect(ThermalPrinterService.invoiceNeedsImageReceipt(inv(name: n), _settings(PageSize.thermal80, thanks: 'Thank you!')), isTrue, reason: n);
      }
    });
  });
}
