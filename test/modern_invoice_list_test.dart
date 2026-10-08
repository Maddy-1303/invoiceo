// The Modern layout's Invoices / Quotations / Receipts page: tabs (All /
// Drafts), the filter row (search, Customer ▾, Filter ▾, Sort ▾, Columns ▾),
// the table (eye = PDF preview, edit, ⋮ with payment, download and the
// rest). Title, subtitle and the export buttons are in the top bar.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_draft_service.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/database/payment_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/layouts/modern/modern_shell.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_draft.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/models/user.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/invoice_management_screen_v2.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/services/invoice_pdf_services.dart';
import 'package:invoiceo/widgets/apply_payment_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  final previewed = <String>[];

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    BackendServices.configure(
      settings: SqliteSettingsRepository(),
      companyInfo: SqliteCompanyInfoRepository(),
      invoices: SqliteInvoiceRepository(),
      payments: SqlitePaymentRepository(),
      installation: SqliteInstallationRepository(),
    );
    tmp = Directory.systemTemp.createTempSync('invoiceo_modern_list');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
    InvoicePdfServices.previewHook = (_, invoice) async => previewed.add(invoice.id);

    // i1 unpaid and past due, i2 paid, i3 partly paid, i4 unpaid (no due
    // date), plus one quotation.
    await DatabaseHelper().switchToFile('modern_list.db');
    final p = Product(id: 'a', name: 'Alpha', description: '', price: 10,
        stock: 0, hsncode: '1', tax_rate: 0, unlimitedStock: true);
    Invoice mk(String id, int day, {String type = 'Invoice', DateTime? due}) => Invoice(
          id: id, invoiceNumber: id,
          customer: Customer(id: 'c', name: 'Madhan', email: '', phone: '', address: '', gstin: ''),
          items: [InvoiceItem(product: p, quantity: 1)],
          date: DateTime(2026, 10, day), type: type, taxRate: 0,
          taxMode: TaxMode.none, currencyCode: 'INR', currencySymbol: 'Rs.',
          dueDate: due,
        );
    await InvoiceService.insertInvoice(mk('00000001', 4, due: DateTime(2026, 1, 15)));
    await InvoiceService.insertInvoice(mk('00000002', 3));
    await InvoiceService.insertInvoice(mk('00000003', 2));
    await InvoiceService.insertInvoice(mk('00000004', 1));
    await InvoiceService.insertInvoice(mk('Q0000001', 5, type: 'Quotation'));
    await PaymentService.addPayment(
        invoice: (await InvoiceService.getInvoiceById('00000002'))!,
        amountPaid: 10,
        datePaid: DateTime(2026, 10, 3));
    await PaymentService.addPayment(
        invoice: (await InvoiceService.getInvoiceById('00000003'))!,
        amountPaid: 4,
        datePaid: DateTime(2026, 10, 3));
  });
  tearDownAll(() async {
    InvoicePdfServices.previewHook = null;
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });
  setUp(previewed.clear);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpList(WidgetTester tester,
      {bool modern = true,
      String type = 'Invoice',
      Locale? locale,
      Size size = const Size(1440, 900),
      void Function(InvoiceDraft)? onOpenDraft,
      void Function(Invoice)? onEdit}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvoiceManagementScreenV2(
          key: UniqueKey(),
          modern: modern,
          filterType: type,
          user: User(id: 'u', username: 'admin', password: '', userType: 'admin'),
          onEditInvoice: onEdit ?? (_) {},
          onCloneInvoice: (_, __) {},
          onOpenDraft: onOpenDraft,
        ),
      ),
    ));
    await settle(tester);
    await settle(tester);
  }

  double rowY(WidgetTester tester, String number) =>
      tester.getTopLeft(find.text('#$number')).dy;

  Future<void> pickFromMenu(WidgetTester tester, String button, String item) async {
    await tester.tap(find.byKey(ValueKey(button)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await settle(tester);
  }

  testWidgets('tabs, filter row and table; no stat cards and no eye toggle', (tester) async {
    await pumpList(tester, onOpenDraft: (_) {});
    expect(tester.takeException(), isNull);

    expect(find.text('All Invoices (4)'), findsOneWidget);
    expect(find.text('Drafts (0)'), findsOneWidget);
    expect(find.byKey(const ValueKey('modernStats')), findsNothing);
    expect(find.byKey(const ValueKey('modernStatsToggle')), findsNothing);
    for (final k in ['modernListSearch', 'modernCustomerFilter', 'modernFilterMenu',
        'modernSort', 'modernColumns']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    expect(find.byKey(const ValueKey('modernChip_all')), findsNothing, reason: 'no status chips');
    expect(find.byKey(const ValueKey('modernTable')), findsOneWidget);
    expect(find.text('Page 1 of 1'), findsOneWidget);

    // Rows per page and Next sit inside the card's edges, not on them.
    final card = tester.getRect(find.byKey(const ValueKey('modernTable')));
    final rows = tester.getRect(find.text('Rows per page:'));
    final next = tester.getRect(find.ancestor(
        of: find.text('Next'), matching: find.bySubtype<OutlinedButton>()));
    expect(rows.left - card.left, greaterThanOrEqualTo(16));
    expect(card.right - next.right, greaterThanOrEqualTo(12));
    expect(card.bottom - next.bottom, greaterThanOrEqualTo(8));
  });

  testWidgets('Filter ▾: status filters the list; the button shows the count; Clear resets',
      (tester) async {
    await pumpList(tester);
    expect(find.text('#00000001'), findsOneWidget);

    await pickFromMenu(tester, 'modernFilterMenu', 'Paid');
    expect(find.text('#00000002'), findsOneWidget);
    expect(find.text('#00000001'), findsNothing);
    expect(find.text('Filter (1)'), findsOneWidget);

    await pickFromMenu(tester, 'modernFilterMenu', 'Overdue');
    expect(find.text('#00000001'), findsOneWidget);
    expect(find.text('#00000002'), findsNothing);

    await pickFromMenu(tester, 'modernFilterMenu', 'Partial');
    expect(find.text('#00000003'), findsOneWidget);
    expect(find.text('#00000001'), findsNothing);

    await pickFromMenu(tester, 'modernFilterMenu', 'Clear');
    expect(find.text('#00000001'), findsOneWidget);
    expect(find.text('#00000004'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
  });

  testWidgets('Filter ▾: dates', (tester) async {
    await pumpList(tester);
    // "Today" has no invoices (they are dated 1–4 October 2026).
    await pickFromMenu(tester, 'modernFilterMenu', 'Today');
    expect(find.text('#00000001'), findsNothing);
    expect(tester.takeException(), isNull);
    await pickFromMenu(tester, 'modernFilterMenu', 'All dates');
    expect(find.text('#00000001'), findsOneWidget);
  });

  testWidgets('Sort ▾ and the Date header change the order', (tester) async {
    await pumpList(tester);
    // Default: newest number first.
    expect(rowY(tester, '00000004'), lessThan(rowY(tester, '00000001')));
    await tester.tap(find.byKey(const ValueKey('modernSort')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckedPopupMenuItem<int>), findsNWidgets(6));
    await tester.tap(find.byType(CheckedPopupMenuItem<int>).at(1)); // oldest number first
    await settle(tester);
    expect(rowY(tester, '00000001'), lessThan(rowY(tester, '00000004')));

    await tester.tap(find.byKey(const ValueKey('modernDateSort')));
    await settle(tester);
    // Newest date first: i1 is 4 Oct, i4 is 1 Oct.
    expect(rowY(tester, '00000001'), lessThan(rowY(tester, '00000004')));
    await tester.tap(find.byKey(const ValueKey('modernDateSort')));
    await settle(tester);
    expect(rowY(tester, '00000004'), lessThan(rowY(tester, '00000001')));
  });

  testWidgets('Columns ▾ hides a column and remembers it', (tester) async {
    await pumpList(tester);
    final header = find.byKey(const ValueKey('modernTable'));
    expect(find.descendant(of: header, matching: find.text('Outstanding')), findsOneWidget);
    await pickFromMenu(tester, 'modernColumns', 'Outstanding');
    expect(find.descendant(of: header, matching: find.text('Outstanding')), findsNothing);
    final saved = await tester.runAsync(() =>
        SqliteSettingsRepository().getSetting(SettingKey.invoiceListHiddenColumns));
    expect(saved, 'outstanding');

    await pumpList(tester);
    expect(find.descendant(of: header, matching: find.text('Outstanding')), findsNothing,
        reason: 'remembered');
    await pickFromMenu(tester, 'modernColumns', 'Outstanding');
    expect(find.descendant(of: header, matching: find.text('Outstanding')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('row eye opens the PDF preview, not the details dialog', (tester) async {
    await pumpList(tester);
    await tester.tap(find.byKey(const ValueKey('rowView_00000001')));
    await settle(tester);
    expect(previewed, ['00000001']);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('row buttons: eye, edit and ⋮ (payment, download, print... inside)',
      (tester) async {
    Invoice? edited;
    await pumpList(tester, onEdit: (i) => edited = i);
    for (final k in ['rowView', 'rowEdit', 'rowMenu']) {
      expect(find.byKey(ValueKey('${k}_00000004')), findsOneWidget, reason: k);
    }
    expect(find.byKey(const ValueKey('rowPay_00000004')), findsNothing);
    expect(find.byKey(const ValueKey('rowDownload_00000004')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('rowEdit_00000004')));
    await settle(tester);
    expect(edited?.id, '00000004');

    await tester.tap(find.byKey(const ValueKey('rowMenu_00000004')));
    await tester.pumpAndSettle();
    for (final t in ['Apply Payment', 'Download PDF', 'Print', 'Duplicate', 'Move to Trash']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('PDF Preview'), findsNothing, reason: 'the eye is the preview');
    expect(find.text('View'), findsNothing);
    await tester.tap(find.text('Apply Payment'));
    await settle(tester);
    expect(find.byType(ApplyPaymentDialog), findsOneWidget);
  });

  testWidgets('Drafts tab lists the drafts; Continue opens one, delete removes it',
      (tester) async {
    final draft = Invoice(
        id: '', type: 'Invoice',
        customer: Customer(id: '', name: 'Draft Kumar', email: '', phone: '', address: '', gstin: ''),
        items: [InvoiceItem(product: Product(id: 'dp', name: 'Rice', description: '', price: 50,
            stock: 0, hsncode: '9', tax_rate: 0, unlimitedStock: true), quantity: 2)],
        date: DateTime(2026, 10, 6));
    await tester.runAsync(() => InvoiceDraftService.saveDraft(
        InvoiceDraft(id: 'd-1', invoice: draft, updatedAt: DateTime(2026, 10, 6, 9, 30))));
    final opened = <String>[];
    await pumpList(tester, onOpenDraft: (d) => opened.add(d.id));
    expect(find.text('Drafts (1)'), findsOneWidget);
    expect(find.text('Draft Kumar'), findsNothing, reason: 'drafts are in their own tab');

    await tester.tap(find.byKey(const ValueKey('modernTabDrafts')));
    await settle(tester);
    expect(find.byKey(const ValueKey('modernDraftsTable')), findsOneWidget);
    expect(find.text('Draft Kumar'), findsOneWidget);
    expect(find.byKey(const ValueKey('modernFilterRow')), findsNothing);
    expect(find.text('#00000001'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('draftContinue_d-1')));
    expect(opened, ['d-1']);

    await tester.tap(find.byKey(const ValueKey('draftDelete_d-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete')));
    await settle(tester);
    expect(find.text('Drafts (0)'), findsOneWidget);
    expect(find.byKey(const ValueKey('modernDraftsEmpty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('modernTabAll')));
    await settle(tester);
    expect(find.text('#00000001'), findsOneWidget);
  });

  testWidgets('Quotations: All Quotations tab; dates only in Filter ▾', (tester) async {
    await pumpList(tester, type: 'Quotation');
    expect(tester.takeException(), isNull);
    expect(find.text('All Quotations (1)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('modernFilterMenu')));
    await tester.pumpAndSettle();
    expect(find.text('Paid'), findsNothing, reason: 'no payment status for quotations');
    expect(find.text('All dates'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rowView_Q0000001')), findsOneWidget);
  });

  testWidgets('Standard page is unchanged', (tester) async {
    await pumpList(tester, modern: false);
    expect(find.byKey(const ValueKey('modernTabs')), findsNothing);
    expect(find.byKey(const ValueKey('modernFilterRow')), findsNothing);
    expect(find.byKey(const ValueKey('rowView_00000001')), findsNothing);
    expect(find.text('#00000001'), findsOneWidget);
  });

  testWidgets('in the app frame: title, buttons and "+ Create Invoice" are in the top bar',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final header = ValueNotifier<ModernPageHeader?>(null);
    addTearDown(header.dispose);
    final created = <String>[];
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(children: [
            ModernTopBar(
              username: 'admin',
              isAdmin: true,
              onSearch: () {},
              onCreate: (_) {},
              onUserAction: (_) {},
              page: 2,
              pageTitle: 'Invoices',
              header: header,
            ),
            Expanded(
              child: ModernHeaderScope(
                page: 2,
                notifier: header,
                child: InvoiceManagementScreenV2(
                  modern: true,
                  user: User(id: 'u', username: 'admin', password: '', userType: 'admin'),
                  onEditInvoice: (_) {},
                  onCloneInvoice: (_, __) {},
                  onCreateNew: created.add,
                ),
              ),
            ),
          ]),
        ),
      ),
    ));
    await settle(tester);
    await settle(tester);
    expect(tester.takeException(), isNull);

    final topBar = find.byKey(const ValueKey('modernTopBar'));
    Finder inBar(Finder f) => find.descendant(of: topBar, matching: f);
    expect(inBar(find.text('Invoices')), findsOneWidget);
    expect(inBar(find.text('Manage, search and track all your invoices')), findsOneWidget);
    expect(find.text('Invoices'), findsOneWidget, reason: 'not again on the page');
    expect(inBar(find.byTooltip('Trash')), findsOneWidget);
    expect(find.byKey(const ValueKey('modernStatsToggle')), findsNothing);
    expect(find.byKey(const ValueKey('modernSearch')), findsNothing);
    expect(find.byType(PopupMenuButton<ModernCreate>), findsNothing);
    final create = inBar(find.byKey(const ValueKey('modernCreateDocument')));
    expect(create, findsOneWidget);
    expect(find.descendant(of: create, matching: find.text('Create Invoice')), findsOneWidget);
    await tester.tap(create);
    expect(created, ['Invoice']);
  });

  testWidgets('no overflow: narrow window and Tamil', (tester) async {
    await pumpList(tester, size: const Size(900, 800), onOpenDraft: (_) {});
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('rowMenu_00000001')), findsOneWidget);
    expect(find.byKey(const ValueKey('rowEdit_00000001')), findsNothing,
        reason: 'narrow: everything is in ⋮');

    await pumpList(tester, size: const Size(1280, 800), locale: const Locale('ta'),
        onOpenDraft: (_) {});
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('modernTabs')), findsOneWidget);

    await pumpList(tester, size: const Size(600, 900), onOpenDraft: (_) {});
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('modernTabDrafts')));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
