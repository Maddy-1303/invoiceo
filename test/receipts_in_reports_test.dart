// A Receipt is a cash sale, paid in full when it is made. Reports and
// dashboards count it as a sale (billed, collected, tax, profit, top
// products / customers) but never as outstanding, and the invoice status
// counts stay about invoices only. Quotations, declined and trashed rows are
// left out. Runs the real services against an ffi sqflite file in a temp dir.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/database/payment_service.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/database/report_service.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/invoice_list_filter.dart';
import 'package:invoiceo/models/product.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('invoiceo_receipts_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });

  var dbCounter = 0;
  setUp(() async {
    await DatabaseHelper().switchToFile('receipts_test_${dbCounter++}.db');
  });

  final customer = Customer(
    id: 'c1',
    name: 'Test Customer',
    email: '',
    phone: '',
    address: '',
    gstin: '',
  );
  // Sold at 100 + 10% tax, bought at 60.
  final widget = Product(
    id: 'p1',
    name: 'Widget',
    description: '',
    price: 100,
    stock: 100,
    hsncode: '',
    tax_rate: 0,
    purchasePrice: 60,
  );

  // This month, so the dashboard's "last 6 months" sees it too.
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(now.year, now.month + 1, 0);
  final day1 = DateTime(now.year, now.month, 1);
  final day2 = DateTime(now.year, now.month, 2);
  final pastDue = DateTime(now.year, now.month, now.day - 3);
  final nextMonth = DateTime(now.year, now.month + 1, 5);

  Invoice doc(String id, String type, double qty, DateTime date,
          {String currency = 'INR'}) =>
      Invoice(
        id: id,
        customer: customer,
        items: [InvoiceItem(product: widget, quantity: qty)],
        date: date,
        dueDate: pastDue,
        type: type,
        taxRate: 0.10,
        currencyCode: currency,
        currencySymbol: currency == 'INR' ? '₹' : r'$',
      );

  // i1: invoice, 2 x 100 + 10% = 220, 100 paid (partly paid, past due).
  // i2: declined invoice. q1: quotation.
  Future<void> seedInvoicesOnly() async {
    await CustomerService.insertCustomer(customer);
    await ProductService.insertProduct(widget);
    final i1 = doc('i1', 'Invoice', 2, day1);
    await InvoiceService.insertInvoice(i1);
    await PaymentService.addPayment(
        invoice: i1, amountPaid: 100, datePaid: day1);
    await InvoiceService.insertInvoice(doc('i2', 'Invoice', 3, day1));
    await InvoiceService.declineInvoice('i2');
    await InvoiceService.insertInvoice(doc('q1', 'Quotation', 5, day1));
  }

  // r1: INR receipt, 1 x 100 + 10% = 110, no payment rows, a past due date.
  // r2: trashed receipt. r3: USD receipt (110).
  Future<void> seedReceipts() async {
    await InvoiceService.insertInvoice(doc('r1', 'Receipt', 1, day2));
    await InvoiceService.insertInvoice(doc('r2', 'Receipt', 4, day2));
    await InvoiceService.softDeleteInvoice('r2');
    await InvoiceService.insertInvoice(
        doc('r3', 'Receipt', 1, day2, currency: 'USD'));
  }

  test('with no receipts the numbers are the invoice-only numbers', () async {
    await seedInvoicesOnly();
    final kpi =
        await ReportService.getRevenueSummary(from, to, currencyCode: 'INR');
    expect(kpi.invoiceCount, 1);
    expect(kpi.billed, closeTo(220, 0.001));
    expect(kpi.collected, closeTo(100, 0.001));
    expect(kpi.outstanding, closeTo(120, 0.001));
    expect(kpi.avgInvoiceValue, closeTo(220, 0.001));

    final fin = await InvoiceService.getDashboardFinancials();
    expect(fin.count, 1);
    expect(fin.revenue, 100.0);
    expect(fin.outstanding, closeTo(120, 0.001));

    final monthly = await InvoiceService.getMonthlyRevenue();
    expect(monthly.single['revenue'], 100.0);
    final top = (await InvoiceService.getTopCustomers()).single;
    expect(top['total_paid'], 100.0);
    expect(top['invoice_count'], 1);
    expect((await InvoiceService.getTopProducts()).single['total_qty'], 2.0);
  });

  test('revenue, collected, outstanding and profit count the receipt',
      () async {
    await seedInvoicesOnly();
    await seedReceipts();

    final kpi =
        await ReportService.getRevenueSummary(from, to, currencyCode: 'INR');
    expect(kpi.billed, closeTo(330, 0.001), reason: '220 + receipt 110');
    expect(kpi.collected, closeTo(210, 0.001), reason: '100 + receipt 110');
    expect(kpi.outstanding, closeTo(120, 0.001), reason: 'receipt owes 0');
    expect(kpi.invoiceCount, 1, reason: 'counts invoices only');
    expect(kpi.avgInvoiceValue, closeTo(165, 0.001), reason: '330 / 2 sales');
    // Net 200 - COGS 120 on the invoice, 100 - 60 on the receipt.
    expect(kpi.profit, closeTo(120, 0.001));
    expect(kpi.realizedProfit, closeTo(80 * 100 / 220 + 40, 0.001));

    // All currencies: the USD receipt counts too.
    final all = await ReportService.getRevenueSummary(from, to);
    expect(all.billed, closeTo(440, 0.001));
    expect(all.collected, closeTo(320, 0.001));
    expect(all.outstanding, closeTo(120, 0.001));

    // Every sold item here has a purchase price.
    expect(
        await ReportService.getMissingCostItemCount(from, to,
            currencyCode: 'INR'),
        0);
  });

  test('monthly and daily trends include the receipt', () async {
    await seedInvoicesOnly();
    await seedReceipts();

    final month = (await ReportService.getMonthlyRevenueTrend(from, to,
            currencyCode: 'INR'))
        .single;
    expect(month.billed, closeTo(330, 0.001));
    expect(month.collected, closeTo(210, 0.001));
    expect(month.outstanding, closeTo(120, 0.001));
    expect(month.netSales, closeTo(300, 0.001));
    expect(month.cogs, closeTo(180, 0.001));
    expect(month.invoiceCount, 1);

    final days =
        await ReportService.getDailyRevenueTrend(from, to, currencyCode: 'INR');
    expect(days.map((d) => d.date).toList(), [
      day1.toIso8601String().substring(0, 10),
      day2.toIso8601String().substring(0, 10)
    ]);
    expect(days[0].invoiceCount, 1);
    expect(days[0].billed, closeTo(200, 0.001));
    expect(days[1].invoiceCount, 0, reason: 'a day of receipts only');
    expect(days[1].billed, closeTo(100, 0.001));
    expect(days[1].cogs, closeTo(60, 0.001));
  });

  test('tax, top products and top customers include the receipt', () async {
    await seedInvoicesOnly();
    await seedReceipts();

    final tax =
        (await ReportService.getTaxByRate(from, to, currencyCode: 'INR'))
            .single;
    expect(tax.rate, 10);
    expect(tax.taxCollected, closeTo(30, 0.001));
    expect(tax.taxableAmount, closeTo(300, 0.001));

    final product =
        (await ReportService.getTopProducts(from, to, currencyCode: 'INR'))
            .single;
    expect(product.unitsSold, 3);
    expect(product.revenue, closeTo(300, 0.001));
    expect(product.cogs, closeTo(180, 0.001));

    final top =
        (await ReportService.getTopCustomers(from, to, currencyCode: 'INR'))
            .single;
    expect(top.billed, closeTo(330, 0.001));
    expect(top.collected, closeTo(210, 0.001));
    expect(top.outstanding, closeTo(120, 0.001));
    expect(top.invoiceCount, 1);
  });

  test('invoice status, receivables and statements stay invoice-only',
      () async {
    await seedInvoicesOnly();
    await seedReceipts();

    final status = await ReportService.getPaymentStatusBreakdown(from, to,
        currencyCode: 'INR');
    expect([status.paid, status.partial, status.unpaid], [0, 1, 0]);
    final list =
        await ReportService.getInvoiceStatusList(from, to, currencyCode: 'INR');
    expect(list.map((r) => r.id), ['i1']);

    final aged = await ReportService.getAgedReceivables(currencyCode: 'INR');
    expect(aged.map((r) => r.invoiceId), ['i1']);
    expect(await ReportService.getOutstandingByCustomer(currencyCode: 'INR'),
        {'c1': closeTo(120, 0.001)});
    final summary =
        await ReportService.getAgedReceivableSummary(currencyCode: 'INR');
    expect(summary.single.total, closeTo(120, 0.001));

    // The receipt is left out of the statement; the balance stays right.
    final st = (await ReportService.getCustomerStatements('c1', from, to,
            currencyCode: 'INR'))
        .single;
    expect(st.invoiced, closeTo(220, 0.001));
    expect(st.paid, closeTo(100, 0.001));
    expect(st.closingBalance, closeTo(120, 0.001));
    expect(st.lines.map((l) => l.type), ['Invoice', 'Payment']);

    // Previous balance on a new invoice: the receipt owes nothing.
    expect(
        await InvoiceService.getPreviousBalanceDueForCustomer(
            customerId: 'c1', currencyCode: 'INR', asOfDate: nextMonth),
        closeTo(120, 0.001));
  });

  test('Standard dashboard: revenue, top customers and products', () async {
    await seedInvoicesOnly();
    await seedReceipts();

    // No currency filter here (as before): 100 paid + receipts 110 + 110.
    final fin = await InvoiceService.getDashboardFinancials();
    expect(fin.count, 1, reason: 'Total Invoices counts invoices only');
    expect(fin.revenue, closeTo(320, 0.001));
    expect(fin.outstanding, closeTo(120, 0.001));

    final monthly = await InvoiceService.getMonthlyRevenue();
    expect(monthly.single['revenue'], closeTo(320, 0.001));

    final top = (await InvoiceService.getTopCustomers()).single;
    expect(top['total_paid'], closeTo(320, 0.001));
    expect(top['invoice_count'], 1);

    expect((await InvoiceService.getTopProducts()).single['total_qty'], 4.0);
  });

  test('a receipt with payment rows counts them, not its total as well',
      () async {
    await seedInvoicesOnly();
    await seedReceipts();
    // Older versions could record a payment against a receipt.
    final r1 = (await InvoiceService.getInvoiceById('r1'))!;
    await PaymentService.addPayment(
        invoice: r1, amountPaid: 110, datePaid: day2);

    final kpi =
        await ReportService.getRevenueSummary(from, to, currencyCode: 'INR');
    expect(kpi.collected, closeTo(210, 0.001));
    expect(kpi.outstanding, closeTo(120, 0.001));
    final month = (await ReportService.getMonthlyRevenueTrend(from, to,
            currencyCode: 'INR'))
        .single;
    expect(month.collected, closeTo(210, 0.001));
    expect((await InvoiceService.getDashboardFinancials()).revenue,
        closeTo(320, 0.001));
    expect((await InvoiceService.getTopCustomers()).single['total_paid'],
        closeTo(320, 0.001));
    expect((await InvoiceService.getMonthlyRevenue()).single['revenue'],
        closeTo(320, 0.001));
  });

  test('a receipt is never unpaid, overdue or offered for payment', () async {
    await seedInvoicesOnly();
    await seedReceipts();

    final r1 = (await InvoiceService.getInvoiceById('r1'))!;
    expect(r1.isReceipt, isTrue);
    expect(r1.paymentStatus, PaymentStatus.paid);
    expect(r1.balanceDue, 0.0);
    final i1 = (await InvoiceService.getInvoiceById('i1'))!;
    expect(i1.paymentStatus, PaymentStatus.partial);
    expect(i1.balanceDue, closeTo(120, 0.001));

    // The receipts list's "Overdue" filter finds nothing.
    expect(
        await InvoiceService.getInvoicesPaginated(
            filterType: 'Receipt',
            filter: const InvoiceListFilter(dueDate: 'overdue')),
        isEmpty);
    expect(
        (await InvoiceService.getInvoicesPaginated(
                filterType: 'Invoice',
                filter: const InvoiceListFilter(dueDate: 'overdue')))
            .map((i) => i.id),
        ['i1']);

    // Open invoices for "Apply Payment" and bulk "Mark Paid" skip receipts.
    expect(
        (await InvoiceService.getOpenInvoicesForCustomer('c1'))
            .map((i) => i.id),
        ['i1']);
    final marked = await PaymentService.addPaymentBatch(
        invoices: [r1, i1], datePaid: day2);
    expect(marked, 1);
    expect(await PaymentService.getPaymentsForInvoice('r1'), isEmpty);
    final saved = await PaymentService.applyPaymentAcrossInvoices(
        allocations: [(invoice: r1, amount: 50.0)], datePaid: day2);
    expect(saved, isEmpty);
    expect(await PaymentService.getPaymentsForInvoice('r1'), isEmpty);
  });
}
