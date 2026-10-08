import 'dart:convert';

/// A USB/system printer as the app remembers it between prints.
///
/// Android reports a vendor and product id; Windows reports only the
/// print-queue name, so [matches] compares ids when both sides have them and
/// the name otherwise.
class ThermalPrinterRef {
  const ThermalPrinterRef({
    required this.name,
    this.vendorId = '',
    this.productId = '',
  });

  final String name;
  final String vendorId;
  final String productId;

  bool matches(ThermalPrinterRef other) {
    final bothHaveIds = vendorId.isNotEmpty &&
        productId.isNotEmpty &&
        other.vendorId.isNotEmpty &&
        other.productId.isNotEmpty;
    if (bothHaveIds) {
      return vendorId == other.vendorId && productId == other.productId;
    }
    return name.isNotEmpty && name == other.name;
  }

  String toJson() => jsonEncode(
      {'name': name, 'vendorId': vendorId, 'productId': productId});

  /// Reads what [toJson] wrote. Null for empty, missing or damaged data, so
  /// a bad saved value just means "ask the user" and never breaks printing.
  static ThermalPrinterRef? tryParse(String? json) {
    if (json == null || json.trim().isEmpty) return null;
    try {
      final map = jsonDecode(json);
      if (map is! Map) return null;
      final name = map['name'];
      if (name is! String || name.isEmpty) return null;
      return ThermalPrinterRef(
        name: name,
        vendorId: map['vendorId'] is String ? map['vendorId'] as String : '',
        productId: map['productId'] is String ? map['productId'] as String : '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// What to do when the user presses Print on a thermal receipt.
class ThermalPrinterChoice {
  const ThermalPrinterChoice.automatic(ThermalPrinterRef this.printer);
  const ThermalPrinterChoice.ask() : printer = null;

  /// The printer to use without asking, or null to show the chooser.
  final ThermalPrinterRef? printer;
  bool get isAutomatic => printer != null;
}

/// Prints without asking only to a printer the user chose earlier and that is
/// still connected. Windows lists every installed printer (PDF writers, an
/// office laser...), so guessing "the only one" could send raw receipt
/// commands to the wrong device; an earlier explicit choice cannot.
ThermalPrinterChoice chooseThermalPrinter({
  required List<ThermalPrinterRef> found,
  required ThermalPrinterRef? lastUsed,
  required bool autoPrint,
}) {
  if (!autoPrint || lastUsed == null) return const ThermalPrinterChoice.ask();
  for (final p in found) {
    if (p.matches(lastUsed)) return ThermalPrinterChoice.automatic(p);
  }
  return const ThermalPrinterChoice.ask();
}
