// The Modern layout's Products and Services pages (one page per kind):
// tinted stat cards, the filter card (search, Columns ▾ and the chips; sort
// by the column headings; Hide stats in ⋯),
// Columns ▾, chips and the stats eye), the table (selling price, status,
// eye / edit / duplicate / delete), ticks with Delete selected, "Showing x
// to y" with page numbers, Delete All for one kind, and the New Product /
// New Service panel. Title, Import / Export / ⋯ and "+ New …" are in the
// top bar.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/layouts/modern/modern_shell.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/models/user.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/product_management_screen_v2.dart';
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
    tmp = Directory.systemTemp.createTempSync('invoiceo_modern_products');
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
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  final admin = User(id: 'u', username: 'admin', password: '', userType: 'admin');

  /// Products: Rice (50), Dal (low, 5), Oil (out, 0), Soap (unlimited).
  /// Services: Repair (18%, SAC 9987), Delivery (0%, no SAC).
  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('modern_products_${dbCounter++}.db');
      Product p(String id, String name, double price,
              {String type = 'product', double stock = 0, bool unlimited = false,
              int tax = 0, String hsn = '1006', double purchase = 0}) =>
          Product(id: id, name: name, description: '', price: price, stock: stock,
              hsncode: hsn, tax_rate: tax, type: type, unlimitedStock: unlimited,
              purchasePrice: purchase);
      await ProductService.insertProduct(p('p1', 'Rice', 60, stock: 50, purchase: 45));
      await ProductService.insertProduct(p('p2', 'Dal', 120, stock: 5));
      await ProductService.insertProduct(p('p3', 'Oil', 180, stock: 0));
      await ProductService.insertProduct(p('p4', 'Soap', 35, unlimited: true));
      await ProductService.insertProduct(
          p('s1', 'Repair', 500, type: 'service', tax: 18, hsn: '9987', unlimited: true));
      await ProductService.insertProduct(
          p('s2', 'Delivery', 40, type: 'service', hsn: '', unlimited: true));
      await ProductService.upsertProductMetadata(
          ProductMetadata(productId: 'p2', skuCode: 'DAL-500'));
    });
  }

  Future<void> pumpPage(WidgetTester tester,
      {String kind = 'product',
      bool modern = true,
      int initialTab = 0,
      Size size = const Size(1600, 1100),
      Locale? locale,
      bool inFrame = false,
      User? user}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final header = ValueNotifier<ModernPageHeader?>(null);
    addTearDown(header.dispose);
    final page = ProductManagementScreenV2(
        key: UniqueKey(),
        user: user ?? admin,
        modern: modern,
        kind: kind,
        initialTab: initialTab);
    final index = kind == 'service' ? 9 : 6;
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
                    page: index,
                    pageTitle: kind == 'service' ? 'Services' : 'Products',
                    header: header,
                  ),
                  Expanded(child: ModernHeaderScope(page: index, notifier: header, child: page)),
                ]),
        ),
      ),
    ));
    await settle(tester);
    await settle(tester);
  }

  Finder row(String id) => find.byKey(ValueKey('prodRow_$id'));
  final stats = find.byKey(const ValueKey('modernProductStats'));
  Finder inStats(String t) => find.descendant(of: stats, matching: find.text(t));
  final table = find.byKey(const ValueKey('modernProductTable'));

  Future<void> pick(WidgetTester tester, String button, String item) async {
    await tester.tap(find.byKey(ValueKey(button)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await settle(tester);
  }

  testWidgets('Products page: only products; cards, chips, price and status', (tester) async {
    await seed(tester);
    await pumpPage(tester);
    expect(tester.takeException(), isNull);

    for (final id in ['p1', 'p2', 'p3', 'p4']) {
      expect(row(id), findsOneWidget, reason: id);
    }
    expect(row('s1'), findsNothing, reason: 'services have their own page');

    expect(inStats('Total Products'), findsOneWidget);
    expect(inStats('4'), findsOneWidget);
    expect(inStats('In Stock'), findsOneWidget);
    expect(inStats('2'), findsOneWidget, reason: 'Rice and Soap (unlimited)');
    expect(inStats('1'), findsNWidgets(2), reason: 'one low, one out of stock');

    expect(find.text('All (4)'), findsOneWidget);
    expect(find.text('In Stock (2)'), findsOneWidget);
    expect(find.text('Low Stock (1)'), findsOneWidget);
    expect(find.text('Out of Stock (1)'), findsOneWidget);
    expect(find.text('Services (2)'), findsNothing, reason: 'no Products / Services chips');

    expect(find.descendant(of: row('p1'), matching: find.text('Rs. 60.00')), findsOneWidget);
    expect(find.descendant(of: row('p1'), matching: find.text('In Stock')), findsOneWidget);
    expect(find.descendant(of: row('p2'), matching: find.text('Low Stock')), findsOneWidget);
    expect(find.descendant(of: row('p3'), matching: find.text('Out of Stock')), findsOneWidget);
    expect(find.descendant(of: row('p4'), matching: find.text('∞')), findsOneWidget);
    for (final k in ['prodView_p1', 'prodEdit_p1', 'prodDuplicate_p1', 'prodDelete_p1']) {
      expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
    }
    expect(find.text('Showing 1 to 4 of 4 products'), findsOneWidget);
    expect(find.byKey(const ValueKey('prodPage_1')), findsOneWidget);
  });

  testWidgets('Services page: only services; tax / SAC cards and chips; no stock or status',
      (tester) async {
    await seed(tester);
    await pumpPage(tester, kind: 'service');
    expect(tester.takeException(), isNull);
    expect(row('s1'), findsOneWidget);
    expect(row('s2'), findsOneWidget);
    expect(row('p1'), findsNothing);

    expect(inStats('Total Services'), findsOneWidget);
    expect(inStats('With Tax'), findsOneWidget);
    expect(inStats('Tax-free'), findsOneWidget);
    expect(inStats('Without SAC'), findsOneWidget);
    expect(find.text('With Tax (1)'), findsOneWidget);
    expect(find.text('Tax-free (1)'), findsOneWidget);
    expect(find.text('Without SAC (1)'), findsOneWidget);
    expect(find.descendant(of: table, matching: find.text('Status')), findsNothing);
    expect(find.descendant(of: table, matching: find.text('Stock')), findsNothing);
    expect(find.text('Showing 1 to 2 of 2 services'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('modernProdChip_taxed')));
    await settle(tester);
    expect(row('s1'), findsOneWidget);
    expect(row('s2'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('modernProdChip_no_hsn')));
    await settle(tester);
    expect(row('s2'), findsOneWidget);
    expect(row('s1'), findsNothing);
  });

  testWidgets('chips and search (name and SKU) filter the products', (tester) async {
    await seed(tester);
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('modernProdChip_low')));
    await settle(tester);
    expect(row('p2'), findsOneWidget);
    expect(row('p1'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('modernProdChip_out')));
    await settle(tester);
    expect(row('p3'), findsOneWidget);
    expect(row('p2'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('modernProdChip_all')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('modernProductSearch')), 'dal-5');
    await settle(tester);
    expect(row('p2'), findsOneWidget, reason: 'found by its SKU');
    expect(row('p1'), findsNothing);
  });

  testWidgets('the Selling Price and Stock headings sort; no Stock ▾ or Sort ▾ buttons',
      (tester) async {
    await seed(tester);
    await pumpPage(tester);
    for (final k in ['modernProductTabMenu', 'modernProductSort', 'modernProductStatsToggle']) {
      expect(find.byKey(ValueKey(k)), findsNothing, reason: k);
    }
    expect(find.byKey(const ValueKey('modernProductColumns')), findsOneWidget);
    double y(String id) => tester.getTopLeft(row(id)).dy;
    await tester.tap(find.byKey(const ValueKey('modernProdSortPrice')));
    await settle(tester);
    expect(y('p4'), lessThan(y('p1')), reason: 'Soap 35 before Rice 60');
    await tester.tap(find.byKey(const ValueKey('modernProdSortPrice')));
    await settle(tester);
    expect(y('p3'), lessThan(y('p2')), reason: 'high to low: Oil 180 before Dal 120');

    await tester.tap(find.byKey(const ValueKey('modernProdSortStock')));
    await settle(tester);
    expect(y('p3'), lessThan(y('p2')), reason: 'stock low to high: Oil 0 before Dal 5');
    expect(y('p2'), lessThan(y('p1')), reason: 'Dal 5 before Rice 50');

    await pumpPage(tester, kind: 'service');
    expect(find.byKey(const ValueKey('modernProdSortStock')), findsNothing,
        reason: 'services have no stock');
  });

  testWidgets('Columns ▾ shows SKU (same choice as the Standard page) and remembers it',
      (tester) async {
    await seed(tester);
    await pumpPage(tester);
    expect(find.descendant(of: row('p2'), matching: find.text('DAL-500')), findsNothing);
    await pick(tester, 'modernProductColumns', 'SKU Code');
    expect(find.descendant(of: row('p2'), matching: find.text('DAL-500')), findsOneWidget);
    final saved = await tester.runAsync(SqliteSettingsRepository().getProductListColumns);
    expect(saved!['skuCode'], isTrue);
    await pumpPage(tester);
    expect(find.descendant(of: row('p2'), matching: find.text('DAL-500')), findsOneWidget,
        reason: 'remembered');
  });

  testWidgets('Duplicate makes "… (copy)" with no stock and opens its edit form', (tester) async {
    await seed(tester);
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('prodDuplicate_p2')));
    await settle(tester);
    expect(find.text('Edit Product'), findsWidgets, reason: 'the copy opens to be edited');
    final all = await tester.runAsync(ProductService.getAllProducts);
    final copy = all!.singleWhere((p) => p.name == 'Dal (copy)');
    expect(copy.stock, 0);
    expect(copy.price, 120);
    expect((await tester.runAsync(() => ProductService.getProductMetadata(copy.id)))?.skuCode,
        'DAL-500');
  });

  testWidgets('ticked rows: "2 selected" and Delete selected', (tester) async {
    await seed(tester);
    await pumpPage(tester);
    await tester.tap(find.descendant(of: row('p1'), matching: find.byType(Checkbox)));
    await tester.tap(find.descendant(of: row('p3'), matching: find.byType(Checkbox)));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('prodDeleteSelected')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('prodDeleteSelectedOk')));
    await settle(tester);
    expect(row('p1'), findsNothing);
    expect(row('p3'), findsNothing);
    expect(find.text('All (2)'), findsOneWidget);
  });

  testWidgets('Delete All on the Services page deletes only services', (tester) async {
    await seed(tester);
    await pumpPage(tester, kind: 'service', inFrame: true);
    await tester.tap(find.byKey(const ValueKey('modernProductMore')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete All Services'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('prodDeleteAllOk')));
    await settle(tester);
    final left = await tester.runAsync(ProductService.getAllProducts);
    expect(left!.map((p) => p.type).toSet(), {'product'});
    expect(left.length, 4);
  });

  testWidgets('New Service: the panel adds a service (no Product / Service switch)',
      (tester) async {
    await seed(tester);
    await pumpPage(tester, kind: 'service', inFrame: true);
    final topBar = find.byKey(const ValueKey('modernTopBar'));
    expect(find.descendant(of: topBar, matching: find.text('Service Management')), findsOneWidget);
    expect(find.descendant(of: topBar, matching: find.text('Manage your services and pricing')),
        findsOneWidget);
    final newBtn = find.descendant(of: topBar, matching: find.byKey(const ValueKey('modernNewProduct')));
    expect(find.descendant(of: newBtn, matching: find.text('New Service')), findsOneWidget);
    await tester.tap(newBtn);
    await settle(tester);
    expect(find.text('Add New Service'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsNothing);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Installation');
    await tester.enterText(find.widgetWithText(TextFormField, 'Sale Price'), '750');
    expect(find.text('Save Product'), findsNothing);
    await tester.tap(find.text('Save Service'));
    await settle(tester);
    final all = await tester.runAsync(ProductService.getAllProducts);
    final added = all!.singleWhere((p) => p.name == 'Installation');
    expect(added.type, 'service');
    expect(added.unlimitedStock, isTrue);
    expect(row(added.id), findsOneWidget);
  });

  testWidgets('in the app frame: Product Management, Import / Export / ⋯ and "+ New Product"',
      (tester) async {
    await seed(tester);
    await pumpPage(tester, inFrame: true);
    final topBar = find.byKey(const ValueKey('modernTopBar'));
    Finder inBar(Finder f) => find.descendant(of: topBar, matching: f);
    expect(inBar(find.text('Product Management')), findsOneWidget);
    expect(inBar(find.text('Manage your products, inventory and pricing')), findsOneWidget);
    expect(inBar(find.byKey(const ValueKey('modernProductImport'))), findsOneWidget);
    expect(inBar(find.byKey(const ValueKey('modernProductExport'))), findsOneWidget);
    expect(inBar(find.byKey(const ValueKey('modernProductMore'))), findsOneWidget);
    expect(inBar(find.text('New Product')), findsOneWidget);
    expect(find.byType(PopupMenuButton<ModernCreate>), findsNothing);
  });

  testWidgets('⋯ > Hide stat cards hides the cards; Show stat cards brings them back',
      (tester) async {
    await seed(tester);
    await pumpPage(tester, inFrame: true);
    await tester.tap(find.byKey(const ValueKey('modernProductMore')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide stat cards'));
    await settle(tester);
    expect(stats, findsNothing);
    expect(await tester.runAsync(() =>
            SqliteSettingsRepository().getSetting(SettingKey.showProductStatsCards)),
        'false');
    await tester.tap(find.byKey(const ValueKey('modernProductMore')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show stat cards'));
    await settle(tester);
    expect(stats, findsOneWidget);
  });

  testWidgets('Standard page is unchanged; it can open on its Services tab', (tester) async {
    await seed(tester);
    await pumpPage(tester, modern: false);
    expect(find.byKey(const ValueKey('modernProductFilters')), findsNothing);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Repair'), findsOneWidget, reason: 'the combined list');

    await pumpPage(tester, modern: false, initialTab: 2);
    expect(find.text('Repair'), findsOneWidget);
    expect(find.text('Rice'), findsNothing, reason: 'opened on the Services tab');
  });

  testWidgets('a non-admin has no delete buttons', (tester) async {
    await seed(tester);
    await pumpPage(tester,
        user: User(id: 'v', username: 'staff', password: '', userType: 'user'));
    expect(find.byKey(const ValueKey('prodDelete_p1')), findsNothing);
    expect(find.byKey(const ValueKey('prodEdit_p1')), findsOneWidget);
  });

  testWidgets('no overflow: narrow windows and Tamil', (tester) async {
    await seed(tester);
    for (final (kind, size, locale) in [
      ('product', const Size(900, 800), null),
      ('service', const Size(600, 900), null),
      ('product', const Size(1366, 800), const Locale('ta')),
      ('service', const Size(1366, 800), const Locale('ta')),
    ]) {
      await pumpPage(tester, kind: kind, size: size, locale: locale);
      expect(tester.takeException(), isNull, reason: '$kind $size $locale');
      expect(table, findsOneWidget);
    }
  });

  testWidgets('Services keep their own Columns choice (not the products one)', (tester) async {
    await seed(tester);
    await pumpPage(tester, kind: 'service');
    await pick(tester, 'modernProductColumns', 'Description');
    final svc = await tester.runAsync(
        () => SqliteSettingsRepository().getSetting(SettingKey.serviceListColumnsConfig));
    expect(svc, contains('"description":true'));
    final prod = await tester.runAsync(SqliteSettingsRepository().getProductListColumns);
    expect(prod!['description'] ?? false, isFalse, reason: 'the Products page is unchanged');
    await pumpPage(tester, kind: 'service');
    expect(find.descendant(of: table, matching: find.text('Description')), findsOneWidget,
        reason: 'remembered');
  });

  testWidgets('a chip with no matches says to adjust the filters', (tester) async {
    await seed(tester);
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('modernProdChip_expired')));
    await settle(tester);
    expect(find.text('Try adjusting your search or filters'), findsOneWidget);
    expect(find.text('Add your first product to get started'), findsNothing);
  });

  testWidgets('deleting one ticked row says "1 item deleted"', (tester) async {
    await seed(tester);
    await pumpPage(tester);
    await tester.tap(find.descendant(of: row('p1'), matching: find.byType(Checkbox)));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('prodDeleteSelected')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('prodDeleteSelectedOk')));
    await settle(tester);
    expect(find.text('1 item deleted'), findsOneWidget);
  });
}
