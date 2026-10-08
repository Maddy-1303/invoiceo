import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class FaqService {
  static const _bundledAssetPath = 'assets/data/faq.json';

  /// Returns the FAQ data as a decoded map ({version, categories, items}).
  /// The help content ships with the app (assets/data/faq.json); it is not
  /// downloaded from any website. [force] is kept for the callers that pass it.
  static Future<Map<String, dynamic>> load({bool force = false}) async {
    final bundled = await rootBundle.loadString(_bundledAssetPath);
    return jsonDecode(bundled) as Map<String, dynamic>;
  }
}
