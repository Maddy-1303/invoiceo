import 'package:flutter/material.dart';

/// What a Modern page shows in the top bar. Only the Dashboard keeps the
/// "Search anything" box; every other page shows its title there.
class ModernPageHeader {
  const ModernPageHeader({
    required this.page,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.createButton,
    this.onBack,
  });

  /// The sidebar index of the page the header belongs to.
  final int page;
  final String title;
  final String? subtitle;

  /// Shown on the right of the top bar, before the + button.
  final List<Widget> actions;

  /// Replaces the + menu (e.g. a full "+ Create Invoice" button).
  final Widget? createButton;

  /// Shows a back arrow before the title.
  final VoidCallback? onBack;
}

/// Put around the open page by the Modern frame. A page with its own top bar
/// header sends it with [ModernHeaderPublisher.publishModernHeader].
class ModernHeaderScope extends InheritedWidget {
  const ModernHeaderScope({
    super.key,
    required this.page,
    required this.notifier,
    required super.child,
  });

  final int page;
  final ValueNotifier<ModernPageHeader?> notifier;

  static ModernHeaderScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ModernHeaderScope>();

  @override
  bool updateShouldNotify(ModernHeaderScope oldWidget) =>
      page != oldWidget.page || notifier != oldWidget.notifier;
}

/// For pages that put their title (and buttons) in the Modern top bar.
mixin ModernHeaderPublisher<T extends StatefulWidget> on State<T> {
  bool _modernHeaderQueued = false;

  /// True when the page is inside the Modern frame (its header goes to the
  /// top bar); false when shown on its own (it then draws its own header).
  bool get hasModernTopBar => ModernHeaderScope.maybeOf(context) != null;

  /// Call from build: the header is built and sent after this frame, so the
  /// top bar always matches the page.
  void publishModernHeader(
      ModernPageHeader Function(int page) build) {
    final scope = ModernHeaderScope.maybeOf(context);
    if (scope == null || _modernHeaderQueued) return;
    _modernHeaderQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _modernHeaderQueued = false;
      if (!mounted) return;
      scope.notifier.value = build(scope.page);
    });
  }
}
