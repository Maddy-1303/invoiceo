// Thermal printing: choose a printer once, then print straight to it.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:thermal_printer/discovery.dart' show PrinterDiscovered;
import 'package:thermal_printer/thermal_printer.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/services/thermal_printer_choice.dart';
import 'package:invoiceo/services/thermal_printer_service_v1.dart';

PrinterDiscovered<UsbPrinterInfo> winPrinter(String name) =>
    PrinterDiscovered<UsbPrinterInfo>(
        name: name,
        detail: UsbPrinterInfo.Windows(name: name, model: '', isDefault: false));

PrinterDiscovered<UsbPrinterInfo> androidPrinter(
        String name, String vendor, String product) =>
    PrinterDiscovered<UsbPrinterInfo>(
        name: name,
        detail: UsbPrinterInfo.Android(
            vendorId: vendor, productId: product, manufacturer: 'm',
            product: name, name: name, deviceId: 'd'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThermalPrinterRef / chooseThermalPrinter', () {
    const pos = ThermalPrinterRef(name: 'POS-80');
    const laser = ThermalPrinterRef(name: 'Office Laser');

    test('prints without asking only to a remembered printer that is connected',
        () {
      final c = chooseThermalPrinter(
          found: [laser, pos], lastUsed: pos, autoPrint: true);
      expect(c.isAutomatic, isTrue);
      expect(c.printer!.name, 'POS-80');
    });

    test('asks when nothing was remembered, even with a single printer', () {
      expect(
          chooseThermalPrinter(found: [pos], lastUsed: null, autoPrint: true)
              .isAutomatic,
          isFalse);
    });

    test('asks when the remembered printer is not connected', () {
      expect(
          chooseThermalPrinter(found: [laser], lastUsed: pos, autoPrint: true)
              .isAutomatic,
          isFalse);
    });

    test('asks when the user turned auto-print off', () {
      expect(
          chooseThermalPrinter(found: [pos], lastUsed: pos, autoPrint: false)
              .isAutomatic,
          isFalse);
    });

    test('matches by vendor/product id when both have them, else by name', () {
      const a = ThermalPrinterRef(name: 'USB Printer', vendorId: '04b8', productId: '0e15');
      const renamed = ThermalPrinterRef(name: 'Epson TM', vendorId: '04b8', productId: '0e15');
      const other = ThermalPrinterRef(name: 'USB Printer', vendorId: '0483', productId: '5740');
      expect(a.matches(renamed), isTrue, reason: 'same device, new name');
      expect(a.matches(other), isFalse, reason: 'same name, different device');
      expect(const ThermalPrinterRef(name: 'X').matches(const ThermalPrinterRef(name: 'X')), isTrue);
      expect(const ThermalPrinterRef(name: '').matches(const ThermalPrinterRef(name: '')), isFalse);
    });

    test('saved value round-trips and bad data means "ask", never a crash', () {
      const r = ThermalPrinterRef(name: 'POS-80', vendorId: '1', productId: '2');
      final back = ThermalPrinterRef.tryParse(r.toJson())!;
      expect([back.name, back.vendorId, back.productId], ['POS-80', '1', '2']);
      for (final bad in [null, '', '   ', 'not json', '[]', '{"name":""}', '{"name":5}', '{"vendorId":"1"}']) {
        expect(ThermalPrinterRef.tryParse(bad), isNull, reason: 'input: $bad');
      }
    });
  });

  group('sendReceipt: a printer that refuses the receipt is a FAILURE', () {
    test('success connects, sends and disconnects', () async {
      final log = <String>[];
      await ThermalPrinterService.sendReceipt(
        connect: () async { log.add('connect'); return true; },
        send: () async { log.add('send'); return true; },
        disconnect: () async { log.add('disconnect'); return true; },
      );
      expect(log, ['connect', 'send', 'disconnect']);
    });

    test('connect returning false throws and never sends', () async {
      final log = <String>[];
      await expectLater(
        ThermalPrinterService.sendReceipt(
          connect: () async { log.add('connect'); return false; },
          send: () async { log.add('send'); return true; },
          disconnect: () async { log.add('disconnect'); return true; },
        ),
        throwsA(isA<StateError>()),
      );
      expect(log, ['connect']);
    });

    test('send returning false throws, and still disconnects', () async {
      final log = <String>[];
      await expectLater(
        ThermalPrinterService.sendReceipt(
          connect: () async { log.add('connect'); return true; },
          send: () async { log.add('send'); return false; },
          disconnect: () async { log.add('disconnect'); return true; },
        ),
        throwsA(isA<StateError>()),
      );
      expect(log, ['connect', 'send', 'disconnect']);
    });

    test('a disconnect error never hides the real result', () async {
      await ThermalPrinterService.sendReceipt(
        connect: () async => true,
        send: () async => true,
        disconnect: () async => throw StateError('usb gone'),
      ); // printed fine: must not throw
      await expectLater(
        ThermalPrinterService.sendReceipt(
          connect: () async => true,
          send: () async => false,
          disconnect: () async => throw StateError('usb gone'),
        ),
        throwsA(predicate((e) => e.toString().contains('did not accept'))),
      );
    });
  });

  group('print flow', () {
    late Directory tmp;
    final origDiscover = ThermalPrinterService.discoverUsbPrinters;
    final origSend = ThermalPrinterService.sendToDevice;
    var dbCounter = 0;
    late List<String> sent; // names the receipt was sent to
    var failSend = false;
    var found = <PrinterDiscovered<UsbPrinterInfo>>[];

    final invoice = Invoice(
      id: '1', invoiceNumber: '1',
      customer: Customer(id: 'c', name: 'x', email: '', phone: '', address: '', gstin: ''),
      items: const [], date: DateTime(2026, 10, 5), type: 'Invoice',
      taxRate: 0, taxMode: TaxMode.none,
    );

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
      tmp = Directory.systemTemp.createTempSync('invoiceo_thermal_auto');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => tmp.path);
    });
    tearDownAll(() async {
      ThermalPrinterService.discoverUsbPrinters = origDiscover;
      ThermalPrinterService.sendToDevice = origSend;
      await DatabaseHelper().close();
      tmp.deleteSync(recursive: true);
    });

    setUp(() async {
      ThermalPrinterService.resetPrintGuard();
      sent = [];
      failSend = false;
      found = [];
      await DatabaseHelper().switchToFile('thermal_auto_${dbCounter++}.db');
      ThermalPrinterService.discoverUsbPrinters = () async => found;
      ThermalPrinterService.sendToDevice = ({required type, required model, required invoice}) async {
        sent.add((model as UsbPrinterInput).name ?? '?');
        if (failSend) throw StateError('printer offline');
      };
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> pressPrint(WidgetTester tester) async {
      await tester.tap(find.text('PRINT'));
      await tester.pump();
      await settle(tester);
    }

    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ThermalPrinterService.printInvoice(context, invoice),
              child: const Text('PRINT'),
            ),
          ),
        ),
      ));
    }

    Future<String?> saved(WidgetTester tester, SettingKey key) async =>
        (await tester.runAsync<String?>(() => BackendServices.settings.getSetting(key)));

    testWidgets('first print asks, remembers the choice, next print is automatic',
        (tester) async {
      found = [winPrinter('Microsoft Print to PDF'), winPrinter('POS-80')];
      await pumpApp(tester);

      await pressPrint(tester);
      expect(find.text('Print Receipt'), findsOneWidget, reason: 'first time: ask');
      expect(sent, isEmpty);
      await tester.tap(find.text('POS-80'));
      await tester.pump();
      await settle(tester);
      expect(sent, ['POS-80']);
      expect(find.text('Print Receipt'), findsNothing);
      expect(ThermalPrinterRef.tryParse(await saved(tester, SettingKey.lastUsedThermalPrinter))!.name, 'POS-80');
      expect(await saved(tester, SettingKey.thermalAutoPrint), 'true');

      // Second print: no dialog at all.
      await pressPrint(tester);
      expect(find.text('Print Receipt'), findsNothing, reason: 'must not ask again');
      expect(sent, ['POS-80', 'POS-80']);
      expect(find.text('Printed to POS-80'), findsOneWidget);
    });

    testWidgets('unticking the box means it keeps asking', (tester) async {
      found = [winPrinter('POS-80')];
      await pumpApp(tester);
      await pressPrint(tester);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('POS-80'));
      await tester.pump();
      await settle(tester);
      expect(sent, ['POS-80']);
      expect(await saved(tester, SettingKey.thermalAutoPrint), 'false');
      expect(await saved(tester, SettingKey.lastUsedThermalPrinter), '');

      await pressPrint(tester);
      expect(find.text('Print Receipt'), findsOneWidget, reason: 'asks every time');
    });

    testWidgets('a different printer connected than the remembered one: asks',
        (tester) async {
      await tester.runAsync(() => BackendServices.settings.setSetting(
          SettingKey.lastUsedThermalPrinter,
          const ThermalPrinterRef(name: 'POS-80').toJson()));
      found = [winPrinter('Office Laser')];
      await pumpApp(tester);
      await pressPrint(tester);
      expect(find.text('Print Receipt'), findsOneWidget);
      expect(sent, isEmpty);
    });

    testWidgets('auto-print that fails shows the error and the chooser',
        (tester) async {
      await tester.runAsync(() => BackendServices.settings.setSetting(
          SettingKey.lastUsedThermalPrinter,
          const ThermalPrinterRef(name: 'POS-80').toJson()));
      found = [winPrinter('POS-80'), winPrinter('Backup Printer')];
      failSend = true;
      await pumpApp(tester);
      await pressPrint(tester);
      expect(sent, ['POS-80'], reason: 'tried the remembered printer first');
      expect(find.textContaining('Could not print to POS-80'), findsOneWidget);
      expect(find.text('Print Receipt'), findsOneWidget, reason: 'lets the user pick another');
    });

    testWidgets('"Change printer" forgets the printer so the next print asks',
        (tester) async {
      await tester.runAsync(() => BackendServices.settings.setSetting(
          SettingKey.lastUsedThermalPrinter,
          const ThermalPrinterRef(name: 'POS-80').toJson()));
      found = [winPrinter('POS-80')];
      await pumpApp(tester);
      await pressPrint(tester);
      expect(find.text('Printed to POS-80'), findsOneWidget);

      await tester.tap(find.text('Change printer'));
      await tester.pump();
      await settle(tester);
      expect(await saved(tester, SettingKey.lastUsedThermalPrinter), '');
      expect(find.textContaining('Printer forgotten'), findsOneWidget);

      await pressPrint(tester);
      expect(find.text('Print Receipt'), findsOneWidget);
    });

    testWidgets('a failed manual choice is reported and not remembered',
        (tester) async {
      found = [winPrinter('POS-80')];
      failSend = true;
      await pumpApp(tester);
      await pressPrint(tester);
      await tester.tap(find.text('POS-80'));
      await tester.pump();
      await settle(tester);
      expect(find.textContaining('Print failed'), findsOneWidget);
      expect(await saved(tester, SettingKey.lastUsedThermalPrinter), isNull);
    });

    testWidgets('no printers: says so', (tester) async {
      await pumpApp(tester);
      await pressPrint(tester);
      expect(find.textContaining('No USB printers found'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('Android printers are matched by vendor/product id',
        (tester) async {
      found = [androidPrinter('Thermal A', '04b8', '0e15'), androidPrinter('Thermal B', '0483', '5740')];
      await pumpApp(tester);
      await pressPrint(tester);
      await tester.tap(find.text('Thermal B'));
      await tester.pump();
      await settle(tester);
      expect(sent, ['Thermal B']);

      await pressPrint(tester);
      expect(find.text('Print Receipt'), findsNothing);
      expect(sent, ['Thermal B', 'Thermal B']);
    });

    testWidgets('a second Print press while one is running prints only once',
        (tester) async {
      await tester.runAsync(() => BackendServices.settings.setSetting(
          SettingKey.lastUsedThermalPrinter,
          const ThermalPrinterRef(name: 'POS-80').toJson()));
      found = [winPrinter('POS-80')];
      final gate = Completer<void>();
      ThermalPrinterService.sendToDevice = ({required type, required model, required invoice}) async {
        sent.add((model as UsbPrinterInput).name ?? '?');
        await gate.future; // the printer is still busy
      };
      await pumpApp(tester);

      await pressPrint(tester);
      expect(find.text('Printing to POS-80...'), findsOneWidget,
          reason: 'immediate feedback while it prints');
      await pressPrint(tester); // double click / held Ctrl+P
      expect(sent, ['POS-80'], reason: 'second press must not send a 2nd receipt');
      expect(find.textContaining('already being printed'), findsOneWidget);

      gate.complete();
      await settle(tester);
      expect(find.text('Printed to POS-80'), findsOneWidget);
      await pressPrint(tester); // a later, deliberate print works again
      expect(sent, ['POS-80', 'POS-80']);
    });

    testWidgets('a printer that refuses the receipt shows the error, not "Printed"',
        (tester) async {
      await tester.runAsync(() => BackendServices.settings.setSetting(
          SettingKey.lastUsedThermalPrinter,
          const ThermalPrinterRef(name: 'POS-80').toJson()));
      found = [winPrinter('POS-80')];
      // The real send path: the plugin answers false instead of throwing.
      ThermalPrinterService.sendToDevice = ({required type, required model, required invoice}) =>
          ThermalPrinterService.sendReceipt(
            connect: () async => true,
            send: () async => false,
            disconnect: () async => true,
          );
      await pumpApp(tester);
      await pressPrint(tester);
      expect(find.text('Printed to POS-80'), findsNothing);
      expect(find.textContaining('Could not print to POS-80'), findsOneWidget);
      expect(find.text('Print Receipt'), findsOneWidget, reason: 'lets the user pick again');
    });

    testWidgets('a manual choice that works says "Printed to ..." too',
        (tester) async {
      found = [winPrinter('POS-80')];
      await pumpApp(tester);
      await pressPrint(tester);
      await tester.tap(find.text('POS-80'));
      await tester.pump();
      // The print runs after the dialog closes; on a busy machine (tests in
      // parallel) it can take a few rounds before the snackbar shows.
      for (var i = 0; i < 6 && find.text('Printed to POS-80').evaluate().isEmpty; i++) {
        await settle(tester);
      }
      expect(find.text('Printed to POS-80'), findsOneWidget);
    });

    testWidgets('the print runs after the dialog closes, under the same guard',
        (tester) async {
      found = [winPrinter('POS-80')];
      final gate = Completer<void>();
      ThermalPrinterService.sendToDevice = ({required type, required model, required invoice}) async {
        sent.add((model as UsbPrinterInput).name ?? '?');
        await gate.future;
      };
      await pumpApp(tester);
      await pressPrint(tester);
      await tester.tap(find.text('POS-80'));
      await tester.pump();
      await settle(tester);
      expect(find.text('Print Receipt'), findsNothing, reason: 'dialog closed');
      await pressPrint(tester); // pressed while that print is still running
      expect(sent, ['POS-80'], reason: 'still guarded after the dialog closed');
      gate.complete();
      await settle(tester);
    });
  });
}
