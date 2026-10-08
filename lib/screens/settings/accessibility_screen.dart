import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/common/constants.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/layouts/ui_layout.dart';
import 'package:invoiceo/providers/repositories.dart';
import 'package:invoiceo/theme/brand_colors.dart';

class AccessibilityScreen extends ConsumerStatefulWidget {
  const AccessibilityScreen({super.key});

  @override
  ConsumerState<AccessibilityScreen> createState() =>
      _AccessibilityScreenState();
}

class _AccessibilityScreenState extends ConsumerState<AccessibilityScreen>
    with ModernSectionActions {
  /// Applies and saves the screen layout for the whole app.
  Future<void> _setUiLayout(UiLayout layout) async {
    if (layout == ref.read(uiLayoutProvider)) return;
    ref.read(uiLayoutProvider.notifier).state = layout;
    await ref
        .read(settingsRepositoryProvider)
        .setSetting(SettingKey.uiLayout, uiLayoutToKey(layout));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final layout = ref.watch(uiLayoutProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : BrandColors.page,
      // Modern: the top bar already shows "Accessibility".
      appBar: inModernTopBar
          ? null
          : AppBar(
              title: Text(l10n.settingsNavAccessibilityLabel),
              elevation: 0,
              centerTitle: false,
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.accessibilityScreenLayoutTitle,
                    style: const TextStyle(
                        fontSize: AppFontSize.large,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                // Text(
                //   'Switching mid-edit discards any unsaved changes on the invoice form — save or finish the invoice first.',
                //   style: TextStyle(
                //       fontSize: AppFontSize.small,
                //       color: Theme.of(context).colorScheme.onSurfaceVariant),
                // ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppBorderRadius.medium),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  layout == UiLayout.standard
                                      ? l10n.accessibilityStandardLayoutLabel
                                      : l10n.accessibilityModernLayoutLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(l10n.accessibilityScreenLayoutDescription,
                                  style: TextStyle(
                                      fontSize: AppFontSize.xsmall,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SegmentedButton<UiLayout>(
                          segments: [
                            ButtonSegment(
                                value: UiLayout.standard,
                                icon: const Icon(Icons.view_sidebar_outlined,
                                    size: 16),
                                label: Text(l10n.accessibilityStandardLabel)),
                            ButtonSegment(
                                value: UiLayout.modern,
                                icon: const Icon(
                                    Icons.dashboard_customize_outlined,
                                    size: 16),
                                label: Text(l10n.pdfTemplateModernName)),
                          ],
                          selected: {layout},
                          onSelectionChanged: (selection) =>
                              _setUiLayout(selection.first),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (!Platform.isAndroid) ...[
                  Text(l10n.dashboardKeyboardShortcutsTitle,
                      style: const TextStyle(
                          fontSize: AppFontSize.large,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    l10n.accessibilityShortcutsSubtitle,
                    style: TextStyle(
                        fontSize: AppFontSize.small,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppBorderRadius.medium),
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Column(
                        children: AppShortcuts.all(context)
                            .map((s) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outlineVariant),
                                        ),
                                        child: Text(s.$1,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(s.$2,
                                            style:
                                                const TextStyle(fontSize: 13)),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
