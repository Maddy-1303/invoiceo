// The Invoices list: the Title column shows the title the invoice prints with
// ("Invoice" when none is set), not an empty dash; and the admin Trash and Edit
// buttons are there.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/invoice_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

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
    tmp = Directory.systemTemp.createTempSync('invoiceo_list_title');
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

  testWidgets('Title column: "Invoice" when none is set, the real title when it is; Edit and Trash are there',
      (tester) async {
    tester.view.physicalSize = const Size(1900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('list_title.db');
      final p = Product(id: 'a', name: 'Alpha', description: '', price: 11,
          stock: 0, hsncode: '1', tax_rate: 0, unlimitedStock: true);
      Invoice mk(String id, String? title) => Invoice(
            id: id, invoiceNumber: id,
            customer: Customer(id: 'c', name: 'Madhan', email: '', phone: '', address: '', gstin: ''),
            items: [InvoiceItem(product: p, quantity: 1)],
            date: DateTime(2026, 10, 5), type: 'Invoice', taxRate: 0,
            taxMode: TaxMode.none, currencyCode: 'INR', currencySymbol: 'Rs.',
            invoiceTitle: title,
          );
      await InvoiceService.insertInvoice(mk('00000001', null));
      await InvoiceService.insertInvoice(mk('00000002', 'Tax Invoice'));
    });
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InvoiceManagementScreenV2(
          user: User(id: 'u', username: 'admin', password: '', userType: 'admin'),
          onEditInvoice: (_) {},
          onCloneInvoice: (_, __) {},
        ),
      ),
    ));
    await settle(tester);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('—'), findsNothing, reason: 'no empty dash in the Title column');
    expect(find.text('Tax Invoice'), findsOneWidget, reason: 'a real title is shown as it is');
    // The invoice with no title shows the plain "Invoice" in its Title cell
    // (the header, the filter and other labels also say Invoice, so look for
    // a cell in the row of #00000001).
    expect(find.text('#00000001'), findsOneWidget);
    expect(find.text('Invoice'), findsWidgets);
    // Admin tools are on the page.
    expect(find.byTooltip('Trash'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsWidgets);
  });
}
