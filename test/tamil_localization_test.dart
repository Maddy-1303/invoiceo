// Tamil (ta) as a first-class app language:
//  * the translation file is complete and safe (every key, same placeholders),
//  * the locale loads and is offered in the language picker,
//  * switching languages keeps the form data,
//  * Tamil product names / aliases / customer names are stored, found and shown,
//  * the main screens lay out in Tamil without overflow.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/database/customer_service.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/providers/locale_provider.dart';
import 'package:invoiceo/providers/sqlite_repository_overrides.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_installation_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
import 'package:invoiceo/screens/create_invoice_screen_modern.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/theme/app_theme.dart';
import 'package:invoiceo/widgets/language_picker.dart';

final _tamilLetter = RegExp(r'[஀-௿]');

Map<String, String> _readArb(String locale) {
  final raw = jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
      as Map<String, dynamic>;
  return {
    for (final e in raw.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

List<String> _names(String s) => RegExp(r'\{([A-Za-z_]\w*)(?=[,}])')
    .allMatches(s)
    .map((m) => m.group(1)!)
    .toList()
  ..sort();
List<String> _selectors(String s) =>
    RegExp(r'(=\d+|\bzero|\bone|\btwo|\bfew|\bmany|\bother)\{')
        .allMatches(s)
        .map((m) => m.group(1)!)
        .toList()
      ..sort();

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
    tmp = Directory.systemTemp.createTempSync('invoiceo_tamil');
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

  group('the Tamil translation file', () {
    final en = _readArb('en');
    final ta = _readArb('ta');

    test('has every English key and nothing else (missing translations are caught here)', () {
      final missing = en.keys.where((k) => !ta.containsKey(k)).toList();
      final extra = ta.keys.where((k) => !en.containsKey(k)).toList();
      expect(missing, isEmpty, reason: 'keys with no Tamil: $missing');
      expect(extra, isEmpty, reason: 'Tamil keys that do not exist in English: $extra');
      expect(ta.length, en.length);
    });

    test('every string keeps its placeholders and plural structure', () {
      final problems = <String>[];
      for (final k in en.keys) {
        final e = en[k]!, t = ta[k]!;
        if (_names(e).join(',') != _names(t).join(',')) problems.add('$k: placeholders');
        if (_selectors(e).join(',') != _selectors(t).join(',')) problems.add('$k: plural/select');
        if ('{'.allMatches(t).length != '}'.allMatches(t).length) problems.add('$k: braces');
        if (t.trim().isEmpty) problems.add('$k: empty');
      }
      expect(problems, isEmpty, reason: problems.take(20).join('\n'));
    });

    test('strings are really translated (Tamil letters), apart from short technical tokens', () {
      final untranslated = <String>[];
      for (final k in en.keys) {
        final t = ta[k]!;
        if (_tamilLetter.hasMatch(t)) continue;
        final e = en[k]!;
        // e.g. "PDF", "GSTIN", "UPI", "{count}": nothing to translate.
        // (placeholders such as "{label} ({count})" carry no words to translate)
        final words = e.replaceAll(RegExp(r'\{[^}]*\}'), '');
        final tokenOnly = !RegExp(r'[A-Za-z]{3,}').hasMatch(words) ||
            (t == e && RegExp(r'^[A-Z0-9 /&.+()-]+$').hasMatch(e)) || // "GSTIN / VAT", "UPI ID"...
            t == 'Invoiceo'; // the brand name stays in Latin script
        if (!tokenOnly) untranslated.add('$k = "$t"');
      }
      expect(untranslated, isEmpty, reason: untranslated.take(25).join('\n'));
    });

    test('shortcuts, e-mail addresses and links are unchanged', () {
      final re = RegExp(r'Ctrl\+\w+|\bF\d{1,2}\b|https?://\S+|[\w.+-]+@[\w.-]+\.\w+');
      final bad = <String>[];
      for (final k in en.keys) {
        final a = re.allMatches(en[k]!).map((m) => m.group(0)).toList()..sort();
        final b = re.allMatches(ta[k]!).map((m) => m.group(0)).toList()..sort();
        if (a.join('|') != b.join('|')) bad.add(k);
      }
      expect(bad, isEmpty, reason: '$bad');
    });
  });

  group('the Tamil locale', () {
    test('loads and is one of the supported languages', () async {
      expect(AppLocalizations.delegate.isSupported(const Locale('ta')), isTrue);
      expect(AppLocalizations.supportedLocales.map((l) => l.languageCode), contains('ta'));
      expect(supportedAppLocales.map((l) => l.languageCode), contains('ta'));
      final l = await AppLocalizations.delegate.load(const Locale('ta'));
      final ta = _readArb('ta');
      expect(l.localeName, 'ta');
      expect(l.actionSave, ta['actionSave']);
      expect(l.appTitle, ta['appTitle']);
      expect(_tamilLetter.hasMatch(l.actionCancel), isTrue);
    });

    test('plural messages work in Tamil', () async {
      final l = await AppLocalizations.delegate.load(const Locale('ta'));
      final one = l.dashboardInvoiceCountLabel(1);
      final many = l.dashboardInvoiceCountLabel(5);
      expect(many, contains('5'));
      expect(one, isNot(contains('5')));
      expect(_tamilLetter.hasMatch(one), isTrue);
      expect(_tamilLetter.hasMatch(many), isTrue);
    });

    test('the language picker offers it under its own name', () {
      expect(appLanguageLabel(const Locale('ta')), 'தமிழ்');
      expect(appLanguageNames.keys, contains('ta'));
      // every language the app supports has a picker name
      for (final l in supportedAppLocales) {
        expect(appLanguageNames, contains(l.languageCode));
      }
    });

    test('the app theme can draw Tamil in the UI (bundled font in the fallback list)', () {
      expect(AppTheme.light.textTheme.bodyMedium?.fontFamilyFallback, contains('NotoSansTamil'));
      expect(AppTheme.dark.textTheme.bodyMedium?.fontFamilyFallback, contains('NotoSansTamil'));
      expect(File('assets/fonts/NotoSansTamil-Regular.ttf').existsSync(), isTrue);
      expect(File('pubspec.yaml').readAsStringSync(), contains('family: NotoSansTamil'));
    });
  });

  group('switching language', () {
    testWidgets('English <-> Tamil <-> other languages changes the text and never loses what was typed',
        (tester) async {
      tester.view.physicalSize = const Size(1500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => DatabaseHelper().switchToFile('tamil_switch_${dbCounter++}.db'));

      final locale = ValueNotifier<Locale>(const Locale('en'));
      await tester.pumpWidget(ProviderScope(
        overrides: sqliteRepositoryOverrides,
        child: ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, _) => MaterialApp(
            locale: value,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: CreateInvoiceScreenModern()),
          ),
        ),
      ));
      await settle(tester);
      AppLocalizations l() => AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;
      final en = _readArb('en');
      final ta = _readArb('ta');
      final hi = _readArb('hi');

      // Type something into the form first.
      final nameBox = find.byKey(const ValueKey('modernCustomerName')); // customer search / name box
      final name = nameBox;
      expect(nameBox, findsOneWidget);
      await tester.enterText(nameBox, 'மதன் Kumar');
      await tester.pump();
      expect(name, findsOneWidget);

      Future<void> switchTo(String code) async {
        locale.value = Locale(code);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'switching to $code');
      }

      await switchTo('ta');
      expect(l().localeName, 'ta');
      expect(l().actionSave, ta['actionSave']);
      expect(find.text(ta['mInvItems']!), findsWidgets, reason: 'the form is drawn in Tamil');
      expect(tester.widget<TextField>(nameBox).controller!.text,
          'மதன் Kumar', reason: 'what was typed survives the switch');

      await switchTo('en');
      expect(l().actionSave, en['actionSave']);
      expect(tester.widget<TextField>(nameBox).controller!.text, 'மதன் Kumar');

      await switchTo('hi');
      expect(l().actionSave, hi['actionSave']);
      await switchTo('ta');
      expect(l().actionSave, ta['actionSave']);
      expect(tester.widget<TextField>(nameBox).controller!.text, 'மதன் Kumar');
      await settle(tester);
    });

    testWidgets('the app locale provider accepts Tamil and remembers its key', (tester) async {
      expect(localeFromKey('ta'), const Locale('ta'));
      expect(localeToKey(const Locale('ta')), 'ta');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(localeProvider.notifier).state = const Locale('ta');
      expect(container.read(localeProvider), const Locale('ta'));
    });
  });

  group('Tamil data', () {
    Future<void> freshDb(WidgetTester tester) async {
      await tester.runAsync(() => DatabaseHelper().switchToFile('tamil_data_${dbCounter++}.db'));
    }

    testWidgets('Tamil product names and aliases are saved, found by search, and read back intact',
        (tester) async {
      await freshDb(tester);
      await tester.runAsync(() async {
        await ProductService.insertProduct(Product(
            id: 't1', name: 'Aashirvaad Atta 5kg', aliasName: 'ஆசிர்வாத் ஆட்டா 5கி',
            description: '', price: 285, stock: 0, hsncode: '1101', tax_rate: 0, unlimitedStock: true));
        await ProductService.insertProduct(Product(
            id: 't2', name: 'அரிசி 1கிலோ', aliasName: 'Rice 1kg',
            description: '', price: 55, stock: 0, hsncode: '1006', tax_rate: 0, unlimitedStock: true));
        await ProductService.insertProduct(Product(
            id: 't3', name: 'Salt', aliasName: null,
            description: '', price: 22, stock: 0, hsncode: '2501', tax_rate: 0, unlimitedStock: true));
      });
      final byAlias = await tester.runAsync(() =>
          ProductService.getProductsPaginated(offset: 0, limit: 20, query: 'ஆட்டா'));
      expect(byAlias!.map((p) => p.id), ['t1'], reason: 'found by the Tamil ALIAS');
      final byTamilName = await tester.runAsync(() =>
          ProductService.getProductsPaginated(offset: 0, limit: 20, query: 'அரிசி'));
      expect(byTamilName!.map((p) => p.id), ['t2'], reason: 'found by the Tamil NAME');
      final byEnglishAlias = await tester.runAsync(() =>
          ProductService.getProductsPaginated(offset: 0, limit: 20, query: 'rice'));
      expect(byEnglishAlias!.map((p) => p.id), ['t2']);
      final byBoth = await tester.runAsync(() =>
          ProductService.getProductsPaginated(offset: 0, limit: 20, query: 'atta'));
      expect(byBoth!.map((p) => p.id), ['t1']);
      final count = await tester.runAsync(() => ProductService.getProductCount('ஆட்டா'));
      expect(count, 1, reason: 'the page count agrees with the search');
      final typed = await tester.runAsync(() =>
          ProductService.getProductsPaginated(offset: 0, limit: 20, query: 'ஆட்டா', type: 'product'));
      expect(typed!.map((p) => p.id), ['t1'], reason: 'also with the product-type filter');
      final back = await tester.runAsync(() => ProductService.getProductById('t1'));
      expect(back!.aliasName, 'ஆசிர்வாத் ஆட்டா 5கி', reason: 'stored and read back without damage');
      final none = await tester.runAsync(() =>
          ProductService.getProductsPaginated(offset: 0, limit: 20, query: 'இல்லாதது'));
      expect(none, isEmpty);
    });

    testWidgets('Tamil customer names are saved and found', (tester) async {
      await freshDb(tester);
      await tester.runAsync(() async {
        await CustomerService.insertCustomer(Customer(
            id: 'c1', name: 'மதன்', email: '', phone: '9876543210', address: 'கோயம்புத்தூர்', gstin: '',
            businessName: 'லிங்க நாடார் ஸ்டோர்ஸ்'));
      });
      final byName = await tester.runAsync(() =>
          CustomerService.getCustomersPaginated(offset: 0, limit: 10, query: 'மதன்'));
      expect(byName!.single.address, 'கோயம்புத்தூர்');
      final byBusiness = await tester.runAsync(() =>
          CustomerService.getCustomersPaginated(offset: 0, limit: 10, query: 'நாடார்'));
      expect(byBusiness!.single.name, 'மதன்');
    });
  });

  group('screens in Tamil', () {
    testWidgets('the Modern Create Invoice screen lays out in Tamil at laptop sizes without overflow',
        (tester) async {
      for (final size in [const Size(1366, 768), const Size(1100, 700)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        await tester.runAsync(() => DatabaseHelper().switchToFile('tamil_screen_${dbCounter++}.db'));
        await tester.pumpWidget(ProviderScope(
          overrides: sqliteRepositoryOverrides,
          child: MaterialApp(
            locale: const Locale('ta'),
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: CreateInvoiceScreenModern()),
          ),
        ));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'Tamil at $size');
        await tester.pumpWidget(const SizedBox());
      }
      addTearDown(tester.view.reset);
    });
  });
}
