// Automatic backup (lib/backup/auto_backup_service.dart):
//
//  * when a backup is due (every day / every week);
//  * the copy: right folder, right name, a valid database that restores;
//  * pruning keeps exactly N of this company's automatic copies and never
//    touches any other file in the folder;
//  * failures (folder missing / not writable / macOS permission lost) are
//    recorded, not thrown, and the dashboards (Modern and Standard) warn;
//  * the schedule: nothing when off, first check after 20 s then every
//    30 minutes, never two backups at once;
//  * Settings > Backup > Automatic backup card, in English and Tamil: the
//    choices, the folder tile (cloud / "This computer only" badge, the tip
//    only for a local folder) and the status line.
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/backup/auto_backup_service.dart';
import 'package:invoiceo/backup/backup_manager.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/company_registry_service.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/ui_layout.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/user.dart';
import 'package:invoiceo/providers/locale_provider.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/dashboard_screen.dart';
import 'package:invoiceo/screens/settings/backup_management_screen.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/theme/app_theme.dart';

/// The folder dialog: returns [directory] (null = cancelled).
class FakeFilePicker extends FilePicker {
  String? directory;
  int directoryCalls = 0;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    directoryCalls++;
    return directory;
  }
}

/// Stands in for the macOS bookmark plugin.
class FakeFolderAccess extends AutoBackupFolderAccess {
  final remembered = <String>[];
  int opens = 0;
  int closes = 0;

  /// Thrown by [open] (a bookmark that no longer resolves).
  AutoBackupException? failOpen;

  /// [open] resolves here (the folder was renamed / moved).
  String? movedTo;

  void reset() {
    remembered.clear();
    opens = 0;
    closes = 0;
    failOpen = null;
    movedTo = null;
  }

  @override
  Future<String?> remember(String folder) async {
    remembered.add(folder);
    return 'bm:$folder';
  }

  @override
  Future<AutoBackupFolderGrant> open(String folder, String? bookmark) async {
    opens++;
    final fail = failOpen;
    if (fail != null) throw fail;
    final moved = movedTo;
    return AutoBackupFolderGrant(moved ?? folder,
        newBookmark: moved == null ? null : 'bm:$moved');
  }

  @override
  Future<void> close(AutoBackupFolderGrant grant) async => closes++;
}

/// No files: counts the backups asked for (and how many at once).
class CountingManager extends BackupManager {
  int calls = 0;
  int running = 0;
  int maxRunning = 0;
  Completer<void>? gate;

  @override
  Future<String> createAutomaticBackup({
    required String companyId,
    required String companySlug,
    String? folder,
    DateTime? time,
  }) async {
    calls++;
    running++;
    if (running > maxRunning) maxRunning = running;
    try {
      final g = gate;
      if (g != null) await g.future;
      return '/fake/${BackupManager.autoBackupFileName(companySlug, time ?? DateTime.now())}';
    } finally {
      running--;
    }
  }

  @override
  Future<List<String>> pruneAutomaticBackups({
    required String companyId,
    required String tag,
    String? folder,
    required int keep,
  }) async =>
      const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String supportDir;
  var counter = 0;
  final picker = FakeFilePicker();
  final folders = FakeFolderAccess();
  final en = lookupAppLocalizations(const Locale('en'));
  final ta = lookupAppLocalizations(const Locale('ta'));
  final admin = User(id: 'u1', username: 'admin', password: 'x', userType: 'admin');
  // invoiceo_auto_<company>-<tag>_<yyyyMMdd-HHmmss>.invoicedb
  final autoName =
      RegExp(r'^invoiceo_auto_my-company-[0-9a-f]{8}_\d{8}-\d{6}\.invoicedb$');

  setUpAll(() async {
    // Real fonts, so Tamil is measured as on a real screen.
    Future<void> loadFont(String family, List<String> paths) async {
      final loader = FontLoader(family);
      for (final path in paths) {
        final f = File(path);
        if (f.existsSync()) {
          loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
        }
      }
      await loader.load();
    }

    final material =
        '${Platform.environment['HOME']}/development/flutter/bin/cache/artifacts/material_fonts';
    await loadFont('Roboto', [
      '$material/Roboto-Regular.ttf',
      '$material/Roboto-Medium.ttf',
      '$material/Roboto-Bold.ttf'
    ]);
    await loadFont('MaterialIcons', ['$material/MaterialIcons-Regular.otf']);
    await loadFont('NotoSansTamil',
        ['assets/fonts/NotoSansTamil-Regular.ttf', 'assets/fonts/NotoSansTamil-Bold.ttf']);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackNumberSymbols();
    BackendServices.configure(
      settings: SqliteSettingsRepository(),
      companyInfo: SqliteCompanyInfoRepository(),
      invoices: SqliteInvoiceRepository(),
      payments: SqlitePaymentRepository(),
      installation: SqliteInstallationRepository(),
    );
    root = Directory.systemTemp.createTempSync('invoiceo_auto_backup');
    supportDir = root.path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => supportDir);
    FilePicker.platform = picker;
    AutoBackupFolderAccess.instance = folders;
  });
  tearDownAll(() async {
    await DatabaseHelper().close();
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });
  setUp(() {
    picker
      ..directory = null
      ..directoryCalls = 0;
    folders.reset();
    AutoBackupService.status.value = null;
  });

  /// A fresh database, app-support folder and preferences for this test.
  Future<void> freshDb(String name, {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    supportDir = p.join(root.path, '${name}_${counter++}');
    Directory(supportDir).createSync(recursive: true);
    await DatabaseHelper().switchToFile('$name.db');
  }

  Directory newFolder(String name) =>
      Directory(p.join(root.path, 'folders', '${name}_${counter++}'))
        ..createSync(recursive: true);

  List<String> names(Directory d) =>
      d.listSync().map((e) => p.basename(e.path)).toList()..sort();

  Customer customer(String id) => Customer(
      id: id, name: 'Customer $id', email: '', phone: '', address: '', gstin: '');

  Future<int> customerCount() async =>
      (await (await DatabaseHelper().database).query('customers')).length;

  /// A service with no database or file work around it (scheduler tests).
  AutoBackupService fakeService(BackupManager manager, {DateTime Function()? clock}) =>
      AutoBackupService(
        manager: manager,
        folderAccess: folders,
        clock: clock,
        companyId: () async => 'c1',
        companyName: () async => 'Shop',
        installationId: () async => 'install-1',
      );

  // ══════════════════════════════════════════════════════════════════════════
  group('when a backup is due', () {
    final now = DateTime(2026, 10, 9, 10, 0);

    test('every day', () {
      const daily = AutoBackupFrequency.daily;
      expect(isAutoBackupDue(null, daily, now), isTrue, reason: 'never backed up');
      expect(isAutoBackupDue(now.subtract(const Duration(hours: 2)), daily, now), isFalse);
      expect(isAutoBackupDue(now.subtract(const Duration(hours: 22, minutes: 59)), daily, now),
          isFalse);
      // Up to an hour early, so it does not drift later every day.
      expect(isAutoBackupDue(now.subtract(const Duration(hours: 23)), daily, now), isTrue);
      expect(isAutoBackupDue(now.subtract(const Duration(hours: 25)), daily, now), isTrue);
      expect(isAutoBackupDue(now.subtract(const Duration(days: 9)), daily, now), isTrue);
      // A clock set back: a "last backup" in the future does not stop backups.
      expect(isAutoBackupDue(now.add(const Duration(days: 2)), daily, now), isTrue);
    });

    test('every week', () {
      const weekly = AutoBackupFrequency.weekly;
      expect(isAutoBackupDue(null, weekly, now), isTrue);
      expect(isAutoBackupDue(now.subtract(const Duration(days: 1)), weekly, now), isFalse);
      expect(isAutoBackupDue(now.subtract(const Duration(days: 3)), weekly, now), isFalse);
      expect(isAutoBackupDue(now.subtract(const Duration(days: 6, hours: 22)), weekly, now),
          isFalse);
      expect(isAutoBackupDue(now.subtract(const Duration(days: 6, hours: 23)), weekly, now),
          isTrue);
      expect(isAutoBackupDue(now.subtract(const Duration(days: 8)), weekly, now), isTrue);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('file names', () {
    test('invoiceo_auto_<company>-<tag>_<yyyyMMdd-HHmmss>.invoicedb, matched exactly', () {
      final tag = BackupManager.autoBackupTag('install-1', defaultCompanyId);
      expect(tag, matches(RegExp(r'^[0-9a-f]{8}$')));
      expect(BackupManager.autoBackupTag('install-1', defaultCompanyId), tag, reason: 'stable');
      expect(BackupManager.autoBackupTag('install-2', defaultCompanyId), isNot(tag),
          reason: 'another computer');
      expect(BackupManager.autoBackupTag('install-1', 'other'), isNot(tag),
          reason: 'another company');

      expect(BackupManager.autoBackupSlug('Madhan Stores & Co.', tag), 'madhan-stores-co-$tag');
      expect(BackupManager.autoBackupSlug('மதன் ஸ்டோர்ஸ்', tag), 'மதன்-ஸ்டோர்ஸ்-$tag',
          reason: 'Tamil letters and vowel signs are kept');
      expect(BackupManager.autoBackupSlug('a_b/c\\d', tag), 'a-b-c-d-$tag');
      expect(BackupManager.autoBackupSlug('  ', tag), 'company-$tag');

      final name = BackupManager.autoBackupFileName(
          BackupManager.autoBackupSlug('My Company', tag), DateTime(2026, 10, 9, 7, 5, 3));
      expect(name, 'invoiceo_auto_my-company-${tag}_20261009-070503.invoicedb');
      expect(BackupManager.isAutoBackupFileName(name, tag), isTrue);
      // The company was renamed: still its own copy.
      expect(BackupManager.isAutoBackupFileName(
              'invoiceo_auto_madhan-stores-${tag}_20261009-070503.invoicedb', tag),
          isTrue);
      for (final other in [
        'invoiceo_auto_my-company-${BackupManager.autoBackupTag('install-2', defaultCompanyId)}'
            '_20261009-070503.invoicedb',
        '$name.tmp',
        '$name.bak',
        'copy of $name',
        'invoice_backup_My_Company_2026-10-09T07-05-03.000.invoicedb',
        'invoiceo_auto_my-company-${tag}_2026-10-09.invoicedb',
        'invoiceo_auto_my_company-${tag}_20261009-070503.invoicedb',
      ]) {
        expect(BackupManager.isAutoBackupFileName(other, tag), isFalse, reason: other);
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('the backup copy', () {
    test('lands in the chosen folder with the automatic name, is valid and restores',
        () async {
      final folder = newFolder('drive');
      await freshDb('copy', prefs: {AutoBackupSettings.folderKey: folder.path});
      await CustomerService.insertCustomer(customer('c1'));

      final r = await AutoBackupService().runNow();
      expect(r.outcome, AutoBackupOutcome.done, reason: '${r.error?.code} ${r.error?.detail}');
      expect(p.dirname(r.path!), folder.path);
      expect(names(folder), [p.basename(r.path!)], reason: 'only the backup, no .tmp left');
      expect(autoName.hasMatch(p.basename(r.path!)), isTrue, reason: r.path);
      expect(await BackupManager().verifyBackup(r.path!), isTrue);
      expect(folders.opens, 1);
      expect(folders.closes, 1, reason: 'folder access is given back');

      final record = await AutoBackupRecord.load(defaultCompanyId);
      expect(record.lastSuccess, isNotNull);
      expect(record.lastFolder, folder.path);
      expect(record.lastError, isNull);

      // A real backup: restoring it brings back the data at that time.
      await CustomerService.insertCustomer(customer('c2'));
      expect(await customerCount(), 2);
      final restored = await BackupManager().restoreBackup(backupPath: r.path!);
      expect(restored.success, isTrue, reason: restored.message);
      expect(await customerCount(), 1);
    });

    test('with no folder chosen it goes to the app\'s own backup folder (and its list)',
        () async {
      await freshDb('appfolder');
      final r = await AutoBackupService().runNow();
      expect(r.outcome, AutoBackupOutcome.done, reason: r.error?.detail);
      expect(p.dirname(r.path!), p.join(supportDir, 'backups', defaultCompanyId));
      final list = await BackupManager().getBackupList(defaultCompanyId);
      expect(list.map((b) => b.filePath), contains(r.path));
      expect((await AutoBackupRecord.load(defaultCompanyId)).lastFolder, '');
      expect(folders.opens, 0, reason: 'nothing to open for the app folder');
    });

    test('two backups in the same second get two names', () async {
      final folder = newFolder('same_second');
      await freshDb('same_second');
      final m = BackupManager();
      final slug = BackupManager.autoBackupSlug('My Company', 'abcdef12');
      final at = DateTime(2026, 10, 9, 8);
      final a = await m.createAutomaticBackup(
          companyId: defaultCompanyId, companySlug: slug, folder: folder.path, time: at);
      final b = await m.createAutomaticBackup(
          companyId: defaultCompanyId, companySlug: slug, folder: folder.path, time: at);
      expect(a, isNot(b));
      expect(names(folder), hasLength(2));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('pruning', () {
    test('keeps exactly N of this company\'s automatic copies and never touches other files',
        () async {
      final folder = newFolder('prune');
      await freshDb('prune');
      final m = BackupManager();
      final tag = BackupManager.autoBackupTag('install-1', defaultCompanyId);
      final otherComputer = BackupManager.autoBackupTag('install-2', defaultCompanyId);
      final otherCompany = BackupManager.autoBackupTag('install-1', 'other-company');

      final made = <String>[];
      for (var i = 0; i < 6; i++) {
        made.add(await m.createAutomaticBackup(
            companyId: defaultCompanyId,
            companySlug: BackupManager.autoBackupSlug('My Company', tag),
            folder: folder.path,
            time: DateTime(2026, 10, 1 + i, 9)));
      }
      // Renamed since: the newest copy has another name but the same tag.
      made.add(await m.createAutomaticBackup(
          companyId: defaultCompanyId,
          companySlug: BackupManager.autoBackupSlug('Madhan Stores', tag),
          folder: folder.path,
          time: DateTime(2026, 10, 8, 9)));

      void touch(String name) => File(p.join(folder.path, name)).writeAsStringSync('keep me');
      final decoys = [
        'invoice_backup_My_Company_2026-10-01T10-00-00.000.invoicedb',
        'invoiceo_auto_my-company-${otherComputer}_20200101-000000.invoicedb',
        'invoiceo_auto_my-company-${otherCompany}_20200101-000000.invoicedb',
        'invoiceo_auto_my-company-${tag}_20200101-000000.invoicedb.bak',
        'invoiceo_auto_my-company-${tag}_20200101-000000.invoicedb.part',
        'invoiceo_auto_my-company-${otherComputer}_20200101-000000.invoicedb.tmp',
        'copy of invoiceo_auto_my-company-${tag}_20200101-000000.invoicedb',
        'invoiceo_auto_my-company-${tag}_2020-01-01.invoicedb',
        'notes.txt',
        'Invoiceo export.json',
      ];
      decoys.forEach(touch);
      // A folder and a link named like old automatic copies.
      final dirLike = p.join(folder.path, 'invoiceo_auto_my-company-${tag}_20000101-000000.invoicedb');
      Directory(dirLike).createSync();
      final linkLike = p.join(folder.path, 'invoiceo_auto_my-company-${tag}_20000102-000000.invoicedb');
      if (!Platform.isWindows) Link(linkLike).createSync(p.join(folder.path, 'notes.txt'));
      // A half-copied file this feature left behind (its own name + .tmp).
      final leftover = 'invoiceo_auto_my-company-${tag}_20200101-000000.invoicedb.tmp';
      touch(leftover);

      final deleted = await m.pruneAutomaticBackups(
          companyId: defaultCompanyId, tag: tag, folder: folder.path, keep: 5);

      expect(deleted.map(p.basename).toSet(),
          {p.basename(made[0]), p.basename(made[1]), leftover});
      for (final f in made.take(2)) {
        expect(File(f).existsSync(), isFalse, reason: 'oldest: $f');
      }
      for (final f in made.skip(2)) {
        expect(File(f).existsSync(), isTrue, reason: 'newest five: $f');
      }
      for (final d in decoys) {
        expect(File(p.join(folder.path, d)).readAsStringSync(), 'keep me', reason: d);
      }
      expect(Directory(dirLike).existsSync(), isTrue);
      if (!Platform.isWindows) {
        expect(FileSystemEntity.typeSync(linkLike, followLinks: false),
            FileSystemEntityType.link);
      }

      // Again: nothing more goes; a bigger number deletes nothing.
      expect(await m.pruneAutomaticBackups(
          companyId: defaultCompanyId, tag: tag, folder: folder.path, keep: 5), isEmpty);
      expect(await m.pruneAutomaticBackups(
          companyId: defaultCompanyId, tag: tag, folder: folder.path, keep: 30), isEmpty);
    });

    test('backing up every day with "keep 5" leaves the newest five', () async {
      final folder = newFolder('rotate');
      await freshDb('rotate', prefs: {
        AutoBackupSettings.enabledKey: true,
        AutoBackupSettings.folderKey: folder.path,
        AutoBackupSettings.keepKey: 5,
      });
      File(p.join(folder.path, 'my notes.txt')).writeAsStringSync('mine');
      var now = DateTime(2026, 10, 1, 9);
      final s = AutoBackupService(clock: () => now);
      for (var day = 0; day < 7; day++) {
        final r = await s.runIfDue();
        expect(r.outcome, AutoBackupOutcome.done, reason: 'day $day ${r.error?.detail}');
        expect((await s.runIfDue()).outcome, AutoBackupOutcome.notDue, reason: 'once a day');
        now = now.add(const Duration(days: 1));
      }
      final backups = names(folder).where((n) => n.startsWith('invoiceo_auto_')).toList();
      expect(backups, hasLength(5));
      expect(backups.first, contains('20261003-090000'));
      expect(backups.last, contains('20261007-090000'));
      expect(File(p.join(folder.path, 'my notes.txt')).readAsStringSync(), 'mine');
    });

    test('every week: not again the next day, again a week later', () async {
      final folder = newFolder('weekly');
      await freshDb('weekly', prefs: {
        AutoBackupSettings.enabledKey: true,
        AutoBackupSettings.folderKey: folder.path,
        AutoBackupSettings.frequencyKey: 'weekly',
      });
      var now = DateTime(2026, 10, 1, 9);
      final s = AutoBackupService(clock: () => now);
      expect((await s.runIfDue()).outcome, AutoBackupOutcome.done);
      now = now.add(const Duration(days: 1));
      expect((await s.runIfDue()).outcome, AutoBackupOutcome.notDue);
      now = now.add(const Duration(days: 6));
      expect((await s.runIfDue()).outcome, AutoBackupOutcome.done);
      expect(names(folder), hasLength(2));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('failures are recorded, not thrown', () {
    test('a missing folder: error kept, folder never created, warning on; a good backup '
        'clears it', () async {
      final missing = p.join(root.path, 'gone_${counter++}', 'Invoiceo');
      await freshDb('missing', prefs: {
        AutoBackupSettings.enabledKey: true,
        AutoBackupSettings.folderKey: missing,
        AutoBackupRecord.successKey(defaultCompanyId): DateTime(2026, 10, 1).toIso8601String(),
      });
      final r = await AutoBackupService(clock: () => DateTime(2026, 10, 5, 10)).runIfDue();
      expect(r.outcome, AutoBackupOutcome.failed);
      expect(r.error!.code, AutoBackupErrorCode.folderMissing);
      expect(Directory(missing).existsSync(), isFalse,
          reason: 'a missing cloud folder is never made as a plain local one');
      final rec = await AutoBackupRecord.load(defaultCompanyId);
      expect(rec.lastError!.code, AutoBackupErrorCode.folderMissing);
      expect(rec.lastSuccess, DateTime(2026, 10, 1), reason: 'the last good backup is kept');
      expect(AutoBackupService.status.value!.showWarning, isTrue);

      // Turned off: no warning.
      await (await AutoBackupSettings.load()).copyWith(enabled: false).save();
      await AutoBackupService().refreshStatus();
      expect(AutoBackupService.status.value!.showWarning, isFalse);

      // On again with a good folder: the next backup clears the error.
      final good = newFolder('good');
      await (await AutoBackupSettings.load())
          .copyWith(enabled: true)
          .withFolder(good.path, null)
          .save();
      final ok = await AutoBackupService().runNow();
      expect(ok.outcome, AutoBackupOutcome.done, reason: ok.error?.detail);
      expect((await AutoBackupRecord.load(defaultCompanyId)).lastError, isNull);
      expect(AutoBackupService.status.value!.showWarning, isFalse);
    });

    test('a folder the app cannot write to: error recorded, nothing left behind', () async {
      final folder = newFolder('readonly');
      await freshDb('readonly', prefs: {
        AutoBackupSettings.enabledKey: true,
        AutoBackupSettings.folderKey: folder.path,
      });
      Process.runSync('chmod', ['555', folder.path]);
      addTearDown(() => Process.runSync('chmod', ['755', folder.path]));
      final r = await AutoBackupService().runNow();
      expect(r.outcome, AutoBackupOutcome.failed);
      expect(r.error!.code, AutoBackupErrorCode.folderNotWritable, reason: r.error!.detail);
      expect(folder.listSync(), isEmpty);
      expect((await AutoBackupRecord.load(defaultCompanyId)).lastError!.code,
          AutoBackupErrorCode.folderNotWritable);
      expect(AutoBackupService.status.value!.showWarning, isTrue);
    }, skip: Platform.isWindows ? 'uses chmod' : false);

    test('macOS: a bookmark that no longer resolves = "access lost"; a renamed folder is '
        'followed and saved', () async {
      final folder = newFolder('mac');
      await freshDb('mac', prefs: {
        AutoBackupSettings.folderKey: folder.path,
        AutoBackupSettings.bookmarkKey: 'bm-old',
      });
      folders.failOpen = AutoBackupException(AutoBackupErrorCode.accessLost, 'stale');
      var r = await AutoBackupService().runNow();
      expect(r.outcome, AutoBackupOutcome.failed);
      expect(r.error!.code, AutoBackupErrorCode.accessLost);
      expect(folder.listSync(), isEmpty);

      folders.failOpen = null;
      final renamed = newFolder('mac_renamed');
      folders.movedTo = renamed.path;
      r = await AutoBackupService().runNow();
      expect(r.outcome, AutoBackupOutcome.done, reason: r.error?.detail);
      expect(p.dirname(r.path!), renamed.path);
      final s = await AutoBackupSettings.load();
      expect(s.folder, renamed.path);
      expect(s.bookmark, 'bm:${renamed.path}', reason: 'the renewed bookmark is kept');
      expect((folders.opens, folders.closes), (2, 1));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('the schedule', () {
    testWidgets('off: never runs; stop() ends the timers', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final m = CountingManager();
      final s = fakeService(m);
      s.start();
      expect(s.isStarted, isTrue);
      await tester.pump(const Duration(seconds: 21));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(minutes: 30));
      }
      expect(m.calls, 0);
      s.stop();
      expect(s.isStarted, isFalse);
    });

    testWidgets('on: first check after 20 s, then every 30 minutes when due', (tester) async {
      SharedPreferences.setMockInitialValues({AutoBackupSettings.enabledKey: true});
      var now = DateTime(2026, 10, 9, 9);
      final m = CountingManager();
      final s = fakeService(m, clock: () => now);
      s.start();
      await tester.pump(const Duration(seconds: 19));
      expect(m.calls, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(m.calls, 1);
      expect(AutoBackupService.status.value?.record.lastSuccess, now);

      await tester.pump(const Duration(minutes: 30));
      expect(m.calls, 1, reason: 'not due again the same day');
      now = now.add(const Duration(hours: 23, minutes: 30));
      await tester.pump(const Duration(minutes: 30));
      expect(m.calls, 2);

      s.stop();
      now = now.add(const Duration(days: 3));
      await tester.pump(const Duration(hours: 2));
      expect(m.calls, 2, reason: 'stopped');
    });

    test('never two backups at once (one instance or two)', () async {
      SharedPreferences.setMockInitialValues({AutoBackupSettings.enabledKey: true});
      final m = CountingManager()..gate = Completer<void>();
      final a = fakeService(m);
      final b = fakeService(m);
      final first = a.runIfDue();
      final second = a.runIfDue();
      final third = b.runIfDue();
      final now = b.runNow(); // waits for the first, then runs
      expect((await second).outcome, AutoBackupOutcome.busy);
      expect((await third).outcome, AutoBackupOutcome.busy);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(m.calls, 1);
      expect(AutoBackupService.isRunning, isTrue);

      m.gate!.complete();
      expect((await first).outcome, AutoBackupOutcome.done);
      expect((await now).outcome, AutoBackupOutcome.done);
      expect(m.calls, 2);
      expect(m.maxRunning, 1);
      expect(AutoBackupService.isRunning, isFalse);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Widgets
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> settle(WidgetTester tester, {int rounds = 12}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> settleUntil(WidgetTester tester, bool Function() done, {int max = 150}) async {
    for (var i = 0; i < max && !done(); i++) {
      await settle(tester, rounds: 1);
    }
    await settle(tester, rounds: 3);
  }

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home, {Locale? locale, ProviderContainer? container}) {
    final material = MaterialApp(
      locale: locale,
      theme: AppTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FallbackLocalizationsDelegate<MaterialLocalizations>(
            GlobalMaterialLocalizations.delegate),
        FallbackLocalizationsDelegate<WidgetsLocalizations>(
            GlobalWidgetsLocalizations.delegate),
        FallbackLocalizationsDelegate<CupertinoLocalizations>(
            GlobalCupertinoLocalizations.delegate),
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
    if (container != null) {
      return UncontrolledProviderScope(container: container, child: material);
    }
    return ProviderScope(overrides: sqliteRepositoryOverrides, child: material);
  }

  Future<SharedPreferences> prefs(WidgetTester tester) async =>
      (await tester.runAsync(SharedPreferences.getInstance))!;

  bool cardShown() => find.byKey(const ValueKey('autoBackupCard')).evaluate().isNotEmpty;

  final failing = <String, Object>{
    AutoBackupSettings.enabledKey: true,
    AutoBackupSettings.folderKey: '/no/such/folder',
    AutoBackupRecord.errorKey(defaultCompanyId):
        AutoBackupError(AutoBackupErrorCode.folderMissing, '/no/such/folder',
                DateTime(2026, 10, 9, 9))
            .toJson(),
  };

  /// The logged-in dashboard in [layout] with [prefsValues].
  Future<void> openDashboard(WidgetTester tester, UiLayout layout, Map<String, Object> prefsValues,
      {Locale? locale, Size size = const Size(1400, 900)}) async {
    setSize(tester, size);
    await tester.runAsync(() async {
      await freshDb('dash_${layout.name}', prefs: prefsValues);
      await BackendServices.settings.setSetting(SettingKey.uiLayout, layout.name);
    });
    final container = ProviderContainer(overrides: sqliteRepositoryOverrides);
    addTearDown(container.dispose);
    if (locale != null) {
      container.read(localeProvider.notifier).state = locale;
      // As applyAppLocale() does once the app has started.
      await tester.pumpWidget(app(const SizedBox(), locale: locale, container: container));
      Intl.defaultLocale = locale.languageCode;
      addTearDown(() => Intl.defaultLocale = 'en');
    }
    await tester.pumpWidget(app(DashboardScreen(admin), locale: locale, container: container));
    await settle(tester);
  }

  group('dashboard warning', () {
    testWidgets('Modern and Standard warn when the last automatic backup failed; the button '
        'opens Settings > Backup', (tester) async {
      for (final layout in UiLayout.values) {
        await openDashboard(tester, layout, failing);
        final banner = find.byKey(const ValueKey('autoBackupWarningBanner'));
        expect(banner, findsOneWidget, reason: layout.name);
        expect(find.text(en.autoBackupBannerMessage(en.autoBackupReasonFolderMissing)),
            findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('autoBackupWarningOpen')));
        await settleUntil(tester, cardShown);
        expect(find.byKey(const ValueKey('autoBackupCard')), findsOneWidget, reason: layout.name);
        expect(find.text(en.autoBackupLastFailed(en.autoBackupReasonFolderMissing)),
            findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await settle(tester, rounds: 2);
        expect(AutoBackupService.status.value, isNull,
            reason: 'the schedule stops with the dashboard');
      }
    });

    testWidgets('nothing is shown when automatic backup is off or working', (tester) async {
      final off = Map<String, Object>.of(failing)..[AutoBackupSettings.enabledKey] = false;
      await openDashboard(tester, UiLayout.modern, off);
      expect(find.byKey(const ValueKey('autoBackupWarningBanner')), findsNothing);
      await tester.pumpWidget(const SizedBox());

      await openDashboard(tester, UiLayout.standard, {
        AutoBackupSettings.enabledKey: true,
        AutoBackupRecord.successKey(defaultCompanyId): DateTime.now().toIso8601String(),
      });
      expect(find.byKey(const ValueKey('autoBackupWarningBanner')), findsNothing);
      expect(AutoBackupService.status.value?.enabled, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failure while the dashboard is open shows the warning', (tester) async {
      final missing = p.join(root.path, 'gone_${counter++}');
      await openDashboard(tester, UiLayout.modern, {
        AutoBackupSettings.enabledKey: true,
        AutoBackupSettings.folderKey: missing,
      });
      expect(find.byKey(const ValueKey('autoBackupWarningBanner')), findsNothing);
      // The first check, 20 s after the dashboard opens.
      await tester.pump(const Duration(seconds: 21));
      await settleUntil(tester,
          () => find.byKey(const ValueKey('autoBackupWarningBanner')).evaluate().isNotEmpty);
      expect(find.byKey(const ValueKey('autoBackupWarningBanner')), findsOneWidget);
      final rec = (await tester.runAsync(() => AutoBackupRecord.load(defaultCompanyId)))!;
      expect(rec.lastError?.code, AutoBackupErrorCode.folderMissing);
      expect(tester.takeException(), isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  group('settings card', () {
    Future<void> openBackup(WidgetTester tester, {Locale? locale}) async {
      await tester.pumpWidget(app(const BackupManagementScreen(), locale: locale));
      await settleUntil(tester, () =>
          find.byKey(const ValueKey('autoBackupCard')).evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty);
      // The options open with a short animation when the feature is on.
      await tester.pump(const Duration(milliseconds: 400));
    }

    String statusText(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const ValueKey('autoBackupStatus'))).data!;

    testWidgets('switch, how often, copies to keep, choose folder, Back up now, Use app folder',
        (tester) async {
      setSize(tester, const Size(1300, 900));
      final folder = newFolder('card');
      await tester.runAsync(() => freshDb('card'));
      await openBackup(tester);
      expect(find.text(en.autoBackupTitle), findsOneWidget);
      expect(tester.widget<Switch>(find.byKey(const ValueKey('autoBackupSwitch'))).value, isFalse,
          reason: 'off by default');
      // Off: only the title and the switch; the options are folded away.
      expect(find.byKey(const ValueKey('autoBackupOptions')), findsNothing);
      expect(find.text(en.autoBackupAppFolder), findsNothing);

      await tester.tap(find.byKey(const ValueKey('autoBackupSwitch')));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect((await prefs(tester)).getBool(AutoBackupSettings.enabledKey), isTrue);
      // On: the options open.
      expect(find.byKey(const ValueKey('autoBackupOptions')), findsOneWidget);
      expect(find.text(en.autoBackupAppFolder), findsOneWidget);
      expect(find.byKey(const ValueKey('autoBackupUseAppFolder')), findsNothing);
      expect(statusText(tester), en.autoBackupNoneYet);

      await tester.tap(find.text(en.autoBackupEveryWeek));
      await settle(tester);
      expect((await prefs(tester)).getString(AutoBackupSettings.frequencyKey), 'weekly');

      // Copies to keep: 5 | 10 | 30 (10 at first).
      final keep = find.byKey(const ValueKey('autoBackupKeep'));
      expect(tester.widget<SegmentedButton<int>>(keep).selected, {10});
      await tester.tap(find.descendant(of: keep, matching: find.text('30')));
      await settle(tester);
      expect((await prefs(tester)).getInt(AutoBackupSettings.keepKey), 30);
      expect(tester.widget<SegmentedButton<int>>(keep).selected, {30});

      // The app's own folder stays on this computer: amber badge and the tip.
      expect(find.byKey(const ValueKey('autoBackupLocalBadge')), findsOneWidget);
      expect(find.text(en.autoBackupLocalOnlyBadge), findsOneWidget);
      expect(find.text(en.autoBackupFolderTip), findsOneWidget);

      picker.directory = folder.path;
      await tester.tap(find.byKey(const ValueKey('autoBackupChooseFolder')));
      await settle(tester);
      expect(picker.directoryCalls, 1);
      expect(folders.remembered, [folder.path], reason: 'the bookmark is made on choosing');
      expect((await prefs(tester)).getString(AutoBackupSettings.folderKey), folder.path);
      expect((await prefs(tester)).getString(AutoBackupSettings.bookmarkKey), 'bm:${folder.path}');
      // The folder's own name in bold and the full path under it.
      expect(find.text(p.basename(folder.path)), findsOneWidget);
      expect(find.text(folder.path), findsOneWidget);
      expect(find.text(en.autoBackupChangeFolderButton), findsOneWidget);
      expect(find.byKey(const ValueKey('autoBackupUseAppFolder')), findsOneWidget);
      expect(folder.listSync(), isEmpty, reason: 'choosing alone makes no backup');

      // Cancelling the dialog changes nothing.
      picker.directory = null;
      await tester.tap(find.byKey(const ValueKey('autoBackupChooseFolder')));
      await settle(tester);
      expect((await prefs(tester)).getString(AutoBackupSettings.folderKey), folder.path);

      await tester.tap(find.byKey(const ValueKey('autoBackupNow')));
      await settleUntil(tester, () => statusText(tester) != en.autoBackupNoneYet);
      final files = names(folder);
      expect(files, hasLength(1));
      expect(autoName.hasMatch(files.single), isTrue, reason: files.single);
      expect(statusText(tester), startsWith('Last backup: Today, '));
      expect((await prefs(tester)).getString(AutoBackupRecord.folderKey(defaultCompanyId)),
          folder.path);
      expect(find.text(en.backupCreatedSuccessMessage), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('autoBackupUseAppFolder')));
      await settle(tester);
      expect((await prefs(tester)).getString(AutoBackupSettings.folderKey), isNull);
      expect((await prefs(tester)).getString(AutoBackupSettings.bookmarkKey), isNull);
      expect(find.text(en.autoBackupAppFolder), findsOneWidget);
      expect(find.byKey(const ValueKey('autoBackupUseAppFolder')), findsNothing);
      // The other choices are kept.
      final s = (await tester.runAsync(AutoBackupSettings.load))!;
      expect((s.enabled, s.frequency, s.keep), (true, AutoBackupFrequency.weekly, 30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('after a failure: red line and "Choose folder"; choosing a good folder backs up '
        'straight away', (tester) async {
      setSize(tester, const Size(1300, 900));
      final missing = p.join(root.path, 'nowhere_${counter++}');
      final good = newFolder('card_good');
      await tester.runAsync(() => freshDb('card_fail', prefs: {
            AutoBackupSettings.enabledKey: true,
            AutoBackupSettings.folderKey: missing,
          }));
      await openBackup(tester);

      await tester.tap(find.byKey(const ValueKey('autoBackupNow')));
      final failed = en.autoBackupLastFailed(en.autoBackupReasonFolderMissing);
      await settleUntil(tester, () => statusText(tester) == failed);
      expect(statusText(tester), failed);
      expect(find.byKey(const ValueKey('autoBackupStatusChooseFolder')), findsOneWidget);

      picker.directory = good.path;
      await tester.tap(find.byKey(const ValueKey('autoBackupStatusChooseFolder')));
      await settleUntil(tester, () => statusText(tester) != failed);
      expect(names(good), hasLength(1));
      expect(statusText(tester), startsWith('Last backup: Today, '));
      expect((await prefs(tester)).getString(AutoBackupRecord.folderKey(defaultCompanyId)),
          good.path);
      expect(find.byKey(const ValueKey('autoBackupStatusChooseFolder')), findsNothing);
      final rec = (await tester.runAsync(() => AutoBackupRecord.load(defaultCompanyId)))!;
      expect(rec.lastError, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tamil: the dashboard warning and the card fit, with no overflow', (tester) async {
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
      try {
        // Through the warning to Settings > Backup, Modern and Standard.
        for (final layout in UiLayout.values) {
          await openDashboard(tester, layout, failing,
              locale: const Locale('ta'), size: const Size(1280, 720));
          expect(find.text(ta.autoBackupBannerMessage(ta.autoBackupReasonFolderMissing)),
              findsOneWidget, reason: layout.name);
          await tester.tap(find.byKey(const ValueKey('autoBackupWarningOpen')));
          await settleUntil(tester, cardShown);
          expect(find.text(ta.autoBackupTitle), findsOneWidget, reason: layout.name);
          expect(find.text(ta.autoBackupLastFailed(ta.autoBackupReasonFolderMissing)),
              findsOneWidget);
          expect(find.text(ta.autoBackupFolderTip), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        }

        // The card alone, wide and narrow (430: the smallest window with the
        // Modern sidebar reduced), after a good backup into a long path.
        final longFolder = p.join(root.path, 'Google Drive', 'My Drive', 'Invoiceo backups',
            'மதன் ஸ்டோர்ஸ் கடை', 'Billing');
        for (final width in const [960.0, 620.0, 430.0]) {
          setSize(tester, Size(width, 760));
          await tester.runAsync(() => freshDb('ta_card', prefs: {
                AutoBackupSettings.enabledKey: true,
                AutoBackupSettings.folderKey: longFolder,
                AutoBackupRecord.successKey(defaultCompanyId):
                    DateTime(2026, 10, 9, 9, 30).toIso8601String(),
                AutoBackupRecord.folderKey(defaultCompanyId): longFolder,
              }));
          await openBackup(tester, locale: const Locale('ta'));
          expect(find.text(ta.autoBackupNowButton), findsOneWidget);
          expect(find.text(ta.autoBackupKeepHint), findsOneWidget);
          // A Google Drive folder: its badge, and no "choose a cloud folder" tip.
          expect(find.text('Google Drive'), findsOneWidget);
          expect(find.text(ta.autoBackupFolderTip), findsNothing);
          await tester.pumpWidget(const SizedBox());
        }
      } finally {
        FlutterError.onError = old;
        Intl.defaultLocale = 'en';
      }
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  });
}
