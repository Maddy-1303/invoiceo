// The English (plain-text) thermal receipt must stay byte-for-byte what it
// was. Goldens live in test/goldens/*.hex; regenerate deliberately with
//   flutter test test/thermal_receipt_golden_test.dart --dart-define=UPDATE_GOLDENS=true
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/models/additional_cost.dart';
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
import 'package:invoiceo/services/pdf/pdf_service.dart';
import 'package:invoiceo/services/pdf/pdf_settings.dart';
import 'package:invoiceo/services/thermal_printer_service_v1.dart';

const _update = bool.fromEnvironment('UPDATE_GOLDENS');

Product _p(String id, String name, double price, {int tax = 18, String unit = ''}) =>
    Product(id: id, name: name, description: 'desc $name', price: price,
        stock: 99, hsncode: '1001', tax_rate: tax, unit: unit);

PdfGenerationSettings _settings(PageSize ps,
        {String thanks = 'Thank you!', bool desc = false}) =>
    PdfGenerationSettings(
      company: CompanyInfo(
          name: 'Linga Nadar Stores', address: '12 Main Street\nChennai',
          phone: '9876543210', email: 'a@b.c', website: '', gstin: '33ABCDE1234F1Z5',
          country: 'India'),
      template: InvoiceTemplate.thermal, invoicePrefix: 'INV-', showGst: true,
      showQuantity: true, showDiscount: true, showTypeTag: true,
      businessType: BusinessType.both, upiEntries: const [], showQrStr: 'false',
      showBankDetails: false, bankAccounts: const [],
      logoPosition: LogoPosition.left, logoSizePx: 80, logoBytes: null,
      signatureBytes: null, thankYouNote: thanks, datePattern: 'dd/MM/yyyy',
      showFooterBranding: true, themeColor: null, showPreviousBalance: false,
      pageFormat: PDFService.pageSizeToFormat(ps), pageSize: ps,
      showTotalQuantity: false, pdfTheme: pw.ThemeData.base(),
      watermarkBytes: null, watermarkOpacity: 0.05, signaturePosition: 'left',
      descriptionNewLine: false, showCgstSgst: false, showDescription: desc,
      landscape: false, fontSizeScale: 1.0, companyNameScale: 1.0,
      docTitleScale: 1.0, tableHeaderScale: 1.0, tableItemsScale: 1.0,
      totalsScale: 1.0,
    );

Invoice _inv({
  required TaxMode tax,
  List<AdditionalCost> extra = const [],
  String? notes,
  bool discount = false,
}) =>
    Invoice(
      id: '1', invoiceNumber: '12',
      customer: Customer(
          id: 'c', name: 'Madhan', email: '', phone: '9000000001', address: 'x',
          gstin: '', businessName: 'Madhan Traders'),
      items: [
        InvoiceItem(product: _p('1', 'Coffee Powder 100g', 90), quantity: 2, unit: 'gm'),
        InvoiceItem(product: _p('2', 'Basmati Rice 5kg', 650, tax: 5), quantity: 1.5,
            discount: discount ? 20 : 0),
        InvoiceItem(product: _p('3', 'A really long product name that must be cut to fit the row', 12.5), quantity: 10),
      ],
      date: DateTime(2026, 10, 5, 21, 2), type: 'Invoice',
      taxRate: 0.18, taxMode: tax, notes: notes, additionalCosts: extra,
      currencyCode: 'INR', currencySymbol: 'Rs.', // what the app stores for INR
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  var n = 0;

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
    tmp = Directory.systemTemp.createTempSync('invoiceo_golden');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });
  tearDownAll(() async {
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> check(String name, Invoice inv, PdfGenerationSettings s,
      {String layout = 'table', double prev = 0}) async {
    await DatabaseHelper().switchToFile('golden_${n++}.db');
    await BackendServices.settings
        .setSetting(SettingKey.thermalItemLayout, layout);
    final bytes = await ThermalPrinterService.buildReceiptBytesFor(inv, s, prev);
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final file = File('test/goldens/thermal_receipt_$name.hex');
    if (_update) {
      file.writeAsStringSync(hex);
      // ignore: avoid_print
      print('GOLDEN written: ${file.path} (${bytes.length} bytes)');
      return;
    }
    expect(file.existsSync(), isTrue, reason: 'golden missing: ${file.path}');
    expect(hex, file.readAsStringSync(),
        reason: '$name: the plain-text receipt changed');
  }

  test('80mm, table layout, per-item tax, discount, extra cost, notes', () async {
    await check('80_table_peritem',
        _inv(tax: TaxMode.perItem, discount: true, notes: 'Pay within 7 days',
            extra: const [AdditionalCost(label: 'Packing', amount: 15)]),
        _settings(PageSize.thermal80), prev: 120);
  });

  test('58mm, table layout, global tax', () async {
    await check('58_table_global', _inv(tax: TaxMode.global),
        _settings(PageSize.thermal58, thanks: ''));
  });

  test('80mm, detailed layout, no tax, with item descriptions', () async {
    await check('80_detailed_notax', _inv(tax: TaxMode.none),
        _settings(PageSize.thermal80, desc: true), layout: 'detailed');
  });

  test('58mm, detailed layout, per-item tax', () async {
    await check('58_detailed_peritem', _inv(tax: TaxMode.perItem, discount: true),
        _settings(PageSize.thermal58), layout: 'detailed');
  });
}
