// The page registry: a page has its Standard design and, once built, a Modern
// one. Until then the Modern layout shows the Standard page.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoiceo/layouts/layout_page.dart';
import 'package:invoiceo/layouts/ui_layout.dart';

void main() {
  Widget text(String s) => Text(s, textDirection: TextDirection.ltr);

  test('a page with both designs gives each layout its own', () {
    final page = LayoutPage(
        standard: () => text('standard'), modern: () => text('modern'));
    expect(page.hasModern, isTrue);
    expect((page.build(UiLayout.standard) as Text).data, 'standard');
    expect((page.build(UiLayout.modern) as Text).data, 'modern');
  });

  test('a page with no Modern design yet shows its Standard page in Modern too', () {
    final page = LayoutPage(standard: () => text('standard'));
    expect(page.hasModern, isFalse);
    expect((page.build(UiLayout.standard) as Text).data, 'standard');
    expect((page.build(UiLayout.modern) as Text).data, 'standard');
  });

  test('layout keys round-trip; anything unknown means Modern', () {
    expect(uiLayoutFromKey('standard'), UiLayout.standard);
    expect(uiLayoutFromKey('modern'), UiLayout.modern);
    expect(uiLayoutFromKey(null), UiLayout.modern);
    expect(uiLayoutFromKey('classic'), UiLayout.modern);
    for (final l in UiLayout.values) {
      expect(uiLayoutFromKey(uiLayoutToKey(l)), l);
    }
  });
}
