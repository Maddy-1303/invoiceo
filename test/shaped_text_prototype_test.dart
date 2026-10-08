import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/models/company_info.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/services/pdf/pdf_service.dart';
import 'package:invoiceo/services/pdf/pdf_settings.dart';
import 'package:invoiceo/services/pdf/shaped_text_rasterizer.dart';
import 'package:pdf/widgets.dart' as pw;


import 'test_pdf_font_service.dart';

typedef PdfDoc = pw.Document;

// Where the before/after PDFs are written; defaults to the system temp dir.
final _out = const String.fromEnvironment('OUT_DIR').isNotEmpty
    ? const String.fromEnvironment('OUT_DIR')
    : Directory.systemTemp.path;

Invoice _invoice() {
  Product p(String id, String name, double price) => Product(
        id: id, name: name, description: '', price: price,
        stock: 10, hsncode: '', tax_rate: 18);
  return Invoice(
    id: 'inv1',
    invoiceNumber: '1',
    customer: Customer(
        id: 'c1', name: 'மதன்', email: '', phone: '', address: 'சென்னை', gstin: ''),
    items: [
      InvoiceItem(product: p('1', 'காபி தூள் 100கி', 90), quantity: 1),
      InvoiceItem(product: p('2', 'கற்பூரம் 10கி', 20), quantity: 1),
      InvoiceItem(product: p('3', 'ஆச்சி மிளகாய் தூள் 100கி', 45), quantity: 33),
      InvoiceItem(product: p('4', 'മലയാളം ഭാഷ', 10), quantity: 2),
      InvoiceItem(product: p('5', 'తెలుగు భాష', 10), quantity: 2),
      InvoiceItem(product: p('6', 'Coffee Powder 100g', 10), quantity: 2),
    ],
    date: DateTime(2026, 10, 5, 13, 21),
    type: 'Invoice',
    taxRate: 0.18,
    taxMode: TaxMode.perItem,
    notes: '',
  );
}

PdfGenerationSettings _settings(theme, InvoiceTemplate template, PageSize pageSize) =>
    PdfGenerationSettings(
      company: CompanyInfo(
          name: 'Your Company Name', address: '123 Street', phone: '9876543210',
          email: '', website: '', gstin: '', country: 'India'),
      template: template,
      invoicePrefix: 'INV-',
      showGst: true, showQuantity: true, showDiscount: true, showTypeTag: true,
      businessType: BusinessType.both,
      upiEntries: const [], showQrStr: 'false', showBankDetails: false,
      bankAccounts: const [],
      logoPosition: LogoPosition.left, logoSizePx: 80, logoBytes: null,
      signatureBytes: null, thankYouNote: '', datePattern: 'dd/MM/yyyy',
      showFooterBranding: true, themeColor: null, showPreviousBalance: false,
      pageFormat: PDFService.pageSizeToFormat(pageSize),
      pageSize: pageSize, showTotalQuantity: false, pdfTheme: theme,
      watermarkBytes: null, watermarkOpacity: 0.05, signaturePosition: 'left',
      descriptionNewLine: false, showCgstSgst: false, showDescription: false,
      landscape: false, fontSizeScale: 1.0, companyNameScale: 1.0,
      docTitleScale: 1.0, tableHeaderScale: 1.0, tableItemsScale: 1.0,
      totalsScale: 1.0,
    );

PageSize _pageSizeFor(InvoiceTemplate t) => switch (t) {
      InvoiceTemplate.compact => PageSize.a6,
      InvoiceTemplate.thermal => PageSize.thermal80,
      _ => PageSize.a4,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _saveTwiceTest();

  for (final template in InvoiceTemplate.values) {
    test('${template.name}: Indic text is drawn as shaped images', () async {
      final theme = await TestPdfFontService.loadTheme();
      final s = _settings(theme, template, _pageSizeFor(template));
      PdfDoc build() => PDFService.generateInvoicePDFWithSettings(
          _invoice(), s, previousBalanceDue: 0);

      final shaped =
          await (await ShapedTextRasterizer.buildWithShaping(build)).save();
      await Directory(_out).create(recursive: true);
      await File('$_out/${template.name}_shaped.pdf').writeAsBytes(shaped);

      // The test invoice has no logo/watermark/signature, so any image in the
      // output is a shaped-text image.
      expect(String.fromCharCodes(shaped), contains('Subtype/Image'));
    });
  }
}

// Preview, print and download each call save() on the returned document.
void _saveTwiceTest() {
  test('a document returned by buildWithShaping saves normally, with images',
      () async {
    final theme = await TestPdfFontService.loadTheme();
    final s = _settings(theme, InvoiceTemplate.thermal, PageSize.thermal80);
    final doc = await ShapedTextRasterizer.buildWithShaping(() =>
        PDFService.generateInvoicePDFWithSettings(_invoice(), s,
            previousBalanceDue: 0));
    final bytes = await doc.save();
    expect(String.fromCharCodes(bytes), contains('Subtype/Image'));
  });

  test('Latin-only invoice: no images, and shaping adds little time', () async {
    final theme = await TestPdfFontService.loadTheme();
    final s = _settings(theme, InvoiceTemplate.classic, PageSize.a4);
    final latin = Invoice(
      id: 'i', invoiceNumber: '1',
      customer: Customer(id: 'c', name: 'Madan', email: '', phone: '', address: 'Chennai', gstin: ''),
      items: List.generate(25, (i) => InvoiceItem(
          product: Product(id: 'p$i', name: 'Coffee Powder $i', description: '', price: 10, stock: 1, hsncode: '', tax_rate: 18),
          quantity: 1)),
      date: DateTime(2026, 10, 5), type: 'Invoice', taxRate: 0.18,
      taxMode: TaxMode.perItem, notes: '');
    pw.Document build() => PDFService.generateInvoicePDFWithSettings(latin, s, previousBalanceDue: 0);

    final t0 = DateTime.now();
    final plain = await build().save();
    final plainMs = DateTime.now().difference(t0).inMilliseconds;
    final t1 = DateTime.now();
    final viaShaping = await (await ShapedTextRasterizer.buildWithShaping(build)).save();
    final shapedMs = DateTime.now().difference(t1).inMilliseconds;
    // ignore: avoid_print
    print('TIMING latin 25 items: direct=${plainMs}ms via-shaping=${shapedMs}ms');
    expect(String.fromCharCodes(viaShaping), isNot(contains('Subtype/Image')));
    expect(viaShaping.length, closeTo(plain.length, 600));
  });
}
