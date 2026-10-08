// Barcode scanning on the real CreateInvoiceScreenV2 with a simulated
// scanner: whichever box has focus (or none), a scan must find the product
// and open its quantity prompt; scans while the prompt is open must not
// become the quantity.
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

const _digitKeys = {
  '0': LogicalKeyboardKey.digit0, '1': LogicalKeyboardKey.digit1,
  '2': LogicalKeyboardKey.digit2, '3': LogicalKeyboardKey.digit3,
  '4': LogicalKeyboardKey.digit4, '5': LogicalKeyboardKey.digit5,
  '6': LogicalKeyboardKey.digit6, '7': LogicalKeyboardKey.digit7,
  '8': LogicalKeyboardKey.digit8, '9': LogicalKeyboardKey.digit9,
};

enum _End { enter, tab, none }

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('invoiceo_scan_prompt_test');
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

  const searchLabel = 'Search & add a product or service (Ctrl+F)';
  const names = ['Alpha Soap', 'Beta Oil', 'Gamma Tea'];

  Future<void> pumpScreen(WidgetTester tester, String db) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile(db);
      for (final p in [
        ['a', 'Alpha Soap', '1001', 11.0],
        ['b', 'Beta Oil', '2002', 22.0],
        ['c', 'Gamma Tea', '3003', 33.0],
      ]) {
        await ProductService.insertProduct(Product(
            id: p[0] as String, name: p[1] as String, description: '',
            price: p[3] as double, stock: 0, hsncode: p[2] as String,
            tax_rate: 0, unlimitedStock: true));
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

  // One key press the way the real engine treats it: the framework sees the
  // key first; if nothing handles it, the character is typed into the box
  // that has focus (null = nothing focused, the character goes nowhere).
  Future<void> press(WidgetTester tester, String ch, Finder? box) async {
    final key = _digitKeys[ch]!;
    final handled = await tester.sendKeyDownEvent(key, character: ch);
    if (!handled && box != null) {
      final cur = tester.widget<TextField>(box).controller!.text;
      await tester.enterText(box, cur + ch);
    }
    await tester.sendKeyUpEvent(key);
  }

  Future<void> terminate(WidgetTester tester, _End end, Finder? box) async {
    if (end == _End.none) return;
    final key =
        end == _End.enter ? LogicalKeyboardKey.enter : LogicalKeyboardKey.tab;
    final handled = await tester.sendKeyDownEvent(key);
    if (!handled && end == _End.enter && box != null) {
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    await tester.sendKeyUpEvent(key);
  }

  // A scanner: characters 5 ms apart, then Enter (or Tab).
  Future<void> scan(WidgetTester tester, String code,
      {Finder? box, _End end = _End.enter}) async {
    for (final ch in code.split('')) {
      await press(tester, ch, box);
      await tester.pump(const Duration(milliseconds: 5));
    }
    await terminate(tester, end, box);
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
  }

  String? openPrompt() {
    for (final n in names) {
      if (find
          .descendant(
              of: find.byType(AlertDialog), matching: find.textContaining('$n (Rs.'))
          .evaluate()
          .isNotEmpty) {
        return n;
      }
    }
    return null;
  }

  Finder promptQty() => find
      .descendant(of: find.byType(AlertDialog), matching: find.byType(TextField))
      .first;
  String qtyBox(WidgetTester tester) =>
      tester.widget<TextField>(promptQty()).controller!.text;

  Future<void> pressAdd(WidgetTester tester) async {
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Add')));
    await tester.pump();
    await settle(tester);
  }

  testWidgets('scan with NOTHING focused opens the product prompt',
      (tester) async {
    await pumpScreen(tester, 'cap_nofocus.db');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await scan(tester, '2002');
    expect(openPrompt(), 'Beta Oil');
  });

  testWidgets('scan while the SEARCH box is focused opens the prompt',
      (tester) async {
    await pumpScreen(tester, 'cap_search.db');
    final search = find.widgetWithText(TextField, searchLabel);
    await tester.tap(search);
    await tester.pump();
    await scan(tester, '3003', box: search);
    expect(openPrompt(), 'Gamma Tea');
    expect(tester.widget<TextField>(search).controller!.text, '');
  });

  testWidgets('scan while ANOTHER box (customer name) is focused stays out of it',
      (tester) async {
    await pumpScreen(tester, 'cap_other.db');
    final customer = find.widgetWithText(TextField, 'Customer Name *');
    await tester.tap(customer);
    await tester.pump();
    await scan(tester, '1001', box: customer);
    expect(openPrompt(), 'Alpha Soap');
    expect(tester.widget<TextField>(customer).controller!.text, '',
        reason: 'the scanned digits must not be left in the customer name');
  });

  testWidgets('a scan ended by TAB instead of Enter also works', (tester) async {
    await pumpScreen(tester, 'cap_tab.db');
    await scan(tester, '2002', end: _End.tab);
    expect(openPrompt(), 'Beta Oil');
  });

  testWidgets('an unknown code adds nothing and says so', (tester) async {
    await pumpScreen(tester, 'cap_unknown.db');
    await scan(tester, '9999');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('9999'), findsWidgets); // the snackbar names it
  });

  testWidgets('scanning the same product again makes quantity 2, not 1001',
      (tester) async {
    await pumpScreen(tester, 'prompt_same.db');
    await scan(tester, '1001');
    expect(openPrompt(), 'Alpha Soap');

    await scan(tester, '1001', box: promptQty()); // same item again
    expect(openPrompt(), 'Alpha Soap', reason: 'scanner Enter must not add it');
    expect(qtyBox(tester), '2');

    await pressAdd(tester);
    expect(openPrompt(), isNull);
    expect(find.text('Rs.22.00'), findsWidgets); // 11.00 x 2, never 11,011.00
    expect(find.text('Rs.11011.00'), findsNothing);
  });

  testWidgets('three scans of the same product in a row make quantity 3',
      (tester) async {
    await pumpScreen(tester, 'prompt_three.db');
    await scan(tester, '1001');
    await scan(tester, '1001', box: promptQty());
    await scan(tester, '1001', box: promptQty());
    expect(openPrompt(), 'Alpha Soap');
    expect(qtyBox(tester), '3');
  });

  testWidgets('a different product scanned meanwhile opens next, after this one',
      (tester) async {
    await pumpScreen(tester, 'prompt_other.db');
    await scan(tester, '1001');
    await scan(tester, '2002', box: promptQty()); // Beta Oil, queued
    expect(openPrompt(), 'Alpha Soap', reason: 'must not close or submit');
    expect(qtyBox(tester), '', reason: 'scanned digits stay out of Quantity');

    await pressAdd(tester); // Alpha Soap added with quantity 1
    expect(find.text('Rs.11.00'), findsWidgets);
    expect(openPrompt(), 'Beta Oil'); // ...and Beta Oil opens by itself
  });

  testWidgets('a person typing a quantity is not mistaken for a scanner',
      (tester) async {
    await pumpScreen(tester, 'prompt_human.db');
    await scan(tester, '1001');
    // "25" typed with human pauses, then Enter.
    for (final ch in ['2', '5']) {
      await press(tester, ch, promptQty());
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(qtyBox(tester), '25');
    await terminate(tester, _End.enter, promptQty());
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(openPrompt(), isNull, reason: 'Enter adds the item as before');
    expect(find.text('Rs.275.00'), findsWidgets); // 11.00 x 25
  });

  testWidgets('holding a key down (auto-repeat) is never taken for a scan',
      (tester) async {
    await pumpScreen(tester, 'cap_repeat.db');
    final search = find.widgetWithText(TextField, searchLabel);
    await tester.tap(search);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit1, character: '1');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.digit1, character: '1');
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit1);
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('another dialog open (custom item) keeps its keyboard to itself',
      (tester) async {
    await pumpScreen(tester, 'cap_dialog.db');
    await tester.tap(find.text('Custom item (Ctrl+M)'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await scan(tester, '1001');
    expect(openPrompt(), isNull, reason: 'must not open a product prompt on top');
  });
}
