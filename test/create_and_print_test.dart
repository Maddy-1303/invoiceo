// Create + print in one go (Modern layout):
//  * the Create button (and Ctrl+S) also prints the new invoice, unless the
//    user switched "print automatically after creating" off,
//  * Ctrl+P and F11 create the invoice and print it, whatever that setting
//    says, once per press (holding the key down must not print twice),
//  * with nothing on the invoice they create nothing and print nothing,
//  * on the finished page they print the invoice again.
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
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/create_invoice_screen_modern.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/services/invoice_pdf_services.dart';
import 'package:invoiceo/widgets/auto_print_after_create_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  var dbCounter = 0;
  final printed = <String>[]; // ids of invoices the app tried to print

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
    tmp = Directory.systemTemp.createTempSync('invoiceo_create_print');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });
  tearDownAll(() async {
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });
  setUp(() {
    printed.clear();
    InvoicePdfServices.printHook = (context, invoice) async {
      printed.add(invoice.id);
    };
  });
  tearDown(() => InvoicePdfServices.printHook = null);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<int> invoiceCount(WidgetTester tester) async =>
      (await tester.runAsync(() async => (await InvoiceService.getAllInvoices()).length))!;

  // Opens a fresh Create Invoice screen on a fresh database. [autoPrint] is
  // the "print automatically after creating" setting (null = never touched).
  Future<void> openScreen(WidgetTester tester, {String? autoPrint}) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('create_print_${dbCounter++}.db');
      await ProductService.insertProduct(Product(
          id: 'a', name: 'Alpha Soap', description: '', price: 11,
          stock: 0, hsncode: '1001', tax_rate: 0, unlimitedStock: true));
      if (autoPrint != null) {
        await BackendServices.settings
            .setSetting(SettingKey.autoPrintAfterCreate, autoPrint);
      }
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
    await tester.enterText(
        find.byKey(const ValueKey('modernCustomerName')), 'mad');
    await tester.pump();
  }

  // Scans the product (hardware keys) and presses Add in its prompt.
  Future<void> addProduct(WidgetTester tester) async {
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
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
        .clearSnackBars();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> pressCreateButton(WidgetTester tester) async {
    final create = find.byKey(const ValueKey('modernCreate'));
    await tester.ensureVisible(create);
    await tester.pump();
    await tester.tap(create);
    await tester.pump();
    await settle(tester);
    await settle(tester);
  }

  Future<void> ctrlP(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await settle(tester);
    await settle(tester);
  }

  Future<void> ctrlS(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await settle(tester);
    await settle(tester);
  }

  // F11, optionally held down so the keyboard sends repeats.
  Future<void> f11(WidgetTester tester, {int repeats = 0}) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.f11);
    for (var i = 0; i < repeats; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.f11);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.f11);
    await tester.pump();
    await settle(tester);
    await settle(tester);
  }

  // The big headline of the Invoice-created page (the snackbar's wording differs).
  final finishedHeadline = find.text('Invoice Created Successfully!');
  void expectFinishedPage() => expect(finishedHeadline, findsOneWidget,
      reason: 'the Invoice-created page is showing');

  testWidgets('Create button creates the invoice AND prints it (default)', (tester) async {
    await openScreen(tester); // setting never touched = on
    await addProduct(tester);
    await pressCreateButton(tester);
    expectFinishedPage();
    expect(await invoiceCount(tester), 1);
    expect(printed, hasLength(1), reason: 'printed exactly once');
  });

  testWidgets('Ctrl+S is the same as the Create button: creates and prints', (tester) async {
    await openScreen(tester);
    await addProduct(tester);
    await ctrlS(tester);
    expectFinishedPage();
    expect(await invoiceCount(tester), 1);
    expect(printed, hasLength(1));
  });

  testWidgets('with the setting off, Create button / Ctrl+S only create', (tester) async {
    await openScreen(tester, autoPrint: 'false');
    await addProduct(tester);
    await pressCreateButton(tester);
    expectFinishedPage();
    expect(await invoiceCount(tester), 1);
    expect(printed, isEmpty, reason: 'user turned auto-print off');
  });

  testWidgets('Ctrl+P creates the invoice and prints it, even with the setting off', (tester) async {
    await openScreen(tester, autoPrint: 'false');
    await addProduct(tester);
    await ctrlP(tester);
    expectFinishedPage();
    expect(await invoiceCount(tester), 1);
    expect(printed, hasLength(1));
  });

  testWidgets('F11 creates the invoice and prints it once, even if the key repeats', (tester) async {
    await openScreen(tester, autoPrint: 'false');
    await addProduct(tester);
    await f11(tester, repeats: 4); // key held down
    expectFinishedPage();
    expect(await invoiceCount(tester), 1, reason: 'one invoice, not one per repeat');
    expect(printed, hasLength(1), reason: 'one print, not one per repeat');
  });

  testWidgets('a held F11 / Ctrl+P that starts repeating AFTER the invoice is created does not print again', (tester) async {
    // On a real keyboard the first repeat arrives ~500 ms after the key goes
    // down, when the invoice is already created and the finished page shows.
    // Without includeRepeats:false that repeat would print a second copy.
    await openScreen(tester, autoPrint: 'false');
    await addProduct(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.f11);
    await settle(tester);
    await settle(tester);
    expectFinishedPage();
    expect(printed, hasLength(1));
    for (var i = 0; i < 4; i++) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.f11);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.f11);
    await settle(tester);
    expect(printed, hasLength(1), reason: 'key repeat never prints');
    expect(await invoiceCount(tester), 1);
  });

  testWidgets('Ctrl+P / F11 with no items create nothing and print nothing', (tester) async {
    await openScreen(tester);
    await ctrlP(tester);
    await f11(tester);
    expect(await invoiceCount(tester), 0);
    expect(printed, isEmpty);
    expect(finishedHeadline, findsNothing);
    expect(find.textContaining('Add at least one item'), findsWidgets,
        reason: 'the user is told why');
  });

  testWidgets('Ctrl+P / F11 without a customer name create nothing and print nothing', (tester) async {
    await openScreen(tester);
    await addProduct(tester);
    await tester.enterText(
        find.byKey(const ValueKey('modernCustomerName')), '');
    await tester.pump();
    await ctrlP(tester);
    await f11(tester);
    expect(await invoiceCount(tester), 0);
    expect(printed, isEmpty);
  });

  testWidgets('on the finished page Ctrl+P and F11 print the invoice again', (tester) async {
    await openScreen(tester, autoPrint: 'false');
    await addProduct(tester);
    await pressCreateButton(tester);
    expectFinishedPage();
    expect(printed, isEmpty);
    await ctrlP(tester);
    expect(printed, hasLength(1));
    await f11(tester);
    expect(printed, hasLength(2));
    expect(await invoiceCount(tester), 1, reason: 'printing again never creates another invoice');
    expect(printed.toSet(), hasLength(1), reason: 'the same invoice');
  });

  testWidgets('editing an invoice: Ctrl+P / F11 save the edit first, then print', (tester) async {
    await openScreen(tester, autoPrint: 'false');
    await addProduct(tester);
    await pressCreateButton(tester);
    expectFinishedPage();
    expect(printed, isEmpty);
    final created = (await tester.runAsync(() async {
      final all = await InvoiceService.getAllInvoices();
      return InvoiceService.getInvoiceById(all.single.id);
    }))!;

    // Open that invoice for editing.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CreateInvoiceScreenModern(invoiceToEdit: created)),
      ),
    ));
    await settle(tester);
    await settle(tester);

    // Nothing changed: Ctrl+P still saves, then prints, once.
    await ctrlP(tester);
    expect(printed, [created.id]);

    // A change made after the last save (the invoice discount): it must be
    // saved before printing, so the paper matches the screen.
    // (the invoice discount is in the "Charges & Adjustments" card: open it)
    await tester.ensureVisible(find.byKey(const ValueKey('modernCharges')));
    await tester.tap(find.byKey(const ValueKey('modernCharges')));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, 'Invoice Discount'), '10');
    await tester.pump();
    await f11(tester);
    expect(printed, [created.id, created.id]);
    final discounted = (await tester.runAsync(
        () => InvoiceService.getInvoiceById(created.id)))!;
    expect(discounted.invoiceDiscountValue, 10,
        reason: 'the discount was saved before the receipt printed');
    expect(discounted.total, lessThan(created.total));

    // Change the customer: Ctrl+P saves the edit first, then prints.
    await tester.enterText(
        find.byKey(const ValueKey('modernCustomerName')), 'madhan');
    await tester.pump();
    await ctrlP(tester);
    expect(printed, [created.id, created.id, created.id]);
    final after = (await tester.runAsync(
        () => InvoiceService.getInvoiceById(created.id)))!;
    expect(after.customer.name, 'madhan', reason: 'the edit was saved before printing');
    expect(await invoiceCount(tester), 1);
  });

  testWidgets('Settings switch: on by default, saves the moment it is flipped', (tester) async {
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('create_print_tile_${dbCounter++}.db');
    });
    await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AutoPrintAfterCreateTile())));
    await settle(tester);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
    expect(await tester.runAsync(InvoicePdfServices.autoPrintAfterCreateEnabled), isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
    expect(await tester.runAsync(InvoicePdfServices.autoPrintAfterCreateEnabled), isFalse);

    // And it is read back as off next time the screen opens.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AutoPrintAfterCreateTile())));
    await settle(tester);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await settle(tester);
    expect(await tester.runAsync(InvoicePdfServices.autoPrintAfterCreateEnabled), isTrue);
  });
}
