// Small shared pieces of Settings > Backup (backup_management_screen.dart
// and auto_backup_card.dart): the card look, section headers, badges, the
// cloud service of a folder, and "Today, 13:03" style times.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/models/backup_info.dart';
import 'package:invoiceo/theme/brand_colors.dart';

/// A cloud service whose desktop app keeps a folder on this computer in
/// step with the cloud. The names are brand names (never translated).
enum BackupCloud {
  googleDrive('Google Drive'),
  oneDrive('OneDrive'),
  iCloud('iCloud Drive'),
  dropbox('Dropbox');

  const BackupCloud(this.label);
  final String label;
}

/// The cloud service that syncs [path], from the usual folder names; null
/// for a folder that is only on this computer (or no folder).
BackupCloud? cloudServiceOf(String? path) {
  if (path == null || path.isEmpty) return null;
  final p = path.replaceAll('\\', '/');
  // "GoogleDrive" also covers macOS ".../CloudStorage/GoogleDrive-<email>".
  if (p.contains('GoogleDrive') ||
      p.contains('Google Drive') ||
      p.contains('My Drive')) {
    return BackupCloud.googleDrive;
  }
  if (p.contains('OneDrive')) return BackupCloud.oneDrive;
  if (p.contains('Mobile Documents/com~apple~CloudDocs') ||
      p.contains('iCloud Drive') ||
      p.contains('iCloudDrive')) {
    return BackupCloud.iCloud;
  }
  if (p.contains('Dropbox')) return BackupCloud.dropbox;
  return null;
}

/// "Today, 13:03", "Yesterday, 09:10" or "09 Oct 2026, 13:03" (month in the
/// app's language).
String backupTimeText(AppLocalizations l10n, DateTime time, {DateTime? now}) {
  final n = now ?? DateTime.now();
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  final clock = DateFormat('HH:mm').format(time);
  if (sameDay(time, n)) return l10n.backupTimeToday(clock);
  if (sameDay(time, DateTime(n.year, n.month, n.day - 1))) {
    return l10n.backupTimeYesterday(clock);
  }
  return DateFormat('dd MMM yyyy, HH:mm').format(time);
}

String backupKindLabel(AppLocalizations l10n, BackupKind kind) =>
    switch (kind) {
      BackupKind.automatic => l10n.autoBackupTitle,
      BackupKind.preRestore => l10n.backupKindBeforeRestore,
      BackupKind.manual => l10n.backupManualTitle,
      BackupKind.json => l10n.backupKindJson,
    };

/// One colour per kind: the automatic and manual sections use the same.
const backupAutomaticColor = BrandColors.primary;
const backupManualColor = BrandColors.accent;
const backupBeforeRestoreColor = Color(0xFFD97706);
const backupJsonColor = Color(0xFF7C3AED);
const backupCloudColor = Color(0xFF16A34A);
const backupLocalColor = Color(0xFFD97706);

Color backupKindColor(BackupKind kind) => switch (kind) {
      BackupKind.automatic => backupAutomaticColor,
      BackupKind.preRestore => backupBeforeRestoreColor,
      BackupKind.manual => backupManualColor,
      BackupKind.json => backupJsonColor,
    };

IconData backupKindIcon(BackupKind kind) => switch (kind) {
      BackupKind.automatic => Icons.update,
      BackupKind.preRestore => Icons.settings_backup_restore,
      BackupKind.manual => Icons.backup_outlined,
      BackupKind.json => Icons.data_object,
    };

/// [color] made easy to read as text on its own pale fill (darker on light,
/// lighter on dark).
Color backupReadable(BuildContext context, Color color) =>
    Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(color, Colors.white, 0.35)!
        : Color.lerp(color, Colors.black, 0.18)!;

/// The white card with a hairline border used on the page (as the Modern
/// customers / products tables).
BoxDecoration backupCardDecoration(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: scheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
  );
}

/// Buttons on the page: 40 high with the app's rounded corners.
final backupButtonShape =
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
const backupButtonPadding = EdgeInsets.symmetric(horizontal: 16);

/// An icon in a soft tinted circle.
class BackupIconCircle extends StatelessWidget {
  const BackupIconCircle(this.icon, this.color, {super.key, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: size * 0.5, color: backupReadable(context, color)),
      );
}

/// A small coloured badge (optionally with an icon).
class BackupBadge extends StatelessWidget {
  const BackupBadge(this.text, this.color, {super.key, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = backupReadable(context, color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ),
        ],
      ),
    );
  }
}

/// Icon, title and a line under it, with [trailing] on the right.
class BackupSectionHeader extends StatelessWidget {
  const BackupSectionHeader({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.titleKey,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        BackupIconCircle(icon, color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  key: titleKey,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}
