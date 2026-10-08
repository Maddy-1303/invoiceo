// The payment receipt, customer statement and report PDFs draw Tamil and
// other complex scripts shaped (as images made by Flutter's text engine),
// the same way invoice PDFs do. English-only reports stay plain text.
// Runs the real services against an ffi sqflite file in a temp dir.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/report_service.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/invoice_payment.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/services/customer_statement_pdf_service.dart';
import 'package:invoiceo/services/payment_receipt_service.dart';

// Set OUT_DIR (--dart-define=OUT_DIR=...) to keep the PDFs for a look.
const _out = String.fromEnvironment('OUT_DIR');

const _tamilCustomer = 'மதன் ஸ்டோர்ஸ்';
const _tamilProduct = 'ஆச்சி மிளகாய் தூள் 100கி';

// No logo is stored in the test database, so any image in these PDFs is
// shaped text.
bool _hasShapedText(Uint8List bytes) =>
    String.fromCharCodes(bytes).contains('Subtype/Image');

Future<void> _keep(String name, Uint8List bytes) async {
  if (_out.isEmpty) return;
  await Directory(_out).create(recursive: true);
  await File('$_out/$name').writeAsBytes(bytes);
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
    tmp = Directory.systemTemp.createTempSync('invoiceo_shaped_reports');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
    // The real PdfFontService.loadTheme() loads all fonts at once, which
    // flutter_test's own asset handler gets wrong (see
    // test_pdf_font_service.dart). Serve assets straight from the project
    // folder instead, so the real loader can be used.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = Uri.decodeFull(
          utf8.decode(message!.buffer.asUint8List(message.offsetInBytes,
              message.lengthInBytes)));
      final file = File(key);
      if (!file.existsSync()) return null;
      return ByteData.sublistView(file.readAsBytesSync());
    });
    await DatabaseHelper().switchToFile('shaped_reports.db');
  });
  tearDownAll(() async {
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });

  test('payment receipt: Tamil customer is shaped', () async {
    final invoice = Invoice(
      id: 'inv1',
      invoiceNumber: '7',
      customer: Customer(
          id: 'c1',
          name: _tamilCustomer,
          email: '',
          phone: '9876543210',
          address: 'சென்னை',
          gstin: ''),
      items: [
        InvoiceItem(
            product: Product(
                id: 'p1',
                name: _tamilProduct,
                description: '',
                price: 45,
                stock: 10,
                hsncode: '',
                tax_rate: 0),
            quantity: 2),
      ],
      date: DateTime(2026, 10, 5),
      type: 'Invoice',
      taxMode: TaxMode.perItem,
    );
    final payment = InvoicePayment(
      id: 'pay1',
      invoiceId: 'inv1',
      invoiceNumber: '7',
      receiptNumber: 'RCPT-0001',
      amountPaid: 50,
      taxAmountPaid: 0,
      previouslyPaid: 0,
      balanceAfter: 40,
      datePaid: DateTime(2026, 10, 6),
      paymentMethod: 'பணம்',
      notes: 'நன்றி',
    );

    final doc = await PaymentReceiptService.generatePDF(invoice, payment);
    final bytes = await doc.save();
    await _keep('payment_receipt.pdf', bytes);
    expect(bytes.length, greaterThan(1000));
    expect(_hasShapedText(bytes), isTrue);
  });

  test('customer statement: Tamil name and table cells are shaped', () async {
    final statement = CustomerStatement(
      customerKey: 'c1',
      customerName: _tamilCustomer,
      currencyCode: 'INR',
      currencySymbol: 'Rs.',
      openingBalance: 0,
      invoiced: 90,
      paid: 50,
      closingBalance: 40,
      overdueBalance: 0,
      lines: const [
        CustomerStatementLine(
            date: '2026-10-05',
            type: 'Invoice',
            reference: 'INV-7',
            description: _tamilProduct,
            debit: 90,
            credit: 0,
            balance: 90),
        CustomerStatementLine(
            date: '2026-10-06',
            type: 'Payment',
            reference: 'RCPT-0001',
            description: 'Payment received',
            debit: 0,
            credit: 50,
            balance: 40),
      ],
    );
    final bytes = await CustomerStatementPdfService.export([statement]);
    await _keep('customer_statement.pdf', bytes);
    expect(bytes.length, greaterThan(1000));
    expect(_hasShapedText(bytes), isTrue);
  });

  test('top products report: Tamil product in a table cell is shaped',
      () async {
    final bytes = await ReportService.exportTopProductsPdf(
      [
        const TopProduct(
            name: _tamilProduct,
            unitsSold: 33,
            revenue: 1485,
            discountGiven: 0,
            cogs: 990),
        const TopProduct(
            name: 'Coffee Powder 100g',
            unitsSold: 2,
            revenue: 20,
            discountGiven: 0,
            cogs: 12),
      ],
      currencySymbol: 'Rs.',
      dateRangeLabel: 'Oct 2026',
    );
    await _keep('top_products.pdf', bytes);
    expect(_hasShapedText(bytes), isTrue);
  });

  test('top customers report: Tamil customer in a table cell is shaped',
      () async {
    final bytes = await ReportService.exportTopCustomersPdf(
      const [
        TopCustomer(
            name: _tamilCustomer,
            invoiceCount: 3,
            billed: 300,
            collected: 200,
            outstanding: 100),
        TopCustomer(
            name: 'Madan',
            invoiceCount: 1,
            billed: 50,
            collected: 50,
            outstanding: 0),
      ],
      currencySymbol: 'Rs.',
      dateRangeLabel: 'Oct 2026',
    );
    await _keep('top_customers.pdf', bytes);
    expect(_hasShapedText(bytes), isTrue);
  });

  test('invoice status report: Tamil customer and many rows are shaped',
      () async {
    final rows = [
      for (var i = 0; i < 60; i++)
        InvoiceStatusRow(
          id: 'INV-$i',
          date: '2026-10-05',
          customerName: i.isEven ? _tamilCustomer : 'Madan',
          total: 100,
          paid: 40,
          outstanding: 60,
          daysOverdue: 0,
          hasNoDueDate: true,
          status: 'partial',
          isOverdue: false,
        ),
    ];
    final bytes = await ReportService.exportInvoiceStatusPdf(rows,
        currencySymbol: '', dateRangeLabel: 'Oct 2026');
    await _keep('invoice_status.pdf', bytes);
    expect(_hasShapedText(bytes), isTrue);
  });

  test('English-only report keeps plain text (no images)', () async {
    final bytes = await ReportService.exportTopCustomersPdf(
      const [
        TopCustomer(
            name: 'Madan',
            invoiceCount: 1,
            billed: 50,
            collected: 50,
            outstanding: 0),
      ],
      currencySymbol: 'Rs.',
      dateRangeLabel: 'Oct 2026',
    );
    expect(bytes.length, greaterThan(1000));
    expect(_hasShapedText(bytes), isFalse);
  });
}
