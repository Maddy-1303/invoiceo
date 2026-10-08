import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/models/company_info.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/services/escpos_raster.dart';
import 'package:invoiceo/services/pdf/pdf_service.dart';
import 'package:invoiceo/services/pdf/pdf_settings.dart';
import 'package:invoiceo/services/thermal_printer_service_v1.dart';

import 'test_pdf_font_service.dart';

Invoice _invoice({String itemName = 'Coffee Powder', String notes = ''}) =>
    Invoice(
      id: 'i1',
      invoiceNumber: '1',
      customer: Customer(
          id: 'c', name: 'Madan', email: '', phone: '', address: '', gstin: ''),
      items: [
        InvoiceItem(
          product: Product(
              id: 'p', name: itemName, description: '', price: 10, stock: 1,
              hsncode: '', tax_rate: 18),
          quantity: 1,
        ),
      ],
      date: DateTime(2026, 10, 5),
      type: 'Invoice',
      taxRate: 0.18,
      taxMode: TaxMode.perItem,
      notes: notes,
      currencyCode: 'INR',
      currencySymbol: 'Rs.', // what the app stores for INR
    );

Future<PdfGenerationSettings> _settings({String companyName = 'Shop'}) async =>
    PdfGenerationSettings(
      company: CompanyInfo(
          name: companyName, address: '1 Street', phone: '1', email: '',
          website: '', gstin: '', country: 'India'),
      template: InvoiceTemplate.thermal, invoicePrefix: 'INV-', showGst: true,
      showQuantity: true, showDiscount: true, showTypeTag: true,
      businessType: BusinessType.both, upiEntries: const [], showQrStr: 'false',
      showBankDetails: false, bankAccounts: const [],
      logoPosition: LogoPosition.left, logoSizePx: 80, logoBytes: null,
      signatureBytes: null, thankYouNote: '', datePattern: 'dd/MM/yyyy',
      showFooterBranding: true, themeColor: null, showPreviousBalance: false,
      pageFormat: PDFService.pageSizeToFormat(PageSize.thermal80),
      pageSize: PageSize.thermal80, showTotalQuantity: false,
      pdfTheme: await TestPdfFontService.loadTheme(), watermarkBytes: null,
      watermarkOpacity: 0.05, signaturePosition: 'left',
      descriptionNewLine: false, showCgstSgst: false, showDescription: false,
      landscape: false, fontSizeScale: 1.0, companyNameScale: 1.0,
      docTitleScale: 1.0, tableHeaderScale: 1.0, tableItemsScale: 1.0,
      totalsScale: 1.0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('escPosRasterBands', () {
    test('packs pixels MSB-first and writes a GS v 0 header', () {
      // 16x2: first row black on the left byte only, second row all white.
      final image = img.Image(width: 16, height: 2, numChannels: 4)
        ..clear(img.ColorRgba8(255, 255, 255, 255));
      for (var x = 0; x < 8; x++) {
        image.setPixel(x, 0, img.ColorRgba8(0, 0, 0, 255));
      }
      final out = escPosRasterBands(image);
      expect(out.sublist(0, 8), [0x1D, 0x76, 0x30, 0x00, 2, 0, 2, 0]);
      expect(out.sublist(8), [0xFF, 0x00, 0x00, 0x00]);
    });

    test('splits a tall image into bands whose heights add up', () {
      final image = img.Image(width: 8, height: 300, numChannels: 4)
        ..clear(img.ColorRgba8(255, 255, 255, 255));
      final out = escPosRasterBands(image, bandHeight: 128);
      final heights = <int>[];
      var i = 0;
      while (i < out.length) {
        expect(out.sublist(i, i + 4), [0x1D, 0x76, 0x30, 0x00]);
        final widthBytes = out[i + 4] + (out[i + 5] << 8);
        final h = out[i + 6] + (out[i + 7] << 8);
        heights.add(h);
        i += 8 + widthBytes * h;
      }
      expect(heights, [128, 128, 44]);
      expect(i, out.length);
    });

    test('pads a width that is not a multiple of 8 with white', () {
      final image = img.Image(width: 10, height: 1, numChannels: 4)
        ..clear(img.ColorRgba8(0, 0, 0, 255));
      final out = escPosRasterBands(image);
      expect(out.sublist(4, 6), [2, 0]); // 2 bytes per row
      expect(out.sublist(8), [0xFF, 0xC0]); // 10 black pixels, 6 white
    });

    test('treats transparent pixels as white paper', () {
      final image = img.Image(width: 8, height: 1, numChannels: 4)
        ..clear(img.ColorRgba8(0, 0, 0, 0));
      expect(escPosRasterBands(image).sublist(8), [0x00]);
    });
  });

  group('invoiceNeedsImageReceipt', () {
    test('Latin-only receipt keeps the original text path', () async {
      expect(
          ThermalPrinterService.invoiceNeedsImageReceipt(
              _invoice(), await _settings()),
          isFalse);
    });

    test('Tamil item name switches to the image path', () async {
      expect(
          ThermalPrinterService.invoiceNeedsImageReceipt(
              _invoice(itemName: 'காபி தூள்'), await _settings()),
          isTrue);
    });

    test('Tamil in notes or company name also switches', () async {
      expect(
          ThermalPrinterService.invoiceNeedsImageReceipt(
              _invoice(notes: 'நன்றி'), await _settings()),
          isTrue);
      expect(
          ThermalPrinterService.invoiceNeedsImageReceipt(
              _invoice(), await _settings(companyName: 'மதன் கடை')),
          isTrue);
    });
  });
}
