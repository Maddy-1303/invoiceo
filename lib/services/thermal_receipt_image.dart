import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:invoiceo/services/pdf/shaped_text_rasterizer.dart';
import 'package:invoiceo/services/thermal_receipt_lines.dart';

/// Draws a thermal receipt as a picture, for receipts a printer cannot print
/// as text (Tamil, Malayalam, ...).
///
/// This replaces printing the PDF page as a picture, which carried the PDF's
/// tiny 6-point text onto the paper: far smaller than a printer's own text.
/// Here the text is sized in printer dots (a normal receipt line is about 26
/// dots tall, like the printer's built-in font) and drawn by Flutter's text
/// engine, which shapes every script correctly.
class ThermalReceiptImage {
  ThermalReceiptImage._();

  /// Text height in dots for the "Receipt text size" setting.
  static double fontPxFor(String? size) => switch (size) {
        'normal' => 26,
        'xlarge' => 36,
        _ => 30, // 'large' (default)
      };

  /// Width of the print head in dots for the "Print width" setting.
  /// 'auto' = the usual width for the paper: 576 (80 mm) or 384 (58 mm).
  static int widthDotsFor(String? setting, {required bool is58}) {
    final auto = is58 ? 384 : 576;
    final n = int.tryParse(setting ?? '');
    if (n == null) return auto;
    return n.clamp(256, 832);
  }

  static const _margin = 6.0;
  static const _gap = 14.0;
  static const _lineGap = 4.0;

  /// The graphics engine cannot make one picture taller than its largest
  /// texture (16384 rows on most GPUs, 8192 on older ones) and silently shrinks
  /// anything bigger. A long invoice is therefore drawn in strips this tall and
  /// joined afterwards. A multiple of 128, the height of one printed band.
  static const _stripRows = 4096;

  /// Renders [lines] at [widthDots] wide. White background, black text.
  static Future<img.Image> render(
    List<ReceiptLine> lines, {
    required int widthDots,
    required double fontPx,
    int stripRows = _stripRows, // a parameter only so tests can force strips
  }) async {
    await ShapedTextRasterizer.prepareFonts();
    final contentW = widthDots - _margin * 2;

    final blocks = <_Block>[];
    var y = 6.0;

    ui.Paragraph para(String text, double width,
        {double? size,
        bool bold = false,
        ui.TextAlign align = ui.TextAlign.left}) {
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
          textAlign: align, textDirection: ui.TextDirection.ltr))
        ..pushStyle(ShapedTextRasterizer.uiTextStyle(
            fontPx: size ?? fontPx, bold: bold))
        ..addText(text.isEmpty ? ' ' : text);
      return builder.build()..layout(ui.ParagraphConstraints(width: width));
    }

    void add(ui.Paragraph p, double x) {
      blocks.add(_Block.paragraph(p, x, y));
    }

    // Left text and right text on one row. If they do not fit side by side the
    // right part drops to its own line (right-aligned) instead of squeezing the
    // left one into a wrapped column.
    double twoCol(String left, String right,
        {bool bold = false, double indent = 0}) {
      final avail = contentW - indent;
      final r = para(right, contentW, bold: bold);
      final rightW = right.isEmpty ? 0.0 : r.longestLine.ceilToDouble() + 1;
      final l = para(left, avail, bold: bold);
      final leftOneLine = left.isEmpty || l.computeLineMetrics().length == 1;
      final fitsSideBySide = leftOneLine &&
          (left.isEmpty ||
              right.isEmpty ||
              l.longestLine + _gap + rightW <= avail);
      if (left.isNotEmpty) add(l, _margin + indent);
      if (right.isEmpty) return left.isEmpty ? 0.0 : l.height;
      if (fitsSideBySide) {
        blocks.add(_Block.paragraph(r, _margin + contentW - rightW, y));
        return l.height > r.height ? l.height : r.height;
      }
      final below = left.isEmpty ? 0.0 : l.height + 2;
      blocks.add(_Block.paragraph(r, _margin + contentW - rightW, y + below));
      return below + r.height;
    }

    // ── Item table columns ────────────────────────────────────────────────
    // Compact (table) layout: one row per item, Item | Qty | Rate | [GST] |
    // Amount, like the PDF receipt and the printer's own text table (the unit
    // is part of the product name or shown by the two-line layout). Every
    // number column is as
    // wide as its widest entry (up to a cap, so one odd value cannot squeeze
    // the names), and a value wider than its cap wraps inside its own cell.
    // When the columns leave too little room for the names (58 mm paper,
    // per-item GST) the receipt uses the two-line layout instead, which loses
    // nothing.
    String qtyWithUnit(ReceiptLine l) =>
        l.unit.isEmpty ? l.qty : '${l.qty} ${l.unit}';
    final rows = lines.where((l) => l.kind == ReceiptLineKind.item).toList();
    final showTax = rows.any((l) => l.gst != null);
    double colWidth(String header, Iterable<String> values, double cap) {
      double w(String t, {bool bold = false}) =>
          para(t, contentW, bold: bold).longestLine.ceilToDouble() + 1;
      var best = w(header, bold: true);
      for (final v in values) {
        final m = w(v);
        if (m > best) best = m;
      }
      return math.min(best, cap);
    }

    final qtyW = colWidth('Qty', rows.map((l) => l.qty), contentW * 0.22);
    final rateW = colWidth('Rate', rows.map((l) => l.rate), contentW * 0.24);
    final gstW = showTax
        ? colWidth('GST', rows.map((l) => l.gst ?? ''), contentW * 0.14)
        : 0.0;
    final amtW = colWidth('Amount', rows.map((l) => l.total), contentW * 0.30);
    final nameW =
        contentW - qtyW - rateW - gstW - amtW - _gap * (showTax ? 4 : 3);
    final compact =
        rows.any((l) => l.tableLayout) && nameW >= contentW * 0.32;
    // Right edge of each column.
    final amtRight = _margin + contentW;
    final gstRight = amtRight - amtW - _gap;
    final rateRight = (showTax ? gstRight - gstW : amtRight - amtW) - _gap;
    final qtyRight = rateRight - rateW - _gap;

    // A right-aligned cell; returns its height.
    double cell(String text, double right, double width,
        {bool bold = false}) {
      final p = para(text, width,
          bold: bold, align: ui.TextAlign.right);
      blocks.add(_Block.paragraph(p, right - width, y));
      return p.height;
    }

    for (final line in lines) {
      switch (line.kind) {
        case ReceiptLineKind.text:
          final size = line.head ? fontPx * 1.35 : fontPx;
          final p = para(line.text, contentW,
              size: size,
              bold: line.bold || line.head,
              align: line.center ? ui.TextAlign.center : ui.TextAlign.left);
          add(p, _margin);
          y += p.height + _lineGap;
        case ReceiptLineKind.twoCol:
          y += twoCol(line.text, line.right, bold: line.bold) + _lineGap;
        case ReceiptLineKind.hr:
          blocks.add(_Block.dashes(y + 6, widthDots.toDouble()));
          y += 14 + _lineGap;
        case ReceiptLineKind.itemHeader:
          if (compact) {
            final item = para('Item', nameW, bold: true);
            add(item, _margin);
            var h = item.height;
            h = math.max(h, cell('Qty', qtyRight, qtyW, bold: true));
            h = math.max(h, cell('Rate', rateRight, rateW, bold: true));
            if (showTax) {
              h = math.max(h, cell('GST', gstRight, gstW, bold: true));
            }
            h = math.max(h, cell('Amount', amtRight, amtW, bold: true));
            y += h + _lineGap;
          } else {
            y += twoCol('Item', 'Amount', bold: true) + _lineGap;
          }
        case ReceiptLineKind.item:
          if (compact) {
            final name = para('${line.sl}. ${line.text}', nameW);
            add(name, _margin);
            var h = name.height;
            h = math.max(h, cell(line.qty, qtyRight, qtyW));
            h = math.max(h, cell(line.rate, rateRight, rateW));
            if (showTax) {
              h = math.max(h, cell(line.gst ?? '', gstRight, gstW));
            }
            h = math.max(h, cell(line.total, amtRight, amtW));
            y += h + _lineGap + 4;
          } else {
            // Line 1: the name, as wide as the paper, wrapping if long.
            final name = para('${line.sl}. ${line.text}', contentW);
            add(name, _margin);
            y += name.height + 2;
            // Line 2: quantity x rate (and tax) left, amount right.
            final detail = '${qtyWithUnit(line)} × ${line.rate}'
                '${line.gst == null ? '' : '   GST ${line.gst}'}';
            y += twoCol(detail, line.total, indent: fontPx * 1.2) +
                _lineGap +
                6;
          }
      }
    }

    final width = widthDots;
    final height = (y + 28).ceil(); // a little white space after the receipt

    // Draw the receipt strip by strip into one pixel buffer.
    final pixels = Uint8List(width * height * 4);
    final dash = ui.Paint()
      ..color = const ui.Color(0xFF000000)
      ..strokeWidth = 2;
    for (var top = 0; top < height; top += stripRows) {
      final h = math.min(stripRows, height - top);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(
          recorder, ui.Rect.fromLTWH(0, 0, width.toDouble(), h.toDouble()));
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), h.toDouble()),
          ui.Paint()..color = const ui.Color(0xFFFFFFFF));
      canvas.translate(0, -top.toDouble());
      for (final b in blocks) {
        if (b.paragraph != null) {
          canvas.drawParagraph(b.paragraph!, ui.Offset(b.x, b.y));
        } else {
          for (var x = _margin; x < b.width - _margin; x += 14) {
            canvas.drawLine(ui.Offset(x, b.y), ui.Offset(x + 8, b.y), dash);
          }
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, h);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      picture.dispose();
      if (data == null || data.lengthInBytes != width * h * 4) {
        throw StateError(
            'Could not draw the receipt picture (strip at row $top).');
      }
      pixels.setRange(top * width * 4, (top + h) * width * 4,
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
    return img.Image.fromBytes(
      width: width,
      height: height,
      bytes: pixels.buffer,
      numChannels: 4,
    );
  }
}

class _Block {
  _Block.paragraph(this.paragraph, this.x, this.y) : width = 0;
  _Block.dashes(this.y, this.width)
      : paragraph = null,
        x = 0;
  final ui.Paragraph? paragraph;
  final double x;
  final double y;
  final double width;
}
