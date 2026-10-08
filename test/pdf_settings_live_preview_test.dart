// PDF Settings' preview panel shows a real sample invoice: a PDF made by the
// app's own invoice code with the company's details and the options picked
// on the page (not yet saved), drawn as a picture of its first page. Picking
// another template makes it again. Without PDF drawing (no printing plugin)
// the old sketch is shown instead, with no errors.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/models/company_info.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/settings/pdf_settings_screen_v2.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/services/pdf/pdf_font_service.dart';
import 'package:invoiceo/services/pdf/pdf_settings.dart';
import 'package:invoiceo/widgets/template_list_tile.dart';

import 'test_pdf_font_service.dart';

const _printingChannel = MethodChannel('net.nfet.printing');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  var dbCounter = 0;

  // What the preview made and asked the printing plugin to draw.
  final built = <PdfGenerationSettings>[];
  final rasterDocs = <Uint8List>[];

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
    tmp = Directory.systemTemp.createTempSync('invoiceo_pdf_live_preview');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
    PdfFontService.loadThemeHook = TestPdfFontService.loadTheme;
    PdfSettingsScreenV2.onPreviewPdfBuilt = built.add;
  });
  tearDownAll(() async {
    PdfFontService.loadThemeHook = null;
    PdfSettingsScreenV2.onPreviewPdfBuilt = null;
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });

  /// Acts like the printing plugin: answers each draw request with a small
  /// white page.
  void mockPrinting({required bool canRaster}) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_printingChannel, (call) async {
      switch (call.method) {
        case 'printingInfo':
          return <String, dynamic>{
            'canPrint': true,
            'canShare': true,
            'canRaster': canRaster,
          };
        case 'rasterPdf':
          final args = call.arguments as Map<dynamic, dynamic>;
          rasterDocs.add(args['doc'] as Uint8List);
          final job = args['job'];
          Future(() async {
            const codec = StandardMethodCodec();
            await messenger.handlePlatformMessage(
                _printingChannel.name,
                codec.encodeMethodCall(MethodCall('onPageRasterized', {
                  'job': job,
                  'width': 4,
                  'height': 6,
                  'image': Uint8List.fromList(List.filled(4 * 6 * 4, 255)),
                })),
                (_) {});
            await messenger.handlePlatformMessage(
                _printingChannel.name,
                codec.encodeMethodCall(
                    MethodCall('onPageRasterEnd', {'job': job})),
                (_) {});
          });
          return null;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_printingChannel, null));
  }

  Future<void> settle(WidgetTester tester, {int rounds = 12}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Settles until [done] (a PDF is slow to make in a test), at most ~10 s.
  Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 100 && !done(); i++) {
      await settle(tester, rounds: 1);
    }
    await settle(tester, rounds: 3);
  }

  Future<void> pump(WidgetTester tester,
      {CompanyInfo? company, Size size = const Size(1500, 900)}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    built.clear();
    rasterDocs.clear();
    await tester.runAsync(() async {
      await DatabaseHelper().switchToFile('pdf_live_preview_${dbCounter++}.db');
      if (company != null) {
        // A new database has the seeded company row; change that one.
        final seeded = await BackendServices.companyInfo.getCompanyInfo();
        await BackendServices.companyInfo.updateCompanyInfo(CompanyInfo(
          id: seeded?.id,
          name: company.name,
          address: company.address,
          phone: company.phone,
          email: company.email,
          website: company.website,
          gstin: company.gstin,
        ));
      }
    });
    await tester.pumpWidget(ProviderScope(
      overrides: sqliteRepositoryOverrides,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PdfSettingsScreenV2()),
      ),
    ));
  }

  final livePreview = find.byKey(const ValueKey('pdfSettingsLivePreview'));

  testWidgets('shows the first page of a real sample PDF; a new template redraws it',
      (tester) async {
    mockPrinting(canRaster: true);
    await pump(tester);
    await settleUntil(tester, () => livePreview.evaluate().isNotEmpty);

    expect(tester.takeException(), isNull);
    expect(livePreview, findsOneWidget);
    expect(find.byType(TemplatePreviewSketch), findsWidgets,
        reason: 'the template list still uses small sketches');
    expect(built, isNotEmpty);
    expect(built.last.template, InvoiceTemplate.classic);
    expect(built.last.company?.name, DatabaseHelper.seedCompanyName,
        reason: "the company's own (here the seeded) details");
    expect(rasterDocs, isNotEmpty);
    expect(String.fromCharCodes(rasterDocs.last.take(5)), '%PDF-');
    expect(find.text('Preview may slightly differ in the final PDF.'),
        findsOneWidget);

    final before = rasterDocs.length;
    await tester.tap(find.byWidgetPredicate(
        (w) => w is TemplateListTile && w.template == InvoiceTemplate.modern));
    await settleUntil(tester, () => rasterDocs.length > before);

    expect(tester.takeException(), isNull);
    expect(built.last.template, InvoiceTemplate.modern,
        reason: 'the picked (unsaved) template');
    expect(rasterDocs.length, greaterThan(before));
    expect(livePreview, findsOneWidget);
  });

  testWidgets('a Tamil company name goes through the shaping path', (tester) async {
    mockPrinting(canRaster: true);
    await pump(tester,
        company: CompanyInfo(
          name: 'சென்னை ஸ்டோர்ஸ்',
          address: 'அண்ணா சாலை, சென்னை',
          phone: '9876543210',
          email: '',
          website: '',
          gstin: '33ABCDE1234F1Z5',
        ));
    await settleUntil(tester, () => livePreview.evaluate().isNotEmpty);

    expect(tester.takeException(), isNull);
    expect(livePreview, findsOneWidget);
    expect(built.last.company?.name, 'சென்னை ஸ்டோர்ஸ்');
    // Shaped text goes into the PDF as images (there is no logo here).
    expect(String.fromCharCodes(rasterDocs.last).contains('/Image'), isTrue);
  });

  testWidgets('the narrow layout shows the sample PDF too, without overflow',
      (tester) async {
    mockPrinting(canRaster: true);
    await pump(tester, size: const Size(820, 900));
    await settleUntil(tester, () => livePreview.evaluate().isNotEmpty);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('pdfSettingsNarrow')), findsOneWidget);
    expect(livePreview, findsOneWidget);
  });

  testWidgets('without PDF drawing the sketch is shown, with no errors',
      (tester) async {
    mockPrinting(canRaster: false);
    await pump(tester);
    await settle(tester);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(livePreview, findsNothing);
    expect(rasterDocs, isEmpty);
    expect(
        find.byWidgetPredicate(
            (w) => w is TemplatePreviewSketch && w.width == 390),
        findsOneWidget,
        reason: 'the big sketch in the preview panel');
  });
}
