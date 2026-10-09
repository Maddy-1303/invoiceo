import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:invoiceo/common/app_config.dart';

/// Anonymous usage counts, described in the website's privacy policy.
///
/// Sends three kinds of event to [AppConfig.usageStatsUrl]:
///   install        the first time the app is opened
///   active         at most once a day while the app is used
///   first_invoice  once, when the first invoice is created
/// Each carries a random ID made only for this (never the installation ID
/// used for password-reset codes), the app version and the operating system.
/// No business data is ever sent.
///
/// Nothing is sent when the URL is empty, in debug and test runs, in the
/// cloud edition, or when the user turned it off on the Software Info page.
/// Everything is per computer, so it is the same for every company.
class UsageStatsService {
  static const _idKey = 'usage_stats_id';
  static const _enabledKey = 'usage_stats_enabled';
  static const _installSentKey = 'usage_stats_install_sent';
  static const _activeDayKey = 'usage_stats_active_day';
  // 'pending' until the first_invoice event has been delivered, then 'sent'.
  static const _firstInvoiceKey = 'usage_stats_first_invoice';

  /// Replaces the HTTP call in tests; returns true when delivered.
  @visibleForTesting
  static Future<bool> Function(Map<String, String> body)? sendOverride;

  static bool get _allowed =>
      sendOverride != null ||
      (kReleaseMode && !AppConfig.kIsCloud && AppConfig.usageStatsUrl.isNotEmpty);

  static Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? true;

  static Future<void> setEnabled(bool enabled) async =>
      (await SharedPreferences.getInstance()).setBool(_enabledKey, enabled);

  /// Call when the main screen opens: sends install (once), active (once a
  /// day) and a first_invoice that could not be delivered earlier.
  static Future<void> onAppOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_allowed || !(prefs.getBool(_enabledKey) ?? true)) return;
      if (prefs.getBool(_installSentKey) != true && await _send(prefs, 'install')) {
        await prefs.setBool(_installSentKey, true);
      }
      final today = _today();
      if (prefs.getString(_activeDayKey) != today && await _send(prefs, 'active')) {
        await prefs.setString(_activeDayKey, today);
      }
      await _sendFirstInvoiceIfPending(prefs);
    } catch (_) {
      // Never disturb the app over usage counts.
    }
  }

  /// Call after a new document has been saved; only the first invoice counts.
  static Future<void> onDocumentCreated(String type) async {
    if (type != 'Invoice') return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_firstInvoiceKey) != null) return;
      await prefs.setString(_firstInvoiceKey, 'pending');
      if (!_allowed || !(prefs.getBool(_enabledKey) ?? true)) return;
      await _sendFirstInvoiceIfPending(prefs);
    } catch (_) {
      // Never disturb the app over usage counts.
    }
  }

  static Future<void> _sendFirstInvoiceIfPending(SharedPreferences prefs) async {
    if (prefs.getString(_firstInvoiceKey) == 'pending' && await _send(prefs, 'first_invoice')) {
      await prefs.setString(_firstInvoiceKey, 'sent');
    }
  }

  static Future<bool> _send(SharedPreferences prefs, String event) async {
    var id = prefs.getString(_idKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_idKey, id);
    }
    final body = {
      'id': id,
      'event': event,
      'version': AppConfig.version.replaceAll(RegExp(r'^v'), ''),
      'os': _os(),
    };
    final override = sendOverride;
    if (override != null) return override(body);
    try {
      final response = await http
          .post(Uri.parse('${AppConfig.usageStatsUrl}/v1/ping'),
              headers: {'content-type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (_) {
      return false; // offline: try again next time
    }
  }

  static String _os() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'other';
  }

  static String _today() => DateTime.now().toUtc().toIso8601String().substring(0, 10);
}
