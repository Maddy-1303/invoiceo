import 'package:flutter/material.dart';
import 'package:invoiceo/backup/backup_manager.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/database/company_registry_service.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/models/backup_info.dart';
import 'package:invoiceo/screens/settings/auto_backup_card.dart';
import 'package:invoiceo/screens/settings/backup_ui.dart';
import 'package:invoiceo/widgets/restart_required_dialog.dart';
import 'package:invoiceo/theme/brand_colors.dart';

class BackupManagementScreen extends StatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  State<BackupManagementScreen> createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends State<BackupManagementScreen>
    with ModernSectionActions {
  final BackupManager _backupManager = BackupManager();
  List<BackupInfo> _backups = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  // [quiet]: refresh the list without the full-page spinner (after an
  // automatic "Back up now").
  Future<void> _loadBackups({bool quiet = false}) async {
    if (mounted && !quiet) setState(() => _isLoading = true);

    try {
      final companyId =
          await CompanyRegistryService.getActiveCompanyId() ?? defaultCompanyId;
      final backups = await _backupManager.getBackupList(companyId);
      if (mounted) setState(() => _backups = backups);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(AppLocalizations.of(context)!.backupLoadErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createBackup(BackupType type) async {
    final l10n = AppLocalizations.of(context)!;
    if (mounted) setState(() => _isLoading = true);

    try {
      final companyId =
          await CompanyRegistryService.getActiveCompanyId() ?? defaultCompanyId;
      final companyName = await CompanyRegistryService.getActiveCompanyName();
      final result = await _backupManager.createBackup(
        companyId: companyId,
        companyName: companyName,
        type: type,
      );

      if (result.success) {
        _showSuccessDialog(l10n.backupCreatedSuccessMessage);
        _loadBackups();
      } else {
        _showErrorDialog(result.message);
      }
    } catch (e) {
      _showErrorDialog(l10n.backupCreateErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup(BackupInfo backup) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _showConfirmDialog(
      l10n.backupRestoreConfirmTitle,
      l10n.backupRestoreConfirmBody,
    );

    if (!confirmed) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final result = await _backupManager.restoreBackup(
        backupPath: backup.filePath,
      );

      if (result.success) {
        _showRestartDialog();
      } else {
        _showErrorDialog(result.message);
      }
    } catch (e) {
      _showErrorDialog(l10n.backupRestoreErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBackup(BackupInfo backup) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _showConfirmDialog(
      l10n.backupDeleteConfirmTitle,
      l10n.backupDeleteConfirmBody,
    );

    if (!confirmed) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final success = await _backupManager.deleteBackup(backup.filePath);

      if (success) {
        _showSuccessDialog(l10n.backupDeletedSuccessMessage);
        _loadBackups();
      } else {
        _showErrorDialog(l10n.backupDeleteFailedMessage);
      }
    } catch (e) {
      _showErrorDialog(l10n.backupDeleteErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadBackup(BackupInfo backup) async {
    final l10n = AppLocalizations.of(context)!;
    if (mounted) setState(() => _isLoading = true);
    try {
      final result = await _backupManager.downloadBackup(backup.filePath);
      if (result.success) {
        _showSuccessDialog(l10n.backupSavedToDownloadsMessage);
      } else {
        _showErrorDialog(result.message);
      }
    } catch (e) {
      _showErrorDialog(l10n.backupDownloadErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareBackup(BackupInfo backup) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await _backupManager.shareBackup(backup.filePath);
    } catch (e) {
      _showErrorDialog(l10n.backupShareErrorMessage(e.toString()));
    }
  }

  Future<void> _importBackup() async {
    final l10n = AppLocalizations.of(context)!;

    // Pick the file first, then ask before any data is replaced.
    final String? backupPath;
    try {
      backupPath = await _backupManager.pickBackupFile();
    } catch (e) {
      if (mounted) _showErrorDialog(l10n.backupImportErrorMessage(e.toString()));
      return;
    }
    if (backupPath == null || !mounted) return;

    final confirmed = await _showConfirmDialog(
      l10n.backupRestoreConfirmTitle,
      l10n.backupRestoreConfirmBody,
    );
    if (!confirmed || !mounted) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final result =
          await _backupManager.restoreBackup(backupPath: backupPath);
      if (!mounted) return;

      if (result.success) {
        _showRestartDialog();
      } else {
        _showErrorDialog(result.message);
      }
    } catch (e) {
      if (mounted) _showErrorDialog(l10n.backupImportErrorMessage(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Modern: the top bar shows the title, so no AppBar here; its Refresh
    // button goes to the top bar.
    final modern = inModernTopBar;
    if (modern) {
      publishSectionActions(() => [
            ModernTopBarButton.soft(
              key: const ValueKey('backupRefreshButton'),
              icon: Icons.refresh,
              label: l10n.actionRefresh,
              onPressed: _isLoading ? null : _loadBackups,
            ),
          ]);
    }
    return Scaffold(
      appBar: modern
          ? null
          : AppBar(
              title: Text(l10n.backupManagementTitle),
              actionsPadding: EdgeInsets.only(right: 50),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadBackups,
                ),
              ],
            ),
      // One scrolling page: the automatic backup card, manual backup, then
      // the saved backups (a short window scrolls instead of overflowing).
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final pad = constraints.maxWidth >= 700 ? 24.0 : 16.0;
              return ListView(
                padding: EdgeInsets.fromLTRB(pad, 20, pad, 28),
                children: [
                  _narrow(AutoBackupCard(
                      onBackupMade: () => _loadBackups(quiet: true))),
                  const SizedBox(height: 16),
                  _narrow(_manualBackup(l10n)),
                  const SizedBox(height: 16),
                  _narrow(_savedBackups(l10n)),
                ],
              );
            }),
    );
  }

  Widget _narrow(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: child,
        ),
      );

  // Create backup / Export as JSON / Import / restore.
  Widget _manualBackup(AppLocalizations l10n) {
    final style = OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: backupButtonPadding,
        shape: backupButtonShape);
    return Container(
      key: const ValueKey('backupManualCard'),
      decoration: backupCardDecoration(context),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackupSectionHeader(
            icon: Icons.save_outlined,
            color: backupManualColor,
            title: l10n.backupManualTitle,
            subtitle: l10n.backupManualSubtitle,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('backupCreateButton'),
                onPressed: () => _createBackup(BackupType.database),
                icon: const Icon(Icons.backup_outlined, size: 18),
                label: Text(l10n.backupCreateDbButton),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: backupButtonPadding,
                    shape: backupButtonShape),
              ),
              OutlinedButton.icon(
                key: const ValueKey('backupExportJsonButton'),
                onPressed: () => _createBackup(BackupType.json),
                icon: const Icon(Icons.data_object, size: 18),
                label: Text(l10n.backupExportJsonButton),
                style: style,
              ),
              OutlinedButton.icon(
                key: const ValueKey('backupImportButton'),
                onPressed: _importBackup,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: Text(l10n.backupImportButton),
                style: style,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // "Saved backups (n)" with Refresh, then one row per backup file.
  Widget _savedBackups(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('backupSavedCard'),
      decoration: backupCardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
            child: BackupSectionHeader(
              icon: Icons.inventory_2_outlined,
              color: BrandColors.slate,
              title: l10n.backupSavedTitle(_backups.length),
              titleKey: const ValueKey('backupSavedTitle'),
              subtitle: l10n.backupSavedSubtitle,
              trailing: IconButton(
                key: const ValueKey('backupListRefresh'),
                tooltip: l10n.actionRefresh,
                onPressed: _isLoading ? null : _loadBackups,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          if (_backups.isEmpty)
            _emptyState(l10n)
          else
            for (var i = 0; i < _backups.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    indent: 74,
                    color: scheme.outlineVariant.withValues(alpha: 0.6)),
              _buildBackupTile(_backups[i]),
            ],
        ],
      ),
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('backupEmptyState'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          Text(
            l10n.backupNoBackupsFoundMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.backupEmptySubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupTile(BackupInfo backup) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final kind = backup.kind;
    final color = backupKindColor(kind);

    return Padding(
      key: ValueKey('backupRow_${backup.fileName}'),
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      child: Row(
        children: [
          BackupIconCircle(backupKindIcon(kind), color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The badge goes under a long title instead of cutting it.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      backupKindLabel(l10n, kind),
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                    BackupBadge(
                        backup.type == BackupType.json
                            ? 'JSON'
                            : l10n.backupFormatDatabase,
                        color),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${backupTimeText(l10n, backup.createdAt)}  ·  '
                  '${backup.formattedSize}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  backup.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: l10n.invoiceMgmtMoreActionsTooltip,
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              switch (value) {
                case 'restore':
                  _restoreBackup(backup);
                  break;
                case 'download':
                  _downloadBackup(backup);
                  break;
                case 'share':
                  _shareBackup(backup);
                  break;
                case 'delete':
                  _deleteBackup(backup);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'restore',
                child: ListTile(
                  leading: const Icon(Icons.restore),
                  title: Text(l10n.actionRestore),
                ),
              ),
              PopupMenuItem(
                value: 'download',
                child: ListTile(
                  leading: const Icon(Icons.download),
                  title: Text(l10n.createInvoiceDownloadLabel),
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: const Icon(Icons.share),
                  title: Text(l10n.actionShare),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: scheme.error),
                  title: Text(l10n.actionDelete,
                      style: TextStyle(color: scheme.error)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.actionCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.actionConfirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showRestartDialog() {

    if (!mounted) return; // the page was left while it worked
    final l10n = AppLocalizations.of(context)!;
    showRestartRequiredDialog(context,
        title: l10n.backupRestoreSuccessTitle,
        body: l10n.backupRestoreSuccessBody);
  }

  void _showSuccessDialog(String message) {

    if (!mounted) return; // the page was left while it worked
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.commonSuccessTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionOk),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {

    if (!mounted) return; // the page was left while it worked
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.commonErrorTitle),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.actionOk),
          ),
        ],
      ),
    );
  }
}
