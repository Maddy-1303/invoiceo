import 'dart:convert';

import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/models/additional_cost.dart';
import 'package:invoiceo/models/custom_field_value.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/product.dart';

/// A half-made invoice, quotation or receipt saved with "Save Draft".
///
/// Drafts live in their own table (`invoice_drafts`), not in `invoices`, so
/// they never count in reports, stock, customer balances or the numbering.
/// Opening a draft fills the create form with [invoice]; creating it makes a
/// real document (with a real number, stock taken off) and deletes the draft.
class InvoiceDraft {
  InvoiceDraft({
    required this.id,
    required this.invoice,
    required this.updatedAt,
  });

  final String id;

  /// The form as it was when saved. Its own id / number mean nothing: the
  /// real ones are given when the document is created.
  final Invoice invoice;
  final DateTime updatedAt;

  String get type => invoice.type;
  String get customerName => invoice.customer.name;

  /// Row for the `invoice_drafts` table. The small columns are there so the
  /// list can be shown without decoding every draft.
  Map<String, Object?> toRow() => {
        'id': id,
        'type': invoice.type,
        'customer_name': invoice.customer.name,
        'total': invoice.total,
        'item_count': invoice.items.length,
        'data': jsonEncode(invoiceToJson(invoice)),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory InvoiceDraft.fromRow(Map<String, Object?> row) => InvoiceDraft(
        id: row['id'] as String,
        invoice: invoiceFromJson(
            jsonDecode(row['data'] as String) as Map<String, dynamic>),
        updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
            DateTime.now(),
      );

  // ── Invoice <-> JSON (everything the create form can set) ────────────────

  static Map<String, dynamic> invoiceToJson(Invoice i) => {
        'type': i.type,
        'customer': i.customer.toMap(),
        'items': [for (final it in i.items) itemToJson(it)],
        'date': i.date.toIso8601String(),
        'dueDate': i.dueDate?.toIso8601String(),
        'invoiceTitle': i.invoiceTitle,
        'notes': i.notes,
        'taxRate': i.taxRate,
        'currencyCode': i.currencyCode,
        'currencySymbol': i.currencySymbol,
        'taxMode': i.taxMode.name,
        'isInterState': i.isInterState,
        'upiId': i.upiId,
        'bankAccountId': i.bankAccountId,
        'quantityLabel': i.quantityLabel,
        'additionalCosts': [for (final c in i.additionalCosts) c.toJson()],
        'invoiceDiscountType': i.invoiceDiscountType.name,
        'invoiceDiscountValue': i.invoiceDiscountValue,
        'hideInvoiceNumber': i.hideInvoiceNumber,
        'customInvoiceNumber': i.customInvoiceNumber,
        'customFields': [for (final f in i.customFields) f.toJson()],
        'convertedFromInvoiceId': i.convertedFromInvoiceId,
      };

  static Invoice invoiceFromJson(Map<String, dynamic> j) => Invoice(
        id: '',
        type: j['type'] as String? ?? 'Invoice',
        customer: Customer.fromMap(
            Map<String, dynamic>.from(j['customer'] as Map? ?? const {})),
        items: [
          for (final it in (j['items'] as List? ?? const []))
            itemFromJson(Map<String, dynamic>.from(it as Map)),
        ],
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        dueDate: DateTime.tryParse(j['dueDate'] as String? ?? ''),
        invoiceTitle: j['invoiceTitle'] as String?,
        notes: j['notes'] as String?,
        taxRate: (j['taxRate'] as num?)?.toDouble() ?? 0.0,
        currencyCode: j['currencyCode'] as String? ?? 'INR',
        currencySymbol: j['currencySymbol'] as String? ?? '₹',
        taxMode: TaxMode.values.firstWhere((m) => m.name == j['taxMode'],
            orElse: () => TaxMode.global),
        isInterState: j['isInterState'] as bool? ?? false,
        upiId: j['upiId'] as String?,
        bankAccountId: j['bankAccountId'] as String?,
        quantityLabel: j['quantityLabel'] as String?,
        additionalCosts: [
          for (final c in (j['additionalCosts'] as List? ?? const []))
            AdditionalCost.fromJson(Map<String, dynamic>.from(c as Map)),
        ],
        invoiceDiscountType: InvoiceDiscountType.values.firstWhere(
            (t) => t.name == j['invoiceDiscountType'],
            orElse: () => InvoiceDiscountType.percent),
        invoiceDiscountValue:
            (j['invoiceDiscountValue'] as num?)?.toDouble() ?? 0.0,
        hideInvoiceNumber: j['hideInvoiceNumber'] as bool? ?? false,
        customInvoiceNumber: j['customInvoiceNumber'] as String?,
        customFields: [
          for (final f in (j['customFields'] as List? ?? const []))
            CustomFieldValue.fromJson(Map<String, dynamic>.from(f as Map)),
        ],
        convertedFromInvoiceId: j['convertedFromInvoiceId'] as String?,
      );

  static Map<String, dynamic> itemToJson(InvoiceItem it) => {
        'id': it.id,
        'product': it.product.toMap(),
        'quantity': it.quantity,
        'discount': it.discount,
        'unitPrice': it.unitPrice,
        'extraCost': it.extraCost,
        'unit': it.unit,
        'description': it.description,
        'metadata': it.metadata?.toMap(),
        'discountPerUnit': it.discountPerUnit,
        'isProductSaved': it.isProductSaved,
      };

  static InvoiceItem itemFromJson(Map<String, dynamic> j) => InvoiceItem(
        id: j['id'] as String?,
        product: Product.fromMap(
            Map<String, dynamic>.from(j['product'] as Map? ?? const {})),
        quantity: (j['quantity'] as num?)?.toDouble() ?? 1,
        discount: (j['discount'] as num?)?.toDouble() ?? 0.0,
        unitPrice: (j['unitPrice'] as num?)?.toDouble(),
        extraCost: (j['extraCost'] as num?)?.toDouble(),
        unit: j['unit'] as String?,
        description: j['description'] as String?,
        metadata: j['metadata'] == null
            ? null
            : ProductMetadata.fromMap(
                Map<String, dynamic>.from(j['metadata'] as Map)),
        discountPerUnit: j['discountPerUnit'] as bool? ?? false,
        isProductSaved: j['isProductSaved'] as bool? ?? false,
      );
}
