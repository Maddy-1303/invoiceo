import 'package:pdf/widgets.dart' as pw;
import 'shaped_text_rasterizer.dart';

/// True if [text] contains a script that needs OpenType shaping (reordering
/// vowel signs, conjuncts, ...) which the `pdf` package cannot do itself.
/// CJK is included too: we bundle no CJK font, so it is drawn by Flutter's
/// engine, which falls back to the system CJK font.
bool needsShaping(String text) {
  for (final r in text.runes) {
    if (r < 0x0900) continue;
    if ((r >= 0x0900 && r <= 0x0DFF) || // Devanagari .. Sinhala (all Indic)
        (r >= 0x0F00 && r <= 0x0FFF) || // Tibetan
        (r >= 0x1000 && r <= 0x109F) || // Myanmar
        (r >= 0x1780 && r <= 0x17FF) || // Khmer
        (r >= 0x3000 && r <= 0x9FFF) || // CJK punctuation, kana, ideographs
        (r >= 0xAC00 && r <= 0xD7AF) || // Hangul syllables
        (r >= 0xF900 && r <= 0xFAFF) || // CJK compatibility ideographs
        (r >= 0xFF00 && r <= 0xFFEF) || // Fullwidth forms
        (r >= 0x20000 && r <= 0x2FA1F)) { // CJK extension ideographs
      return true;
    }
  }
  return false;
}

/// Drop-in replacement for `pw.Text` (same constructor).
///
/// Text without complex script is drawn by `pw.Text` exactly as before.
/// Complex-script text is drawn as an image rendered by Flutter's text engine
/// (see [ShapedTextRasterizer]); until that image exists, or if it cannot be
/// made, it falls back to `pw.Text`.
class Text extends pw.StatelessWidget {
  Text(
    this.text, {
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.tightBounds = false,
    this.textScaleFactor = 1.0,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final pw.TextStyle? style;
  final pw.TextAlign? textAlign;
  final pw.TextDirection? textDirection;
  final bool? softWrap;
  final bool tightBounds;
  final double textScaleFactor;
  final int? maxLines;
  final pw.TextOverflow? overflow;

  pw.Widget _plain() => pw.Text(
        text,
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        softWrap: softWrap,
        tightBounds: tightBounds,
        textScaleFactor: textScaleFactor,
        maxLines: maxLines,
        overflow: overflow,
      );

  String get _alignKey => switch (textAlign) {
        pw.TextAlign.right || pw.TextAlign.end => 'right',
        pw.TextAlign.center => 'center',
        _ => 'left',
      };

  @override
  pw.Widget build(pw.Context context) {
    if (!needsShaping(text)) return _plain();

    return pw.LayoutBuilder(builder: (ctx, constraints) {
      final resolved = pw.Theme.of(ctx).defaultTextStyle.merge(style);
      final maxW = constraints?.maxWidth;
      final key = ShapedTextKey(
        text: text,
        fontSizePt: (resolved.fontSize ?? 12) * textScaleFactor,
        bold: resolved.fontWeight == pw.FontWeight.bold,
        italic: resolved.fontStyle == pw.FontStyle.italic,
        colorArgb: ShapedTextRasterizer.colorToArgb(resolved.color),
        maxWidthPt: (maxW == null || !maxW.isFinite) ? null : maxW.floorToDouble(),
        align: _alignKey,
        maxLines: maxLines,
      );

      final img = ShapedTextRasterizer.lookup(key);
      if (img == null) {
        ShapedTextRasterizer.request(key);
        return _plain();
      }
      final image = pw.Image(
        pw.MemoryImage(img.png),
        width: img.widthPt,
        height: img.heightPt,
        fit: pw.BoxFit.fill,
      );
      // pw.Text fills a width its parent fixes (e.g. an Expanded table
      // cell). An Image is only as wide as its picture, which would shift
      // every column after it, so fill that width and align inside it.
      if (constraints != null &&
          constraints.hasTightWidth &&
          constraints.maxWidth.isFinite) {
        return pw.SizedBox(
          width: constraints.maxWidth,
          child: pw.Align(
            alignment: switch (_alignKey) {
              'right' => pw.Alignment.topRight,
              'center' => pw.Alignment.topCenter,
              _ => pw.Alignment.topLeft,
            },
            child: image,
          ),
        );
      }
      return image;
    });
  }
}
