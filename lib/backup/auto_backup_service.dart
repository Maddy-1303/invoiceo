// Automatic backup: while the app is open, a copy of the active company's
// database is saved on its own, every day or every week, into a folder the
// user chose (ideally inside Google Drive or OneDrive, so the copy reaches
// the cloud with no server) or into the app's own backup folder.
//
//  * Choices (Settings > Backup > Automatic backup) are kept for the whole
//    computer: on/off, how often, folder, how many copies to keep, and on
//    macOS the folder's security-scoped bookmark.
//  * Per company: when the last backup worked, where it went, and the last
//    error (cleared by the next good backup).
//  * The logged-in dashboard starts [AutoBackupService]: it checks 20 s
//    after opening and then every 30 minutes, and backs up when it is due.
//  * Only files this feature made are ever deleted (see
//    BackupManager.pruneAutomaticBackups).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:invoiceo/backup/backup_manager.dart';
import 'package:invoiceo/database/company_registry_service.dart';
import 'package:invoiceo/utils/app_logger.dart';

const _tag = 'AutoBackup';

enum AutoBackupFrequency {
  daily(Duration(days: 1)),
  weekly(Duration(days: 7));

  const AutoBackupFrequency(this.interval);
  final Duration interval;
}

/// A backup may run this much before a full day / week has passed, so a
/// shop that opens at about the same time every day gets its backup then
/// (instead of drifting 30 minutes later each day and missing days).
const autoBackupEarlyAllowance = Duration(hours: 1);

/// True when the next automatic backup is due.
bool isAutoBackupDue(
    DateTime? lastSuccess, AutoBackupFrequency frequency, DateTime now) {
  if (lastSuccess == null) return true;
  // The clock was set back: a "last backup" in the future must not stop
  // backups until that day comes.
  if (lastSuccess.isAfter(now.add(const Duration(minutes: 5)))) return true;
  return now.difference(lastSuccess) >=
      frequency.interval - autoBackupEarlyAllowance;
}

/// The choices on Settings > Backup > Automatic backup. Kept for the whole
/// computer (SharedPreferences), the same for every company.
class AutoBackupSettings {
  const AutoBackupSettings({
    this.enabled = false,
    this.frequency = AutoBackupFrequency.daily,
    this.folder,
    this.bookmark,
    this.keep = defaultKeep,
  });

  static const keepChoices = [5, 10, 30];
  static const defaultKeep = 10;

  static const enabledKey = 'auto_backup_enabled';
  static const frequencyKey = 'auto_backup_frequency';
  static const folderKey = 'auto_backup_folder';
  static const bookmarkKey = 'auto_backup_bookmark';
  static const keepKey = 'auto_backup_keep';

  final bool enabled;
  final AutoBackupFrequency frequency;

  /// The chosen folder; null = the app's own backup folder.
  final String? folder;

  /// macOS: security-scoped bookmark of [folder] (base64).
  final String? bookmark;

  /// How many automatic copies of a company to keep in the folder.
  final int keep;

  static Future<AutoBackupSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final folder = prefs.getString(folderKey);
    final keep = prefs.getInt(keepKey);
    return AutoBackupSettings(
      enabled: prefs.getBool(enabledKey) ?? false,
      frequency: prefs.getString(frequencyKey) == AutoBackupFrequency.weekly.name
          ? AutoBackupFrequency.weekly
          : AutoBackupFrequency.daily,
      folder: folder == null || folder.isEmpty ? null : folder,
      bookmark: prefs.getString(bookmarkKey),
      keep: keepChoices.contains(keep) ? keep! : defaultKeep,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(enabledKey, enabled);
    await prefs.setString(frequencyKey, frequency.name);
    await prefs.setInt(keepKey, keep);
    if (folder == null) {
      await prefs.remove(folderKey);
    } else {
      await prefs.setString(folderKey, folder!);
    }
    if (bookmark == null) {
      await prefs.remove(bookmarkKey);
    } else {
      await prefs.setString(bookmarkKey, bookmark!);
    }
  }

  AutoBackupSettings copyWith(
          {bool? enabled, AutoBackupFrequency? frequency, int? keep}) =>
      AutoBackupSettings(
        enabled: enabled ?? this.enabled,
        frequency: frequency ?? this.frequency,
        folder: folder,
        bookmark: bookmark,
        keep: keep ?? this.keep,
      );

  /// Another folder (null = the app's own) and its bookmark.
  AutoBackupSettings withFolder(String? folder, String? bookmark) =>
      AutoBackupSettings(
        enabled: enabled,
        frequency: frequency,
        folder: folder,
        bookmark: folder == null ? null : bookmark,
        keep: keep,
      );
}

/// Why the last automatic backup of a company failed.
class AutoBackupError {
  const AutoBackupError(this.code, this.detail, this.at);

  final AutoBackupErrorCode code;
  final String detail;
  final DateTime at;

  String toJson() => jsonEncode(
      {'code': code.name, 'detail': detail, 'at': at.toIso8601String()});

  static AutoBackupError? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return AutoBackupError(
        AutoBackupErrorCode.values.firstWhere((c) => c.name == m['code'],
            orElse: () => AutoBackupErrorCode.failed),
        m['detail'] as String? ?? '',
        DateTime.tryParse(m['at'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return AutoBackupError(AutoBackupErrorCode.failed, raw, DateTime.now());
    }
  }
}

/// What happened last for one company (kept per company id).
class AutoBackupRecord {
  const AutoBackupRecord({this.lastSuccess, this.lastFolder, this.lastError});

  static String successKey(String companyId) =>
      'auto_backup_last_success_$companyId';
  static String folderKey(String companyId) =>
      'auto_backup_last_folder_$companyId';
  static String errorKey(String companyId) =>
      'auto_backup_last_error_$companyId';

  final DateTime? lastSuccess;

  /// Where the last good backup went; '' = the app's own backup folder.
  final String? lastFolder;

  /// Set when the last attempt failed; cleared by the next good backup.
  final AutoBackupError? lastError;

  static Future<AutoBackupRecord> load(String companyId) async {
    final prefs = await SharedPreferences.getInstance();
    return AutoBackupRecord(
      lastSuccess: DateTime.tryParse(prefs.getString(successKey(companyId)) ?? ''),
      lastFolder: prefs.getString(folderKey(companyId)),
      lastError: AutoBackupError.fromJson(prefs.getString(errorKey(companyId))),
    );
  }

  static Future<void> saveSuccess(
      String companyId, DateTime at, String? folder) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(successKey(companyId), at.toIso8601String());
    await prefs.setString(folderKey(companyId), folder ?? '');
    await prefs.remove(errorKey(companyId));
  }

  static Future<void> saveError(String companyId, AutoBackupError error) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(errorKey(companyId), error.toJson());
  }
}

/// What the dashboard banner needs for the active company.
class AutoBackupStatus {
  const AutoBackupStatus({required this.enabled, required this.record});

  final bool enabled;
  final AutoBackupRecord record;

  /// On, and the last attempt failed.
  bool get showWarning => enabled && record.lastError != null;
}

enum AutoBackupOutcome {
  /// A backup was made.
  done,

  /// It was tried and failed; the error is recorded.
  failed,

  /// Automatic backup is off.
  disabled,

  /// The last backup is recent enough.
  notDue,

  /// Another backup is running.
  busy,

  /// The company changed as it started; nothing was done or recorded.
  skipped,
}

class AutoBackupResult {
  const AutoBackupResult(this.outcome, {this.path, this.error});

  final AutoBackupOutcome outcome;

  /// The new backup file (done).
  final String? path;

  /// Why it failed (failed).
  final AutoBackupError? error;
}

/// Access to the folder chosen for automatic backups. macOS keeps access to
/// a folder outside the app's sandbox after a restart only through a
/// security-scoped bookmark; elsewhere the path is enough.
abstract class AutoBackupFolderAccess {
  const AutoBackupFolderAccess();

  /// The one in use. Tests replace it with a fake, so they never call the
  /// macOS plugin.
  static AutoBackupFolderAccess instance = Platform.isMacOS
      ? const MacBookmarkFolderAccess()
      : const PlainFolderAccess();

  /// Called right after the user picked [folder], while the picker's
  /// permission still holds. Returns the bookmark to keep, or null.
  Future<String?> remember(String folder);

  /// Opens [folder] for one backup. Throws [AutoBackupException]
  /// (accessLost) when the saved permission no longer works.
  Future<AutoBackupFolderGrant> open(String folder, String? bookmark);

  /// Gives back what [open] took.
  Future<void> close(AutoBackupFolderGrant grant);
}

class AutoBackupFolderGrant {
  const AutoBackupFolderGrant(this.path, {this.newBookmark});

  /// The folder's path now (a renamed folder resolves to its new path).
  final String path;

  /// A renewed bookmark to keep instead of the old one.
  final String? newBookmark;
}

/// Windows and Linux: the path as it is.
class PlainFolderAccess extends AutoBackupFolderAccess {
  const PlainFolderAccess();

  @override
  Future<String?> remember(String folder) async => null;

  @override
  Future<AutoBackupFolderGrant> open(String folder, String? bookmark) async =>
      AutoBackupFolderGrant(folder);

  @override
  Future<void> close(AutoBackupFolderGrant grant) async {}
}

/// macOS: a security-scoped bookmark made when the folder is chosen, and
/// resolved (with access started) before each backup, stopped after it.
class MacBookmarkFolderAccess extends AutoBackupFolderAccess {
  const MacBookmarkFolderAccess();

  static const _scopeId = 'invoiceo_auto_backup';

  @override
  Future<String?> remember(String folder) async {
    if (!Platform.isMacOS) return null;
    try {
      final mint = await SecureBookmarks().mint(Directory(folder));
      return base64Encode(mint.bookmark);
    } catch (e) {
      // Still works until the app restarts; then the user is asked to
      // choose the folder again.
      AppLogger.w(_tag, 'No bookmark for $folder: $e');
      return null;
    }
  }

  @override
  Future<AutoBackupFolderGrant> open(String folder, String? bookmark) async {
    if (!Platform.isMacOS || bookmark == null || bookmark.isEmpty) {
      return AutoBackupFolderGrant(folder);
    }
    try {
      final r = await SecureBookmarks()
          .resolve(id: _scopeId, bookmarkBytes: base64Decode(bookmark));
      final renewed = r.refreshedBookmark;
      return AutoBackupFolderGrant(r.path,
          newBookmark: renewed == null ? null : base64Encode(renewed));
    } on MissingPluginException {
      return AutoBackupFolderGrant(folder);
    } on UnresolvableBookmark catch (e) {
      // Moved, deleted, drive not connected, or the bookmark is broken.
      throw AutoBackupException(AutoBackupErrorCode.accessLost, e.toString());
    } catch (e) {
      throw AutoBackupException(AutoBackupErrorCode.accessLost, e.toString());
    }
  }

  @override
  Future<void> close(AutoBackupFolderGrant grant) async {
    if (!Platform.isMacOS) return;
    try {
      await SecureBookmarks().release(_scopeId);
    } catch (_) {}
  }
}

/// Makes the automatic backups. [start] / [stop] run the schedule (the
/// dashboard does this); [runIfDue] and [runNow] make one backup. Never two
/// at once (across every instance), never throws: failures are recorded
/// for the company and returned.
class AutoBackupService {
  AutoBackupService({
    BackupManager? manager,
    AutoBackupFolderAccess? folderAccess,
    DateTime Function()? clock,
    Future<String> Function()? companyId,
    Future<String> Function()? companyName,
    Future<String> Function()? installationId,
  })  : _manager = manager ?? BackupManager(),
        _folderAccess = folderAccess,
        _clock = clock ?? DateTime.now,
        _companyId = companyId ?? _activeCompanyId,
        _companyName = companyName ?? CompanyRegistryService.getActiveCompanyName,
        _installationId =
            installationId ?? CompanyRegistryService.getOrCreateInstallationId;

  final BackupManager _manager;
  final AutoBackupFolderAccess? _folderAccess;
  final DateTime Function() _clock;
  final Future<String> Function() _companyId;
  final Future<String> Function() _companyName;
  final Future<String> Function() _installationId;

  static Future<String> _activeCompanyId() async =>
      await CompanyRegistryService.getActiveCompanyId() ?? defaultCompanyId;

  AutoBackupFolderAccess get _folders =>
      _folderAccess ?? AutoBackupFolderAccess.instance;

  /// Access to the chosen folder (the settings card keeps a new folder's
  /// bookmark through it).
  AutoBackupFolderAccess get folderAccess => _folders;

  /// The company whose backups this works on (the active one).
  Future<String> companyId() => _companyId();

  /// The active company's automatic backup status, for the dashboard
  /// banner. Null until read (and when no dashboard runs the schedule).
  static final ValueNotifier<AutoBackupStatus?> status = ValueNotifier(null);

  // The backup being made, by any instance.
  static Future<AutoBackupResult>? _running;

  /// True while a backup is being made.
  static bool get isRunning => _running != null;

  Timer? _firstCheck;
  Timer? _repeat;

  /// True between [start] and [stop].
  bool get isStarted => _repeat != null;

  /// Checks [firstCheck] after now, then [every]; backs up when due.
  void start({
    Duration firstCheck = const Duration(seconds: 20),
    Duration every = const Duration(minutes: 30),
  }) {
    _cancelTimers();
    unawaited(refreshStatus());
    _firstCheck = Timer(firstCheck, _tick);
    _repeat = Timer.periodic(every, (_) => _tick());
  }

  /// Stops the schedule (logout, company switch, dashboard closed). A
  /// backup already being made finishes.
  void stop() {
    _cancelTimers();
    // After this frame: listeners may be in the middle of being removed.
    scheduleMicrotask(() => status.value = null);
  }

  void _cancelTimers() {
    _firstCheck?.cancel();
    _repeat?.cancel();
    _firstCheck = null;
    _repeat = null;
  }

  void _tick() {
    if (!isStarted) return;
    unawaited(runIfDue());
  }

  /// Backs up when on and due. Returns [AutoBackupOutcome.busy] when a
  /// backup is already being made.
  Future<AutoBackupResult> runIfDue() {
    if (_running != null) {
      return Future.value(const AutoBackupResult(AutoBackupOutcome.busy));
    }
    return _exclusive(() async {
      final settings = await AutoBackupSettings.load();
      if (!settings.enabled) {
        return const AutoBackupResult(AutoBackupOutcome.disabled);
      }
      final companyId = await _companyId();
      final record = await AutoBackupRecord.load(companyId);
      if (!isAutoBackupDue(record.lastSuccess, settings.frequency, _clock())) {
        return const AutoBackupResult(AutoBackupOutcome.notDue);
      }
      return _backup(settings, companyId);
    });
  }

  /// "Back up now": one automatic-style backup into the chosen folder, on
  /// or off. Waits for a backup being made to finish first.
  Future<AutoBackupResult> runNow() async {
    while (_running != null) {
      await _running;
    }
    return _exclusive(() async =>
        _backup(await AutoBackupSettings.load(), await _companyId()));
  }

  // Runs [body] as the only backup; [_running] is set before anything else
  // can look at it.
  Future<AutoBackupResult> _exclusive(Future<AutoBackupResult> Function() body) {
    final run = () async {
      try {
        return await body();
      } catch (e, s) {
        AppLogger.e(_tag, 'Automatic backup stopped', e, s);
        return AutoBackupResult(AutoBackupOutcome.failed,
            error: AutoBackupError(AutoBackupErrorCode.failed, '$e', _clock()));
      }
    }();
    _running = run;
    unawaited(run.whenComplete(() {
      if (identical(_running, run)) _running = null;
    }));
    return run;
  }

  Future<AutoBackupResult> _backup(
      AutoBackupSettings settings, String companyId) async {
    final now = _clock();
    AutoBackupFolderGrant? grant;
    try {
      String name;
      try {
        name = await _companyName();
      } catch (_) {
        name = '';
      }
      final tag = BackupManager.autoBackupTag(await _installationId(), companyId);
      var folder = settings.folder;
      if (folder != null) {
        grant = await _folders.open(folder, settings.bookmark);
        if (grant.path != folder || grant.newBookmark != null) {
          await settings
              .withFolder(grant.path, grant.newBookmark ?? settings.bookmark)
              .save();
        }
        folder = grant.path;
      }
      final path = await _manager.createAutomaticBackup(
        companyId: companyId,
        companySlug: BackupManager.autoBackupSlug(name, tag),
        folder: folder,
        time: now,
      );
      try {
        await _manager.pruneAutomaticBackups(
            companyId: companyId, tag: tag, folder: folder, keep: settings.keep);
      } catch (e) {
        // The backup itself is fine; old copies go next time.
        AppLogger.w(_tag, 'Old copies not removed: $e');
      }
      await AutoBackupRecord.saveSuccess(companyId, now, folder);
      return AutoBackupResult(AutoBackupOutcome.done, path: path);
    } on AutoBackupException catch (e) {
      if (e.code == AutoBackupErrorCode.companyChanged) {
        return const AutoBackupResult(AutoBackupOutcome.skipped);
      }
      return _failed(companyId, AutoBackupError(e.code, e.detail, now));
    } catch (e) {
      return _failed(
          companyId, AutoBackupError(AutoBackupErrorCode.failed, '$e', now));
    } finally {
      if (grant != null) {
        try {
          await _folders.close(grant);
        } catch (_) {}
      }
      await refreshStatus();
    }
  }

  Future<AutoBackupResult> _failed(String companyId, AutoBackupError error) async {
    AppLogger.w(_tag, 'Failed (${error.code.name}): ${error.detail}');
    try {
      await AutoBackupRecord.saveError(companyId, error);
    } catch (_) {}
    return AutoBackupResult(AutoBackupOutcome.failed, error: error);
  }

  /// Reads the active company's status into [status].
  Future<void> refreshStatus() async {
    try {
      final settings = await AutoBackupSettings.load();
      final record = await AutoBackupRecord.load(await _companyId());
      status.value = AutoBackupStatus(enabled: settings.enabled, record: record);
    } catch (_) {
      // No preferences (tests without them): nothing to show.
    }
  }
}
