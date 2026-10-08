import 'package:flutter/widgets.dart';
import 'package:invoiceo/layouts/ui_layout.dart';

/// One page of the app in each layout.
///
/// [standard] always exists. [modern] is added when that page's Modern design
/// is built; until then the Modern layout shows the Standard page.
class LayoutPage {
  const LayoutPage({required this.standard, this.modern});

  final Widget Function() standard;
  final Widget Function()? modern;

  /// True once this page has its own Modern design.
  bool get hasModern => modern != null;

  Widget build(UiLayout layout) =>
      layout == UiLayout.modern && modern != null ? modern!() : standard();
}
