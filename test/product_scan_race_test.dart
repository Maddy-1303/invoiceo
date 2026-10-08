// Reproduces the "scanner adds the previous product" bug on the REAL
// CreateInvoiceScreenV2: a barcode/QR scanner types the code in a few
// milliseconds and presses Enter, long before the search box's 400 ms
// debounce has loaded the results for that code.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/screens/create_invoice_screen_v2.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('invoiceo_scan_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });

  tearDownAll(() async {
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  // Types [code] one character at a time (5 ms apart, like a scanner) and
  // presses Enter immediately after the last character.
  Future<void> scan(WidgetTester tester, Finder field, String code,
      {bool tapFirst = true, bool doubleEnter = false}) async {
    if (tapFirst) {
      await tester.tap(field);
      await tester.pump();
    }
    for (var i = 1; i <= code.length; i++) {
      await tester.enterText(field, code.substring(0, i));
      await tester.pump(const Duration(milliseconds: 5));
    }
    await tester.testTextInput.receiveAction(TextInputAction.done);
    if (doubleEnter) {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    // Let the 400 ms debounce and the database query finish afterwards.
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
  }

  // Name of the product the add-to-invoice prompt opened for ('' if none).
  String promptedProduct(WidgetTester tester, List<String> names) {
    for (final n in names) {
      if (find
          .descendant(
              of: find.byType(AlertDialog), matching: find.textContaining('$n (Rs.'))
          .evaluate()
          .isNotEmpty) {
        return n;
      }
    }
    return '(no prompt)';
  }

  Future<void> closePrompt(WidgetTester tester) async {
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
  }

  testWidgets('scanner Enter must add the scanned product, not the previous one',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const names = ['Alpha Soap', 'Beta Oil', 'Gamma Tea'];
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('scan_test.db');
      for (final p in [
        ['a', 'Alpha Soap', '1001', 11.0],
        ['b', 'Beta Oil', '2002', 22.0],
        ['c', 'Gamma Tea', '3003', 33.0],
      ]) {
        await ProductService.insertProduct(Product(
            id: p[0] as String, name: p[1] as String, description: '',
            price: p[3] as double, stock: 50, hsncode: p[2] as String,
            tax_rate: 0));
      }
    });

    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CreateInvoiceScreenV2()),
      ),
    ));
    await settle(tester);

    final field = find.widgetWithText(
        TextField, 'Search & add a product or service (Ctrl+F)');
    expect(field, findsOneWidget);

    // The exact sequence from the bug report. Only the very first scan
    // clicks the box; after that the scanner just keeps typing, so focus has
    // to be back in the search box once each prompt is closed.
    final seen = <String>[];
    var first = true;
    for (final code in ['2002', '2002', '3003', '3003']) {
      await scan(tester, field, code, tapFirst: first);
      first = false;
      seen.add('$code -> ${promptedProduct(tester, names)}');
      await closePrompt(tester);
      expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue,
          reason: 'search box must regain focus so the next scan is typed into it');
    }
    // ignore: avoid_print
    print('SCAN RESULTS:\n  ${seen.join('\n  ')}');

    expect(seen, [
      '2002 -> Beta Oil',
      '2002 -> Beta Oil',
      '3003 -> Gamma Tea',
      '3003 -> Gamma Tea',
    ]);
  });

  testWidgets('a scanned code that is a prefix of another code picks the exact match',
      (tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const names = ['Aardvark Pen', 'Zulu Soap'];
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('scan_test_prefix.db');
      // 'Aardvark Pen' sorts first, and its code CONTAINS the other code.
      for (final p in [
        ['x', 'Aardvark Pen', '10010', 5.0],
        ['y', 'Zulu Soap', '1001', 9.0],
      ]) {
        await ProductService.insertProduct(Product(
            id: p[0] as String, name: p[1] as String, description: '',
            price: p[3] as double, stock: 50, hsncode: p[2] as String,
            tax_rate: 0));
      }
    });
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CreateInvoiceScreenV2()),
      ),
    ));
    await settle(tester);
    final field = find.widgetWithText(
        TextField, 'Search & add a product or service (Ctrl+F)');

    // Scan twice: the 2nd scan removes the stale-list effect, leaving only
    // the "contains" matching to blame.
    await scan(tester, field, '1001');
    await closePrompt(tester);
    await scan(tester, field, '1001');
    final got = promptedProduct(tester, names);
    // ignore: avoid_print
    print('PREFIX RESULT: scanned 1001 (Zulu Soap) -> $got');
    expect(got, 'Zulu Soap');
  });

  Future<void> pumpScreen(WidgetTester tester, String db,
      List<List<Object>> products) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile(db);
      for (final p in products) {
        await ProductService.insertProduct(Product(
            id: p[0] as String, name: p[1] as String, description: '',
            price: p[3] as double, stock: 50, hsncode: p[2] as String,
            tax_rate: 0));
      }
    });
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CreateInvoiceScreenV2()),
      ),
    ));
    await settle(tester);
  }

  const searchLabel = 'Search & add a product or service (Ctrl+F)';
  const trio = [
    ['a', 'Alpha Soap', '1001', 11.0],
    ['b', 'Beta Oil', '2002', 22.0],
    ['c', 'Gamma Tea', '3003', 33.0],
  ];
  const trioNames = ['Alpha Soap', 'Beta Oil', 'Gamma Tea'];

  testWidgets('a scanner that sends Enter twice opens only one prompt',
      (tester) async {
    await pumpScreen(tester, 'scan_test_double.db', trio);
    final field = find.widgetWithText(TextField, searchLabel);
    await scan(tester, field, '2002', doubleEnter: true);
    expect(promptedProduct(tester, trioNames), 'Beta Oil');
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('a code that matches nothing adds nothing and keeps the text',
      (tester) async {
    await pumpScreen(tester, 'scan_test_unknown.db', trio);
    final field = find.widgetWithText(TextField, searchLabel);
    await scan(tester, field, '9999');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.widget<TextField>(field).controller!.text, '9999');
  });

  testWidgets('typing slowly, arrow down, Enter still uses the highlighted row',
      (tester) async {
    await pumpScreen(tester, 'scan_test_keys.db', trio);
    final field = find.widgetWithText(TextField, searchLabel);
    await tester.tap(field);
    await tester.enterText(field, 'a'); // matches all three names
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(promptedProduct(tester, trioNames), 'Beta Oil');
  });
}
