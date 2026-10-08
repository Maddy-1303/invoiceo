// The Settings control for the saved thermal printer.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/services/thermal_printer_choice.dart';
import 'package:invoiceo/widgets/saved_thermal_printer_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  var n = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    BackendServices.configure(
      settings: SqliteSettingsRepository(),
      companyInfo: SqliteCompanyInfoRepository(),
      invoices: SqliteInvoiceRepository(),
      payments: SqlitePaymentRepository(),
      installation: SqliteInstallationRepository(),
    );
    tmp = Directory.systemTemp.createTempSync('invoiceo_tile');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });
  tearDownAll(() async {
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });
  setUp(() async => DatabaseHelper().switchToFile('tile_${n++}.db'));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: SavedThermalPrinterTile()))));
    await settle(tester);
  }

  Future<String?> saved(WidgetTester tester, SettingKey k) async =>
      tester.runAsync<String?>(() => BackendServices.settings.getSetting(k));

  testWidgets('nothing saved: says so, no Forget button', (tester) async {
    await pumpTile(tester);
    expect(find.textContaining('No printer saved'), findsOneWidget);
    expect(find.text('Forget'), findsNothing);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
  });

  testWidgets('shows the saved printer and Forget clears it', (tester) async {
    await tester.runAsync(() => BackendServices.settings.setSetting(
        SettingKey.lastUsedThermalPrinter,
        const ThermalPrinterRef(name: 'POS-80').toJson()));
    await pumpTile(tester);
    expect(find.text('Saved printer: POS-80'), findsOneWidget);

    await tester.tap(find.text('Forget'));
    await tester.pump();
    await settle(tester);
    expect(await saved(tester, SettingKey.lastUsedThermalPrinter), '');
    expect(find.textContaining('No printer saved'), findsOneWidget);
    expect(find.text('Forget'), findsNothing);
  });

  testWidgets('the switch turns auto-print off and on, saved at once',
      (tester) async {
    await pumpTile(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await settle(tester);
    expect(await saved(tester, SettingKey.thermalAutoPrint), 'false');

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await settle(tester);
    expect(await saved(tester, SettingKey.thermalAutoPrint), 'true');
  });

  testWidgets('shows auto-print as off when it was turned off before',
      (tester) async {
    await tester.runAsync(() => BackendServices.settings
        .setSetting(SettingKey.thermalAutoPrint, 'false'));
    await pumpTile(tester);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
  });

  testWidgets('text size and print width default to Large and Automatic',
      (tester) async {
    await pumpTile(tester);
    expect(tester.widget<DropdownButtonFormField<String>>(find.byKey(const Key('thermalTextSize'))).initialValue, 'large');
    expect(tester.widget<DropdownButtonFormField<String>>(find.byKey(const Key('thermalPrintWidth'))).initialValue, 'auto');
  });

  testWidgets('choosing a text size and a print width saves them at once',
      (tester) async {
    await pumpTile(tester);

    await tester.tap(find.byKey(const Key('thermalTextSize')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra large').last);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(await saved(tester, SettingKey.thermalReceiptTextSize), 'xlarge');

    await tester.tap(find.byKey(const Key('thermalPrintWidth')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('512 dots').last);
    await tester.pumpAndSettle();
    await settle(tester);
    expect(await saved(tester, SettingKey.thermalPrintWidth), '512');
  });

  testWidgets('previously saved size and width are shown again', (tester) async {
    await tester.runAsync(() async {
      await BackendServices.settings.setSetting(SettingKey.thermalReceiptTextSize, 'normal');
      await BackendServices.settings.setSetting(SettingKey.thermalPrintWidth, '448');
    });
    await pumpTile(tester);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('448 dots'), findsOneWidget);
  });
}
