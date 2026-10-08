import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/services/pdf_service.dart';
import 'package:invoiceo/services/thermal_printer_service_v1.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/utils/formatters.dart';

/// Where "print" goes: the saved template, or explicitly a thermal receipt or
/// an A4 PDF.
enum PrintTarget { auto, thermal, a4 }

class InvoicePdfServices {
  /// Replaces the real printing in tests, so a test can see that (and how
  /// often) the app tried to print without opening a printer dialog.
  @visibleForTesting
  static Future<void> Function(BuildContext context, Invoice invoice)? printHook;

  /// Whether a newly created invoice is printed straight away. On unless the
  /// user turned it off in Settings ('false').
  static Future<bool> autoPrintAfterCreateEnabled() async {
    try {
      return (await BackendServices.settings
              .getSetting(SettingKey.autoPrintAfterCreate)) !=
          'false';
    } catch (_) {
      return true; // an unreadable setting must not silently stop printing
    }
  }

  /// Prints [invoice]. [target]: [PrintTarget.auto] uses the saved template
  /// (thermal receipt or PDF); the other two choose explicitly ("Save & Print"
  /// menu on the Modern create screen).
  static Future<void> generatePDF(BuildContext context, Invoice invoice,
      {PrintTarget target = PrintTarget.auto}) async {
    final hook = printHook;
    if (hook != null) return hook(context, invoice);
    try {
      final template = await BackendServices.settings.getInvoiceTemplate();
      final thermal = switch (target) {
        PrintTarget.thermal => true,
        PrintTarget.a4 => false,
        PrintTarget.auto => template == InvoiceTemplate.thermal,
      };
      if (thermal) {
        if (!context.mounted) return;
        await ThermalPrinterService.printInvoice(context, invoice);
      } else {
        final forceA4 = target == PrintTarget.a4;
        final dateFmt = await BackendServices.settings.getDateFormat();
        final pdf = await PDFService.generateInvoicePDF(invoice,
            datePattern: dateFmt.key, forceA4: forceA4);
        final pageSize =
            forceA4 ? PageSize.a4 : await BackendServices.settings.getPageSize();
        await Printing.layoutPdf(
            format: PDFService.pageSizeToFormat(pageSize),
            onLayout: (PdfPageFormat format) async => pdf.save());
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  /// Tests can replace the PDF preview window.
  static Future<void> Function(BuildContext context, Invoice invoice)? previewHook;

  static Future<void> previewPDF(BuildContext context, Invoice invoice) async {
    final hook = previewHook;
    if (hook != null) return hook(context, invoice);
    try {
      final dateFmt = await BackendServices.settings.getDateFormat();
      final pdf = await PDFService.generateInvoicePDF(invoice,
          datePattern: dateFmt.key);
      final bytes = await pdf.save();
      if (context.mounted) {
        PDFService.showCenteredPDFViewer(context, bytes, invoice);
      }
    } catch (e) {
      if (context.mounted) {
        if(kDebugMode) print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error previewing PDF: $e')),
        );
      }
    }
  }

  static Future<void> deleteInvoice(
      BuildContext context, Invoice invoice) async {
    try {
      await BackendServices.invoices.deleteInvoice(invoice.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error deleting PDF: $e')));
      }
    }
  }

  static Future<void> showInvoiceDetails(
      BuildContext context, Invoice invoice) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invoice #${invoice.invoiceNumber ?? invoice.id}'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (invoice.status == 'declined')
                const Text('DECLINED',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              Text('Customer: ${invoice.customer.name}'),
              Text('Date: ${AppFormatters.formatShortDate(invoice.date)}'),
              const SizedBox(height: 16),
              const Text('Items:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...invoice.items.map((item) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${item.product.name} x${item.quantity == item.quantity.roundToDouble() ? item.quantity.toInt() : item.quantity}'),
                        Text(
                            '${invoice.currencySymbol} ${item.total.toStringAsFixed(2)}'),
                      ],
                    ),
                  )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      '${invoice.currencySymbol} ${invoice.subtotal.toStringAsFixed(2)}'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_taxLabel(invoice),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      '${invoice.currencySymbol} ${invoice.tax.toStringAsFixed(2)}'),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      '${invoice.currencySymbol} ${invoice.total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(invoice.notes!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  static String _taxLabel(Invoice invoice) {
    switch (invoice.taxMode) {
      case TaxMode.global:
        return 'Tax (${formatTaxRate(invoice.taxRate * 100)}%):';
      case TaxMode.perItem:
        return 'Tax (per item):';
      case TaxMode.none:
        return 'Tax:';
    }
  }

  /// Generates the next `id` (primary key) — global sequence across all
  /// types, unchanged from before. Other queries (e.g. "recent invoices")
  /// rely on `id` sorting as a single monotonic sequence, so this must never
  /// be scoped by type.
  static Future<String> generateNextId() => BackendServices.invoices.generateNextId();

  /// Generates the next **display** number for [type] ('Invoice' |
  /// 'Quotation' | 'Receipt') — each type has its own independent sequence.
  /// This is separate from `id` (the PK, always global) and is stored in the
  /// `invoice_number` column purely for display.
  ///
  /// Derived from existing rows rather than a persisted counter: takes the
  /// max of the legacy `id` sequence (pre-migration rows, shared across all
  /// types) and the new `invoice_number` column (post-migration, per-type)
  /// for this type, so upgrading preserves numbering continuity for existing
  /// customers without any data migration.
  static Future<String> generateNextInvoiceNumber(String type) =>
      BackendServices.invoices.generateNextInvoiceNumber(type);

  /// Non-consuming preview of [generateNextId] — for UI display only.
  static Future<String> peekNextId() => BackendServices.invoices.peekNextId();

  /// Non-consuming preview of [generateNextInvoiceNumber] — for UI display only.
  static Future<String> peekNextInvoiceNumber(String type) =>
      BackendServices.invoices.peekNextInvoiceNumber(type);
}
