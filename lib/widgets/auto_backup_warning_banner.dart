import 'package:flutter/material.dart';
import 'package:invoiceo/backup/auto_backup_service.dart';
import 'package:invoiceo/backup/backup_manager.dart';
import 'package:invoiceo/l10n/app_localizations.dart';

/// Why an automatic backup failed, in the app's language. An unknown error
/// shows its own (system) text.
String autoBackupReasonText(AppLocalizations l10n, AutoBackupError error) =>
    switch (error.code) {
      AutoBackupErrorCode.folderMissing => l10n.autoBackupReasonFolderMissing,
      AutoBackupErrorCode.folderNotWritable => l10n.autoBackupReasonNotWritable,
      AutoBackupErrorCode.accessLost => l10n.autoBackupReasonAccessLost,
      AutoBackupErrorCode.invalidCopy => l10n.autoBackupReasonInvalidCopy,
      _ => error.detail.isEmpty ? l10n.autoBackupReasonInvalidCopy : error.detail,
    };

/// Slim warning on the dashboard (Modern and Standard) when automatic backup
/// is on and its last attempt for the active company failed. Shows nothing
/// otherwise. [onOpenSettings] opens Settings > Backup (null = no button,
/// e.g. for a user who cannot open Settings).
class AutoBackupWarningBanner extends StatelessWidget {
  const AutoBackupWarningBanner({
    super.key,
    this.onOpenSettings,
    this.margin = EdgeInsets.zero,
  });

  final VoidCallback? onOpenSettings;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AutoBackupStatus?>(
      valueListenable: AutoBackupService.status,
      builder: (context, status, _) {
        final error = status?.record.lastError;
        if (status == null || !status.showWarning || error == null) {
          return const SizedBox.shrink();
        }
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;
        final fg = scheme.onErrorContainer;
        return Container(
          key: const ValueKey('autoBackupWarningBanner'),
          margin: margin,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.autoBackupBannerMessage(autoBackupReasonText(l10n, error)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: fg),
                ),
              ),
              if (onOpenSettings != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: TextButton(
                    key: const ValueKey('autoBackupWarningOpen'),
                    onPressed: onOpenSettings,
                    style: TextButton.styleFrom(
                      foregroundColor: fg,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    child: Text(l10n.autoBackupBannerAction,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
