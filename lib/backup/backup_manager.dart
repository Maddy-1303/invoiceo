import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:invoiceo/common/app_config.dart';
import 'package:invoiceo/database/company_registry_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/utils/fs_utils.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/models/backup_info.dart';
import 'package:invoiceo/models/backup_results.dart';

class BackupManager {
  static const String _backupExtension = '.invoicedb';
  static const String _jsonExtension = '.json';

  // Tables excluded from JSON exports (contain sensitive data).
  static const Set<String> _excludedFromJsonExport = {'users'};

  // Restore order ensures parent tables are inserted before child tables,
  // preventing foreign-key constraint violations. Every table listed here
  // is cleared before a JSON restore, so drafts and product metadata from
  // the current data don't survive a "replace all" restore.
  static const List<String> _restoreTableOrder = [
    'customers',
    'products',
    'product_metadata',
    'company_info',
    'settings',
    'invoices',
    'invoice_items',
    'invoice_payments',
    'invoice_drafts',
  ];

  // Create backup of the entire database
  Future<BackupResult> createBackup({
    required String companyId,
    required String companyName,
    String? customPath,
    BackupType type = BackupType.database,
  }) async {
    try {
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupName =
          'invoice_backup_${_sanitizeForFilename(companyName)}_$timestamp';

      String backupPath;

      if (type == BackupType.database) {
        backupPath =
            await _createDatabaseBackup(backupName, customPath, companyId);
      } else {
        backupPath =
            await _createJsonBackup(backupName, customPath, companyId);
      }

      return BackupResult(
        success: true,
        message: 'Backup created successfully',
        filePath: backupPath,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Backup failed: ${e.toString()}',
      );
    }
  }

  // Create database file backup — copies the live DB file while it is open.
  // SQLite WAL mode on desktop keeps the file consistent during a copy.
  Future<String> _createDatabaseBackup(
      String backupName,
      String? customPath,
      String companyId,
      ) async {
    final dbPath = DatabaseHelper.path!;
    final backupDir = customPath != null
        ? (await ensureDirectory(customPath)).path
        : await _getBackupDirectory(companyId);
    final backupPath = join(backupDir, '$backupName$_backupExtension');

    await File(dbPath).copy(backupPath);

    return backupPath;
  }

  // Create JSON export backup (excludes sensitive tables such as 'users')
  Future<String> _createJsonBackup(
      String backupName,
      String? customPath,
      String companyId,
      ) async {
    final backupDir = customPath != null
        ? (await ensureDirectory(customPath)).path
        : await _getBackupDirectory(companyId);
    final backupPath = join(backupDir, '$backupName$_jsonExtension');

    final backupData = await _exportDataToJson(await DatabaseHelper().database);

    await File(backupPath).writeAsString(jsonEncode(backupData));

    return backupPath;
  }

  // Export database data to JSON format (sensitive tables excluded)
  Future<Map<String, dynamic>> _exportDataToJson(Database database) async {
    final backupData = <String, dynamic>{};

    final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    );

    for (final table in tables) {
      final tableName = table['name'] as String;
      if (_excludedFromJsonExport.contains(tableName)) continue;
      final tableData = await database.query(tableName);
      backupData[tableName] = tableData;
    }

    backupData['_metadata'] = {
      'created_at': DateTime.now().toIso8601String(),
      'version': '1.0',
      'app_name': AppConfig.name,
      'backup_type': 'json_export',
      'record_count': backupData.length - 1,
    };

    return backupData;
  }

  // Restore from backup
  Future<BackupResult> restoreBackup({
    required String backupPath,
  }) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        return BackupResult(
          success: false,
          message: 'Backup file not found',
        );
      }

      // Verify integrity before touching the live database
      if (!await verifyBackup(backupPath)) {
        return BackupResult(
          success: false,
          message: 'Backup file is corrupted or invalid',
        );
      }

      final extension = backupPath.split('.').last;
      final isDatabase = extension == _backupExtension.replaceAll('.', '');
      final isJson = extension == _jsonExtension.replaceAll('.', '');
      if (!isDatabase && !isJson) {
        return BackupResult(
          success: false,
          message: 'Unsupported backup format',
        );
      }

      // Back up the current data first, as a normal listed backup, so a
      // wrong restore can be undone from the backup list. Nothing is
      // replaced if this copy can't be made.
      final String preRestorePath;
      try {
        preRestorePath = await _createPreRestoreBackup();
      } catch (e) {
        return BackupResult(
          success: false,
          message: 'Could not back up the current data, so nothing was '
              'restored: ${e.toString()}',
        );
      }

      if (isDatabase) {
        // Not while the automatic backup copies the file.
        await DatabaseHelper.withFileLock(
            () => _restoreFromDatabaseBackup(backupPath, preRestorePath));
      } else {
        await _restoreFromJsonBackup(backupPath);
      }

      return BackupResult(
        success: true,
        message: 'Backup restored successfully',
        filePath: backupPath,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Restore failed: ${e.toString()}',
      );
    }
  }

  // Copies the live database into the active company's backup folder as
  // `invoice_backup_<name>_pre_restore_<timestamp>.invoicedb`. It shows in
  // the backup list like any other backup and is never deleted by a restore.
  Future<String> _createPreRestoreBackup() async {
    final companyId =
        await CompanyRegistryService.getActiveCompanyId() ?? defaultCompanyId;
    // The name only labels the file. It is read from the live company_info,
    // so a damaged database (the usual reason to restore) must not block
    // the copy — or the restore — just because the label can't be read.
    String companyName;
    try {
      companyName = await CompanyRegistryService.getActiveCompanyName();
    } catch (_) {
      companyName = '';
    }
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupName = 'invoice_backup_${_sanitizeForFilename(companyName)}'
        '_pre_restore_$timestamp';
    return _createDatabaseBackup(backupName, null, companyId);
  }

  // Restore from database backup.
  // [safetyPath] is the pre-restore copy of the current data. Replaces the
  // file and re-initializes the singleton so all subsequent DB calls get a
  // live connection. On failure the safety copy is put back. The copy is
  // kept either way, so a wrong restore can be undone later.
  Future<void> _restoreFromDatabaseBackup(
      String backupPath, String safetyPath) async {
    final dbPath = DatabaseHelper.path!;

    try {
      // Close singleton and null its reference
      await DatabaseHelper().close();

      // Replace the database file on disk
      await File(backupPath).copy(dbPath);

      // Re-initialize through the singleton — runs migrations if needed
      await DatabaseHelper().reinitialize();
    } catch (e) {
      // Restore safety copy on failure
      try {
        await DatabaseHelper().close();
        await File(safetyPath).copy(dbPath);
        await DatabaseHelper().reinitialize();
      } catch (rollbackError) {
        // Rollback failed — the safety copy is now the only good copy of the
        // user's data, so tell the user where it is.
        throw Exception(
          'Restore failed ($e) and rollback failed ($rollbackError). '
          'Your previous data is saved at: $safetyPath',
        );
      }
      rethrow;
    }
  }

  // Restore from JSON backup
  Future<void> _restoreFromJsonBackup(String backupPath) async {
    final jsonContent = await File(backupPath).readAsString();
    final backupData = jsonDecode(jsonContent) as Map<String, dynamic>;

    // Validate metadata version
    const supportedVersion = '1.0';
    final metadata = backupData['_metadata'] as Map<String, dynamic>?;
    if (metadata != null) {
      final backupVersion = metadata['version'] as String?;
      if (backupVersion != null && backupVersion != supportedVersion) {
        throw Exception(
          'Incompatible backup version: $backupVersion. '
          'This backup was created with a newer version of the app.',
        );
      }
    }

    final database = await DatabaseHelper().database;

    await database.transaction((txn) async {
      // Clear existing data in reverse FK order
      for (final tableName in _restoreTableOrder.reversed) {
        await txn.delete(tableName);
      }

      // Restore in FK-safe order (parents before children)
      for (final tableName in _restoreTableOrder) {
        if (!backupData.containsKey(tableName)) continue;
        final tableData = backupData[tableName] as List<dynamic>;
        for (final row in tableData) {
          await txn.insert(
            tableName,
            row as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Restore any tables not in the ordered list (excluding metadata keys)
      for (final entry in backupData.entries) {
        if (entry.key.startsWith('_')) continue;
        if (_restoreTableOrder.contains(entry.key)) continue;
        final tableData = entry.value as List<dynamic>;
        for (final row in tableData) {
          await txn.insert(
            entry.key,
            row as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  // Get list of a company's available backups (its own store, plus — for the
  // default company only — the pre-multi-company flat store and the legacy
  // Documents store, so users upgrading from an earlier build still see the
  // backups they made before companies existed).
  Future<List<BackupInfo>> getBackupList(String companyId) async {
    final backups = <String, BackupInfo>{};

    for (final dirPath in {
      await _getBackupDirectory(companyId),
      if (companyId == defaultCompanyId) ...[
        await _legacyFlatBackupDirectory(),
        await _legacyBackupDirectory(),
      ],
    }) {
      final directory = Directory(dirPath);
      if (!await directory.exists()) continue;

      for (final file in await directory.list().toList()) {
        if (file is! File) continue;
        final fileName = basename(file.path);
        if (!fileName.endsWith(_backupExtension) &&
            !fileName.endsWith(_jsonExtension)) {
          continue;
        }
        if (backups.containsKey(fileName)) continue;
        final stat = await file.stat();
        backups[fileName] = BackupInfo(
          fileName: fileName,
          filePath: file.path,
          size: stat.size,
          // A copied database keeps its own modified time, so the time in
          // the name is when the backup was made.
          createdAt: BackupInfo.timeFromFileName(fileName) ?? stat.modified,
          type: fileName.endsWith(_backupExtension)
              ? BackupType.database
              : BackupType.json,
        );
      }
    }

    final list = backups.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // Delete backup file
  Future<bool> deleteBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Share backup file
  Future<void> shareBackup(String backupPath) async {
    final file = File(backupPath);
    if (await file.exists()) {
      await SharePlus.instance.share(ShareParams(files: [XFile(backupPath)]));
    }
  }

  // Auto backup (scheduled)
  Future<void> performAutoBackup(
      Database database, String companyId, String companyName) async {
    final backups = await getBackupList(companyId);

    if (backups.isEmpty ||
        DateTime.now().difference(backups.first.createdAt).inDays >= 7) {
      await createBackup(companyId: companyId, companyName: companyName);
      await _cleanupOldBackups(companyId);
    }
  }

  // Filesystem-safe fragment for a backup filename — strips characters
  // invalid on Windows/Android and collapses whitespace so a business name
  // like "Acme / Sons: Ltd." doesn't break path handling on any platform.
  String _sanitizeForFilename(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? 'company' : cleaned;
  }

  // Clean up old backups
  Future<void> _cleanupOldBackups(String companyId) async {
    final backups = await getBackupList(companyId);

    if (backups.length > 5) {
      final oldBackups = backups.skip(5);
      for (final backup in oldBackups) {
        await deleteBackup(backup.filePath);
      }
    }
  }

  // Lets the user pick a backup file from an external source. Returns its
  // path, or null when nothing was picked. Does not restore anything — the
  // caller asks for confirmation first, then calls [restoreBackup].
  Future<String?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['invoicedb', 'json'],
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first.path;
  }

  // Download backup file to Downloads folder
  Future<BackupResult> downloadBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) {
        return BackupResult(success: false, message: 'Backup file not found');
      }

      final downloadsDir = await _getDownloadsDirectory();
      final fileName = basename(backupPath);
      final newPath = join(downloadsDir.path, fileName);

      await file.copy(newPath);

      return BackupResult(
        success: true,
        message: 'Backup downloaded to Downloads folder',
        filePath: newPath,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Download failed: ${e.toString()}');
    }
  }

  // Verify backup integrity
  Future<bool> verifyBackup(String backupPath) async {
    try {
      final file = File(backupPath);
      if (!await file.exists()) return false;

      final extension = backupPath.split('.').last;

      if (extension == _backupExtension.replaceAll('.', '')) {
        return await _isInvoiceoDatabase(file);
      } else if (extension == _jsonExtension.replaceAll('.', '')) {
        final content = await file.readAsString();
        jsonDecode(content);
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Must really be an Invoiceo database: an empty or foreign file would
  // otherwise replace the live data and look like a success.
  Future<bool> _isInvoiceoDatabase(File file) async {
    final head = await file
        .openRead(0, 16)
        .fold<List<int>>(<int>[], (a, b) => a..addAll(b));
    if (head.length < 16 ||
        String.fromCharCodes(head.take(15)) != 'SQLite format 3') {
      return false;
    }
    final tempDb =
        await openDatabase(file.path, readOnly: true, singleInstance: false);
    try {
      final check = await tempDb.rawQuery('PRAGMA quick_check');
      if (check.isEmpty || check.first.values.first != 'ok') return false;
      final tables = (await tempDb
              .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
          .map((r) => r['name'] as String)
          .toSet();
      const needed = ['invoices', 'customers', 'products', 'settings', 'company_info'];
      return needed.every(tables.contains);
    } finally {
      await tempDb.close();
    }
  }

  // ── Automatic backup (see lib/backup/auto_backup_service.dart) ──────────

  static const autoBackupPrefix = 'invoiceo_auto_';

  /// Short id of this computer + company, part of every automatic backup's
  /// name. Pruning matches it exactly, so it only ever deletes this
  /// computer's own automatic copies of this company, even when several
  /// companies or computers share one cloud folder.
  static String autoBackupTag(String installationId, String companyId) =>
      sha1.convert(utf8.encode('$installationId/$companyId')).toString().substring(0, 8);

  /// `<company name>-<tag>`: letters and digits of the name (any script),
  /// with no `_`, so the name can be split again.
  static String autoBackupSlug(String companyName, String tag) {
    var name = companyName
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{M}\p{N}]+', unicode: true), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final runes = name.runes.toList();
    if (runes.length > 40) {
      name = String.fromCharCodes(runes.take(40)).replaceAll(RegExp(r'-+$'), '');
    }
    return '${name.isEmpty ? 'company' : name}-$tag';
  }

  /// `invoiceo_auto_<slug>_<yyyyMMdd-HHmmss>.invoicedb` (local time, plain
  /// digits in every language).
  static String autoBackupFileName(String slug, DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${time.year.toString().padLeft(4, '0')}${two(time.month)}'
        '${two(time.day)}-${two(time.hour)}${two(time.minute)}${two(time.second)}';
    return '$autoBackupPrefix${slug}_$stamp$_backupExtension';
  }

  /// True only for an automatic backup file of [tag] (any company name, as
  /// the company may have been renamed since).
  static bool isAutoBackupFileName(String fileName, String tag) =>
      RegExp('^$autoBackupPrefix' r'[^_/\\]*-' '${RegExp.escape(tag)}'
              r'_\d{8}-\d{6}\.invoicedb$')
          .hasMatch(fileName);

  // yyyyMMdd-HHmmss of an automatic backup file name, for sorting.
  static String _autoBackupStamp(String fileName) => fileName.substring(
      fileName.length - _backupExtension.length - 15,
      fileName.length - _backupExtension.length);

  /// Copies the active company's database for the automatic backup into
  /// [folder] (null = the app's own backup folder) and returns the new
  /// file's path. A chosen folder must already exist (it is never created:
  /// a missing Google Drive / OneDrive folder must not become a plain local
  /// one). The copy is made locally first while nothing writes to the
  /// database, checked, then put in the folder under a temporary name and
  /// renamed, so a cloud folder never uploads half a file.
  /// Throws [AutoBackupException].
  Future<String> createAutomaticBackup({
    required String companyId,
    required String companySlug,
    String? folder,
    DateTime? time,
  }) async {
    final String dir;
    if (folder == null) {
      dir = await _getBackupDirectory(companyId);
    } else {
      try {
        if (!await Directory(folder).exists()) {
          throw AutoBackupException(AutoBackupErrorCode.folderMissing, folder);
        }
      } on FileSystemException catch (e) {
        throw AutoBackupException.fromFileSystem(e);
      }
      dir = folder;
    }

    final tempDir = await ensureDirectory((await getTemporaryDirectory()).path);
    final snapshot = File(join(tempDir.path,
        'invoiceo_auto_${DateTime.now().microsecondsSinceEpoch}.tmp'));
    try {
      await DatabaseHelper.withFileLock(() async {
        // The company may have been switched since the caller looked.
        final active =
            await CompanyRegistryService.getActiveCompanyId() ?? defaultCompanyId;
        if (active != companyId) {
          throw AutoBackupException(AutoBackupErrorCode.companyChanged, active);
        }
        final db = await DatabaseHelper().database;
        final dbPath = DatabaseHelper.path!;
        // Holding a transaction keeps every write out until the copy is done.
        await db.transaction((txn) async {
          await txn.rawQuery('SELECT count(*) FROM sqlite_master');
          await File(dbPath).copy(snapshot.path);
        });
      });
      if (!await _isInvoiceoDatabase(snapshot)) {
        throw AutoBackupException(AutoBackupErrorCode.invalidCopy, snapshot.path);
      }

      var at = time ?? DateTime.now();
      var target = join(dir, autoBackupFileName(companySlug, at));
      // Two backups in the same second: the next second's name.
      while (await File(target).exists() || await File('$target.tmp').exists()) {
        at = at.add(const Duration(seconds: 1));
        target = join(dir, autoBackupFileName(companySlug, at));
      }
      final partial = File('$target.tmp');
      try {
        await snapshot.copy(partial.path);
        await partial.rename(target);
      } on FileSystemException catch (e) {
        try {
          if (await partial.exists()) await partial.delete();
        } catch (_) {}
        throw AutoBackupException.fromFileSystem(e);
      }
      return target;
    } finally {
      try {
        if (await snapshot.exists()) await snapshot.delete();
      } catch (_) {}
    }
  }

  /// Deletes older automatic backups of [tag] in [folder] (null = the app's
  /// own backup folder of [companyId]), keeping the newest [keep]. Only
  /// files named exactly as [createAutomaticBackup] names them (and its own
  /// left-over `.tmp` files) are touched; nothing else in the folder is.
  /// Returns the deleted paths.
  Future<List<String>> pruneAutomaticBackups({
    required String companyId,
    required String tag,
    String? folder,
    required int keep,
  }) async {
    final dir = Directory(folder ?? await _getBackupDirectory(companyId));
    if (!await dir.exists()) return const [];
    final ours = <File>[];
    final leftovers = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = basename(entity.path);
      if (isAutoBackupFileName(name, tag)) {
        ours.add(entity);
      } else if (name.endsWith('.tmp') &&
          isAutoBackupFileName(name.substring(0, name.length - 4), tag)) {
        leftovers.add(entity);
      }
    }
    // Newest first, by the time in the name.
    ours.sort((a, b) => _autoBackupStamp(basename(b.path))
        .compareTo(_autoBackupStamp(basename(a.path))));
    final deleted = <String>[];
    for (final file in [...ours.skip(keep < 1 ? 1 : keep), ...leftovers]) {
      try {
        await file.delete();
        deleted.add(file.path);
      } catch (_) {
        // Tried again after the next backup.
      }
    }
    return deleted;
  }

  // App-managed store for a company's rolling automatic backups. Lives
  // beside the database (getApplicationSupportDirectory) — a directory the
  // app already created and can always write to — so it never fails even
  // when the user's Documents folder is missing or redirected (Windows +
  // OneDrive). Grouped under the company's id so switching companies can't
  // mix one company's backups into another's list. Users get a copy
  // elsewhere via the Download / Share actions on each backup.
  Future<String> _getBackupDirectory(String companyId) async {
    final supportDir = await getApplicationSupportDirectory();
    return (await ensureDirectory(join(supportDir.path, 'backups', companyId)))
        .path;
  }

  // Where backups landed before per-company grouping existed; kept only for
  // [getBackupList] on the default company, so upgrading users still see
  // backups they made before companies existed.
  Future<String> _legacyFlatBackupDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    return join(supportDir.path, 'backups');
  }

  // Where even older builds saved backups; kept only for [getBackupList].
  Future<String> _legacyBackupDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return join(docsDir.path, 'backups');
  }

  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) return dir;
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final path = (await getDownloadsDirectory())?.path ?? '';
      if (path.isNotEmpty) return ensureDirectory(path);
    }

    final docs = await getApplicationDocumentsDirectory();
    return ensureDirectory(docs.path);
  }
}

/// Why an automatic backup could not be made.
enum AutoBackupErrorCode {
  /// The chosen folder does not exist (moved, deleted, drive not connected).
  folderMissing,

  /// The folder exists but the app may not write there.
  folderNotWritable,

  /// macOS: the saved permission for the folder no longer works.
  accessLost,

  /// The copy was not a valid database.
  invalidCopy,

  /// The active company changed while the backup started (not an error:
  /// nothing is recorded).
  companyChanged,

  /// Anything else; the detail says what.
  failed,
}

class AutoBackupException implements Exception {
  AutoBackupException(this.code, [this.detail = '']);

  /// Sorts a file error into folder missing / not writable / other.
  factory AutoBackupException.fromFileSystem(FileSystemException e) {
    final os = e.osError?.errorCode;
    // e.g. "Cannot copy file to '<target>' (No space left on device)".
    final detail = e.osError?.message.isNotEmpty == true
        ? '${e.message} (${e.osError!.message})'
        : e.toString();
    // Windows: 2/3 not found, 5 access denied, 19 write protected.
    // Others: 2 ENOENT, 1 EPERM, 13 EACCES, 30 EROFS.
    final missing = Platform.isWindows ? const {2, 3} : const {2};
    final denied = Platform.isWindows ? const {5, 19} : const {1, 13, 30};
    final code = missing.contains(os)
        ? AutoBackupErrorCode.folderMissing
        : denied.contains(os)
            ? AutoBackupErrorCode.folderNotWritable
            : AutoBackupErrorCode.failed;
    return AutoBackupException(code, detail);
  }

  final AutoBackupErrorCode code;
  final String detail;

  @override
  String toString() => 'AutoBackupException(${code.name}): $detail';
}
