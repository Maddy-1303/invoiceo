import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One-time, copy-only move of the user's data from an earlier app identity.
///
/// The data folder on Windows is named after the app (company + product name
/// in the executable). When the app was renamed to Invoiceo, that folder
/// changed, so a PC that ran the earlier test build would start empty. On the
/// first start of the new app, if its own folder has no database yet and an
/// earlier folder does, the files are COPIED over (never moved or deleted: the
/// old folder stays exactly as it was).
class LegacyDataMigration {
  LegacyDataMigration._();

  static bool _hasDatabase(Directory dir) {
    if (!dir.existsSync()) return false;
    return dir
        .listSync(followLinks: false)
        .whereType<File>()
        .any((f) => RegExp(r'^invoice_manager.*\.db$').hasMatch(p.basename(f.path)));
  }

  /// Copies the first earlier folder that holds a database into [newDir],
  /// unless [newDir] already has one. Returns true if something was copied.
  static Future<bool> run({
    required Directory newDir,
    required List<Directory> legacyDirs,
  }) async {
    try {
      if (_hasDatabase(newDir)) return false;
      for (final legacy in legacyDirs) {
        if (legacy.path == newDir.path || !_hasDatabase(legacy)) continue;
        await newDir.create(recursive: true);
        await _copy(legacy, newDir);
        return true;
      }
    } catch (e) {
      // Never stop the app from starting because of this.
      if (kDebugMode) debugPrint('Legacy data migration skipped: $e');
    }
    return false;
  }

  static Future<void> _copy(Directory from, Directory to) async {
    await for (final entity in from.list(followLinks: false)) {
      final target = p.join(to.path, p.basename(entity.path));
      if (entity is File) {
        if (!File(target).existsSync()) await entity.copy(target);
      } else if (entity is Directory) {
        final sub = Directory(target);
        await sub.create(recursive: true);
        await _copy(entity, sub);
      }
    }
  }

  /// Earlier data folders on this PC (Windows). The earlier test build kept its
  /// data under "Invoiso Tamil Test".
  static List<Directory> windowsLegacyDirs(String? appData) {
    if (appData == null || appData.isEmpty) return const [];
    return [
      Directory(p.join(appData, 'Invoiso Tamil Test', 'Invoiso Tamil Test')),
    ];
  }

  /// Called once at start-up, before the database is opened.
  static Future<void> runAtStartup() async {
    if (!Platform.isWindows) return;
    final newDir = await getApplicationSupportDirectory();
    await run(
      newDir: newDir,
      legacyDirs: windowsLegacyDirs(Platform.environment['APPDATA']),
    );
  }
}
