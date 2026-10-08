import 'package:intl/intl.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/services/pdf/pdf_settings.dart';
import 'package:invoiceo/services/pdf/pdf_widgets.dart'
    show invoiceTaxLabel, roundNetTotal;
import 'package:invoiceo/utils/amount_in_words.dart';

import 'package:invoiceo/common/app_config.dart';
enum ReceiptLineKind { text, twoCol, hr, itemHeader, item }

/// One line of a thermal receipt, independent of how it is drawn.
///
/// The receipt's CONTENT (which fields show, in which order, with which
/// settings) is decided once in [buildReceiptLines]. Two renderers draw it:
/// the plain ESC/POS text printer, and the picture renderer used when the
/// receipt contains scripts a printer cannot print as text (Tamil, ...).
class ReceiptLine {
  const ReceiptLine._(
    this.kind, {
    this.text = '',
    this.right = '',
    this.bold = false,
    this.center = false,
    this.head = false,
    this.sl = '',
    this.qty = '',
    this.unit = '',
    this.rate = '',
    this.gst,
    this.total = '',
    this.tableLayout = true,
    this.showTax = false,
  });

  final ReceiptLineKind kind;

  /// text: the line. twoCol: the left part.
  final String text;

  /// twoCol: the right part.
  final String right;
  final bool bold;
  final bool center;

  /// The big heading style (company name).
  final bool head;

  // Item rows (kind == item). [text] holds the product name.
  final String sl;
  final String qty;
  final String unit;
  final String rate;
  final String? gst;
  final String total;

  /// Item rows / header: the compact column layout vs. the two-line one.
  final bool tableLayout;
  final bool showTax;

  factory ReceiptLine.text(String text,
          {bool center = false, bool bold = false, bool head = false}) =>
      ReceiptLine._(ReceiptLineKind.text,
          text: text, center: center, bold: bold, head: head);

  factory ReceiptLine.twoCol(String left, String right, {bool bold = false}) =>
      ReceiptLine._(ReceiptLineKind.twoCol,
          text: left, right: right, bold: bold);

  factory ReceiptLine.hr() => const ReceiptLine._(ReceiptLineKind.hr);

  factory ReceiptLine.itemHeader(
          {required bool tableLayout, required bool showTax}) =>
      ReceiptLine._(ReceiptLineKind.itemHeader,
          tableLayout: tableLayout, showTax: showTax);

  factory ReceiptLine.item({
    required int sl,
    required String name,
    required String qty,
    required String unit,
    required String rate,
    required String? gst,
    required String total,
    required bool tableLayout,
  }) =>
      ReceiptLine._(ReceiptLineKind.item,
          text: name,
          sl: '$sl',
          qty: qty,
          unit: unit,
          rate: rate,
          gst: gst,
          total: total,
          tableLayout: tableLayout);
}

/// Everything that goes on the receipt, in order.
List<ReceiptLine> buildReceiptLines(
  Invoice invoice,
  PdfGenerationSettings settings, {
  required double previousBalance,
  required String dateFormatKey,
  required bool tableLayout,
}) {
  final lines = <ReceiptLine>[];
  final company = settings.company;
  final currency = invoice.currencySymbol;
  final showItemTax = invoice.taxMode == TaxMode.perItem;

  void text(String t,
          {bool center = false, bool bold = false, bool head = false}) =>
      lines.add(ReceiptLine.text(t, center: center, bold: bold, head: head));
  void two(String l, String r, {bool bold = false}) =>
      lines.add(ReceiptLine.twoCol(l, r, bold: bold));
  void hr() => lines.add(ReceiptLine.hr());

  // ── Business header ──
  // The same show/hide settings as the PDF receipt.
  if (settings.showCompanyName && (company?.name ?? '').isNotEmpty) {
    text(company!.name, center: true, bold: true, head: true);
  }
  if (settings.showAddress && (company?.address ?? '').isNotEmpty) {
    text(company!.address, center: true);
  }
  if (settings.showPhone && (company?.phone ?? '').isNotEmpty) {
    text('Ph: ${company!.phone}', center: true);
  }
  if (settings.showGst && (company?.gstin ?? '').isNotEmpty) {
    text('${taxLabel(company?.country)}: ${company!.gstin}', center: true);
  }
  hr();
  text((invoice.invoiceTitle ?? invoice.type).toUpperCase(),
      center: true, bold: true);
  if (invoice.status == 'declined') {
    text('*** DECLINED ***', center: true, bold: true);
  }
  hr();

  // ── Invoice meta ──
  final dateFormatter = DateFormat(dateFormatKey, 'en_US');
  final dateStr = settings.showTimeInPdf
      ? '${dateFormatter.format(invoice.date)} ${DateFormat(settings.pdfTimeFormat == '12' ? 'h:mm a' : 'HH:mm', 'en_US').format(invoice.date)}'
      : dateFormatter.format(invoice.date);
  final numberText = invoice.pdfNumberText(settings.invoicePrefix,
      showLeadingZeros: settings.showLeadingZeros);
  two(numberText != null ? 'Inv No: $numberText' : '', 'Date: $dateStr');
  if (invoice.dueDate != null) {
    two('Due:', dateFormatter.format(invoice.dueDate!));
  }
  hr();

  // ── Customer ──
  text('Name: ${invoice.customer.name}', bold: true);
  if (settings.showCustomerBusinessName &&
      invoice.customer.businessName.isNotEmpty) {
    text(invoice.customer.businessName);
  }
  if (settings.showCustomerPhone && invoice.customer.phone.isNotEmpty) {
    text('Ph: ${invoice.customer.phone}');
  }
  if (settings.showGst &&
      settings.showCustomerGstin &&
      invoice.customer.gstin.isNotEmpty) {
    text('${taxLabel(company?.country)}: ${invoice.customer.gstin}');
  }
  hr();

  // ── Items ──
  lines.add(ReceiptLine.itemHeader(
      tableLayout: tableLayout, showTax: showItemTax));
  hr();
  for (var i = 0; i < invoice.items.length; i++) {
    final item = invoice.items[i];
    final qty = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(2);
    lines.add(ReceiptLine.item(
      sl: i + 1,
      name: item.product.displayName(settings.showAliasName),
      qty: qty,
      unit: item.effectiveUnit.trim(),
      rate: item.effectivePrice.toStringAsFixed(2),
      gst: showItemTax ? '${item.product.tax_rate}%' : null,
      total: item.total.toStringAsFixed(2),
      tableLayout: tableLayout,
    ));
    if (settings.showDescription && item.printedDescription.isNotEmpty) {
      text('  ${item.printedDescription}');
    }
    if (settings.showDiscount && item.totalDiscount > 0) {
      text('  Disc: -${item.totalDiscount.toStringAsFixed(2)}');
    }
  }
  hr();

  // ── Totals ──
  if (invoice.totalDiscount > 0) {
    two('Subtotal:', '$currency ${invoice.grossSubtotal.toStringAsFixed(2)}');
    two('Discount:', '-$currency ${invoice.totalDiscount.toStringAsFixed(2)}');
  }
  if (invoice.taxMode != TaxMode.none) {
    two(invoiceTaxLabel(invoice), '$currency ${invoice.tax.toStringAsFixed(2)}');
  }
  for (final c in invoice.additionalCosts) {
    two(
        c.label.isEmpty ? 'Extra Cost' : c.label,
        c.amount < 0
            ? '-$currency ${(-c.amount).toStringAsFixed(2)}'
            : '$currency ${c.amount.toStringAsFixed(2)}');
  }
  if (invoice.invoiceDiscountAmount > 0) {
    two(
        invoice.invoiceDiscountType == InvoiceDiscountType.percent
            ? 'Extra Discount (${invoice.invoiceDiscountValue.toStringAsFixed(1)}%)'
            : 'Extra Discount',
        '-$currency ${invoice.invoiceDiscountAmount.toStringAsFixed(2)}');
  }
  if (previousBalance > 0) {
    two('Prev Balance:', '$currency ${previousBalance.toStringAsFixed(2)}');
  }
  two(
    'TOTAL',
    '$currency ${(invoice.total + previousBalance).toStringAsFixed(2)}',
    bold: true,
  );
  if (settings.showRoundOff) {
    final net = roundNetTotal(invoice.total + previousBalance);
    two('Round off:', '$currency ${net.roundOff.toStringAsFixed(2)}');
    two('NET AMOUNT', '$currency ${net.rounded.toStringAsFixed(2)}',
        bold: true);
    text(AmountInWords.amount(net.rounded,
        indian: invoice.currencyCode == 'INR'));
  }

  if (invoice.taxMode != TaxMode.none && invoice.tax > 0) {
    final isIndia = (company?.country ?? '').isEmpty ||
        company!.country.toLowerCase() == 'india';
    hr();
    text('=== TAX SUMMARY ===', center: true, bold: true);
    two('Taxable Amt:', '$currency ${invoice.subtotal.toStringAsFixed(2)}');
    if (isIndia && invoice.isInterState) {
      two('IGST:', '$currency ${invoice.tax.toStringAsFixed(2)}');
    } else if (isIndia) {
      two('SGST:', '$currency ${(invoice.tax / 2).toStringAsFixed(2)}');
      two('CGST:', '$currency ${(invoice.tax / 2).toStringAsFixed(2)}');
    }
    two('Total Tax:', '$currency ${invoice.tax.toStringAsFixed(2)}');
  }

  if (invoice.amountPaid > 0) {
    hr();
    two('Paid:', '$currency ${invoice.amountPaid.toStringAsFixed(2)}');
    if (invoice.outstandingBalance <= 0) {
      two('PAID IN FULL', '', bold: true);
    } else {
      two('Balance Due',
          '$currency ${invoice.outstandingBalance.toStringAsFixed(2)}',
          bold: true);
    }
  }

  // ── Notes ──
  if ((invoice.notes ?? '').isNotEmpty) {
    hr();
    text(invoice.notes!);
  }

  // ── Footer ──
  hr();
  if (settings.thankYouNote.isNotEmpty) {
    text(settings.thankYouNote, center: true, bold: true);
  }
  if (settings.showFooterBranding) {
    text('Generated by ${AppConfig.brandName}', center: true);
  }
  return lines;
}

/// True when [text] can be sent to the printer as plain ESC/POS text.
///
/// The ESC/POS library encodes Latin-1 only (after swapping a few look-alike
/// characters), and throws on anything else: the rupee sign, Tamil, Arabic,
/// Thai... Mirrors the swaps in flutter_esc_pos_utils' Generator._encode.
/// Only ASCII is allowed: we never select a code page, so Latin-1 letters
/// such as é, ñ, £ and ¥ would print as the wrong glyphs. Those receipts
/// use the image path instead.
bool canPrintAsEscPosText(String text) {
  final swapped = text
      .replaceAll('\u2019', "'") // ’
      .replaceAll('\u00B4', "'") // ´
      .replaceAll('\u00BB', '"') // »
      .replaceAll('\u00A0', ' ') // no-break space
      .replaceAll('\u2022', '.'); // •
  return swapped.runes.every((r) => r < 0x80);
}

/// True when any line of the receipt has text a printer cannot print as text,
/// so the whole receipt must be drawn as a picture instead.
bool receiptNeedsImage(List<ReceiptLine> lines) => lines.any((l) =>
    ![l.text, l.right, l.sl, l.qty, l.unit, l.rate, l.gst ?? '', l.total]
        .every(canPrintAsEscPosText));
