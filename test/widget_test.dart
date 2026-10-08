// The version shown in Software Info must match the build version in
// pubspec.yaml (CI stamps both from the release tag).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceo/common/app_config.dart';

void main() {
  test('About-screen version matches pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    final version = line.split(':')[1].trim().split('+').first;
    expect(AppConfig.version, 'v$version');
  });
}
