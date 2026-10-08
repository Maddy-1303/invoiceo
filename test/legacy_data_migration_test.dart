// Renaming the app changes its data folder on Windows; the first start of the
// new app COPIES the earlier folder's data across (and never touches the old one).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:invoiceo/database/legacy_data_migration.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('invoiceo_migrate'));
  tearDown(() => root.deleteSync(recursive: true));

  Directory dir(String name) => Directory(p.join(root.path, name))..createSync(recursive: true);

  test('copies the earlier folder (databases, backups, company files) into an empty new folder', () async {
    final old = dir('old');
    File(p.join(old.path, 'invoice_manager.db')).writeAsStringSync('main db');
    File(p.join(old.path, 'invoice_manager_abc.db')).writeAsStringSync('company db');
    Directory(p.join(old.path, 'backups', 'abc')).createSync(recursive: true);
    File(p.join(old.path, 'backups', 'abc', 'x.json')).writeAsStringSync('{"a":1}');
    final fresh = Directory(p.join(root.path, 'new'));

    expect(await LegacyDataMigration.run(newDir: fresh, legacyDirs: [old]), isTrue);

    expect(File(p.join(fresh.path, 'invoice_manager.db')).readAsStringSync(), 'main db');
    expect(File(p.join(fresh.path, 'invoice_manager_abc.db')).readAsStringSync(), 'company db');
    expect(File(p.join(fresh.path, 'backups', 'abc', 'x.json')).readAsStringSync(), '{"a":1}');
    expect(File(p.join(old.path, 'invoice_manager.db')).existsSync(), isTrue, reason: 'the old folder is left as it was');
  });

  test('never overwrites a folder that already has a database', () async {
    final old = dir('old');
    File(p.join(old.path, 'invoice_manager.db')).writeAsStringSync('OLD');
    final fresh = dir('new');
    File(p.join(fresh.path, 'invoice_manager.db')).writeAsStringSync('NEW');
    expect(await LegacyDataMigration.run(newDir: fresh, legacyDirs: [old]), isFalse);
    expect(File(p.join(fresh.path, 'invoice_manager.db')).readAsStringSync(), 'NEW');
  });

  test('does nothing, safely, when there is no earlier data', () async {
    final fresh = Directory(p.join(root.path, 'new'));
    expect(await LegacyDataMigration.run(newDir: fresh, legacyDirs: [Directory(p.join(root.path, 'missing')), dir('empty')]), isFalse);
    expect(fresh.existsSync(), isFalse);
  });

  test('runs once: a second start changes nothing', () async {
    final old = dir('old');
    File(p.join(old.path, 'invoice_manager.db')).writeAsStringSync('v1');
    final fresh = Directory(p.join(root.path, 'new'));
    expect(await LegacyDataMigration.run(newDir: fresh, legacyDirs: [old]), isTrue);
    File(p.join(fresh.path, 'invoice_manager.db')).writeAsStringSync('edited in the new app');
    expect(await LegacyDataMigration.run(newDir: fresh, legacyDirs: [old]), isFalse);
    expect(File(p.join(fresh.path, 'invoice_manager.db')).readAsStringSync(), 'edited in the new app');
  });

  test('the earlier test build folder is where it looks on Windows', () {
    final dirs = LegacyDataMigration.windowsLegacyDirs(r'C:\Users\x\AppData\Roaming');
    expect(dirs.single.path.replaceAll('/', r'\').endsWith(r'Invoiso Tamil Test\Invoiso Tamil Test'), isTrue);
    expect(LegacyDataMigration.windowsLegacyDirs(null), isEmpty);
  });
}
