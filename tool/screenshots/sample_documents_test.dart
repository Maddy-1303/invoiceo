// Makes the website's sample documents with the real PDF code: an A4 GST
// invoice (Classic design) and an 80 mm thermal receipt with Tamil item
// names, for a sample shop (phone numbers start with 1, which no Indian
// mobile does, so they cannot reach a real person; no UPI ID or bank
// account is set, so nothing on them can take a real payment). Run:
//   flutter test tool/screenshots/sample_documents_test.dart
// Output: build/sample_documents/{invoice-a4,receipt-80mm}.pdf (override with
// --dart-define=DOCS_OUT=/some/folder). tool/screenshots/pdf_to_png.swift
// turns them into the PNGs the website uses.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/company_info_service.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/database/payment_service.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/database/settings_service.dart';
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

const _out = String.fromEnvironment('DOCS_OUT', defaultValue: 'build/sample_documents');

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
    tmp = Directory.systemTemp.createTempSync('invoiceo_docs');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
    // Serve assets straight from the project folder (see
    // test/shaped_report_pdfs_test.dart for why).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = Uri.decodeFull(utf8.decode(
          message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes)));
      final file = File(key);
      if (!file.existsSync()) return null;
      return ByteData.sublistView(file.readAsBytesSync());
    });
    await DatabaseHelper().switchToFile('sample_documents.db');
    Directory(_out).createSync(recursive: true);
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
  });

  Future<void> save(String name, Invoice invoice) async {
    final pdf = await PDFService.generateInvoicePDF(invoice);
    File('$_out/$name.pdf').writeAsBytesSync(await pdf.save());
    // ignore: avoid_print
    print('saved $_out/$name.pdf');
  }

  test('sample A4 invoice and thermal receipt', () async {
    final existing = await CompanyInfoService.getCompanyInfo();
    final saveCompany = existing == null
        ? CompanyInfoService.insertCompanyInfo
        : CompanyInfoService.updateCompanyInfo;
    await saveCompany(CompanyInfo(
        id: existing?.id,
        name: 'Sri Murugan Traders', address: '12, Big Bazaar Street, Madurai 625001',
        phone: '12345 00010', email: 'billing@srimurugan.example', website: '',
        gstin: '33ABCDE1234F1Z5'));
    await BackendServices.settings.setSetting(SettingKey.showCgstSgst, 'true');

    final kannan = Customer(id: 'c1', name: 'Kannan', businessName: 'Kannan Stores',
        phone: '12345 00011', email: 'kannan@stores.example',
        address: '4, East Masi Street, Madurai', gstin: '33AAKCK1122L1Z9');
    final lakshmi = Customer(id: 'c2', name: 'Lakshmi', phone: '12345 00015',
        email: '', address: '', gstin: '');
    for (final c in [kannan, lakshmi]) {
      await CustomerService.insertCustomer(c);
    }

    Product p(String id, String name, double price, String hsn, int tax,
            {String type = 'product', String unit = 'pcs'}) =>
        Product(id: id, name: name, description: '', price: price, stock: 100, hsncode: hsn,
            tax_rate: tax, purchasePrice: 0, type: type, unlimitedStock: type == 'service', unit: unit);
    final products = [
      p('p1', '3 Roses Tea 250g', 145, '0902', 5),
      p('p2', 'Ponni Rice 25kg', 1450, '1006', 0),
      p('p3', 'Toor Dal 1kg', 168, '0713', 0),
      p('p4', 'Aachi Chilli Powder 100g', 45, '0904', 5),
      p('p5', 'Aavin Ghee 500ml', 340, '0405', 12),
      p('s1', 'Home Delivery', 40, '9968', 18, type: 'service'),
      // Tamil names, as many shops in Tamil Nadu keep them.
      p('t1', 'பொன்னி அரிசி 5கி', 310, '1006', 0),
      p('t2', 'துவரம் பருப்பு 1கி', 168, '0713', 0),
      p('t3', 'ஆச்சி மிளகாய் தூள் 100கி', 45, '0904', 5),
      p('p6', 'Sugar 1kg', 46, '1701', 5),
    ];
    for (final x in products) {
      await ProductService.insertProduct(x);
    }
    Product byId(String id) => products.firstWhere((x) => x.id == id);

    final now = DateTime.now();
    Future<Invoice> invoice(Customer c, List<(String, double)> lines,
        {int? dueDays}) async {
      final id = await InvoiceService.generateNextId();
      final number = await InvoiceService.generateNextInvoiceNumber('Invoice');
      await InvoiceService.insertInvoice(Invoice(
        id: id, invoiceNumber: number, customer: c, type: 'Invoice',
        items: [for (final (pid, q) in lines) InvoiceItem(product: byId(pid), quantity: q)],
        date: now,
        dueDate: dueDays == null ? null : now.add(Duration(days: dueDays)),
        taxMode: TaxMode.perItem, currencyCode: 'INR', currencySymbol: 'Rs.',
      ));
      return (await InvoiceService.getInvoiceById(id))!;
    }

    // A4 GST invoice to a business customer, due in 15 days.
    await SettingsService.setInvoiceTemplate(InvoiceTemplate.classic);
    await SettingsService.setPageSize(PageSize.a4);
    final a4 = await invoice(kannan,
        [('p1', 10), ('p2', 2), ('p3', 5), ('p4', 12), ('p5', 3), ('s1', 1)], dueDays: 15);
    await save('invoice-a4', a4);

    // Counter sale on an 80 mm thermal printer, paid in cash.
    await SettingsService.setInvoiceTemplate(InvoiceTemplate.thermal);
    await SettingsService.setPageSize(PageSize.thermal80);
    final receipt = await invoice(lakshmi, [('t1', 1), ('t2', 2), ('t3', 3), ('p1', 1), ('p6', 2)]);
    await PaymentService.addPayment(
        invoice: receipt, amountPaid: receipt.total, datePaid: now, paymentMethod: 'Cash');
    await save('receipt-80mm', (await InvoiceService.getInvoiceById(receipt.id))!);
  });
}
