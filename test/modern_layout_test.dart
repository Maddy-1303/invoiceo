// The "Modern" Create Invoice layout (the default):
//  * Customer box at the TOP of the right-hand panel, above Invoice details;
//    the items table owns the left side,
//  * the right panel scrolls, the totals stay pinned under it,
//  * narrow windows stack everything in one scrolling column,
//  * the existing V2 layout is unchanged (customer on the left; Ctrl+P /
//    F11 / auto-print belong to Modern only),
//  * Settings > Accessibility offers it and it is the default.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/ui_layout.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/create_invoice_screen_modern.dart';
import 'package:invoiceo/screens/create_invoice_screen_v2.dart';
import 'package:invoiceo/screens/settings/accessibility_screen.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/services/invoice_pdf_services.dart';

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
    tmp = Directory.systemTemp.createTempSync('invoiceo_modern_layout');
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

  Future<void> open(WidgetTester tester, Widget screen,
      {Size size = const Size(1800, 1000)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('modern_layout_${dbCounter++}.db');
      await ProductService.insertProduct(Product(
          id: 'a', name: 'Alpha Soap', description: '', price: 11,
          stock: 0, hsncode: '1001', tax_rate: 0, unlimitedStock: true));
    });
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: screen),
      ),
    ));
    await settle(tester);
  }

  final customerBox = find.text('CUSTOMER DETAILS');
  final invoiceBox = find.text('Invoice Details');
  // Modern: the customer search box; V2 (the previous developer's screen):
  // the labelled Customer Name box.
  final nameField = find.byKey(const ValueKey('modernCustomerName'));
  final v2NameField = find.widgetWithText(TextField, 'Customer Name *');
  final searchField =
      find.widgetWithText(TextField, 'Search & add a product or service (Ctrl+F)');

  testWidgets('Modern: no customer card in the right panel; the customer row is above the search',
      (tester) async {
    await open(tester, const CreateInvoiceScreenModern());
    expect(tester.takeException(), isNull);
    expect(customerBox, findsNothing, reason: 'the CUSTOMER DETAILS card is gone');
    expect(invoiceBox, findsOneWidget);

    final invoice = tester.getTopLeft(invoiceBox);
    final name = tester.getRect(nameField);
    final search = tester.getTopLeft(searchField);

    expect(invoice.dx, greaterThan(1800 * 0.6),
        reason: 'the right panel (Invoice details first) is on the RIGHT side');
    expect(invoice.dy, lessThan(160), reason: 'Invoice details is at the top of the panel');
    expect(name.right, lessThan(invoice.dx), reason: 'the customer row is on the left');
    expect(name.bottom, lessThanOrEqualTo(search.dy), reason: 'above the product search');
    expect(name.width, greaterThan(150));
  });

  testWidgets('Modern: the right panel scrolls; totals stay pinned; nothing overflows',
      (tester) async {
    await open(tester, const CreateInvoiceScreenModern(),
        size: const Size(1500, 640)); // a short window
    expect(tester.takeException(), isNull, reason: 'no overflow stripes on a short window');

    final scroll = find.byKey(const ValueKey('modernRightPanelScroll'));
    expect(scroll, findsOneWidget);
    final position = tester
        .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)).first)
        .position;
    expect(position.maxScrollExtent, greaterThan(100),
        reason: 'more in the panel than fits: it must scroll');

    final totalsBefore = tester.getTopLeft(find.textContaining('Subtotal').last);
    final customerBefore = tester.getTopLeft(invoiceBox).dy;
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pump();
    expect(position.pixels, greaterThan(0));
    expect(tester.getTopLeft(invoiceBox).dy, lessThan(customerBefore),
        reason: 'the panel content moved up');
    expect(tester.getTopLeft(find.textContaining('Subtotal').last), totalsBefore,
        reason: 'the totals do not move with the scrolling content');
    expect(tester.takeException(), isNull);

    // And back to the top.
    await tester.drag(scroll, const Offset(0, 800));
    await tester.pump();
    expect(position.pixels, 0);
  });

  testWidgets('Modern: typing in the customer box in the panel works', (tester) async {
    await open(tester, const CreateInvoiceScreenModern());
    await tester.enterText(nameField, 'மதன்');
    await tester.pump();
    expect(tester.widget<TextField>(nameField).controller!.text, 'மதன்');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Modern: clicking a customer field after using the product search keeps the cursor there',
      (tester) async {
    await open(tester, const CreateInvoiceScreenModern());
    // Cashier is in the product search box...
    await tester.tap(searchField);
    await tester.pump();
    final searchFocus = tester
        .state<EditableTextState>(
            find.descendant(of: searchField, matching: find.byType(EditableText)))
        .widget
        .focusNode;
    expect(searchFocus.hasFocus, isTrue);
    // ...then clicks the customer name box in the right panel.
    await tester.tap(nameField);
    await tester.pump();
    // The screen used to grab the focus back ~150 ms later, so the cursor
    // vanished and the first letters typed went nowhere.
    await tester.pump(const Duration(milliseconds: 500));
    final nameFocus = tester
        .state<EditableTextState>(
            find.descendant(of: nameField, matching: find.byType(EditableText)))
        .widget
        .focusNode;
    expect(nameFocus.hasFocus, isTrue, reason: 'the customer box keeps the focus');
    await tester.enterText(nameField, 'மதன்');
    expect(tester.widget<TextField>(nameField).controller!.text, 'மதன்');
    await settle(tester); // let the customer lookup (database) finish
  });

  testWidgets('Modern: a narrow window stacks everything in one column, nothing overflows',
      (tester) async {
    await open(tester, const CreateInvoiceScreenModern(), size: const Size(900, 900));
    expect(tester.takeException(), isNull);
    expect(customerBox, findsNothing);
    expect(nameField, findsOneWidget, reason: 'the customer row is in the items card');
    expect(invoiceBox, findsOneWidget);
  });

  testWidgets('V2 stays as it was: customer box on the LEFT, no Ctrl+P / F11 create-and-print',
      (tester) async {
    final printed = <String>[];
    InvoicePdfServices.printHook = (c, i) async => printed.add(i.id);
    addTearDown(() => InvoicePdfServices.printHook = null);

    await open(tester, const CreateInvoiceScreenV2());
    expect(tester.takeException(), isNull);
    final customer = tester.getTopLeft(customerBox);
    final invoice = tester.getTopLeft(find.text('INVOICE DETAILS'));
    expect(customer.dx, lessThan(1800 * 0.5), reason: 'V2: customer is on the left');
    expect(invoice.dx, greaterThan(customer.dx), reason: 'V2: invoice details on the right');

    // Fill a customer and one item, then Ctrl+P / F11: V2 must do nothing new.
    await tester.enterText(v2NameField, 'mad');
    await tester.pump();
    for (final ch in '1001'.split('')) {
      final key = {'0': LogicalKeyboardKey.digit0, '1': LogicalKeyboardKey.digit1}[ch]!;
      await tester.sendKeyDownEvent(key, character: ch);
      await tester.sendKeyUpEvent(key);
      await tester.pump(const Duration(milliseconds: 5));
    }
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 700));
    await settle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Add')));
    await tester.pump();
    await settle(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.f11);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.f11);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(printed, isEmpty);
    final count = (await tester.runAsync(
        () async => (await InvoiceService.getAllInvoices()).length))!;
    expect(count, 0, reason: 'V2 does not create on Ctrl+P / F11');
  });

  group('Settings > Accessibility (screen layout)', () {
    Future<ProviderContainer> openSettings(WidgetTester tester,
        {String? stored, String? legacy}) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await DatabaseHelper().switchToFile('modern_layout_${dbCounter++}.db');
        if (stored != null) {
          await BackendServices.settings.setSetting(SettingKey.uiLayout, stored);
        }
        if (legacy != null) {
          await BackendServices.settings
              .setSetting(SettingKey.createInvoiceLayout, legacy);
        }
      });
      await tester.pumpWidget(const SizedBox()); // a fresh screen state each time
      final container = ProviderContainer(overrides: sqliteRepositoryOverrides);
      addTearDown(container.dispose);
      // The dashboard loads the saved layout into the provider at start-up.
      await tester.runAsync(() async {
        container.read(uiLayoutProvider.notifier).state =
            await loadUiLayout(BackendServices.settings);
      });
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccessibilityScreen(),
        ),
      ));
      await settle(tester);
      return container;
    }

    UiLayout selected(WidgetTester tester) => tester
        .widget<SegmentedButton<UiLayout>>(find.byType(SegmentedButton<UiLayout>))
        .selected
        .single;

    testWidgets('Modern is the default; Standard is offered next to it', (tester) async {
      await openSettings(tester);
      expect(selected(tester), UiLayout.modern);
      final picker = find.byType(SegmentedButton<UiLayout>);
      expect(find.descendant(of: picker, matching: find.text('Modern')), findsOneWidget);
      expect(find.descendant(of: picker, matching: find.text('Standard')), findsOneWidget);
      expect(find.descendant(of: picker, matching: find.text('Classic')), findsNothing);
    });

    testWidgets('a saved Standard choice is kept', (tester) async {
      await openSettings(tester, stored: 'standard');
      expect(selected(tester), UiLayout.standard);
    });

    testWidgets('the old Create Invoice choice carries over: New (v2) = Standard',
        (tester) async {
      await openSettings(tester, legacy: 'v2');
      expect(selected(tester), UiLayout.standard);
      await openSettings(tester, legacy: 'v1'); // the removed Classic screen
      expect(selected(tester), UiLayout.modern);
      await openSettings(tester, legacy: 'modern');
      expect(selected(tester), UiLayout.modern);
    });

    testWidgets('choosing a layout applies it at once and saves it', (tester) async {
      final container = await openSettings(tester, stored: 'standard');
      await tester.tap(find.descendant(
          of: find.byType(SegmentedButton<UiLayout>), matching: find.text('Modern')));
      await settle(tester);
      expect(selected(tester), UiLayout.modern);
      expect(container.read(uiLayoutProvider), UiLayout.modern);
      final saved = await tester.runAsync(() =>
          BackendServices.settings.getSetting(SettingKey.uiLayout));
      expect(saved, 'modern');

      await tester.tap(find.descendant(
          of: find.byType(SegmentedButton<UiLayout>), matching: find.text('Standard')));
      await settle(tester);
      expect(container.read(uiLayoutProvider), UiLayout.standard);
      final saved2 = await tester.runAsync(() =>
          BackendServices.settings.getSetting(SettingKey.uiLayout));
      expect(saved2, 'standard');
    });
  });
}
