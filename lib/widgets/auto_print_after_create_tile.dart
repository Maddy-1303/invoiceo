import 'package:flutter/material.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/common/constants.dart';
import 'package:invoiceo/services/backend_services.dart';

/// Settings switch: print a new invoice straight away when it is created.
///
/// On by default. Like the thermal printer controls it is an action rather
/// than part of a form, so it saves the moment it is switched.
class AutoPrintAfterCreateTile extends StatefulWidget {
  const AutoPrintAfterCreateTile({super.key});

  @override
  State<AutoPrintAfterCreateTile> createState() =>
      _AutoPrintAfterCreateTileState();
}

class _AutoPrintAfterCreateTileState extends State<AutoPrintAfterCreateTile> {
  bool _on = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await BackendServices.settings
        .getSetting(SettingKey.autoPrintAfterCreate);
    if (!mounted) return;
    setState(() => _on = value != 'false');
  }

  Future<void> _set(bool value) async {
    setState(() => _on = value);
    await BackendServices.settings
        .setSetting(SettingKey.autoPrintAfterCreate, value.toString());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: SwitchListTile(
        title: Text(AppLocalizations.of(context)!.autoPrintAfterCreateTitle),
        subtitle: Text(AppLocalizations.of(context)!.autoPrintAfterCreateSubtitle),
        secondary: Icon(Icons.print_outlined,
            color: _on ? Theme.of(context).primaryColor : scheme.onSurfaceVariant),
        value: _on,
        onChanged: _set,
        activeColor: Theme.of(context).primaryColor,
      ),
    );
  }
}
