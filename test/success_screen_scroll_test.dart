// The "Invoice created" screen must never overflow, however short the
// window is: it scrolls instead (it used to show "BOTTOM OVERFLOWED BY n
// PIXELS"), and stays centred when the window is tall.
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
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/create_invoice_screen_v2.dart';
import 'package:invoiceo/services/backend_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  var dbCounter = 0;

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
    tmp = Directory.systemTemp.createTempSync('invoiceo_success_scroll');
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

  // Creates one invoice for a NEW customer ("mad"), so the success screen
  // shows its tallest form: the "Save customer?" banner is included.
  Future<void> reachSuccessScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('success_scroll_${dbCounter++}.db');
      await ProductService.insertProduct(Product(
          id: 'a', name: 'Alpha Soap', description: '', price: 11,
          stock: 0, hsncode: '1001', tax_rate: 0, unlimitedStock: true));
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
    await tester.enterText(
        find.widgetWithText(TextField, 'Customer Name *'), 'mad');
    await tester.pump();

    // Scan the product (hardware keys), then Add in its prompt.
    for (final ch in '1001'.split('')) {
      final key = {
        '0': LogicalKeyboardKey.digit0, '1': LogicalKeyboardKey.digit1,
      }[ch]!;
      await tester.sendKeyDownEvent(key, character: ch);
      await tester.sendKeyUpEvent(key);
      await tester.pump(const Duration(milliseconds: 5));
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Add')));
    await tester.pump();
    await settle(tester);

    final create = find.textContaining('Create Invoice (Ctrl+S)');
    await tester.ensureVisible(create);
    await tester.pump();
    await tester.tap(create);
    await tester.pump();
    await settle(tester);
    await settle(tester);
    expect(find.textContaining('Create New Invoice'), findsOneWidget,
        reason: 'the Invoice-created screen is showing');
  }

  Future<void> resize(WidgetTester tester, double w, double h) async {
    tester.view.physicalSize = Size(w, h);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('never overflows, at any window height', (tester) async {
    await reachSuccessScreen(tester);
    expect(tester.takeException(), isNull, reason: 'tall window is fine');

    final problems = <String>[];
    for (final h in [900.0, 760.0, 640.0, 520.0, 420.0, 300.0]) {
      await resize(tester, 1500, h);
      final e = tester.takeException();
      if (e != null) {
        problems.add('height $h: ${e.toString().split('\n').first}');
      }
    }
    // ignore: avoid_print
    print('OVERFLOWS: ${problems.isEmpty ? 'none' : problems}');
    expect(problems, isEmpty);
  });

  testWidgets('every control stays reachable by scrolling in a short window',
      (tester) async {
    await reachSuccessScreen(tester);
    await resize(tester, 1500, 420);
    tester.takeException();

    final newInvoice = find.textContaining('Create New Invoice');
    await tester.ensureVisible(newInvoice);
    await tester.pump();
    final box = tester.getRect(newInvoice);
    expect(box.bottom, lessThanOrEqualTo(420.0),
        reason: 'scrolled the New Invoice button into view');
    expect(find.text('Save'), findsWidgets, reason: 'save-customer banner there');
  });

  testWidgets('the scroll area fills the space and the card stays centred',
      (tester) async {
    await reachSuccessScreen(tester);
    await resize(tester, 1500, 1600); // tall: nothing to scroll
    final cardFinder = find.byType(Card).first;
    final scroll = tester.getRect(find
        .ancestor(of: cardFinder, matching: find.byType(SingleChildScrollView))
        .first);
    final card = tester.getRect(cardFinder);
    expect(scroll.width, greaterThan(card.width + 200),
        reason: 'the scroll area must be wider than the card, or the mouse '
            'wheel does nothing beside it (scroll ${scroll.width}, card ${card.width})');
    expect((card.center.dy - scroll.center.dy).abs(), lessThan(2.0),
        reason: 'card vertically centred in its scroll area');
    expect((card.center.dx - scroll.center.dx).abs(), lessThan(2.0),
        reason: 'card horizontally centred in its scroll area');
  });

  testWidgets('scrolling works from the empty space beside the card',
      (tester) async {
    await reachSuccessScreen(tester);
    await resize(tester, 1500, 420); // short: must scroll
    tester.takeException();
    final cardFinder = find.byType(Card).first;
    final before = tester.getRect(cardFinder).top;
    // A drag that starts far left of the card, on blank background.
    await tester.dragFrom(const Offset(20, 300), const Offset(0, -200));
    await tester.pump();
    final after = tester.getRect(cardFinder).top;
    expect(after, lessThan(before - 50),
        reason: 'the card scrolled up (top $before -> $after)');
  });
}
