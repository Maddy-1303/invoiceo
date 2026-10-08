// Settings → Customization: no fixed prices or delivery promises, every option
// says it is quoted per request, and the cards fit in English and Tamil.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/screens/settings/customization_screen.dart';

void main() {
  Future<AppLocalizations> pump(WidgetTester tester, Locale locale, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CustomizationScreen(highlightIndex: 0),
    ));
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(CustomizationScreen)))!;
  }

  for (final locale in const [Locale('en'), Locale('ta')]) {
    for (final size in const [Size(900, 900), Size(1400, 900)]) {
      testWidgets('${locale.languageCode} at ${size.width.toInt()}px: quoted per request, no prices',
          (tester) async {
        final l10n = await pump(tester, locale, size);
        expect(find.text(l10n.customizationQuotedBadge), findsNWidgets(4));
        expect(find.textContaining(r'$'), findsNothing);
        expect(find.byIcon(Icons.schedule_rounded), findsNothing);
        expect(find.text(l10n.customizationRequestButton), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
