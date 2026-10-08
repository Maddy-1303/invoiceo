// The PDF preview window uses printing's PdfPreview (the Syncfusion viewer is
// gone). It asks printing to draw exactly the bytes it was given, sharp enough
// for the real page size (a thermal roll is narrower than A4), keeps its own
// Print / Download / Close bar, and says so plainly when it cannot draw.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/services/pdf_service.dart';

const _printingChannel = MethodChannel('net.nfet.printing');

Invoice _invoice() => Invoice(
      id: 'inv1',
      invoiceNumber: '0042',
      customer: Customer(
        id: 'c1',
        name: 'Test Customer',
        email: '',
        phone: '',
        address: '',
        gstin: '',
      ),
      items: const [],
      date: DateTime(2026, 10, 8),
      type: 'Invoice',
    );

Future<pw.Document> _savedDoc(PdfPageFormat format) async {
  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: format,
    build: (_) => pw.Text('Hello'),
  ));
  await doc.save();
  return doc;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List rollBytes;
  late PdfPageFormat rollFormat;

  // What the app asked the printing plugin to draw.
  final rasterCalls = <Map<dynamic, dynamic>>[];
  var canRaster = true;

  setUpAll(() async {
    final roll = await _savedDoc(PdfPageFormat.roll80);
    rollBytes = await roll.save();
    rollFormat = PDFService.firstPageFormat(roll)!;
  });

  setUp(() {
    rasterCalls.clear();
    canRaster = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_printingChannel, (call) async {
      switch (call.method) {
        case 'printingInfo':
          return <String, dynamic>{
            'canPrint': true,
            'canShare': true,
            'canRaster': canRaster,
          };
        case 'rasterPdf':
          // Never answers, so the preview keeps its loading spinner.
          rasterCalls.add(call.arguments as Map<dynamic, dynamic>);
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_printingChannel, null);
  });

  Future<void> openPreview(WidgetTester tester, Uint8List bytes,
      {PdfPageFormat? pageFormat}) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => PDFService.showCenteredPDFViewer(
                context, bytes, _invoice(),
                pageFormat: pageFormat),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    // PdfPreview waits 300 ms before it draws.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  group('firstPageFormat', () {
    test('gives the saved page size, with a real height for a roll', () async {
      expect(rollFormat.width, closeTo(PdfPageFormat.roll80.width, 0.001));
      expect(rollFormat.height.isFinite, isTrue);
      expect(rollFormat.height, greaterThan(0));

      final a4 = await _savedDoc(PdfPageFormat.a4);
      expect(PDFService.firstPageFormat(a4)!.width,
          closeTo(PdfPageFormat.a4.width, 0.001));
    });

    test('is null for a document with no pages', () {
      expect(PDFService.firstPageFormat(pw.Document()), isNull);
    });
  });

  testWidgets('preview draws the given bytes with PdfPreview and our own bar',
      (tester) async {
    await openPreview(tester, rollBytes, pageFormat: rollFormat);

    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.text('Invoice #0042'), findsOneWidget);
    expect(find.byTooltip('Print'), findsOneWidget);
    expect(find.byTooltip('Download'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    // PdfPreview's own print / share / page-size bar stays hidden.
    expect(find.byType(PdfPrintAction), findsNothing);
    expect(find.byType(PdfShareAction), findsNothing);
    expect(find.byType(PdfPageFormatAction), findsNothing);

    expect(rasterCalls, isNotEmpty);
    final call = rasterCalls.first;
    expect(call['doc'], rollBytes);
    // Drawn for the real roll width: the page image is as wide as the window
    // (1200 - 16 px), so the narrow receipt is sharp when it fills the dialog.
    final scale = (call['scale'] as num).toDouble();
    expect(scale * rollFormat.width, closeTo(1200 - 16, 0.01));

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(PdfPreview), findsNothing);
  });

  testWidgets('without a page size the preview still opens (A4 / Letter width)',
      (tester) async {
    await openPreview(tester, rollBytes);

    expect(find.byType(PdfPreview), findsOneWidget);
    expect(rasterCalls, isNotEmpty);
    final scale = (rasterCalls.first['scale'] as num).toDouble();
    // Sized for a full-size sheet, so lower than for the roll.
    expect(scale * PdfPageFormat.a4.width, lessThanOrEqualTo(1200 - 16 + 0.01));
    expect(scale * rollFormat.width, lessThan(1200 - 16));
  });

  testWidgets('shows a plain message when the PDF cannot be drawn',
      (tester) async {
    canRaster = false;
    await openPreview(tester, rollBytes, pageFormat: rollFormat);

    expect(find.textContaining('Could not show the preview'), findsOneWidget);
    expect(rasterCalls, isEmpty);
    // Print and Download still work from the bar.
    expect(find.byTooltip('Print'), findsOneWidget);
    expect(find.byTooltip('Download'), findsOneWidget);
  });
}
