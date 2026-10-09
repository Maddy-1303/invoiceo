import 'package:invoiceo/common/common.dart';

/// What made a backup file, read from its name (Settings > Backup list).
enum BackupKind {
  /// `invoiceo_auto_*`: made by automatic backup (or its "Back up now").
  automatic,

  /// `*_pre_restore_*`: the data as it was just before a restore.
  preRestore,

  /// Any other `.invoicedb`: made with "Create backup".
  manual,

  /// `.json`: made with "Export as JSON".
  json,
}

class BackupInfo {
  final String fileName;
  final String filePath;
  final int size;
  final DateTime createdAt;
  final BackupType type;

  BackupInfo({
    required this.fileName,
    required this.filePath,
    required this.size,
    required this.createdAt,
    required this.type,
  });

  BackupKind get kind => kindOf(fileName);

  static BackupKind kindOf(String fileName) {
    if (fileName.startsWith('invoiceo_auto_')) return BackupKind.automatic;
    if (fileName.contains('_pre_restore_')) return BackupKind.preRestore;
    if (fileName.toLowerCase().endsWith('.json')) return BackupKind.json;
    return BackupKind.manual;
  }

  // invoice_backup_<name>_[pre_restore_]2026-10-09T13-03-19.123456.invoicedb
  // (DateTime.toIso8601String with ':' made '-'; local time).
  static final _isoStamp = RegExp(
      r'(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})(?:\.(\d{1,6}))?(Z?)'
      r'\.(?:invoicedb|json)$');

  // invoiceo_auto_<slug>_20261009-130319.invoicedb (local time).
  static final _autoStamp =
      RegExp(r'_(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})\.invoicedb$');

  /// When the backup was made, from the time in its file name; null when
  /// the name holds none. A copied file keeps the database's own modified
  /// time, so the name is the right time.
  static DateTime? timeFromFileName(String fileName) {
    final iso = _isoStamp.firstMatch(fileName);
    if (iso != null) {
      final fraction = (iso.group(7) ?? '').padRight(6, '0');
      return _valid(
        [for (var i = 1; i <= 6; i++) int.parse(iso.group(i)!)],
        micro: int.parse(fraction),
        utc: iso.group(8) == 'Z',
      );
    }
    final auto = _autoStamp.firstMatch(fileName);
    if (auto != null) {
      return _valid([for (var i = 1; i <= 6; i++) int.parse(auto.group(i)!)]);
    }
    return null;
  }

  // Null for an impossible date (month 13, 31 June, hour 25...).
  static DateTime? _valid(List<int> v, {int micro = 0, bool utc = false}) {
    final t = utc
        ? DateTime.utc(v[0], v[1], v[2], v[3], v[4], v[5], 0, micro)
        : DateTime(v[0], v[1], v[2], v[3], v[4], v[5], 0, micro);
    if (t.year != v[0] ||
        t.month != v[1] ||
        t.day != v[2] ||
        t.hour != v[3] ||
        t.minute != v[4] ||
        t.second != v[5]) {
      return null;
    }
    return utc ? t.toLocal() : t;
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
