import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:invoiceo/backup/auto_backup_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/screens/settings/backup_ui.dart';
import 'package:invoiceo/widgets/auto_backup_warning_banner.dart';

/// Settings > Backup: the "Automatic backup" card at the top (Modern and
/// Standard). See lib/backup/auto_backup_service.dart.
class AutoBackupCard extends StatefulWidget {
  const AutoBackupCard({super.key, this.service, this.onBackupMade});

  /// Tests pass one with fakes; the app uses the default.
  final AutoBackupService? service;

  /// After "Back up now" made a file (the backup list may show it).
  final VoidCallback? onBackupMade;

  @override
  State<AutoBackupCard> createState() => _AutoBackupCardState();
}

class _AutoBackupCardState extends State<AutoBackupCard> {
  late final AutoBackupService _service = widget.service ?? AutoBackupService();
  AutoBackupSettings _settings = const AutoBackupSettings();
  AutoBackupRecord _record = const AutoBackupRecord();
  bool _loaded = false;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await AutoBackupSettings.load();
      final record = await AutoBackupRecord.load(await _service.companyId());
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _record = record;
        _loaded = true;
      });
    } catch (_) {
      // No preferences: the defaults stay, nothing can be saved.
    }
  }

  Future<void> _save(AutoBackupSettings settings) async {
    setState(() => _settings = settings);
    try {
      await settings.save();
    } catch (_) {}
    // The dashboard warning follows the switch.
    unawaited(_service.refreshStatus());
  }

  Future<void> _chooseFolder() async {
    final l10n = AppLocalizations.of(context)!;
    String? path;
    try {
      path = await FilePicker.platform
          .getDirectoryPath(dialogTitle: l10n.autoBackupChooseFolderButton);
    } catch (_) {
      return;
    }
    if (path == null || path.isEmpty || !mounted) return;
    // macOS: keeps the permission for this folder after a restart.
    final bookmark = await _service.folderAccess.remember(path);
    if (!mounted) return;
    await _save(_settings.withFolder(path, bookmark));
    // After a failure, try the new folder straight away.
    if (_record.lastError != null) await _backupNow();
  }

  Future<void> _useAppFolder() async {
    await _save(_settings.withFolder(null, null));
    if (_record.lastError != null) await _backupNow();
  }

  Future<void> _backupNow() async {
    if (_running || !mounted) return;
    setState(() => _running = true);
    final result = await _service.runNow();
    await _load();
    if (!mounted) return;
    setState(() => _running = false);
    if (result.outcome == AutoBackupOutcome.done) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content:
              Text(AppLocalizations.of(context)!.backupCreatedSuccessMessage)));
      widget.onBackupMade?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('autoBackupCard'),
      decoration: backupCardDecoration(context),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and the on / off switch; the options open below it only
          // while it is on.
          BackupSectionHeader(
            icon: Icons.cloud_sync_outlined,
            color: backupAutomaticColor,
            title: l10n.autoBackupTitle,
            subtitle: l10n.autoBackupSwitchSubtitle,
            trailing: Tooltip(
              message: l10n.autoBackupSwitchLabel,
              child: Switch(
                key: const ValueKey('autoBackupSwitch'),
                value: _settings.enabled,
                onChanged: _loaded
                    ? (v) => _save(_settings.copyWith(enabled: v))
                    : null,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !_settings.enabled
                ? const SizedBox(width: double.infinity)
                : Column(
                    key: const ValueKey('autoBackupOptions'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      Divider(height: 1, color: scheme.outlineVariant),
                      const SizedBox(height: 18),
                      _options(l10n),
                      const SizedBox(height: 18),
                      Divider(height: 1, color: scheme.outlineVariant),
                      const SizedBox(height: 16),
                      _footer(l10n),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // How often / copies to keep / save to: label on the left and the choice
  // on the right, or the label above it when narrow.
  Widget _options(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);
    final enabled = _loaded && !_running;
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 560;
      Widget row(String label, Widget control) {
        final text = Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 8), control],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 170,
              // Lines the label up with the middle of a 40 px control.
              child: Padding(padding: const EdgeInsets.only(top: 9), child: text),
            ),
            const SizedBox(width: 16),
            Expanded(child: control),
          ],
        );
      }

      final folder = _settings.folder;
      final cloud = cloudServiceOf(folder);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            l10n.autoBackupFrequencyLabel,
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SegmentedButton<AutoBackupFrequency>(
                key: const ValueKey('autoBackupFrequency'),
                showSelectedIcon: false,
                style: _segmentStyle(context),
                segments: [
                  ButtonSegment(
                      value: AutoBackupFrequency.daily,
                      label: Text(l10n.autoBackupEveryDay)),
                  ButtonSegment(
                      value: AutoBackupFrequency.weekly,
                      label: Text(l10n.autoBackupEveryWeek)),
                ],
                selected: {_settings.frequency},
                onSelectionChanged: _loaded
                    ? (s) => _save(_settings.copyWith(frequency: s.first))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 18),
          row(
            l10n.autoBackupKeepLabel,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<int>(
                  key: const ValueKey('autoBackupKeep'),
                  showSelectedIcon: false,
                  style: _segmentStyle(context),
                  segments: [
                    for (final n in AutoBackupSettings.keepChoices)
                      ButtonSegment(
                          value: n,
                          label: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 24),
                              child: Text('$n', textAlign: TextAlign.center))),
                  ],
                  selected: {_settings.keep},
                  onSelectionChanged: _loaded
                      ? (s) => _save(_settings.copyWith(keep: s.first))
                      : null,
                ),
                const SizedBox(height: 8),
                Text(l10n.autoBackupKeepHint, style: muted),
              ],
            ),
          ),
          const SizedBox(height: 18),
          row(
            l10n.autoBackupFolderLabel,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _folderTile(l10n, folder, cloud, enabled),
                // A gentle hint, only when the copies stay on this computer.
                if (cloud == null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(Icons.lightbulb_outline,
                            size: 16, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(l10n.autoBackupFolderTip, style: muted)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  ButtonStyle _segmentStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    return SegmentedButton.styleFrom(
      selectedBackgroundColor: primary.withValues(alpha: 0.12),
      selectedForegroundColor: backupReadable(context, primary),
      side: BorderSide(color: scheme.outlineVariant),
      shape: backupButtonShape,
      textStyle: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
    );
  }

  // The folder the copies go to: its name, the full path, and whether a
  // cloud service keeps a copy, with Change folder / Use app folder.
  Widget _folderTile(AppLocalizations l10n, String? folder, BackupCloud? cloud,
      bool enabled) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = folder == null
        ? l10n.autoBackupAppFolder
        : (p.basename(folder).isEmpty ? folder : p.basename(folder));
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name,
            key: const ValueKey('autoBackupFolderText'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        if (folder != null) ...[
          const SizedBox(height: 2),
          Tooltip(
            message: folder,
            child: Text(folder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
        ],
        const SizedBox(height: 8),
        cloud != null
            ? BackupBadge(cloud.label, backupCloudColor,
                key: const ValueKey('autoBackupCloudBadge'),
                icon: Icons.cloud_done_outlined)
            : BackupBadge(l10n.autoBackupLocalOnlyBadge, backupLocalColor,
                key: const ValueKey('autoBackupLocalBadge'),
                icon: Icons.computer_outlined),
      ],
    );
    Widget buttons({bool end = false}) => Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: end ? WrapAlignment.end : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('autoBackupChooseFolder'),
          onPressed: enabled ? _chooseFolder : null,
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: Text(l10n.autoBackupChangeFolderButton),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: backupButtonPadding,
              shape: backupButtonShape),
        ),
        if (folder != null)
          TextButton(
            key: const ValueKey('autoBackupUseAppFolder'),
            onPressed: enabled ? _useAppFolder : null,
            style: TextButton.styleFrom(
                minimumSize: const Size(0, 40), shape: backupButtonShape),
            child: Text(l10n.autoBackupUseAppFolderButton,
                textAlign: TextAlign.center),
          ),
      ],
    );
    final icon = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.folder_outlined,
          size: 22, color: backupReadable(context, Theme.of(context).primaryColor)),
    );
    return Container(
      key: const ValueKey('autoBackupFolderTile'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainer : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final top = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [icon, const SizedBox(width: 12), Expanded(child: info)],
        );
        // Wide: the buttons on the right (half the width at most, long
        // labels wrap); narrow: under the folder.
        if (c.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: top),
              const SizedBox(width: 16),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: c.maxWidth / 2),
                child: buttons(end: true),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [top, const SizedBox(height: 12), buttons()],
        );
      }),
    );
  }

  // The last backup (or why it failed) and "Back up now".
  Widget _footer(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = _loaded && !_running;
    final error = _record.lastError;
    final last = _record.lastSuccess;
    final Widget icon;
    final Widget text;
    if (error != null) {
      icon = Icon(Icons.error_outline, size: 20, color: scheme.error);
      text = Text(
        l10n.autoBackupLastFailed(autoBackupReasonText(l10n, error)),
        key: const ValueKey('autoBackupStatus'),
        style: TextStyle(
            fontSize: 13.5, fontWeight: FontWeight.w600, color: scheme.error),
      );
    } else if (last != null) {
      final where = _record.lastFolder ?? '';
      icon = Icon(Icons.check_circle,
          size: 20, color: backupReadable(context, backupCloudColor));
      text = Tooltip(
        message: where.isEmpty ? l10n.autoBackupAppFolder : where,
        child: Text(
          l10n.autoBackupLastBackup(backupTimeText(l10n, last)),
          key: const ValueKey('autoBackupStatus'),
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      );
    } else {
      icon = Icon(Icons.schedule, size: 20, color: scheme.onSurfaceVariant);
      text = Text(l10n.autoBackupNoneYet,
          key: const ValueKey('autoBackupStatus'),
          style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant));
    }
    final status = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [icon, const SizedBox(width: 8), Flexible(child: text)],
    );
    final buttons = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (error != null)
          OutlinedButton.icon(
            key: const ValueKey('autoBackupStatusChooseFolder'),
            onPressed: enabled ? _chooseFolder : null,
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: Text(l10n.autoBackupChooseFolderButton),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: backupButtonPadding,
                shape: backupButtonShape),
          ),
        FilledButton.icon(
          key: const ValueKey('autoBackupNow'),
          onPressed: enabled ? _backupNow : null,
          icon: _running
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.backup_outlined, size: 18),
          label: Text(l10n.autoBackupNowButton),
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: backupButtonPadding,
              shape: backupButtonShape),
        ),
      ],
    );
    // The status on the left and the buttons on the right when both fit
    // on one line; otherwise the buttons go under it.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [status, buttons],
      ),
    );
  }
}
