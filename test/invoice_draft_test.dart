// "Save Draft": drafts are kept apart from invoices, so they never count in
// reports, stock or numbering, and read back exactly as saved.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_draft_service.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/models/additional_cost.dart';
import 'package:invoiceo/models/custom_field_value.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_draft.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  var n = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('invoiceo_drafts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });
  setUp(() async => DatabaseHelper().switchToFile('drafts_${n++}.db'));
  tearDownAll(() async {
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });

  final tea = Product(
      id: 'p1', name: '3 Roses Tea 250g', aliasName: '3 ரோசஸ் டீ 250கி',
      description: 'tea', price: 200, stock: 12, hsncode: '0902', tax_rate: 5,
      unit: 'pkt', priceIncludesTax: true);

  Invoice sample() => Invoice(
        id: 'ignored',
        type: 'Quotation',
        customer: Customer(
            id: 'c1', name: 'Madhan', email: 'm@x.in', phone: '9876543210',
            address: 'No. 12, Main Road, Chennai', gstin: '33ABCDE1234F1Z5',
            businessName: 'Madhan Stores'),
        items: [
          InvoiceItem(
              id: 'line1', product: tea, quantity: 2.5, discount: 10,
              unitPrice: 190, extraCost: 4, unit: 'box', description: 'note',
              metadata: ProductMetadata(productId: 'p1', batchNumber: 'B7', expiryDate: '2027-01-31'),
              discountPerUnit: true, isProductSaved: true),
        ],
        date: DateTime(2026, 10, 7, 18, 31),
        dueDate: DateTime(2026, 10, 21),
        invoiceTitle: 'Tax Invoice',
        notes: 'deliver by noon',
        taxRate: 0.18,
        currencyCode: 'INR',
        currencySymbol: '₹',
        taxMode: TaxMode.perItem,
        isInterState: true,
        upiId: 'upi1',
        bankAccountId: 'bank1',
        quantityLabel: 'Boxes',
        additionalCosts: [AdditionalCost(label: 'Shipping', amount: 40)],
        invoiceDiscountType: InvoiceDiscountType.amount,
        invoiceDiscountValue: 15,
        hideInvoiceNumber: true,
        customInvoiceNumber: 'Q-77',
        customFields: [const CustomFieldValue(defId: 'f1', label: 'Vehicle', value: 'TN 01 AB 1234')],
      );

  test('every field the form can set reads back the same', () {
    final back = InvoiceDraft.invoiceFromJson(InvoiceDraft.invoiceToJson(sample()));
    final a = sample();
    expect(back.type, a.type);
    expect(back.customer.toMap(), a.customer.toMap());
    expect(back.date, a.date);
    expect(back.dueDate, a.dueDate);
    expect([back.invoiceTitle, back.notes, back.taxRate, back.currencyCode, back.currencySymbol],
        [a.invoiceTitle, a.notes, a.taxRate, a.currencyCode, a.currencySymbol]);
    expect([back.taxMode, back.isInterState, back.upiId, back.bankAccountId, back.quantityLabel],
        [a.taxMode, a.isInterState, a.upiId, a.bankAccountId, a.quantityLabel]);
    expect(back.additionalCosts.single.toJson(), a.additionalCosts.single.toJson());
    expect([back.invoiceDiscountType, back.invoiceDiscountValue, back.hideInvoiceNumber, back.customInvoiceNumber],
        [a.invoiceDiscountType, a.invoiceDiscountValue, a.hideInvoiceNumber, a.customInvoiceNumber]);
    expect(back.customFields.single.toJson(), a.customFields.single.toJson());
    final i = back.items.single, j = a.items.single;
    expect([i.id, i.quantity, i.discount, i.unitPrice, i.extraCost, i.unit, i.description, i.discountPerUnit, i.isProductSaved],
        [j.id, j.quantity, j.discount, j.unitPrice, j.extraCost, j.unit, j.description, j.discountPerUnit, j.isProductSaved]);
    expect(i.product.toMap(), j.product.toMap());
    expect(i.metadata!.toMap(), j.metadata!.toMap());
    expect(back.total, closeTo(a.total, 0.001), reason: 'same totals');
  });

  test('saved, listed by type (newest first), opened and deleted', () async {
    final older = InvoiceDraft(id: 'd1', invoice: sample(), updatedAt: DateTime(2026, 10, 7, 9));
    final newer = InvoiceDraft(id: 'd2', invoice: sample(), updatedAt: DateTime(2026, 10, 7, 11));
    final other = InvoiceDraft(
        id: 'd3', invoice: sample()..type = 'Invoice', updatedAt: DateTime(2026, 10, 7, 12));
    for (final d in [older, newer, other]) {
      await InvoiceDraftService.saveDraft(d);
    }
    final quotes = await InvoiceDraftService.getDrafts('Quotation');
    expect(quotes.map((d) => d.id), ['d2', 'd1']);
    expect(await InvoiceDraftService.countDrafts('Invoice'), 1);
    final opened = await InvoiceDraftService.getDraft('d1');
    expect(opened!.customerName, 'Madhan');
    expect(opened.invoice.items.single.product.name, '3 Roses Tea 250g');

    // saving again under the same id replaces it
    final edited = sample()..notes = 'changed';
    await InvoiceDraftService.saveDraft(
        InvoiceDraft(id: 'd1', invoice: edited, updatedAt: DateTime(2026, 10, 7, 13)));
    expect((await InvoiceDraftService.getDraft('d1'))!.invoice.notes, 'changed');
    expect(await InvoiceDraftService.countDrafts('Quotation'), 2);

    await InvoiceDraftService.deleteDraft('d1');
    expect(await InvoiceDraftService.getDraft('d1'), isNull);
    expect(await InvoiceDraftService.countDrafts('Quotation'), 1);
  });

  test('a draft is not an invoice: no stock taken, no number used, not listed', () async {
    await ProductService.insertProduct(tea);
    final before = await SqliteInvoiceRepository().peekNextInvoiceNumber('Invoice');
    await InvoiceDraftService.saveDraft(InvoiceDraft(
        id: 'd9', invoice: sample()..type = 'Invoice', updatedAt: DateTime.now()));
    expect((await ProductService.getProductById('p1'))!.stock, 12);
    expect(await SqliteInvoiceRepository().peekNextInvoiceNumber('Invoice'), before);
    expect(await InvoiceService.getAllInvoices(), isEmpty);
  });
}
