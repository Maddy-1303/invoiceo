import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoiceo/common/setting_key.dart';
import 'package:invoiceo/repositories/settings_repository.dart';

/// The two screen layouts of the app. The choice is saved per company.
///
///  * [standard]: the design the app came with (the previous developer's
///    screens), kept as it is.
///  * [modern]: the new design, built page by page. A page that has no Modern
///    design yet shows its Standard page, so Modern is always complete.
///
/// Login and onboarding are not part of either layout: they look the same in
/// both. See docs/LAYOUTS.md for the list of pages and their status.
enum UiLayout { standard, modern }

/// The layout in use right now. The dashboard loads it from the settings; the
/// layout picker in Settings changes it (and saves it).
final uiLayoutProvider = StateProvider<UiLayout>((ref) => UiLayout.modern);

UiLayout uiLayoutFromKey(String? key) =>
    key == 'standard' ? UiLayout.standard : UiLayout.modern;

String uiLayoutToKey(UiLayout layout) => layout.name;

/// Reads the saved layout.
///
/// An install that only ever had the old Create Invoice layout choice has no
/// layout saved yet: its 'v2' (the previous developer's "New" screen) becomes
/// Standard, anything else (or nothing) becomes Modern, and the answer is
/// saved so this is only worked out once.
Future<UiLayout> loadUiLayout(SettingsRepository settings) async {
  final saved = await settings.getSetting(SettingKey.uiLayout);
  if (saved == 'standard' || saved == 'modern') return uiLayoutFromKey(saved);
  final legacy = await settings.getSetting(SettingKey.createInvoiceLayout);
  final layout = legacy == 'v2' ? UiLayout.standard : UiLayout.modern;
  await settings.setSetting(SettingKey.uiLayout, uiLayoutToKey(layout));
  return layout;
}
