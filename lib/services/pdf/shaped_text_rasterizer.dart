import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:invoiceo/services/pdf/pdf_font_assets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Identifies one piece of text drawn as an image. Two [Text] widgets with the
/// same key can share one rendered PNG.
class ShapedTextKey {
  final String text;
  final double fontSizePt;
  final bool bold;
  final bool italic;
  final int colorArgb;
  final double? maxWidthPt; // null = unbounded
  final String align; // 'left' | 'right' | 'center'
  final int? maxLines;

  const ShapedTextKey({
    required this.text,
    required this.fontSizePt,
    required this.bold,
    required this.italic,
    required this.colorArgb,
    required this.maxWidthPt,
    required this.align,
    required this.maxLines,
  });

  @override
  bool operator ==(Object other) =>
      other is ShapedTextKey &&
      other.text == text &&
      other.fontSizePt == fontSizePt &&
      other.bold == bold &&
      other.italic == italic &&
      other.colorArgb == colorArgb &&
      other.maxWidthPt == maxWidthPt &&
      other.align == align &&
      other.maxLines == maxLines;

  @override
  int get hashCode => Object.hash(text, fontSizePt, bold, italic, colorArgb,
      maxWidthPt, align, maxLines);
}

class ShapedTextImage {
  final Uint8List png;
  final double widthPt;
  final double heightPt;
  const ShapedTextImage(this.png, this.widthPt, this.heightPt);
}

/// Draws complex-script text (Tamil, Malayalam, Telugu, Devanagari, ...) to a
/// PNG using Flutter's own text engine, which performs real OpenType shaping.
///
/// Why: the `pdf` package maps characters straight to glyphs and has no
/// GSUB/GPOS shaping, so vowel signs and conjuncts of Indic scripts are drawn
/// in the wrong place. The Flutter UI shapes them correctly, so we let it draw
/// the text and place the result in the PDF as an image.
///
/// Rendering is async but PDF layout is sync, so documents are built in
/// passes: pass 1 lays the document out and records which strings need an
/// image; those are rendered; pass 2 rebuilds with the images available.
class ShapedTextRasterizer {
  ShapedTextRasterizer._();

  /// Image pixels per PDF point. 4 => 288 dpi, sharp enough for print.
  static const double _scale = 4.0;
  static const int _maxCacheEntries = 400;

  static final Map<ShapedTextKey, ShapedTextImage> _cache = {};
  static final Set<ShapedTextKey> _pending = {};
  static bool _fontsReady = false;

  // ---- font registration -------------------------------------------------

  // family name -> asset. Registered with dart:ui under private names so they
  // never collide with the app's own font families.
  static const _regular = <String, String>{
    'inv_primary': PdfFontAssets.regular,
    'inv_sinhala': PdfFontAssets.sinhalaFallback,
    'inv_bengali': PdfFontAssets.bengaliFallback,
    'inv_devanagari': PdfFontAssets.devanagariFallback,
    'inv_malayalam': PdfFontAssets.malayalamFallback,
    'inv_tamil': PdfFontAssets.tamilFallback,
    'inv_kannada': PdfFontAssets.kannadaFallback,
    'inv_telugu': PdfFontAssets.teluguFallback,
    'inv_arabic': PdfFontAssets.arabicFallback,
    'inv_thai': PdfFontAssets.thaiFallback,
    'inv_khmer': PdfFontAssets.khmerFallback,
    'inv_myanmar': PdfFontAssets.myanmarFallback,
    'inv_tibetan': PdfFontAssets.tibetanFallback,
  };
  static const _bold = <String, String>{
    'inv_primary_b': PdfFontAssets.bold,
    'inv_bengali_b': PdfFontAssets.bengaliFallbackBold,
    'inv_devanagari_b': PdfFontAssets.devanagariFallbackBold,
    'inv_malayalam_b': PdfFontAssets.malayalamFallbackBold,
    'inv_tamil_b': PdfFontAssets.tamilFallbackBold,
    'inv_kannada_b': PdfFontAssets.kannadaFallbackBold,
    'inv_telugu_b': PdfFontAssets.teluguFallbackBold,
    'inv_arabic_b': PdfFontAssets.arabicFallbackBold,
    'inv_thai_b': PdfFontAssets.thaiFallbackBold,
    'inv_khmer_b': PdfFontAssets.khmerFallbackBold,
    'inv_myanmar_b': PdfFontAssets.myanmarFallbackBold,
    'inv_tibetan_b': PdfFontAssets.tibetanFallbackBold,
  };

  static Future<void> _ensureFonts() async {
    if (_fontsReady) return;
    // Sequential on purpose: flutter_test's asset bundle misbehaves under
    // concurrent loads (see test/test_pdf_font_service.dart).
    for (final entry in {..._regular, ..._bold}.entries) {
      final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
    _fontsReady = true;
  }

  // ---- recording (called while a document is being laid out) ------------

  static ShapedTextImage? lookup(ShapedTextKey key) => _cache[key];

  static void request(ShapedTextKey key) {
    if (!_cache.containsKey(key)) _pending.add(key);
  }

  // ---- building documents ------------------------------------------------

  /// Builds a document with correctly shaped complex-script text.
  ///
  /// [build] must create a fresh [pw.Document] each call.
  ///
  /// Text widgets ask for their image while the document is laid out, but
  /// `pw.MultiPage` lays out inside `addPage` whereas a plain `pw.Page` (the
  /// thermal template) only lays out in `save()`. So each pass calls `save()`
  /// to make sure every page has been laid out, then checks what was recorded.
  /// The returned document is always a fresh, unsaved one: saving the same
  /// `pw.Document` twice does not give identical output. A document with no
  /// complex-script text records nothing and costs one extra build and save.
  static Future<pw.Document> buildWithShaping(
      pw.Document Function() build) async {
    _pending.clear();
    var doc = build();
    // A few passes: a rebuild can expose new constraints (and so new keys)
    // when column widths depend on the images' own size.
    for (var pass = 0; pass < 3; pass++) {
      await doc.save();
      if (_pending.isEmpty) return build();
      await _renderPending(); // also clears _pending
      doc = build();
    }
    _pending.clear();
    return doc;
  }

  static Future<void> _renderPending() async {
    await _ensureFonts();
    if (_cache.length > _maxCacheEntries) _cache.clear();
    for (final key in _pending.toList()) {
      final image = await _render(key);
      if (image != null) _cache[key] = image;
    }
    _pending.clear();
  }

  // ---- rendering ---------------------------------------------------------

  static const _scriptFamilies = [
    'inv_tamil',
    'inv_malayalam',
    'inv_telugu',
    'inv_kannada',
    'inv_devanagari',
    'inv_bengali',
    'inv_sinhala',
    'inv_arabic',
    'inv_thai',
    'inv_khmer',
    'inv_myanmar',
    'inv_tibetan',
  ];

  /// Registers the bundled fonts with Flutter's text engine (once).
  static Future<void> prepareFonts() => _ensureFonts();

  /// A text style that uses the bundled fonts: Latin from DejaVu, every other
  /// script from its own Noto font, so the engine shapes it correctly.
  /// Call [prepareFonts] first.
  static ui.TextStyle uiTextStyle({
    required double fontPx,
    bool bold = false,
    int argb = 0xFF000000,
  }) =>
      ui.TextStyle(
        color: ui.Color(argb),
        fontSize: fontPx,
        fontFamily: bold ? 'inv_primary_b' : 'inv_primary',
        fontFamilyFallback: [
          for (final f in _scriptFamilies)
            if (bold && _bold.containsKey('${f}_b')) '${f}_b' else f,
        ],
      );

  static Future<ShapedTextImage?> _render(ShapedTextKey key) async {
    try {
      final family = key.bold ? 'inv_primary_b' : 'inv_primary';
      // Bold file for a script if we ship one, else its regular file.
      final fallback = [
        for (final f in _scriptFamilies)
          if (key.bold && _bold.containsKey('${f}_b')) '${f}_b' else f,
      ];

      final align = switch (key.align) {
        'right' => ui.TextAlign.right,
        'center' => ui.TextAlign.center,
        _ => ui.TextAlign.left,
      };
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: align,
        textDirection: ui.TextDirection.ltr,
        maxLines: key.maxLines,
      ))
        ..pushStyle(ui.TextStyle(
          color: ui.Color(key.colorArgb),
          fontSize: key.fontSizePt * _scale,
          fontFamily: family,
          fontFamilyFallback: fallback,
          fontStyle: key.italic ? ui.FontStyle.italic : ui.FontStyle.normal,
        ))
        ..addText(key.text);
      final paragraph = builder.build();
      final layoutWidth = key.maxWidthPt == null
          ? 100000.0
          : (key.maxWidthPt! * _scale).floorToDouble();
      paragraph.layout(ui.ParagraphConstraints(width: layoutWidth));

      // Left-aligned text only needs its own width. Right/centre text needs
      // the whole available width so the paragraph can align itself.
      final fillWidth = key.maxWidthPt != null && key.align != 'left';
      final pxW = (fillWidth ? layoutWidth : paragraph.longestLine).ceil() + 2;
      final pxH = paragraph.height.ceil() + 2;
      if (pxW <= 2 || pxH <= 2) return null;

      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawParagraph(paragraph, ui.Offset.zero);
      final picture = recorder.endRecording();
      final img = await picture.toImage(pxW, pxH);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      picture.dispose();
      if (data == null) return null;
      return ShapedTextImage(
        data.buffer.asUint8List(),
        pxW / _scale,
        pxH / _scale,
      );
    } catch (_) {
      // Never break invoice generation over a rendering problem: the caller
      // falls back to the plain pdf text path when there is no image.
      return null;
    }
  }

  static int colorToArgb(PdfColor? color) {
    final c = color ?? PdfColors.black;
    int ch(double v) => (v * 255).round().clamp(0, 255);
    return (ch(c.alpha) << 24) | (ch(c.red) << 16) | (ch(c.green) << 8) | ch(c.blue);
  }
}
