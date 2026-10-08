// Reports and Settings in the Modern frame: the top bar shows the open
// section ("Revenue", "Receivables", "PDF Settings"...), Reports' own
// "Reports" bar moves into it (with refresh), and the side lists scroll
// instead of overflowing on a short window. Also: PDF and Invoice Settings
// on a narrow content area, and the developer name in Software Info.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/layouts/modern/modern_shell.dart';
import 'package:invoiceo/models/user.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/reports_screen.dart';
import 'package:invoiceo/screens/settings/invoice_settings_screen_v2.dart';
import 'package:invoiceo/screens/settings/pdf_settings_screen_v2.dart';
import 'package:invoiceo/screens/settings/settings_screen.dart';
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
    tmp = Directory.systemTemp.createTempSync('invoiceo_reports_settings');
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

  /// [page] inside the Modern frame (top bar + header scope), or alone.
  Future<void> pump(WidgetTester tester, Widget page,
      {int index = 7, bool inFrame = true, Size size = const Size(1500, 900)}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(
        () => DatabaseHelper().switchToFile('reports_settings_${dbCounter++}.db'));
    final header = ValueNotifier<ModernPageHeader?>(null);
    addTearDown(header.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: MaterialApp(
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
                    pageTitle: index == 7 ? 'Reports' : 'Settings',
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

  final topBar = find.byKey(const ValueKey('modernTopBar'));
  Finder inBar(String t) => find.descendant(of: topBar, matching: find.text(t));

  testWidgets('Reports: the top bar shows the open report and has refresh', (tester) async {
    await pump(tester, const ReportsScreen());
    expect(tester.takeException(), isNull);
    expect(inBar('Revenue'), findsOneWidget);
    expect(inBar('Reports'), findsOneWidget, reason: 'as the subtitle');
    expect(find.text('Reports'), findsOneWidget, reason: "no second 'Reports' bar on the page");
    expect(find.descendant(of: topBar, matching: find.byKey(const ValueKey('reportsRefresh'))),
        findsOneWidget);

    await tester.tap(find.text('Receivables'));
    await settle(tester);
    expect(inBar('Receivables'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reports: a short window scrolls the left list instead of overflowing',
      (tester) async {
    await pump(tester, const ReportsScreen(), size: const Size(1400, 560));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('reportsSidebarScroll')), findsOneWidget);
    await tester.tap(find.text('Invoice Status'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reports on its own (Standard) keeps its "Reports" bar', (tester) async {
    await pump(tester, const ReportsScreen(), inFrame: false);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('Settings: the top bar shows the open section; the rail scrolls',
      (tester) async {
    await pump(tester, SettingsScreen(currentUser: admin), index: 8,
        size: const Size(1500, 700));
    expect(tester.takeException(), isNull);
    expect(inBar('Company Info'), findsOneWidget);
    expect(inBar('Settings'), findsOneWidget, reason: 'as the subtitle');
    expect(find.byKey(const ValueKey('settingsRailScroll')), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byType(NavigationRail), matching: find.text('PDF Settings')));
    await settle(tester);
    expect(inBar('PDF Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PDF Settings on a narrow area uses the full width (no overflow)', (tester) async {
    await pump(tester, const PdfSettingsScreenV2(), inFrame: false, size: const Size(820, 900));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('pdfSettingsNarrow')), findsOneWidget);
    final area = tester.getSize(find.byKey(const ValueKey('pdfSettingsNarrow'))).width;
    expect(area, greaterThan(780), reason: 'not a narrow centred column');
  });

  testWidgets('Invoice Settings on a narrow area keeps only Save at the bottom', (tester) async {
    await pump(tester, InvoiceSettingsScreenV2(onNavigateToCustomization: () {}),
        inFrame: false, size: const Size(820, 800));
    expect(tester.takeException(), isNull);
    final bar = find.byKey(const ValueKey('invoiceSettingsSaveBar'));
    expect(bar, findsOneWidget);
    expect(tester.getSize(bar).height, lessThan(90), reason: 'just the Save button');
  });

  testWidgets('Software Info shows the developer, Madhan Prasath', (tester) async {
    await pump(tester, SettingsScreen(currentUser: admin), index: 8);
    await tester.tap(find.descendant(
        of: find.byType(NavigationRail), matching: find.text('Software Info')));
    await settle(tester);
    expect(find.text('Madhan Prasath'), findsOneWidget);
    expect(inBar('Software Info'), findsOneWidget);
  });
}
