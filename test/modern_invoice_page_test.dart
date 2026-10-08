// Modern Create Invoice, the October 2026 page design: title and date (in the
// Modern top bar inside the app), a customer box (name, phone, GSTIN, address;
// closes to the name), items edited right in the table down to the bottom,
// and a right panel (details, advanced options, charges, totals, then Save
// Draft and Create ▾ with "start a new one" and "Save & Print").
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:intl/intl.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/models/invoice_draft.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/database/invoice_draft_service.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/layouts/modern/modern_shell.dart';
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
    tmp = Directory.systemTemp.createTempSync('invoiceo_modern_page');
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
      Future<void> Function()? beforePump,
      VoidCallback? onBack,
      Invoice? cloneFrom,
      String? draftId,
      bool inFrame = false,
      Invoice? Function()? toEdit,
      VoidCallback? onCreateNew,
      void Function(String type)? onGoToList,
      Locale? locale}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('modern_page_${dbCounter++}.db');
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
    final page = CreateInvoiceScreenModern(
        onBack: onBack,
        cloneFrom: cloneFrom,
        draftId: draftId,
        invoiceToEdit: toEdit?.call(),
        onCreateNewInvoice: onCreateNew,
        onGoToList: onGoToList);
    // inFrame: inside the Modern frame (top bar above the page), as in the app.
    final header = ValueNotifier<ModernPageHeader?>(null);
    addTearDown(header.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
            body: !inFrame
                ? page
                : Column(children: [
                    ModernTopBar(
                      username: 'admin',
                      isAdmin: true,
                      onSearch: () {},
                      onCreate: (_) {},
                      onUserAction: (_) {},
                      page: 1,
                      pageTitle: 'New Invoice',
                      header: header,
                    ),
                    Expanded(
                        child: ModernHeaderScope(
                            page: 1, notifier: header, child: page)),
                  ])),
      ),
    ));
    await settle(tester);
  }

  final nameField = find.byKey(const ValueKey('modernCustomerName'));
  final card = find.byKey(const ValueKey('modernCustomerCard'));
  Finder field(String key) => find.byKey(ValueKey(key));
  TextField textBox(WidgetTester tester, String key) =>
      tester.widget<TextField>(field(key));
  Finder onCard(String t) => find.descendant(of: card, matching: find.textContaining(t));

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
    // "Add" (the dialog's last button, whatever the language).
    await tester.tap(find
        .descendant(of: find.byType(AlertDialog), matching: find.bySubtype<ButtonStyleButton>())
        .last);
    await tester.pump();
    await settle(tester);
  }

  Future<int> invoiceCount(WidgetTester tester) async =>
      (await tester.runAsync(() async => (await InvoiceService.getAllInvoices()).length))!;
  Future<int> draftCount(WidgetTester tester) async =>
      (await tester.runAsync(() => InvoiceDraftService.countDrafts('Invoice')))!;


  group('header', () {
    testWidgets('title, subtitle and date; no back arrow and no number chip', (tester) async {
      await open(tester, onBack: () {});
      expect(find.text('Create New Invoice'), findsOneWidget);
      expect(find.text('Add the customer, items and billing details.'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('modernHeaderDate')),
          matching: find.text(DateFormat('dd MMM yyyy').format(DateTime.now()))), findsOneWidget);
      expect(find.byKey(const ValueKey('modernBack')), findsNothing);
      expect(find.byKey(const ValueKey('modernHeaderNumber')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in the app frame: title and date are in the top bar, no search box', (tester) async {
      await open(tester, inFrame: true);
      final topBar = find.byKey(const ValueKey('modernTopBar'));
      expect(find.descendant(of: topBar, matching: find.text('Create New Invoice')), findsOneWidget);
      expect(find.text('Create New Invoice'), findsOneWidget, reason: 'not again on the page');
      expect(find.descendant(of: topBar, matching: find.byKey(const ValueKey('modernHeaderDate'))),
          findsOneWidget);
      expect(find.byKey(const ValueKey('modernSearch')), findsNothing);
      expect(find.byType(PopupMenuButton<ModernCreate>), findsOneWidget,
          reason: 'a new invoice keeps the + menu');
      expect(tester.takeException(), isNull);
    });

    testWidgets('editing an invoice: "+ Create Invoice" in the top bar instead of +', (tester) async {
      Invoice? saved;
      var started = 0;
      await open(tester, inFrame: true, onCreateNew: () => started++, beforePump: () async {
        final p = Product(id: 'e1', name: 'Edit Rice', description: '', price: 40, stock: 0,
            hsncode: '8001', tax_rate: 0, unlimitedStock: true);
        await InvoiceService.insertInvoice(Invoice(
            id: '00000009', invoiceNumber: '00000009', type: 'Invoice',
            customer: Customer(id: '', name: 'Old Buyer', email: '', phone: '', address: '', gstin: ''),
            items: [InvoiceItem(product: p, quantity: 1)], date: DateTime(2026, 10, 1)));
        saved = await InvoiceService.getInvoiceById('00000009');
      }, toEdit: () => saved);
      expect(find.byType(PopupMenuButton<ModernCreate>), findsNothing);
      final create = find.byKey(const ValueKey('modernCreateDocument'));
      expect(create, findsOneWidget);
      expect(find.descendant(of: create, matching: find.text('Create Invoice')), findsOneWidget);
      await tester.tap(create);
      await settle(tester);
      expect(started, 1);
    });
  });

  group('customer', () {
    testWidgets('name, phone, GSTIN and address boxes; Save customer adds a new one', (tester) async {
      await open(tester);
      expect(find.text("Search customer or type a walk-in customer's name..."), findsOneWidget);
      for (final k in ['modernCustomerPhone', 'modernCustomerGstin', 'modernCustomerAddress']) {
        expect(field(k), findsOneWidget, reason: k);
      }
      expect(find.byKey(const ValueKey('modernAddCustomer')), findsNothing, reason: 'no Add New dialog');
      await tester.enterText(nameField, 'Selvi Stores');
      await tester.pump();
      expect(field('modernCustomerPhone'), findsOneWidget, reason: 'details open while typing a walk-in');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Save customer'), findsOneWidget, reason: 'a new customer is saved, not updated');
      await tester.enterText(field('modernCustomerPhone'), '9000000002');
      await tester.enterText(field('modernCustomerGstin'), '33AAAAA0000A1Z5');
      await tester.enterText(field('modernCustomerAddress'), '5, Car Street, Madurai');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('modernSaveCustomer')));
      await settle(tester);
      final all = await tester.runAsync(CustomerService.getAllCustomers);
      final c = all!.singleWhere((c) => c.name == 'Selvi Stores');
      expect(c.phone, '9000000002');
      expect(c.gstin, '33AAAAA0000A1Z5');
      expect(c.address, '5, Car Street, Madurai');
      expect(find.byKey(const ValueKey('modernSaveCustomer')), findsNothing, reason: 'saved');
    });

    testWidgets('clicking the customer box opens the details; picking a customer opens them too',
        (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('customerStripToggle')));
      await tester.pump();
      expect(field('modernCustomerPhone'), findsNothing, reason: 'closed with the arrow');
      await tester.tap(nameField);
      await tester.pump();
      expect(field('modernCustomerPhone'), findsOneWidget, reason: 'a click on the box opens them');

      await tester.enterText(nameField, 'Ma');
      await settle(tester);
      final list = find.byKey(const ValueKey('customerSuggestionList'));
      await tester.tap(find.descendant(of: list, matching: find.text('Mala')));
      await settle(tester);
      expect(textBox(tester, 'modernCustomerPhone').controller!.text, '2222222222');

      // Closed by the product search, a click on the picked name opens them
      // again — with no search list over them.
      await tester.tap(find.widgetWithText(TextField, 'Search & add a product or service (Ctrl+F)'));
      await settle(tester);
      expect(field('modernCustomerPhone'), findsNothing);
      await tester.tap(nameField);
      await settle(tester);
      expect(field('modernCustomerPhone'), findsOneWidget);
      expect(find.byKey(const ValueKey('customerSuggestionList')), findsNothing);
    });

    testWidgets('going to the product search closes the customer details', (tester) async {
      await open(tester);
      await tester.tap(nameField);
      await tester.enterText(nameField, 'Mad');
      await settle(tester);
      final list = find.byKey(const ValueKey('customerSuggestionList'));
      await tester.tap(find.descendant(of: list, matching: find.text('Madhan')));
      await settle(tester);
      expect(field('modernCustomerPhone'), findsOneWidget, reason: 'open after the pick');

      final search = find.widgetWithText(TextField, 'Search & add a product or service (Ctrl+F)');
      await tester.tap(search);
      await settle(tester);
      expect(field('modernCustomerPhone'), findsNothing, reason: 'closed while adding items');
      expect(textBox(tester, 'modernCustomerName').controller!.text, 'Madhan');

      // Typing a walk-in name and going straight to the product search: it
      // stays closed too.
      await tester.tap(find.byKey(const ValueKey('modernClearCustomer')));
      await settle(tester);
      await tester.tap(nameField);
      await tester.enterText(nameField, 'Walk In');
      await tester.pump();
      await tester.tap(search);
      await settle(tester);
      expect(field('modernCustomerPhone'), findsNothing);
    });

    testWidgets('the arrow opens and closes the details by hand', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('customerStripToggle')));
      await tester.pump();
      expect(field('modernCustomerPhone'), findsNothing);
      expect(nameField, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('customerStripToggle')));
      await tester.pump();
      expect(field('modernCustomerPhone'), findsOneWidget);
    });

    testWidgets('a picked customer can be changed straight away and updated; X clears', (tester) async {
      await open(tester);
      await tester.tap(nameField);
      await tester.enterText(nameField, 'Mad');
      await settle(tester);
      final list = find.byKey(const ValueKey('customerSuggestionList'));
      await tester.tap(find.descendant(of: list, matching: find.text('Madhan')));
      await settle(tester);
      expect(textBox(tester, 'modernCustomerPhone').controller!.text, '1111111111');
      expect(textBox(tester, 'modernCustomerPhone').readOnly, isFalse, reason: 'editable, no pencil');
      expect(find.byKey(const ValueKey('modernEditCustomer')), findsNothing);
      expect(find.byKey(const ValueKey('modernSaveCustomer')), findsNothing, reason: 'nothing changed yet');

      // Address changed: "Update customer" saves it to Madhan, no question.
      await tester.enterText(field('modernCustomerAddress'), '7, North Street');
      await tester.pump();
      expect(find.text('Update customer'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('modernSaveCustomer')));
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      var c = (await tester.runAsync(CustomerService.getAllCustomers))!.singleWhere((c) => c.id == 'c1');
      expect(c.address, '7, North Street');
      expect((await tester.runAsync(CustomerService.getAllCustomers))!.length, 3, reason: 'no new customer');

      // Phone changed: it asks first (update this customer or save a new one).
      await tester.enterText(field('modernCustomerPhone'), '1234567890');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('modernSaveCustomer')));
      await settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Update Existing'));
      await settle(tester);
      c = (await tester.runAsync(CustomerService.getAllCustomers))!.singleWhere((c) => c.id == 'c1');
      expect(c.phone, '1234567890');

      await tester.tap(find.byKey(const ValueKey('modernClearCustomer')));
      await settle(tester);
      expect(textBox(tester, 'modernCustomerName').controller!.text, isEmpty);
      expect(textBox(tester, 'modernCustomerPhone').controller!.text, isEmpty);
    });
  });

  group('items', () {
    testWidgets('quantity, price and discount are edited right in the table', (tester) async {
      await open(tester);
      await addProduct(tester, '2001'); // Apple 1, price 11
      final row = find.byKey(const ValueKey('itemRow0'));
      await tester.enterText(find.byKey(const ValueKey('qty_0')), '3');
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('price_0')), '15');
      await tester.pump();
      expect(find.descendant(of: row, matching: find.textContaining('45.00')), findsOneWidget,
          reason: '3 × 15');
      await tester.enterText(find.byKey(const ValueKey('disc_0')), '5');
      await tester.pump();
      // The discount works as before: per unit when "discount per unit" is on
      // (the default), so 3 × (15 − 5).
      expect(find.descendant(of: row, matching: find.textContaining('30.00')), findsOneWidget,
          reason: '3 × (15 − 5)');
      expect(tester.takeException(), isNull);
      await settle(tester); // let the search box's focus timer finish
    });

    testWidgets("changes made in the row's edit dialog show in the boxes", (tester) async {
      await open(tester);
      await addProduct(tester, '2001');
      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('itemRow0')), matching: find.byIcon(Icons.edit_outlined)));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextField, 'Quantity')),
          '7');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Update')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('qty_0'))).controller!.text, '7');
    });

    testWidgets('the unit is chosen in the table', (tester) async {
      await open(tester);
      await addProduct(tester, '2001');
      await tester.tap(find.byKey(const ValueKey('unit_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('kg').last);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byKey(const ValueKey('unit_0')), matching: find.text('kg')),
          findsOneWidget);
    });

    testWidgets('Clear All asks first, then empties the table', (tester) async {
      await open(tester);
      await addProduct(tester, '2001');
      await addProduct(tester, '3001');
      expect(find.byKey(const ValueKey('itemRow1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('modernClearAll')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Clear All')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('itemRow0')), findsNothing);
      expect(find.byKey(const ValueKey('modernClearAll')), findsNothing);
    });

    testWidgets('no "Add another item" button under the table', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('modernAddAnotherItem')), findsNothing);
      expect(find.text('Add another item'), findsNothing);
    });
  });

  group('right panel', () {
    testWidgets('details, Advanced Options and Charges & Adjustments open and close', (tester) async {
      await open(tester);
      expect(find.text('Invoice Details'), findsOneWidget);
      expect(find.text('TAX SETTINGS'), findsNothing, reason: 'advanced options start closed');
      await tester.tap(find.byKey(const ValueKey('modernAdvancedOptions')));
      await tester.pump();
      expect(find.text('TAX SETTINGS'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Invoice Discount'), findsNothing,
          reason: 'charges start closed when nothing is filled in');
      await tester.ensureVisible(find.byKey(const ValueKey('modernCharges')));
      await tester.tap(find.byKey(const ValueKey('modernCharges')));
      await tester.pump();
      expect(find.widgetWithText(TextField, 'Invoice Discount'), findsOneWidget);
    });
  });

  group('bottom bar', () {
    testWidgets('no status card; Create is off until there is an item', (tester) async {
      await open(tester);
      expect(find.byKey(const ValueKey('modernStatus')), findsNothing);
      expect(find.text('Add a customer'), findsNothing);
      expect(tester.widget<InkWell>(find.byKey(const ValueKey('modernCreate'))).onTap, isNull);
      await tester.enterText(nameField, 'Walk In');
      await tester.pump();
      await addProduct(tester, '2001');
      expect(tester.widget<InkWell>(find.byKey(const ValueKey('modernCreate'))).onTap, isNotNull);
    });

    testWidgets('Save Draft keeps a draft (no invoice); creating it removes the draft', (tester) async {
      await open(tester);
      await tester.enterText(nameField, 'Walk In');
      await tester.pump();
      await addProduct(tester, '2001');
      await tester.tap(find.byKey(const ValueKey('modernSaveDraft')));
      await settle(tester);
      expect(find.text('Draft saved'), findsOneWidget);
      expect(await draftCount(tester), 1);
      expect(await invoiceCount(tester), 0, reason: 'a draft is not an invoice');

      // saving again updates the same draft
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('qty_0')), '4');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('modernSaveDraft')));
      await settle(tester);
      expect(await draftCount(tester), 1);
      final draft = (await tester.runAsync(() => InvoiceDraftService.getDrafts('Invoice')))!.single;
      expect(draft.invoice.items.single.quantity, 4);

      InvoicePdfServices.printHook = (c, i) async {};
      addTearDown(() => InvoicePdfServices.printHook = null);
      await tester.tap(find.byKey(const ValueKey('modernCreate')));
      await settle(tester);
      await settle(tester);
      expect(await invoiceCount(tester), 1);
      expect(await draftCount(tester), 0, reason: 'the draft became the invoice');
    });

    testWidgets('leaving with unsaved changes: "Save Draft" in the popup keeps a draft and leaves',
        (tester) async {
      await open(tester); // database and products
      await tester.pumpWidget(ProviderScope(
        overrides: sqliteRepositoryOverrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(ctx, MaterialPageRoute(
                    builder: (_) => const Scaffold(body: CreateInvoiceScreenModern()))),
                child: const Text('open form'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open form'));
      await settle(tester);
      await settle(tester);
      await tester.enterText(nameField, 'Walk In');
      await tester.pump();
      await addProduct(tester, '2001');

      tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
      await settle(tester);
      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(find.byKey(const ValueKey('leaveSaveDraft')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('leaveSaveDraft')));
      await settle(tester);
      await settle(tester);
      expect(await draftCount(tester), 1);
      expect(await invoiceCount(tester), 0);
      expect(find.text('open form'), findsOneWidget, reason: 'left the form');
    });

    testWidgets('an empty form is not saved as a draft', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('modernSaveDraft')));
      await settle(tester);
      expect(await draftCount(tester), 0);
    });

    testWidgets('a draft opens exactly as saved and is removed once created', (tester) async {
      final draftInvoice = Invoice(
          id: '',
          type: 'Invoice',
          customer: Customer(id: '', name: 'Draft Kumar', email: '', phone: '9999', address: '', gstin: ''),
          items: [],
          date: DateTime(2026, 9, 3, 10, 30),
          dueDate: DateTime(2026, 9, 20));
      await tester.runAsync(() async {
        await DatabaseHelper().switchToFile('modern_page_${dbCounter++}.db');
      });
      // a product to put in the draft
      final p = Product(id: 'dp', name: 'Draft Rice', description: '', price: 50, stock: 0,
          hsncode: '9001', tax_rate: 0, unlimitedStock: true);
      draftInvoice.items = [InvoiceItem(product: p, quantity: 2)];
      await open(tester, cloneFrom: draftInvoice, draftId: 'd-1', beforePump: () async {
        await InvoiceDraftService.saveDraft(
            InvoiceDraft(id: 'd-1', invoice: draftInvoice, updatedAt: DateTime.now()));
      });
      expect(find.text('Create New Invoice'), findsOneWidget, reason: 'not "Duplicate as"');
      expect(onCard('Draft Kumar'), findsOneWidget);
      expect(find.text('Draft Rice'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('modernHeaderDate')),
          matching: find.text('03 Sep 2026')), findsOneWidget, reason: 'the draft keeps its date');

      InvoicePdfServices.printHook = (c, i) async {};
      addTearDown(() => InvoicePdfServices.printHook = null);
      await tester.tap(find.byKey(const ValueKey('modernCreate')));
      await settle(tester);
      await settle(tester);
      expect(await invoiceCount(tester), 1);
      expect((await tester.runAsync(() => InvoiceDraftService.getDraft('d-1'))), isNull);
    });

    testWidgets('auto-print on (the default): Create ▾ has no Save & Print', (tester) async {
      await open(tester);
      await tester.enterText(nameField, 'Walk In');
      await tester.pump();
      await addProduct(tester, '2001');
      await tester.tap(find.byKey(const ValueKey('modernCreateDropdown')));
      await tester.pumpAndSettle();
      expect(find.text('Create and start a new one'), findsOneWidget);
      expect(find.text('Save & Print'), findsNothing,
          reason: 'Create already prints when auto-print is on');
    });

    testWidgets('Create ▾ has two choices: start a new one, and Save & Print', (tester) async {
      final printed = <String>[];
      InvoicePdfServices.printHook = (c, i) async => printed.add(i.id);
      addTearDown(() => InvoicePdfServices.printHook = null);
      await open(tester,
          beforePump: () => BackendServices.settings
              .setSetting(SettingKey.autoPrintAfterCreate, 'false'));
      // (the menu wakes up once there is something to save)
      await tester.enterText(nameField, 'Walk In');
      await tester.pump();
      await addProduct(tester, '2001');
      await tester.tap(find.byKey(const ValueKey('modernCreateDropdown')));
      await tester.pumpAndSettle();
      expect(find.text('Create and start a new one'), findsOneWidget);
      expect(find.text('Save & Print'), findsOneWidget);
      expect(find.text('Create and preview'), findsNothing);
      await tester.tap(find.text('Save & Print'));
      await settle(tester);
      await settle(tester);
      expect(await invoiceCount(tester), 1);
      expect(printed, hasLength(1));
    });

    testWidgets('"Create and start a new one" creates it and clears the form', (tester) async {
      final printed = <String>[];
      InvoicePdfServices.printHook = (c, i) async => printed.add(i.id);
      addTearDown(() => InvoicePdfServices.printHook = null);
      await open(tester);
      await tester.enterText(nameField, 'Walk In');
      await tester.pump();
      await addProduct(tester, '2001');
      await tester.tap(find.byKey(const ValueKey('modernCreateDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create and start a new one'));
      await settle(tester);
      await settle(tester);
      expect(await invoiceCount(tester), 1);
      expect(find.byKey(const ValueKey('itemRow0')), findsNothing, reason: 'a fresh form');
      expect(tester.widget<TextField>(nameField).controller!.text, isEmpty);
      expect(find.text('Create New Invoice'), findsOneWidget);
    });

    testWidgets('narrow and Tamil-length windows: no overflow', (tester) async {
      for (final size in [const Size(1366, 768), const Size(1100, 700), const Size(900, 800)]) {
        await open(tester, size: size);
        await addProduct(tester, '2001');
        expect(tester.takeException(), isNull, reason: '$size');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('created screen', () {
    Future<void> createOne(WidgetTester tester) async {
      InvoicePdfServices.printHook = (c, i) async {};
      addTearDown(() => InvoicePdfServices.printHook = null);
      await tester.enterText(nameField, 'Walk In');
      await tester.pump();
      await addProduct(tester, '2001');
      await tester.tap(find.byKey(const ValueKey('modernCreate')));
      await settle(tester);
      await settle(tester);
    }

    testWidgets('tick, number with copy, four one-line tiles, Go to Invoices and Create New Invoice',
        (tester) async {
      final lists = <String>[];
      final previewed = <String>[];
      InvoicePdfServices.previewHook = (c, i) async => previewed.add(i.id);
      addTearDown(() => InvoicePdfServices.previewHook = null);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
          (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await open(tester, onGoToList: lists.add);
      await createOne(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('modernSuccess')), findsOneWidget);
      expect(find.byKey(const ValueKey('modernSuccessBadge')), findsOneWidget);
      expect(find.text('Invoice Created Successfully!'), findsOneWidget);
      expect(find.text('The invoice has been saved and is ready to use.'), findsOneWidget);
      final id = find.byKey(const ValueKey('modernSuccessId'));
      expect(find.descendant(of: id, matching: find.text('Invoice ID')), findsOneWidget);
      final number = (await tester.runAsync(InvoiceService.getAllInvoices))!.single.invoiceNumber;
      expect(find.descendant(of: id, matching: find.text('#$number')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('modernSuccessCopy')));
      await tester.pump();
      expect(copied, number);

      for (final k in ['modernSuccessView', 'modernSuccessPreview', 'modernSuccessDownload',
          'modernSuccessPrint']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(find.text('Print Invoice'), findsOneWidget);
      expect(find.text('Open invoice'), findsNothing, reason: 'no second lines on the tiles');
      expect(find.text('Send to printer'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('modernSuccessPreview')));
      await settle(tester);
      expect(previewed, hasLength(1));

      // Two buttons for this document type: Go to Invoices | Create New Invoice.
      final goTo = find.byKey(const ValueKey('modernSuccessGoToList'));
      final newInvoice = find.byKey(const ValueKey('modernSuccessNewInvoice'));
      expect(find.byKey(const ValueKey('modernSuccessNewReceipt')), findsNothing);
      expect(find.descendant(of: goTo, matching: find.text('Go to Invoices')), findsOneWidget);
      expect(find.descendant(of: newInvoice, matching: find.text('Create New Invoice')), findsOneWidget);
      expect(find.text('Ctrl + N'), findsNothing, reason: 'the shortcut is in the tooltip');
      expect(find.byTooltip('Ctrl + N'), findsOneWidget);
      expect(tester.getRect(goTo).right, lessThan(tester.getRect(newInvoice).left));

      await tester.tap(goTo);
      expect(lists, ['Invoice']);

      await tester.tap(newInvoice);
      await settle(tester);
      expect(find.byKey(const ValueKey('modernSuccess')), findsNothing);
      expect(find.text('Create New Invoice'), findsOneWidget, reason: 'a fresh invoice form');
    });

    testWidgets('Ctrl+N starts a new invoice; the top bar has the title with a back arrow',
        (tester) async {
      final lists = <String>[];
      await open(tester, inFrame: true, onGoToList: lists.add);
      await createOne(tester);
      final topBar = find.byKey(const ValueKey('modernTopBar'));
      expect(find.descendant(of: topBar, matching: find.text('Invoice Created')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('modernHeaderBack')));
      expect(lists, ['Invoice']);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await settle(tester);
      expect(find.byKey(const ValueKey('modernSuccess')), findsNothing);
      expect(find.descendant(of: topBar, matching: find.text('Create New Invoice')), findsOneWidget);
    });

    testWidgets('no overflow: narrow, short and Tamil windows', (tester) async {
      for (final (size, locale) in [
        (const Size(1366, 768), null),
        (const Size(900, 600), null),
        (const Size(560, 700), null),
        (const Size(1280, 800), const Locale('ta')),
      ]) {
        await open(tester, size: size, locale: locale);
        await createOne(tester);
        expect(find.byKey(const ValueKey('modernSuccess')), findsOneWidget, reason: '$size');
        expect(tester.takeException(), isNull, reason: '$size $locale');
        await tester.pumpWidget(const SizedBox());
      }
    });
  });
}
