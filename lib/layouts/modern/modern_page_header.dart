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

/// Put by a page whose top bar shows one of its sub-pages (Settings: the open
/// section). The sub-page sends its buttons with
/// [ModernSectionActions.publishSectionActions]; the page adds them to its
/// top bar header.
class ModernSectionScope extends InheritedWidget {
  const ModernSectionScope({
    super.key,
    required this.actions,
    required super.child,
  });

  final ValueNotifier<List<Widget>> actions;

  static ModernSectionScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ModernSectionScope>();

  @override
  bool updateShouldNotify(ModernSectionScope oldWidget) =>
      actions != oldWidget.actions;
}

/// For a sub-page (a Settings section) that, inside the Modern frame, drops
/// its own title bar and shows its buttons in the top bar instead.
mixin ModernSectionActions<T extends StatefulWidget> on State<T> {
  bool _sectionActionsQueued = false;

  /// True inside the Modern frame: do not draw the section's own title bar;
  /// send its buttons with [publishSectionActions].
  bool get inModernTopBar => ModernSectionScope.maybeOf(context) != null;

  /// Call from build. The buttons are built after this frame, so the top bar
  /// always matches the section (a Save button turns on when something
  /// changes, and so on).
  void publishSectionActions(List<Widget> Function() build) {
    final scope = ModernSectionScope.maybeOf(context);
    if (scope == null || _sectionActionsQueued) return;
    _sectionActionsQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sectionActionsQueued = false;
      if (!mounted) return;
      scope.actions.value = build();
    });
  }
}

/// Buttons for the Modern top bar, so every page's buttons look alike
/// (the same as Products' Import / Export and "+ New Product").
class ModernTopBarButton {
  ModernTopBarButton._();

  static final _shape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

  /// A light, secondary button (Reset, Import, Refresh...).
  static Widget soft({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      Builder(builder: (context) {
        final primary = Theme.of(context).primaryColor;
        return TextButton.icon(
          key: key,
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          style: TextButton.styleFrom(
            foregroundColor: primary,
            backgroundColor: primary.withValues(alpha: 0.08),
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: _shape,
          ),
        );
      });

  /// The page's main button (Save, Add User...). Grey while [onPressed] is
  /// null (for example nothing to save yet).
  static Widget primary({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      FilledButton.icon(
        key: key,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: _shape,
        ),
      );
}
