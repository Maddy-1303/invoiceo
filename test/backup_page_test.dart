// Settings > Backup page (backup_management_screen.dart, backup_ui.dart):
//
//  * the kind of a backup, from its file name (automatic / before restore /
//    manual / JSON export);
//  * the time a backup was made, from its file name: a copied database keeps
//    its own modified time, so the list used to show a wrong date (a file
//    named ...2026-10-09T13-03-19... showed "Oct 08, 2026 18:23");
//  * which cloud service keeps the automatic backup folder (the badge, and
//    the "choose a cloud folder" tip only for a local folder);
//  * "Today, 13:03" / "Yesterday, 09:10" / "02 Oct 2026, 11:15";
//  * the saved backups list, its empty state, and no overflow in Tamil.
import 'dart:io';

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
import 'package:invoiceo/database/company_registry_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/models/backup_info.dart';
import 'package:invoiceo/providers/locale_provider.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/settings/backup_management_screen.dart';
import 'package:invoiceo/screens/settings/backup_ui.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late String supportDir;
  var counter = 0;
  final en = lookupAppLocalizations(const Locale('en'));
  final ta = lookupAppLocalizations(const Locale('ta'));

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
    root = Directory.systemTemp.createTempSync('invoiceo_backup_page');
    supportDir = root.path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => supportDir);
    AutoBackupFolderAccess.instance = const PlainFolderAccess();
  });
  tearDownAll(() async {
    await DatabaseHelper().close();
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// A fresh app-support folder (and its backups folder) and preferences.
  Future<Directory> fresh(String name, {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    supportDir = p.join(root.path, '${name}_${counter++}');
    Directory(supportDir).createSync(recursive: true);
    await DatabaseHelper().switchToFile('$name.db');
    return Directory(p.join(supportDir, 'backups', defaultCompanyId))
      ..createSync(recursive: true);
  }

  /// A backup file of [bytes] whose modified time is [modified].
  void file(Directory dir, String name, {int bytes = 2048, DateTime? modified}) {
    final f = File(p.join(dir.path, name))..writeAsBytesSync(List.filled(bytes, 1));
    if (modified != null) f.setLastModifiedSync(modified);
  }

  String iso(DateTime t) => t.toIso8601String().replaceAll(':', '-');

  // ══════════════════════════════════════════════════════════════════════════
  group('file names', () {
    test('the kind of a backup', () {
      expect(BackupInfo.kindOf('invoiceo_auto_my-shop-1a2b3c4d_20261009-130319.invoicedb'),
          BackupKind.automatic);
      expect(BackupInfo.kindOf('invoice_backup_My_Shop_pre_restore_2026-10-09T13-03-19.123.invoicedb'),
          BackupKind.preRestore);
      expect(BackupInfo.kindOf('invoice_backup_My_Shop_2026-10-09T13-03-19.123.invoicedb'),
          BackupKind.manual);
      expect(BackupInfo.kindOf('my own copy.invoicedb'), BackupKind.manual);
      expect(BackupInfo.kindOf('invoice_backup_My_Shop_2026-10-09T13-03-19.123.json'),
          BackupKind.json);
      expect(BackupInfo.kindOf('Invoiceo export.JSON'), BackupKind.json);

      expect(backupKindLabel(en, BackupKind.automatic), 'Automatic backup');
      expect(backupKindLabel(en, BackupKind.preRestore), 'Before restore');
      expect(backupKindLabel(en, BackupKind.manual), 'Manual backup');
      expect(backupKindLabel(en, BackupKind.json), 'JSON export');
      expect(backupKindLabel(ta, BackupKind.preRestore), ta.backupKindBeforeRestore);
    });

    test('the time in the name (both name patterns, pre-restore and JSON)', () {
      DateTime? t(String name) => BackupInfo.timeFromFileName(name);
      expect(t('invoice_backup_My_Shop_2026-10-09T13-03-19.123456.invoicedb'),
          DateTime(2026, 10, 9, 13, 3, 19, 123, 456));
      expect(t('invoice_backup_My_Shop_2026-10-09T13-03-19.123.invoicedb'),
          DateTime(2026, 10, 9, 13, 3, 19, 123));
      expect(t('invoice_backup_My_Shop_2026-10-09T13-03-19.invoicedb'),
          DateTime(2026, 10, 9, 13, 3, 19));
      expect(t('invoice_backup_My_Shop_pre_restore_2026-10-09T13-03-19.5.invoicedb'),
          DateTime(2026, 10, 9, 13, 3, 19, 500));
      expect(t('invoice_backup_My_Shop_2026-09-28T16-40-10.120.json'),
          DateTime(2026, 9, 28, 16, 40, 10, 120));
      expect(t('invoiceo_auto_my-shop-1a2b3c4d_20261009-070503.invoicedb'),
          DateTime(2026, 10, 9, 7, 5, 3));
      // Digits and dates in the company name do not count; only the end.
      expect(t('invoice_backup_Shop_2024-01-01T00-00-00_2026-10-09T13-03-19.000.invoicedb'),
          DateTime(2026, 10, 9, 13, 3, 19));
      expect(t('invoiceo_auto_shop-2024-1a2b3c4d_20261009-070503.invoicedb'),
          DateTime(2026, 10, 9, 7, 5, 3));
      // A UTC time is shown in local time.
      expect(t('invoice_backup_My_Shop_2026-10-09T07-33-19.000Z.invoicedb'),
          DateTime.utc(2026, 10, 9, 7, 33, 19).toLocal());

      // No time, or an impossible one: null (the file's own time is used).
      for (final name in [
        'my own copy.invoicedb',
        'Invoiceo export.json',
        'invoiceo_auto_my-shop-1a2b3c4d_20261332-250000.invoicedb',
        'invoice_backup_My_Shop_2026-02-30T10-00-00.000.invoicedb',
        'invoiceo_auto_my-shop-1a2b3c4d_20261009-070503.invoicedb.tmp',
        'invoice_backup_My_Shop_2026-10-09T13-03-19.123.txt',
      ]) {
        expect(t(name), isNull, reason: name);
      }
    });

    test('the list takes the time from the name, not the copied file\'s date; newest first',
        () async {
      final dir = await fresh('list_times');
      // Every file looks modified at the same old time, as a copied
      // database does.
      final stale = DateTime(2026, 10, 8, 18, 23);
      final manual = 'invoice_backup_Shop_${iso(DateTime(2026, 10, 9, 13, 3, 19, 123))}.invoicedb';
      final auto = BackupManager.autoBackupFileName('shop-1a2b3c4d', DateTime(2026, 10, 9, 7, 5, 3));
      final pre = 'invoice_backup_Shop_pre_restore_${iso(DateTime(2026, 10, 9, 10))}.invoicedb';
      final json = 'invoice_backup_Shop_${iso(DateTime(2026, 9, 28, 16, 40, 10, 120))}.json';
      for (final name in [manual, auto, pre, json, 'my own copy.invoicedb']) {
        file(dir, name, modified: stale);
      }

      final list = await BackupManager().getBackupList(defaultCompanyId);
      expect(list.map((b) => (b.fileName, b.createdAt)).toList(), [
        (manual, DateTime(2026, 10, 9, 13, 3, 19, 123)),
        (pre, DateTime(2026, 10, 9, 10)),
        (auto, DateTime(2026, 10, 9, 7, 5, 3)),
        ('my own copy.invoicedb', stale),
        (json, DateTime(2026, 9, 28, 16, 40, 10, 120)),
      ]);
      expect(list.map((b) => b.kind).toList(), [
        BackupKind.manual,
        BackupKind.preRestore,
        BackupKind.automatic,
        BackupKind.manual,
        BackupKind.json,
      ]);
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  test('the cloud service of a folder', () {
    final cases = <String?, BackupCloud?>{
      '/Users/a/Library/CloudStorage/GoogleDrive-a@example.com/My Drive/Invoiceo':
          BackupCloud.googleDrive,
      r'G:\My Drive\Invoiceo': BackupCloud.googleDrive,
      '/Users/a/Google Drive/Invoiceo': BackupCloud.googleDrive,
      r'C:\Users\a\OneDrive\Documents\Invoiceo': BackupCloud.oneDrive,
      r'C:\Users\a\OneDrive - Contoso\Backups': BackupCloud.oneDrive,
      '/Users/a/Library/CloudStorage/OneDrive-Personal/Invoiceo': BackupCloud.oneDrive,
      '/Users/a/Library/Mobile Documents/com~apple~CloudDocs/Invoiceo': BackupCloud.iCloud,
      '/Users/a/iCloud Drive/Invoiceo': BackupCloud.iCloud,
      r'C:\Users\a\iCloudDrive\Invoiceo': BackupCloud.iCloud,
      '/Users/a/Dropbox/Invoiceo': BackupCloud.dropbox,
      '/Users/a/Library/CloudStorage/Dropbox/Invoiceo': BackupCloud.dropbox,
      '/Users/a/Documents/Invoiceo backups': null,
      r'D:\Backups\Invoiceo': null,
      '/home/a/drive/backups': null,
      '': null,
      null: null,
    };
    cases.forEach((path, cloud) => expect(cloudServiceOf(path), cloud, reason: path));
    expect(BackupCloud.googleDrive.label, 'Google Drive');
    expect(BackupCloud.oneDrive.label, 'OneDrive');
    expect(BackupCloud.iCloud.label, 'iCloud Drive');
    expect(BackupCloud.dropbox.label, 'Dropbox');
  });

  test('"Today, 13:03" / "Yesterday, 09:10" / "02 Oct 2026, 11:15"', () {
    final now = DateTime(2026, 10, 9, 15);
    expect(backupTimeText(en, DateTime(2026, 10, 9, 13, 3), now: now), 'Today, 13:03');
    expect(backupTimeText(en, DateTime(2026, 10, 9, 0, 5), now: now), 'Today, 00:05');
    expect(backupTimeText(en, DateTime(2026, 10, 8, 9, 10), now: now), 'Yesterday, 09:10');
    expect(backupTimeText(en, DateTime(2026, 10, 2, 11, 15), now: now), '02 Oct 2026, 11:15');
    expect(backupTimeText(en, DateTime(2025, 10, 9, 13, 3), now: now), '09 Oct 2025, 13:03');
    // Across a month and a year.
    expect(backupTimeText(en, DateTime(2026, 9, 30, 23, 59), now: DateTime(2026, 10, 1, 8)),
        'Yesterday, 23:59');
    expect(backupTimeText(en, DateTime(2026, 12, 31, 22), now: DateTime(2027, 1, 1, 8)),
        'Yesterday, 22:00');
    expect(backupTimeText(ta, DateTime(2026, 10, 9, 13, 3), now: now), 'இன்று, 13:03');
    expect(backupTimeText(ta, DateTime(2026, 10, 8, 9, 10), now: now), 'நேற்று, 09:10');
  });

  // ══════════════════════════════════════════════════════════════════════════
  // The page
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> settle(WidgetTester tester, {int rounds = 12}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget home, {Locale? locale}) => ProviderScope(
        overrides: sqliteRepositoryOverrides,
        child: MaterialApp(
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
        ),
      );

  /// Until the list and the automatic backup card have loaded.
  Future<void> settleLoaded(WidgetTester tester) async {
    bool loaded() =>
        find.byKey(const ValueKey('backupSavedTitle')).evaluate().isNotEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty;
    for (var i = 0; i < 150 && !loaded(); i++) {
      await settle(tester, rounds: 1);
    }
    await settle(tester, rounds: 4);
    // The automatic backup options open with a short animation.
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openBackup(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(app(const BackupManagementScreen(), locale: locale));
    await settleLoaded(tester);
  }

  Finder row(String fileName) => find.byKey(ValueKey('backupRow_$fileName'));

  // Four backups of each kind, every file "modified" two days ago.
  Future<List<String>> seedFour(Directory dir) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 13, 3, 19);
    final yesterday = DateTime(now.year, now.month, now.day - 1, 9, 10);
    final stale = DateTime(now.year, now.month, now.day - 2, 18, 23);
    final names = [
      BackupManager.autoBackupFileName('my-shop-1a2b3c4d', today),
      'invoice_backup_My_Shop_pre_restore_${iso(yesterday)}.invoicedb',
      'invoice_backup_My_Shop_${iso(DateTime(2026, 10, 2, 11, 15, 42, 654))}.invoicedb',
      'invoice_backup_My_Shop_${iso(DateTime(2026, 9, 28, 16, 40, 10, 120))}.json',
    ];
    for (final n in names) {
      file(dir, n, bytes: n.endsWith('.json') ? 512 : 2048, modified: stale);
    }
    return names;
  }

  testWidgets('saved backups: a row per file, named by kind, with the time from its name, '
      'size, badge and file name; newest first', (tester) async {
    setSize(tester, const Size(1300, 1400));
    final dir = (await tester.runAsync(() => fresh('page_rows')))!;
    final names = (await tester.runAsync(() => seedFour(dir)))!;
    await openBackup(tester);

    expect(find.text(en.backupSavedTitle(4)), findsOneWidget);
    expect(find.text(en.backupSavedSubtitle), findsOneWidget);
    for (final n in names) {
      expect(row(n), findsOneWidget, reason: n);
      expect(find.descendant(of: row(n), matching: find.text(n)), findsOneWidget,
          reason: 'the raw file name, small');
    }
    Finder inRow(int i, String text) =>
        find.descendant(of: row(names[i]), matching: find.text(text));
    expect(inRow(0, en.autoBackupTitle), findsOneWidget);
    expect(inRow(0, '${en.backupTimeToday('13:03')}  ·  2.0 KB'), findsOneWidget);
    expect(inRow(0, en.backupFormatDatabase), findsOneWidget);
    expect(inRow(1, en.backupKindBeforeRestore), findsOneWidget);
    expect(inRow(1, '${en.backupTimeYesterday('09:10')}  ·  2.0 KB'), findsOneWidget);
    expect(inRow(2, en.backupManualTitle), findsOneWidget);
    expect(inRow(2, '02 Oct 2026, 11:15  ·  2.0 KB'), findsOneWidget);
    expect(inRow(3, en.backupKindJson), findsOneWidget);
    expect(inRow(3, '28 Sep 2026, 16:40  ·  512 B'), findsOneWidget);
    expect(inRow(3, 'JSON'), findsOneWidget);
    // Newest first, each with its ⋯ menu.
    final tops = [for (final n in names) tester.getTopLeft(row(n)).dy];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.byType(PopupMenuButton<String>), findsNWidgets(4));

    // The manual buttons, and the list's Refresh.
    expect(find.text(en.backupManualTitle), findsNWidgets(2), reason: 'section and row');
    for (final key in ['backupCreateButton', 'backupExportJsonButton', 'backupImportButton']) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
    expect(find.text(en.backupCreateDbButton), findsOneWidget);
    expect(find.text(en.backupExportJsonButton), findsOneWidget);
    expect(find.text(en.backupImportButton), findsOneWidget);
    await tester.runAsync(() async =>
        File(p.join(dir.path, names[2])).deleteSync());
    await tester.tap(find.byKey(const ValueKey('backupListRefresh')));
    await tester.pump();
    await settleLoaded(tester);
    expect(find.text(en.backupSavedTitle(3)), findsOneWidget);
    expect(row(names[2]), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no backups: "No backups yet" with a hint', (tester) async {
    setSize(tester, const Size(1300, 900));
    await tester.runAsync(() => fresh('page_empty'));
    await openBackup(tester);
    expect(find.text(en.backupSavedTitle(0)), findsOneWidget);
    expect(find.byKey(const ValueKey('backupEmptyState')), findsOneWidget);
    expect(find.text(en.backupNoBackupsFoundMessage), findsOneWidget);
    expect(find.text(en.backupEmptySubtitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the folder tile: a cloud folder shows its service and no tip; a local one '
      'shows "This computer only" and the tip', (tester) async {
    setSize(tester, const Size(1300, 1000));
    final cases = <String?, String?>{
      '/Users/a/Library/CloudStorage/GoogleDrive-a@example.com/My Drive/Invoiceo':
          'Google Drive',
      '/Users/a/OneDrive/Invoiceo': 'OneDrive',
      '/Users/a/Library/Mobile Documents/com~apple~CloudDocs/Invoiceo': 'iCloud Drive',
      '/Users/a/Dropbox/Invoiceo': 'Dropbox',
      '/Users/a/Documents/Invoiceo backups': null,
      null: null, // the app's own folder
    };
    for (final MapEntry(key: folder, value: service) in cases.entries) {
      await tester.runAsync(() => fresh('tile', prefs: {
            AutoBackupSettings.enabledKey: true,
            if (folder != null) AutoBackupSettings.folderKey: folder,
          }));
      await openBackup(tester);
      final tile = find.byKey(const ValueKey('autoBackupFolderTile'));
      expect(tile, findsOneWidget);
      if (service != null) {
        expect(find.descendant(of: tile, matching: find.text(service)), findsOneWidget,
            reason: folder);
        expect(find.byKey(const ValueKey('autoBackupLocalBadge')), findsNothing);
        expect(find.text(en.autoBackupFolderTip), findsNothing, reason: folder);
      } else {
        expect(find.byKey(const ValueKey('autoBackupCloudBadge')), findsNothing);
        expect(find.descendant(of: tile, matching: find.text(en.autoBackupLocalOnlyBadge)),
            findsOneWidget, reason: folder);
        expect(find.text(en.autoBackupFolderTip), findsOneWidget, reason: folder);
      }
      if (folder != null) {
        // The folder's last part in bold, the whole path under it.
        expect(find.text(p.basename(folder)), findsOneWidget);
        expect(find.text(folder), findsOneWidget);
        expect(find.byKey(const ValueKey('autoBackupUseAppFolder')), findsOneWidget);
      } else {
        expect(find.text(en.autoBackupAppFolder), findsOneWidget);
        expect(find.byKey(const ValueKey('autoBackupUseAppFolder')), findsNothing);
      }
      expect(find.text(en.autoBackupChangeFolderButton), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tamil, wide and narrow, with backups, a failure and a cloud folder: '
      'no overflow', (tester) async {
    final errors = <String>[];
    final old = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
    Intl.defaultLocale = 'ta';
    try {
      final failing = <String, Object>{
        AutoBackupSettings.enabledKey: true,
        AutoBackupSettings.folderKey: '/Users/a/Documents/பழைய காப்புப்பிரதிகள்',
        AutoBackupRecord.errorKey(defaultCompanyId):
            AutoBackupError(AutoBackupErrorCode.folderMissing, 'x', DateTime.now()).toJson(),
      };
      final cloud = <String, Object>{
        AutoBackupSettings.enabledKey: true,
        AutoBackupSettings.folderKey:
            '/Users/a/Library/CloudStorage/GoogleDrive-a@example.com/My Drive/மதன் ஸ்டோர்ஸ்',
        AutoBackupRecord.successKey(defaultCompanyId): DateTime.now().toIso8601String(),
      };
      for (final width in const [1300.0, 760.0, 600.0, 430.0]) {
        for (final prefs in [failing, cloud]) {
          setSize(tester, Size(width, 2400));
          final dir = (await tester.runAsync(() => fresh('ta_page', prefs: prefs)))!;
          await tester.runAsync(() => seedFour(dir));
          await openBackup(tester, locale: const Locale('ta'));
          expect(find.text(ta.backupSavedTitle(4)), findsOneWidget, reason: '$width');
          expect(find.text(ta.backupKindBeforeRestore), findsOneWidget);
          expect(find.text(ta.backupManualTitle), findsNWidgets(2));
          expect(find.text(ta.autoBackupNowButton), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
        }
      }
    } finally {
      FlutterError.onError = old;
      Intl.defaultLocale = 'en';
    }
    expect(errors, isEmpty, reason: errors.join('\n'));
  });
}
