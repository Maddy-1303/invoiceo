import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:invoiceo/services/backend_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/services/pdf/pdf_service.dart';
import 'package:invoiceo/services/escpos_raster.dart';
import 'package:invoiceo/services/thermal_printer_choice.dart';
import 'package:invoiceo/services/thermal_receipt_image.dart';
import 'package:invoiceo/services/thermal_receipt_lines.dart';
import 'package:invoiceo/services/pdf/pdf_settings.dart';
import 'package:printing/printing.dart' show Printing;
import 'package:thermal_printer/discovery.dart' show PrinterDiscovered;
import 'package:thermal_printer/thermal_printer.dart';

/// Prints receipts as raw ESC/POS commands sent directly to the printer,
/// instead of rendering a PDF and letting the OS/GDI driver rasterize it.
/// This is what fixes garbled thermal output — the printer gets its native
/// command language instead of a rasterized page the driver may mishandle.
///
/// Exception: a receipt containing Indic-script text (Tamil, Malayalam, ...)
/// cannot be sent as ESC/POS text — the library encodes Latin-1 only, and
/// printers have no such fonts. Those receipts are rendered from the same PDF
/// the preview shows and sent as a raster image instead.
typedef SendToDevice = Future<void> Function({
  required PrinterType type,
  required BasePrinterInput model,
  required Invoice invoice,
});

class ThermalPrinterService {
  /// Test seams: the real plugin and the real send, replaced only by tests.
  @visibleForTesting
  static Future<List<PrinterDiscovered<UsbPrinterInfo>>> Function()
      discoverUsbPrinters = UsbPrinterConnector.discoverPrinters;
  @visibleForTesting
  static SendToDevice sendToDevice = _printToDevice;

  static bool _printInProgress = false;

  /// Tests that end with the chooser still open leave the guard set.
  @visibleForTesting
  static void resetPrintGuard() => _printInProgress = false;

  /// Print [invoice] on a thermal printer.
  ///
  /// If the user chose a printer earlier (and left "print automatically"
  /// on) and it is still connected, the receipt goes straight to it. In every
  /// other case the chooser is shown; choosing there remembers the printer.
  ///
  /// Only one print runs at a time: with no modal box in the way, a double
  /// click or a held Ctrl+P would otherwise send several receipts.
  static Future<void> printInvoice(
      BuildContext context, Invoice invoice) async {
    if (_printInProgress) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      // Replace "Printing to X..." (which would otherwise hold this message
      // back in the queue); the final result message follows when it ends.
      messenger?.clearSnackBars();
      messenger?.showSnackBar(const SnackBar(
          content: Text('A receipt is already being printed...')));
      return;
    }
    _printInProgress = true;
    try {
      await _printInvoice(context, invoice);
    } finally {
      _printInProgress = false;
    }
  }

  /// The printer plugin only works on Windows, Android and iOS.
  static bool get _pluginSupported =>
      Platform.isWindows || Platform.isAndroid || Platform.isIOS;

  static Future<void> _printInvoice(
      BuildContext context, Invoice invoice) async {
    // macOS and Linux have no thermal plugin, so print the receipt PDF
    // through the system print dialog instead. Tests replace
    // discoverUsbPrinters, so they still run the thermal flow on any host.
    if (!_pluginSupported &&
        discoverUsbPrinters == UsbPrinterConnector.discoverPrinters) {
      await _printPdfFallback(context, invoice);
      return;
    }
    final found = await discoverUsbPrinters();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final settings = BackendServices.settings;

    final autoPrint =
        (await settings.getSetting(SettingKey.thermalAutoPrint)) != 'false';
    final lastUsed = ThermalPrinterRef.tryParse(
        await settings.getSetting(SettingKey.lastUsedThermalPrinter));
    if (!context.mounted) return;

    final refs = [for (final p in found) _refOf(p)];
    final choice = chooseThermalPrinter(
        found: refs, lastUsed: lastUsed, autoPrint: autoPrint);
    if (choice.isAutomatic) {
      final device = found[refs.indexWhere((r) => r.matches(choice.printer!))];
      _showPrinting(messenger, device.name);
      try {
        await _sendTo(device, invoice);
        _announcePrinted(messenger, device.name);
        return;
      } catch (e) {
        messenger?.clearSnackBars();
        messenger?.showSnackBar(SnackBar(
            content: Text('Could not print to ${device.name}: $e')));
        // Fall through so the user can pick another printer.
      }
    }
    if (!context.mounted) return;
    await _showChooser(context, invoice, found, autoPrint, messenger);
  }

  /// Prints the receipt as a PDF with the system print dialog.
  static Future<void> _printPdfFallback(
      BuildContext context, Invoice invoice) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final dateFmt = await BackendServices.settings.getDateFormat();
      final pdf =
          await PDFService.generateInvoicePDF(invoice, datePattern: dateFmt.key);
      final bytes = await pdf.save();
      // A roll page has no fixed height until it is laid out, so give the
      // print dialog the real size of the first page.
      final pages = pdf.document.pdfPageList.pages;
      final format = pages.isNotEmpty
          ? pages.first.pageFormat
          : PDFService.pageSizeToFormat(
              await BackendServices.settings.getPageSize());
      await Printing.layoutPdf(format: format, onLayout: (_) async => bytes);
    } catch (e) {
      messenger?.clearSnackBars();
      messenger?.showSnackBar(SnackBar(content: Text('Print failed: $e')));
    }
  }

  static void _showPrinting(ScaffoldMessengerState? messenger, String name) {
    messenger?.clearSnackBars();
    messenger?.showSnackBar(SnackBar(
      content: Text('Printing to $name...'),
      duration: const Duration(seconds: 30),
    ));
  }

  static void _announcePrinted(ScaffoldMessengerState? messenger, String name) {
    messenger?.clearSnackBars();
    messenger?.showSnackBar(SnackBar(
      content: Text('Printed to $name'),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'Change printer',
        onPressed: () => forgetSavedPrinter(messenger),
      ),
    ));
  }

  /// Forgets the saved printer so the next print asks again. Also reachable
  /// from Settings > PDF settings (the snackbar above cannot be tapped while
  /// a dialog such as the PDF preview is on screen).
  static Future<void> forgetSavedPrinter(
      ScaffoldMessengerState? messenger) async {
    try {
      await BackendServices.settings
          .setSetting(SettingKey.lastUsedThermalPrinter, '');
      messenger?.showSnackBar(const SnackBar(
          content: Text(
              "Printer forgotten. You'll be asked to choose one next time.")));
    } catch (e) {
      messenger?.showSnackBar(
          SnackBar(content: Text('Could not forget the printer: $e')));
    }
  }

  static ThermalPrinterRef _refOf(PrinterDiscovered<UsbPrinterInfo> p) =>
      ThermalPrinterRef(
        name: p.detail.name.isNotEmpty ? p.detail.name : p.name,
        vendorId: p.detail.vendorId,
        productId: p.detail.productId,
      );

  static Future<void> _sendTo(
      PrinterDiscovered<UsbPrinterInfo> p, Invoice invoice) {
    final input = UsbPrinterInput(
      name: p.detail.name,
      vendorId: p.detail.vendorId,
      productId: p.detail.productId,
    );
    return sendToDevice(
        type: PrinterType.usb, model: input, invoice: invoice);
  }

  static Future<void> _showChooser(
    BuildContext context,
    Invoice invoice,
    List<PrinterDiscovered<UsbPrinterInfo>> found,
    bool autoPrint,
    ScaffoldMessengerState? messenger,
  ) async {
    final settings = BackendServices.settings;
    var rememberChoice = autoPrint;

    final chosen = await showDialog<PrinterDiscovered<UsbPrinterInfo>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Print Receipt'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('USB Printers',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (found.isEmpty)
                  const Text(
                      'No USB printers found. Connect the printer and press Print again.')
                else
                  ...found.map((p) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(p.name),
                        onTap: () => Navigator.pop(dialogContext, p),
                      )),
                if (found.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: rememberChoice,
                    title: const Text(
                        'Print automatically to this printer next time'),
                    onChanged: (v) =>
                        setDialogState(() => rememberChoice = v ?? true),
                  ),
                ],
                if (kDebugMode) ...[
                  const Divider(height: 24),
                  const Text('Test via network (e.g. local ESC/POS listener)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _NetworkPrintRow(invoice: invoice),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;

    // The print happens here, after the dialog has closed but still inside
    // printInvoice, so the "one print at a time" guard covers it.
    _showPrinting(messenger, chosen.name);
    try {
      await _sendTo(chosen, invoice);
    } catch (e) {
      messenger?.clearSnackBars();
      messenger?.showSnackBar(SnackBar(content: Text('Print failed: $e')));
      return;
    }
    // The receipt is out. Remembering the printer is a convenience and must
    // never turn a successful print into an error.
    try {
      await settings.setSetting(
          SettingKey.thermalAutoPrint, rememberChoice.toString());
      await settings.setSetting(SettingKey.lastUsedThermalPrinter,
          rememberChoice ? _refOf(chosen).toJson() : '');
    } catch (_) {}
    _announcePrinted(messenger, chosen.name);
  }

  static Future<void> _printToDevice({
    required PrinterType type,
    required BasePrinterInput model,
    required Invoice invoice,
  }) async {
    final manager = PrinterManager.instance;
    final bytes = await _buildReceiptBytes(invoice);
    await sendReceipt(
      connect: () => manager.connect(type: type, model: model),
      send: () => manager.send(type: type, bytes: bytes),
      disconnect: () => manager.disconnect(type: type),
    );
  }

  /// Sends one receipt, and FAILS when the printer does not take it.
  ///
  /// The printer plugin reports hardware problems by returning `false`; it
  /// does not throw. Ignoring that made a failed print look successful.
  @visibleForTesting
  static Future<void> sendReceipt({
    required Future<bool> Function() connect,
    required Future<bool> Function() send,
    required Future<bool> Function() disconnect,
  }) async {
    if (!await connect()) {
      throw StateError('Could not connect to the printer.');
    }
    try {
      if (!await send()) {
        throw StateError('The printer did not accept the receipt.');
      }
    } finally {
      try {
        await disconnect();
      } catch (_) {
        // Never hide the real error behind a disconnect problem.
      }
    }
  }

  /// Mirrors [PDFService.generateInvoicePDF]'s content exactly (same
  /// settings fetch, same fields shown/hidden) so the ESC/POS printout
  /// matches the PDF preview. Deliberately avoids the ESC/POS library's
  /// row()/absolute-column-position feature — that's what produced the
  /// broken layout on real/virtual printers; plain text lines with manual
  /// space padding render correctly everywhere.
  static Future<List<int>> _buildReceiptBytes(Invoice invoice) async {
    final dateFmt = await BackendServices.settings.getDateFormat();
    final settings = await PDFService.fetchPdfSettings(datePattern: dateFmt.key);
    final previousBalanceDue = settings.showPreviousBalance
        ? await BackendServices.invoices.getPreviousBalanceDueForInvoice(invoice)
        : 0.0;
    final effectivePreviousBalance =
    settings.showPreviousBalance ? previousBalanceDue : 0.0;
    return buildReceiptBytesFor(invoice, settings, effectivePreviousBalance);
  }

  /// The receipt bytes for [invoice] with explicit [settings]; split out so
  /// tests can run it without the app's asset-heavy settings loader.
  ///
  /// The content is decided once ([buildReceiptLines]) and then drawn one of
  /// two ways: as plain ESC/POS text (the printer's own font, fastest), or,
  /// when it contains text a printer cannot print (Tamil, ...), as a picture.
  @visibleForTesting
  static Future<List<int>> buildReceiptBytesFor(Invoice invoice,
      PdfGenerationSettings settings, double effectivePreviousBalance) async {
    final dateFmt = await BackendServices.settings.getDateFormat();
    final itemLayout =
        await BackendServices.settings.getSetting(SettingKey.thermalItemLayout) ??
            'table';
    final lines = buildReceiptLines(
      invoice,
      settings,
      previousBalance: effectivePreviousBalance,
      dateFormatKey: dateFmt.key,
      tableLayout: itemLayout != 'detailed',
    );
    if (receiptNeedsImage(lines)) return _imageReceiptBytes(lines, settings);
    return _textReceiptBytes(lines, settings);
  }

  /// Draws the receipt with the printer's own text commands.
  static Future<List<int>> _textReceiptBytes(
      List<ReceiptLine> lines, PdfGenerationSettings settings) async {
    final is58 = settings.pageSize == PageSize.thermal58;

    // Trim a few chars off the textbook 32/48 — real hardware often
    // physically clips the last column(s) on full-width lines. Adjustable
    // per-install via SettingKey.thermalWidthMargin since printer models vary
    // (e.g. WOOSIM WSP-R241 needed 1).
    final marginStr = await BackendServices.settings.getSetting(SettingKey.thermalWidthMargin);
    final margin = int.tryParse(marginStr ?? '') ?? 1;
    final width = (is58 ? 32 : 48) - margin;
    final profile = await CapabilityProfile.load();
    final generator = Generator(is58 ? PaperSize.mm58 : PaperSize.mm80, profile,spaceBetweenRows: 1);
    List<int> bytes = [];

    void line(String text, {PosAlign align = PosAlign.left, bool bold = false,bool isHead = false})
    {
      if(isHead) {
        bytes += generator.text(text, styles: PosStyles(align: align, bold: bold,height: PosTextSize.size2,width: PosTextSize.size1,));
      } else {
        bytes += generator.text(text, styles: PosStyles(align: align, bold: bold,));
      }
    }

    void twoCol(String left, String right, {bool bold = false}) {
      final pad = width - left.length - right.length;
      final text = pad > 0 ? '$left${' ' * pad}$right' : '$left $right';
      line(text, bold: bold);
    }

    String padRight(String s, int w) =>
        s.length >= w ? s.substring(0, w) : s + ' ' * (w - s.length);
    String padLeft(String s, int w) =>
        s.length >= w ? s.substring(s.length - w) : ' ' * (w - s.length) + s;
    String padCenter(String s, int w) {
      if (s.length >= w) return s.substring(0, w);
      final totalPad = w - s.length;
      final left = totalPad ~/ 2;
      return ' ' * left + s + ' ' * (totalPad - left);
    }

    // Table layout: compact column widths, tight enough to still fit on
    // 58mm (31 chars) while leaving extra room for the name on 80mm.
    const slW = 2, qtyW = 4, rateW = 6, gstW = 4, totalW = 7;
    String singleLineRow(bool showTax, String sl, String name, String qty,
        String rate, String? gst, String total) {
      final gaps = showTax ? 5 : 4;
      final nameW =
          (width - slW - qtyW - rateW - (showTax ? gstW : 0) - totalW - gaps)
              .clamp(1, 999);
      final parts = <String>[
        padRight(sl, slW),
        padRight(name, nameW),
        padCenter(qty, qtyW),
        padLeft(rate, rateW),
      ];
      if (gst != null) parts.add(padLeft(gst, gstW));
      parts.add(padLeft(total, totalW));
      return parts.join(' ');
    }

    for (final l in lines) {
      switch (l.kind) {
        case ReceiptLineKind.text:
          line(l.text,
              align: l.center ? PosAlign.center : PosAlign.left,
              bold: l.bold,
              isHead: l.head);
        case ReceiptLineKind.twoCol:
          twoCol(l.text, l.right, bold: l.bold);
        case ReceiptLineKind.hr:
          bytes += generator.hr();
        case ReceiptLineKind.itemHeader:
          if (l.tableLayout) {
            line(
                singleLineRow(l.showTax, 'Sl', 'Description', 'Qty', 'Rate',
                    l.showTax ? 'GST%' : null, 'Total'),
                bold: true);
          } else {
            twoCol('# Item', 'Total', bold: true);
          }
        case ReceiptLineKind.item:
          if (l.tableLayout) {
            line(singleLineRow(
                l.gst != null, l.sl, l.text, l.qty, l.rate, l.gst, l.total));
          } else {
            line('${l.sl} ${l.text}', bold: true);
            final detailParts = ['Qty:${l.qty}', 'Rate:${l.rate}'];
            if (l.gst != null) detailParts.add(l.gst!);
            detailParts.add(l.total);
            line('  ${detailParts.join('  ')}');
          }
      }
    }

    // generator.cut() forces 5 blank lines internally before cutting, with
    // no way to configure that. Reverse-feed 3 lines first to shrink the
    // net visible gap to ~2 lines. Requires printer support for ESC/POS
    // reverse feed (most auto-cutter printers have it, but not guaranteed).
    bytes += generator.reverseFeed(3);
    bytes += generator.cut();
    return _stripKanjiCancel(bytes);
  }

  /// True when the receipt for [invoice] has any text a printer cannot print
  /// as plain text (Tamil and other scripts, the rupee sign...), so it is
  /// drawn as a picture. Receipts that return false use the plain-text path,
  /// byte for byte as before.
  static bool invoiceNeedsImageReceipt(
          Invoice invoice, PdfGenerationSettings settings) =>
      receiptNeedsImage(buildReceiptLines(invoice, settings,
          previousBalance: 0,
          dateFormatKey: 'dd/MM/yyyy',
          tableLayout: true));

  /// Draws the receipt as a picture ([ThermalReceiptImage]) and encodes it
  /// as ESC/POS raster images. Text size and print width come from settings.
  static Future<List<int>> _imageReceiptBytes(
      List<ReceiptLine> lines, PdfGenerationSettings settings) async {
    final is58 = settings.pageSize == PageSize.thermal58;
    final store = BackendServices.settings;
    final fontPx = ThermalReceiptImage.fontPxFor(
        await store.getSetting(SettingKey.thermalReceiptTextSize));
    final widthDots = ThermalReceiptImage.widthDotsFor(
        await store.getSetting(SettingKey.thermalPrintWidth),
        is58: is58);

    final image = await ThermalReceiptImage.render(lines,
        widthDots: widthDots, fontPx: fontPx);

    final profile = await CapabilityProfile.load();
    final generator =
        Generator(is58 ? PaperSize.mm58 : PaperSize.mm80, profile);
    final bytes = <int>[
      ...generator.reset(),
      ...escPosRasterBands(image),
      ...generator.reverseFeed(3),
      ...generator.cut(),
    ];
    // Do not run _stripKanjiCancel here: it would also delete any 0x1C 0x2E
    // byte pair inside the image data.
    return bytes;
  }

  /// The ESC/POS library emits `FS .` (bytes 0x1C 0x2E — "Cancel Kanji
  /// Character Mode") before every single text call, unconditionally, even
  /// though we never use Kanji mode. Some printers (e.g. WOOSIM WSP-R241)
  /// don't recognize 0x1C as a command byte, drop it, and print the
  /// following 0x2E as a literal '.' — showing up as a stray dot at the
  /// start of every line. Safe to strip: 0x1C never appears in our own
  /// text content (it's a non-printable control byte).
  static List<int> _stripKanjiCancel(List<int> bytes) {
    final result = <int>[];
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] == 0x1C && i + 1 < bytes.length && bytes[i + 1] == 0x2E) {
        i++;
        continue;
      }
      result.add(bytes[i]);
    }
    return result;
  }
}

class _NetworkPrintRow extends StatefulWidget {
  final Invoice invoice;
  const _NetworkPrintRow({required this.invoice});

  @override
  State<_NetworkPrintRow> createState() => _NetworkPrintRowState();
}

class _NetworkPrintRowState extends State<_NetworkPrintRow> {
  final _ipController = TextEditingController(text: '0.0.0.0');
  final _portController = TextEditingController(text: '9200');
  bool _sending = false;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final input = TcpPrinterInput(
        ipAddress: _ipController.text.trim(),
        port: int.tryParse(_portController.text.trim()) ?? 9100,
      );
      await ThermalPrinterService._printToDevice(
        type: PrinterType.network,
        model: input,
        invoice: widget.invoice,
      );
      messenger?.showSnackBar(
        const SnackBar(content: Text('Sent to network printer/listener.')),
      );
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _ipController,
            decoration: const InputDecoration(labelText: 'IP address'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: _portController,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: _sending
              ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
