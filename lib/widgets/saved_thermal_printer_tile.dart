import 'package:flutter/material.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/common/constants.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/services/thermal_printer_choice.dart';
import 'package:invoiceo/services/thermal_printer_service_v1.dart';

/// Settings control for thermal auto-print: shows the saved printer, lets the
/// user forget it, and turns "print straight to it" on or off.
///
/// These are actions, not part of the PDF settings' preview-then-save form, so
/// they take effect immediately.
class SavedThermalPrinterTile extends StatefulWidget {
  const SavedThermalPrinterTile({super.key});

  @override
  State<SavedThermalPrinterTile> createState() =>
      _SavedThermalPrinterTileState();
}

class _SavedThermalPrinterTileState extends State<SavedThermalPrinterTile> {
  ThermalPrinterRef? _printer;
  bool _autoPrint = true;
  String _textSize = 'large';
  String _printWidth = 'auto';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = BackendServices.settings;
    final printer = ThermalPrinterRef.tryParse(
        await settings.getSetting(SettingKey.lastUsedThermalPrinter));
    final auto =
        (await settings.getSetting(SettingKey.thermalAutoPrint)) != 'false';
    final size = await settings.getSetting(SettingKey.thermalReceiptTextSize);
    final width = await settings.getSetting(SettingKey.thermalPrintWidth);
    if (!mounted) return;
    setState(() {
      _printer = printer;
      _autoPrint = auto;
      _textSize = const ['normal', 'large', 'xlarge'].contains(size) ? size! : 'large';
      _printWidth = const ['auto', '384', '448', '512', '576'].contains(width) ? width! : 'auto';
    });
  }

  Future<void> _setTextSize(String? v) async {
    if (v == null) return;
    setState(() => _textSize = v);
    await BackendServices.settings.setSetting(SettingKey.thermalReceiptTextSize, v);
  }

  Future<void> _setPrintWidth(String? v) async {
    if (v == null) return;
    setState(() => _printWidth = v);
    await BackendServices.settings.setSetting(SettingKey.thermalPrintWidth, v);
  }

  Future<void> _forget() async {
    await ThermalPrinterService.forgetSavedPrinter(
        ScaffoldMessenger.maybeOf(context));
    await _load();
  }

  Future<void> _setAuto(bool value) async {
    setState(() => _autoPrint = value);
    await BackendServices.settings
        .setSetting(SettingKey.thermalAutoPrint, value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppBorderRadius.small),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.thermalPrinterTitle,
            style: TextStyle(
              fontSize: AppFontSize.small,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _printer == null
                      ? l10n.thermalPrinterNoneSavedMessage
                      : l10n.thermalPrinterSavedLabel(_printer!.name),
                ),
              ),
              if (_printer != null)
                TextButton(
                  onPressed: _forget,
                  child: Text(l10n.thermalPrinterForgetButton),
                ),
            ],
          ),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.thermalPrinterAutoPrintTitle),
            subtitle: Text(l10n.thermalPrinterAutoPrintSubtitle),
            value: _autoPrint,
            onChanged: _setAuto,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.thermalPrinterImageModeNote,
            style: TextStyle(
              fontSize: AppFontSize.xsmall,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('thermalTextSize'),
            value: _textSize,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: l10n.thermalPrinterTextSizeLabel,
                isDense: true,
                border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(
                  value: 'normal', child: Text(l10n.thermalPrinterTextSizeNormal)),
              DropdownMenuItem(
                  value: 'large', child: Text(l10n.thermalPrinterTextSizeLargeDefault)),
              DropdownMenuItem(
                  value: 'xlarge', child: Text(l10n.thermalPrinterTextSizeXLarge)),
            ],
            onChanged: _setTextSize,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('thermalPrintWidth'),
            value: _printWidth,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: l10n.thermalPrinterWidthLabel,
                helperText: l10n.thermalPrinterWidthHelper,
                isDense: true,
                border: const OutlineInputBorder()),
            items: [
              DropdownMenuItem(
                  value: 'auto', child: Text(l10n.thermalPrinterWidthAuto)),
              for (final dots in const ['576', '512', '448', '384'])
                DropdownMenuItem(
                    value: dots, child: Text(l10n.thermalPrinterWidthDots(dots))),
            ],
            onChanged: _setPrintWidth,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.thermalPrinterAppliesNowNote,
            style: TextStyle(
              fontSize: AppFontSize.xsmall,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
