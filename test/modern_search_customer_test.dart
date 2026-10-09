// Modern Create Invoice layout, second round:
//  * the product search is at the TOP of the items card, with Custom item
//    (Ctrl+M) beside it; clicking it lists the first 9 products, typing lists
//    only the matches, nothing matching says "Item not found";
//  * the items card runs top to bottom; there is no View / Preview / Download /
//    Print bar; the Create button sits right under the totals, panel-wide;
//  * the Customer Name box lists ALL customers when focused and narrows as you
//    type; the "Select from existing" button is gone.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceo/database/invoice_draft_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/create_invoice_screen_modern.dart';
import 'package:invoiceo/common/common.dart';
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
    tmp = Directory.systemTemp.createTempSync('invoiceo_modern_search');
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

  // 12 products: Apple 1-9 and Banana 1-3 (HSN 2001...). 3 customers.
  Future<void> open(WidgetTester tester,
      {Size size = const Size(1800, 1000),
      Future<void> Function()? beforePump}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('modern_search_${dbCounter++}.db');
      for (var i = 1; i <= 9; i++) {
        await ProductService.insertProduct(Product(
            id: 'a$i', name: 'Apple $i', description: '', price: 10.0 + i,
            stock: 0, hsncode: '200$i', tax_rate: 0, unlimitedStock: true));
      }
      for (var i = 1; i <= 3; i++) {
        await ProductService.insertProduct(Product(
            id: 'b$i', name: 'Banana $i', description: '', price: 20.0 + i,
            stock: 0, hsncode: '300$i', tax_rate: 0, unlimitedStock: true));
      }
      for (final c in [
        ['c1', 'Madhan', '1111111111'],
        ['c2', 'Mala', '2222222222'],
        ['c3', 'Ravi', '3333333333'],
      ]) {
        await CustomerService.insertCustomer(Customer(
            id: c[0], name: c[1], email: '', phone: c[2], address: '', gstin: ''));
      }
      if (beforePump != null) await beforePump();
    });
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CreateInvoiceScreenModern()),
      ),
    ));
    await settle(tester);
  }

  final searchField =
      find.widgetWithText(TextField, 'Search & add a product or service (Ctrl+F)');
  final nameField = find.byKey(const ValueKey('modernCustomerName'));
  // The chosen customer's details fill the boxes of the customer card.
  final customerCard = find.byKey(const ValueKey('modernCustomerCard'));
  Finder onCard(String text) => find.descendant(of: customerCard, matching: find.text(text));

  // Rows of the product list (not the text typed into the search box).
  Finder rows(String text) => find.descendant(
      of: find.byType(ListTile), matching: find.textContaining(text));
  int appleBananaRows() =>
      rows('Apple ').evaluate().length + rows('Banana ').evaluate().length;
  final isElevatedButton = find.byWidgetPredicate((w) => w is ElevatedButton);

  group('product search', () {
    testWidgets('it is at the top of the items card, Custom Item beside it',
        (tester) async {
      await open(tester);
      final search = tester.getTopLeft(searchField);
      final itemsHeading = tester.getTopLeft(find.text('Items'));
      final card = tester.getRect(find.byKey(const ValueKey('modernItemsCard')));
      expect(search.dy, lessThan(itemsHeading.dy), reason: 'search above the Items list');
      expect(search.dy - card.top, lessThan(40), reason: 'right at the top of the items card');
      // The customer has its own card, above the items card.
      final customerCard = tester.getRect(find.byKey(const ValueKey('modernCustomerCard')));
      expect(customerCard.bottom, lessThanOrEqualTo(card.top));
      expect(tester.getTopLeft(nameField).dy, lessThan(card.top));
      final custom = find.text('Custom Item');
      expect(custom, findsOneWidget);
      expect(tester.getTopLeft(custom).dx, greaterThan(search.dx + 300),
          reason: 'the button is beside the search box');
      expect((tester.getCenter(custom).dy - tester.getCenter(searchField).dy).abs(), lessThan(30));
    });
  });

  group('page layout', () {
    testWidgets('items card runs to the bottom of the page; Save Draft and Create are under the totals',
        (tester) async {
      await open(tester);
      expect(tester.takeException(), isNull);
      for (final label in ['View', 'Preview', 'Download']) {
        expect(find.text(label), findsNothing, reason: 'no "$label" button while creating');
      }
      expect(find.byKey(const ValueKey('modernBottomBar')), findsNothing);
      expect(find.byKey(const ValueKey('modernStatus')), findsNothing, reason: 'no status card');
      final card = tester.getRect(find.byKey(const ValueKey('modernItemsCard')));
      expect(1000 - card.bottom, lessThan(24), reason: 'the items card reaches the bottom');

      final create = find.byKey(const ValueKey('modernCreate'));
      expect(create, findsOneWidget);
      final button = tester.getRect(create);
      final totals = tester.getRect(find.byKey(const ValueKey('modernTotals')));
      expect(button.top, greaterThan(totals.bottom), reason: 'under the totals');
      expect(button.right, greaterThan(1800 - 120), reason: 'at the bottom right');
      final draft = tester.getRect(find.byKey(const ValueKey('modernSaveDraft')));
      expect(draft.top, greaterThan(totals.bottom));
      // Side by side when both names fit, else Create on top and Save Draft
      // under it (long Tamil names; also the wide test font used here).
      final sideBySide = (draft.center.dy - button.center.dy).abs() < 4;
      if (sideBySide) {
        expect(draft.right, lessThan(button.left), reason: 'Save Draft, then Create');
      } else {
        expect(draft.top, greaterThanOrEqualTo(button.bottom), reason: 'Create, then Save Draft under it');
        expect(draft.left, closeTo(button.left, 1), reason: 'lined up on the left');
      }
      expect(find.byKey(const ValueKey('modernSavePrint')), findsNothing,
          reason: 'Save & Print is in the Create ▾ menu');
    });

    testWidgets('narrow window: the totals are at the end of the page, the Create button below them',
        (tester) async {
      await open(tester, size: const Size(900, 900));
      expect(tester.takeException(), isNull);
      final create = find.byKey(const ValueKey('modernCreate'));
      expect(create, findsOneWidget);
      final totals = find.byKey(const ValueKey('modernTotals'));
      await tester.ensureVisible(totals);
      await tester.pump();
      expect(tester.getTopLeft(create).dy, greaterThan(tester.getTopLeft(totals).dy));
    });
  });

  group('customer name suggestions', () {
    testWidgets('the "Select from existing" button is gone', (tester) async {
      await open(tester);
      expect(find.textContaining('Select from existing'), findsNothing);
      expect(find.textContaining('Select existing'), findsNothing);
    });

    testWidgets('focusing the name box lists every customer', (tester) async {
      await open(tester);
      expect(find.text('Madhan'), findsNothing);
      await tester.tap(nameField);
      await settle(tester);
      expect(find.text('Madhan'), findsOneWidget);
      expect(find.text('Mala'), findsOneWidget);
      expect(find.text('Ravi'), findsOneWidget);
      // Directly under the name box.
      expect(tester.getTopLeft(find.text('Madhan')).dy,
          greaterThan(tester.getRect(nameField).bottom - 4));
    });

    testWidgets('typing lists only matching customers', (tester) async {
      await open(tester);
      await tester.tap(nameField);
      await tester.enterText(nameField, 'ma');
      await settle(tester);
      expect(find.text('Madhan'), findsOneWidget);
      expect(find.text('Mala'), findsOneWidget);
      expect(find.text('Ravi'), findsNothing);
      await tester.enterText(nameField, 'rav');
      await settle(tester);
      expect(find.text('Ravi'), findsOneWidget);
      expect(find.text('Madhan'), findsNothing);
      // Searching by phone works too.
      await tester.enterText(nameField, '2222');
      await settle(tester);
      expect(find.text('Mala'), findsOneWidget);
    });

    testWidgets('a name nobody has shows no list and stays as typed', (tester) async {
      await open(tester);
      await tester.tap(nameField);
      await tester.enterText(nameField, 'Kumar');
      await settle(tester);
      expect(find.text('Madhan'), findsNothing);
      expect(find.text('Ravi'), findsNothing);
      expect(tester.widget<TextField>(nameField).controller!.text, 'Kumar');
    });

    testWidgets('picking one fills the customer details and closes the list', (tester) async {
      await open(tester);
      await tester.tap(nameField);
      await settle(tester);
      await tester.tap(find.text('Mala'));
      await settle(tester);
      expect(tester.widget<TextField>(nameField).controller!.text, 'Mala');
      expect(onCard('2222222222'), findsOneWidget);
      expect(find.text('Madhan'), findsNothing, reason: 'list closed');
      expect(find.text('Ravi'), findsNothing);
    });

    testWidgets('arrow keys + Enter pick a customer; Enter alone never swaps a new name',
        (tester) async {
      await open(tester);
      // Typing a NEW name that resembles Madhan, then Enter: nothing is picked.
      await tester.tap(nameField);
      await tester.enterText(nameField, 'Madh');
      await settle(tester);
      expect(find.text('Madhan'), findsOneWidget);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(tester.widget<TextField>(nameField).controller!.text, 'Madh');
      expect(
          tester.widget<TextField>(find.byKey(const ValueKey('modernCustomerPhone'))).controller!.text,
          isEmpty,
          reason: 'no saved customer was swapped in');

      // Now with the arrow keys: all customers, move down once (Mala), Enter.
      await tester.enterText(nameField, '');
      await settle(tester);
      expect(find.text('Ravi'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(tester.widget<TextField>(nameField).controller!.text, 'Mala');
      expect(onCard('2222222222'), findsOneWidget);
    });

    testWidgets('Escape closes the list', (tester) async {
      await open(tester);
      await tester.tap(nameField);
      await settle(tester);
      expect(find.text('Ravi'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Ravi'), findsNothing);
    });

    testWidgets('a customer added after the screen opened is listed too', (tester) async {
      await open(tester);
      await tester.runAsync(() => CustomerService.insertCustomer(Customer(
          id: 'c9', name: 'Zainab', email: '', phone: '9999999999', address: '', gstin: '')));
      await tester.tap(nameField);
      await settle(tester);
      expect(find.text('Zainab'), findsOneWidget);
    });
  });

  group('review fixes', () {
    testWidgets('the customer list keeps working after the window crosses the 980px breakpoint',
        (tester) async {
      await open(tester);
      await tester.tap(nameField);
      await settle(tester);
      expect(find.text('Madhan'), findsOneWidget);

      tester.view.physicalSize = const Size(900, 900); // stacked layout
      await settle(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      await tester.tap(nameField);
      await settle(tester);
      expect(find.text('Madhan'), findsOneWidget, reason: 'list opens in the narrow layout');

      tester.view.physicalSize = const Size(1800, 1000); // and back
      await settle(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
      await tester.tap(nameField);
      await settle(tester);
      expect(find.text('Madhan'), findsOneWidget, reason: 'and again in the wide layout');
    });

    testWidgets('after picking a customer the keyboard shortcuts still work', (tester) async {
      await open(tester);
      await tester.tap(nameField);
      await settle(tester);
      await tester.tap(find.text('Mala'));
      await settle(tester);
      expect(tester.widget<TextField>(nameField).controller!.text, 'Mala');
      // Ctrl+F opens the product list only if the screen still gets the keys.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle(tester);
      expect(appleBananaRows(), 9, reason: 'Ctrl+F worked after the pick');
    });

    testWidgets('a slow click on a suggestion (or a drag on its scrollbar) does not close the list first',
        (tester) async {
      // On Windows a press outside the box unfocuses it at once.
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await open(tester);
        await tester.tap(nameField);
        await settle(tester);
        final press = await tester.startGesture(tester.getCenter(find.text('Mala')));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Mala'), findsOneWidget, reason: 'still open while the button is held');
        await press.up();
        await settle(tester);
        expect(onCard('2222222222'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null; // must be reset before the test ends
      }
    });

    testWidgets('the customer list never runs off the bottom of a short window', (tester) async {
      await open(tester, size: const Size(1500, 520), beforePump: () async {
        for (var i = 0; i < 14; i++) {
          await CustomerService.insertCustomer(Customer(
              id: 'x$i', name: 'Customer ${i.toString().padLeft(2, '0')}',
              email: '', phone: '70000000$i', address: '', gstin: ''));
        }
      });
      await tester.tap(nameField);
      await settle(tester);
      final list = tester.getRect(find.byKey(const ValueKey('customerSuggestionList')));
      expect(list.bottom, lessThanOrEqualTo(520), reason: 'inside the window');
      expect(list.height, greaterThan(100));
    });

    testWidgets('empty search box: arrow keys + Enter pick the highlighted product; Enter alone picks nothing',
        (tester) async {
      await open(tester);
      await tester.tap(searchField);
      await settle(tester);
      // Enter without touching the arrows: nothing is added.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(searchField);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining('Apple 3')),
          findsWidgets, reason: 'the third row was highlighted');
    });

    testWidgets('narrow window: every row of the search list can be clicked', (tester) async {
      await open(tester, size: const Size(900, 900));
      await tester.tap(searchField);
      await settle(tester);
      expect(appleBananaRows(), 9);
      await tester.ensureVisible(rows('Apple 9'));
      await tester.pump();
      await tester.tap(rows('Apple 9'), warnIfMissed: false);
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'the 9th row responded to the click');
    });

    testWidgets('the first-9 list shows the stock as it is now, not as it was when the screen opened',
        (tester) async {
      await open(tester, beforePump: () async {
        await ProductService.insertProduct(Product(
            id: 'stk', name: 'Aaa Stock Item', description: '', price: 5,
            stock: 7, hsncode: '5555', tax_rate: 0));
      });
      // Someone sells the lot elsewhere (or the previous invoice did).
      await tester.runAsync(() => ProductService.updateProductStock('stk', 0));
      await tester.tap(searchField);
      await settle(tester);
      expect(find.textContaining('Stock: 0'), findsWidgets);
      expect(find.textContaining('Stock: 7'), findsNothing);
    });
  });

  group('foldable right panel and the table', () {
    // Pumps a fresh screen again on the SAME database (to see what was saved).
    Future<void> reopen(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(ProviderScope(
        overrides: sqliteRepositoryOverrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CreateInvoiceScreenModern()),
        ),
      ));
      await settle(tester);
    }

    final panel = find.byKey(const ValueKey('modernRightPanel'));
    final strip = find.byKey(const ValueKey('modernRightStrip'));
    final hide = find.byKey(const ValueKey('modernHidePanel'));
    final items = find.byKey(const ValueKey('modernItemsCard'));

    Future<void> addProduct(WidgetTester tester, String code) async {
      final keys = {
        '0': LogicalKeyboardKey.digit0, '1': LogicalKeyboardKey.digit1,
        '2': LogicalKeyboardKey.digit2, '3': LogicalKeyboardKey.digit3,
      };
      for (final ch in code.split('')) {
        await tester.sendKeyDownEvent(keys[ch]!, character: ch);
        await tester.sendKeyUpEvent(keys[ch]!);
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
    }

    testWidgets('a button folds the panel to a slim strip and another opens it again',
        (tester) async {
      await open(tester);
      expect(tester.getSize(panel).width, 360);
      expect(strip, findsNothing);
      final itemsOpen = tester.getSize(items).width;

      await tester.tap(hide);
      await settle(tester);
      expect(tester.getSize(panel).width, 64, reason: 'folded to the right edge');
      expect(strip, findsOneWidget);
      expect(nameField, findsOneWidget, reason: 'the customer row sits above the items, not in the panel');
      expect(find.text('Invoice Details'), findsNothing,
          reason: 'the panel fields are out of the way');
      expect(tester.getSize(items).width, greaterThan(itemsOpen + 250),
          reason: 'the items table takes the freed width');
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Show details panel'));
      await settle(tester);
      expect(tester.getSize(panel).width, 360);
      expect(strip, findsNothing);
      expect(nameField, findsOneWidget);
      expect(find.text('Invoice Details'), findsOneWidget);
      expect(tester.getSize(items).width, itemsOpen);
    });

    testWidgets('the choice is remembered', (tester) async {
      await open(tester);
      await tester.tap(hide);
      await settle(tester);
      final saved = await tester.runAsync(() =>
          BackendServices.settings.getSetting(SettingKey.modernRightPanelOpen));
      expect(saved, 'false');

      await reopen(tester);
      expect(strip, findsOneWidget, reason: 'still folded next time');
      expect(tester.getSize(panel).width, 64);

      await tester.tap(find.byTooltip('Show details panel'));
      await settle(tester);
      await reopen(tester);
      expect(strip, findsNothing, reason: 'and open again once reopened');
    });

    testWidgets('with the panel folded the invoice can still be created from the strip',
        (tester) async {
      final printed = <String>[];
      InvoicePdfServices.printHook = (c, i) async => printed.add(i.id);
      addTearDown(() => InvoicePdfServices.printHook = null);
      await open(tester);
      await tester.enterText(nameField, 'mad');
      await tester.pump();
      await addProduct(tester, '2001');
      await tester.tap(hide);
      await settle(tester);
      expect(find.textContaining('Rs.'), findsWidgets, reason: 'the total shows in the strip');

      await tester.tap(find.byKey(const ValueKey('modernStripCreate')));
      await settle(tester);
      await settle(tester);
      expect(find.text('Invoice Created Successfully!'), findsOneWidget);
      expect(printed, hasLength(1));
    });

    testWidgets('folded panel: Save Draft icon, and the ▾ under Create has the two choices',
        (tester) async {
      // With auto-print off: when it is on (the default) Create already
      // prints, so "Save & Print" is left out.
      await open(tester,
          beforePump: () => BackendServices.settings
              .setSetting(SettingKey.autoPrintAfterCreate, 'false'));
      await tester.enterText(nameField, 'mad');
      await tester.pump();
      await addProduct(tester, '2001');
      await tester.tap(hide);
      await settle(tester);
      expect(find.byKey(const ValueKey('modernStripDraft')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('modernStripCreateMenu')));
      await tester.pumpAndSettle();
      expect(find.text('Create and start a new one'), findsOneWidget);
      expect(find.text('Save & Print'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('modernStripDraft')));
      await settle(tester);
      expect(await tester.runAsync(() => InvoiceDraftService.countDrafts('Invoice')), 1);
    });

    testWidgets('the strip Create button is off until there is an item', (tester) async {
      await open(tester);
      await tester.tap(hide);
      await settle(tester);
      final b = tester.widget<InkWell>(find.byKey(const ValueKey('modernStripCreate')));
      expect(b.onTap, isNull);
      expect(tester.widget<PopupMenuButton<int>>(find.byKey(const ValueKey('modernStripCreateMenu'))).enabled,
          isFalse);
    });

    testWidgets('items stay a table on narrow windows, with Total, Edit and Delete always reachable',
        (tester) async {
      for (final size in [const Size(1366, 800), const Size(1190, 800), const Size(1100, 800), const Size(900, 800)]) {
        await open(tester, size: size);
        await addProduct(tester, '2002');
        expect(tester.takeException(), isNull, reason: '$size');
        final itemsTotal = find.descendant(of: items, matching: find.text('Total'));
        expect(find.descendant(of: items, matching: find.text('Product / Service')), findsOneWidget,
            reason: '$size: table header');
        expect(itemsTotal, findsOneWidget, reason: '$size');
        expect(find.byKey(const ValueKey('itemRow0')), findsOneWidget, reason: '$size');
        // Total and the row buttons are inside the card, no sideways scrolling needed.
        final card = tester.getRect(items);
        final total = tester.getRect(itemsTotal);
        expect(total.right, lessThanOrEqualTo(card.right), reason: '$size: TOTAL column is in view');
        // (the header's number chip has a pencil too: look inside the row)
        final editIcons = find.descendant(
            of: find.byKey(const ValueKey('itemRow0')), matching: find.byIcon(Icons.edit_outlined));
        final menu = find.descendant(
            of: find.byKey(const ValueKey('itemRow0')), matching: find.byIcon(Icons.more_vert));
        if (editIcons.evaluate().isNotEmpty) {
          expect(tester.getRect(editIcons.first).right, lessThanOrEqualTo(card.right),
              reason: '$size: Edit button in view');
        } else {
          expect(menu, findsOneWidget, reason: '$size: Edit / Delete are in the row menu');
          expect(tester.getRect(menu).right, lessThanOrEqualTo(card.right), reason: '$size');
          await tester.tap(menu);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Edit item'), findsOneWidget, reason: '$size');
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('folding the panel makes room: the whole table fits without sideways scrolling',
        (tester) async {
      await open(tester, size: const Size(1100, 800));
      await addProduct(tester, '2003');
      // Open panel: a narrow table; the sideways scroll may be needed.
      await tester.tap(hide);
      await settle(tester);
      final row = tester.getRect(find.byKey(const ValueKey('itemRow0')));
      final card = tester.getRect(items);
      expect(row.right, lessThanOrEqualTo(card.right + 1), reason: 'the whole row is inside the card');
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });
  });
}
