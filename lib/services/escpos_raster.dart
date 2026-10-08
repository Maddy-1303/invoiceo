import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Encodes [image] as ESC/POS raster bit images (`GS v 0`), the image command
/// nearly every thermal receipt printer understands.
///
/// The image is sent in horizontal bands rather than as one tall command:
/// many printers have a small receive buffer and drop or garble a single very
/// tall image. A pixel prints black when it is darker than [threshold]
/// (0-255); transparent pixels count as white paper.
///
/// Rows are packed 8 pixels per byte, most significant bit first. A width
/// that is not a multiple of 8 is padded on the right with white.
List<int> escPosRasterBands(
  img.Image image, {
  int bandHeight = 128,
  int threshold = 150,
}) {
  assert(bandHeight > 0 && bandHeight <= 255);
  final width = image.width;
  final widthBytes = (width + 7) >> 3;
  final out = <int>[];

  for (var y0 = 0; y0 < image.height; y0 += bandHeight) {
    final h = math.min(bandHeight, image.height - y0);
    out.addAll([
      0x1D, 0x76, 0x30, 0x00, // GS v 0, normal density
      widthBytes & 0xFF, widthBytes >> 8, // xL xH: bytes per row
      h & 0xFF, h >> 8, // yL yH: rows in this band
    ]);
    for (var y = y0; y < y0 + h; y++) {
      for (var xb = 0; xb < widthBytes; xb++) {
        var byte = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = xb * 8 + bit;
          if (x < width && _isBlack(image.getPixel(x, y), threshold)) {
            byte |= 0x80 >> bit;
          }
        }
        out.add(byte);
      }
    }
  }
  return out;
}

bool _isBlack(img.Pixel p, int threshold) {
  // Blend onto white paper, then compare brightness with the threshold.
  final brightness = 1.0 - p.aNormalized * (1.0 - p.luminanceNormalized);
  return brightness * 255 < threshold;
}
