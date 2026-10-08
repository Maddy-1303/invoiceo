import 'package:intl/intl.dart';

/// Leading characters that make Excel/LibreOffice treat a cell as a formula.
const _csvFormulaTriggers = ['=', '+', '-', '@', '\t', '\r'];
final _csvPlainNumber = RegExp(r'^-?[\d,]*\.?\d+$');

/// Prefixes formula-like text with `'` so spreadsheets show it as text
/// instead of executing it (CSV formula injection). Plain numbers such as
/// negative amounts are left untouched.
String _neutralizeCsvFormula(String s) {
  if (s.isEmpty || !_csvFormulaTriggers.contains(s[0])) return s;
  if (_csvPlainNumber.hasMatch(s)) return s;
  return "'$s";
}

/// Reverses [_neutralizeCsvFormula] so re-importing an exported CSV
/// doesn't keep the added `'`.
String stripCsvFormulaGuard(String s) =>
    s.length > 1 && s[0] == "'" && _csvFormulaTriggers.contains(s[1])
        ? s.substring(1)
        : s;

/// Converts a list of rows to CSV with every field double-quoted.
/// Internal double quotes are escaped by doubling them (RFC 4180).
String buildQuotedCsv(List<List<dynamic>> rows) {
  return rows.map((row) {
    return row.map((cell) {
      final s = _neutralizeCsvFormula(cell.toString()).replaceAll('"', '""');
      return '"$s"';
    }).join(',');
  }).join('\n');
}

class AppFormatters {
  static final _dateFormat = DateFormat('dd MMM yyyy');
  // ASCII digits in every language, like the PDFs (Nepali would otherwise
  // switch to Devanagari digits).
  static final _numberFormat = NumberFormat('#,##0.00', 'en_US');

  static String formatDate(DateTime? date) =>
      date != null ? _dateFormat.format(date) : 'Unknown date';

  static String formatShortDate(DateTime? date, {String pattern = 'dd/MM/yyyy'}) =>
      date != null ? DateFormat(pattern).format(date) : '-';

  static String formatAmount(double amount, String symbol) =>
      '$symbol ${_numberFormat.format(amount)}';

  /// A stock or quantity as people write it: 50 (not 50.0), 49.6, 0.25.
  /// At most 3 decimals, no thousands commas (CSV export reads it back).
  static String formatStock(num value) {
    if (!value.isFinite) return '0';
    final r = (value * 1000).round() / 1000;
    if (r == r.truncateToDouble()) return r.toInt().toString();
    return r.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }
}

extension StringLimit on String {
  String limit(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return substring(0, maxLength) + suffix;
  }
}
