// The Modern layout's frame: the sidebar and the top bar around every page.
// (The pages inside it are listed in dashboard_screen.dart; see
// docs/LAYOUTS.md.) Both widgets only draw; the dashboard passes in the data
// and what each tap does, so the behaviour is the same as in Standard.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/models/company_profile.dart';
import 'package:invoiceo/theme/brand_colors.dart';

/// Left sidebar: logo, company switcher, grouped navigation, and Help & Support
/// at the bottom (under a line). The reduce button folds it to an icon rail.
///
/// Page numbers are the dashboard's: 0 Dashboard, 1 New Invoice, 2 Invoices,
/// 3 Quotations, 4 Receipts, 5 Customers, 6 Products, 7 Reports, 8 Settings,
/// 9 Services (drawn under Catalog, after Products).
class ModernSidebar extends StatelessWidget {
  const ModernSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.companyName,
    required this.companies,
    required this.activeCompanyId,
    required this.onCompanySelected,
    required this.onManageCompanies,
    required this.onHelp,
    this.onToggleCompact,
    this.compact = false,
    this.showUpdateDot = false,
    this.showProducts = true,
    this.showServices = true,
  });

  /// Products and Services follow the business type (Settings > Company).
  final bool showProducts;
  final bool showServices;

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String? companyName;
  final List<CompanyProfile> companies;
  final String? activeCompanyId;
  final ValueChanged<String> onCompanySelected;
  final VoidCallback onManageCompanies;

  /// Help & Support, at the bottom of the sidebar.
  final VoidCallback onHelp;

  /// Reduces the sidebar to icons, or opens it again. Null hides the button
  /// (a window too narrow for the full sidebar).
  final VoidCallback? onToggleCompact;

  /// Icons only: chosen with the reduce button, or forced by a narrow window.
  final bool compact;
  final bool showUpdateDot;

  static const double expandedWidth = 224;
  static const double compactWidth = 72;

  // A short window (1280x720, a small laptop) gets a denser sidebar, so
  // Reports, Settings and Help & Support still show. The page list scrolls
  // if even that does not fit.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, c) =>
          _build(context, _SidebarDensity.forHeight(c.maxHeight)));

  Widget _build(BuildContext context, _SidebarDensity d) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget item(int index, IconData icon, String label, {bool dot = false}) =>
        _ModernNavItem(
          icon: icon,
          label: label,
          selected: selectedIndex == index,
          compact: compact,
          showDot: dot,
          height: d.itemHeight,
          onTap: () => onSelect(index),
        );

    Widget section(String title) => compact
        ? SizedBox(height: d.compactSectionGap)
        : Padding(
            padding: d.sectionPadding,
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: scheme.onSurfaceVariant,
              ),
            ),
          );

    return Container(
      key: const ValueKey('modernSidebar'),
      width: compact ? compactWidth : expandedWidth,
      decoration: BoxDecoration(
        color: isDark ? scheme.surface : BrandColors.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            Padding(
              padding: d.compactLogoPadding,
              child: Column(
                children: [
                  Image.asset(
                    isDark
                        ? 'assets/images/logo_v_dark.png'
                        : 'assets/images/logo_v.png',
                    height: d.compactLogoHeight,
                  ),
                  if (onToggleCompact != null)
                    IconButton(
                      key: const ValueKey('modernSidebarToggle'),
                      tooltip: l10n.dashboardExpandSidebarTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggleCompact,
                      icon: Icon(Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: d.logoPadding,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Image.asset(
                        isDark
                            ? 'assets/images/logo_compact_dark.png'
                            : 'assets/images/logo_compact.png',
                        height: d.logoHeight,
                        fit: BoxFit.fitHeight,
                      ),
                    ),
                  ),
                  if (onToggleCompact != null)
                    IconButton(
                      key: const ValueKey('modernSidebarToggle'),
                      tooltip: l10n.dashboardCollapseSidebarTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggleCompact,
                      icon: Icon(Icons.chevron_left_rounded,
                          color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          _companyPill(context, l10n, scheme, d.pillVertical),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: d.listGap),
              children: [
                SizedBox(height: d.listGap),
                item(0, Icons.grid_view_outlined, l10n.navDashboard),
                section(l10n.modernNavSectionSales),
                item(1, Icons.description_outlined, l10n.navNewInvoice),
                item(2, Icons.receipt_long_outlined, l10n.navInvoices),
                item(3, Icons.request_quote_outlined, l10n.navQuotations),
                item(4, Icons.point_of_sale_outlined, l10n.navReceipts),
                section(l10n.modernNavSectionCatalog),
                item(5, Icons.people_alt_outlined, l10n.navCustomers),
                if (showProducts)
                  item(6, Icons.inventory_2_outlined, l10n.navProducts),
                if (showServices)
                  item(9, Icons.design_services_outlined, l10n.navServices),
                section(l10n.modernNavSectionBusiness),
                item(7, Icons.bar_chart_outlined, l10n.navReports),
                item(8, Icons.settings_outlined, l10n.navSettings,
                    dot: showUpdateDot),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          SizedBox(height: d.helpTop),
          _ModernNavItem(
            icon: Icons.help_outline,
            label: l10n.modernHelpSupport,
            selected: false,
            compact: compact,
            height: d.itemHeight,
            onTap: onHelp,
          ),
          SizedBox(height: d.helpBottom),
        ],
      ),
    );
  }

  Widget _companyPill(BuildContext context, AppLocalizations l10n,
      ColorScheme scheme, double vertical) {
    final primary = Theme.of(context).primaryColor;
    final name = (companyName?.isNotEmpty ?? false) ? companyName! : '—';
    final initial = name.characters.first.toUpperCase();
    final avatar = CircleAvatar(
      radius: 13,
      backgroundColor: primary,
      child: Text(initial,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    );
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: compact ? 14 : 14, vertical: vertical),
      child: PopupMenuButton<String>(
        key: const ValueKey('modernCompanyMenu'),
        tooltip: name,
        padding: EdgeInsets.zero,
        offset: const Offset(0, 46),
        onSelected: (value) {
          if (value == '__manage__') {
            onManageCompanies();
          } else if (value != activeCompanyId) {
            onCompanySelected(value);
          }
        },
        itemBuilder: (context) => [
          for (final company in companies)
            PopupMenuItem<String>(
              value: company.id,
              child: Row(
                children: [
                  Icon(
                    company.id == activeCompanyId
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 18,
                    color: company.id == activeCompanyId
                        ? Colors.green
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                      child:
                          Text(company.name, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: '__manage__',
            child: Row(
              children: [
                Icon(Icons.settings_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Text(l10n.companyMgmtTitle),
              ],
            ),
          ),
        ],
        child: compact
            ? Center(child: avatar)
            : Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primary),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down, size: 20, color: primary),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Sidebar spacing for the window height. Tall windows keep the full look;
/// shorter ones get smaller gaps and rows, so every page and Help & Support
/// fit.
class _SidebarDensity {
  const _SidebarDensity({
    required this.itemHeight,
    required this.sectionPadding,
    required this.compactSectionGap,
    required this.logoPadding,
    required this.logoHeight,
    required this.compactLogoPadding,
    required this.compactLogoHeight,
    required this.pillVertical,
    required this.listGap,
    required this.helpTop,
    required this.helpBottom,
  });

  final double itemHeight;
  final EdgeInsets sectionPadding;
  final double compactSectionGap;
  final EdgeInsets logoPadding;
  final double logoHeight;
  final EdgeInsets compactLogoPadding;
  final double compactLogoHeight;
  final double pillVertical;
  final double listGap;
  final double helpTop;
  final double helpBottom;

  static const full = _SidebarDensity(
    itemHeight: 42,
    sectionPadding: EdgeInsets.fromLTRB(22, 18, 16, 6),
    compactSectionGap: 14,
    logoPadding: EdgeInsets.fromLTRB(18, 18, 8, 10),
    logoHeight: 46,
    compactLogoPadding: EdgeInsets.only(top: 14, bottom: 4),
    compactLogoHeight: 40,
    pillVertical: 4,
    listGap: 8,
    helpTop: 6,
    helpBottom: 12,
  );

  static const dense = _SidebarDensity(
    itemHeight: 36,
    sectionPadding: EdgeInsets.fromLTRB(22, 12, 16, 4),
    compactSectionGap: 10,
    logoPadding: EdgeInsets.fromLTRB(18, 12, 8, 6),
    logoHeight: 42,
    compactLogoPadding: EdgeInsets.only(top: 10, bottom: 2),
    compactLogoHeight: 36,
    pillVertical: 4,
    listGap: 6,
    helpTop: 4,
    helpBottom: 8,
  );

  static const tight = _SidebarDensity(
    itemHeight: 32,
    sectionPadding: EdgeInsets.fromLTRB(22, 6, 16, 2),
    compactSectionGap: 6,
    logoPadding: EdgeInsets.fromLTRB(18, 8, 8, 4),
    logoHeight: 36,
    compactLogoPadding: EdgeInsets.only(top: 6, bottom: 2),
    compactLogoHeight: 32,
    pillVertical: 2,
    listGap: 4,
    helpTop: 4,
    helpBottom: 4,
  );

  /// The full look needs about 760 px, [dense] about 650 and [tight] about
  /// 560 (all ten pages shown).
  static _SidebarDensity forHeight(double height) {
    if (!height.isFinite || height >= 780) return full;
    if (height >= 660) return dense;
    return tight;
  }
}

class _ModernNavItem extends StatelessWidget {
  const _ModernNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
    this.showDot = false,
    this.height = 42,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final bool showDot;
  final VoidCallback onTap;

  /// Row height: 42, less on a short window (see [_SidebarDensity]).
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    final color = selected ? primary : scheme.onSurface.withValues(alpha: 0.78);

    final iconWidget = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 20, color: color),
        if (showDot)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
            ),
          ),
      ],
    );

    final row = compact
        ? Center(child: iconWidget)
        : Row(
            children: [
              const SizedBox(width: 14),
              iconWidget,
              const SizedBox(width: 14),
              // A long label (Tamil "புதிய விலைப்பட்டியல்") shrinks a little
              // to fit instead of being cut off.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          );

    return Tooltip(
      message: compact ? label : '',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: Material(
          color:
              selected ? primary.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('modernNav_$label'),
            onTap: onTap,
            hoverColor: primary.withValues(alpha: 0.06),
            child: SizedBox(
              height: height,
              child: Stack(
                children: [
                  if (selected)
                    Positioned(
                      left: 0,
                      top: (height - 24) / 2,
                      bottom: (height - 24) / 2,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(3)),
                        ),
                      ),
                    ),
                  Positioned.fill(child: row),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the plus button creates.
enum ModernCreate { invoice, quotation, receipt }

extension ModernCreateType on ModernCreate {
  /// The document type used by the rest of the app.
  String get type => switch (this) {
        ModernCreate.invoice => 'Invoice',
        ModernCreate.quotation => 'Quotation',
        ModernCreate.receipt => 'Receipt',
      };
}

/// What the user menu offers.
enum ModernUserAction { settings, changePassword, coffee, help, logout }

/// Top bar: search, the plus button (new invoice / quotation / receipt), the
/// language picker, and the signed-in user.
class ModernTopBar extends StatelessWidget {
  const ModernTopBar({
    super.key,
    required this.username,
    required this.isAdmin,
    required this.onSearch,
    required this.onCreate,
    required this.onUserAction,
    this.page = 0,
    this.pageTitle,
    this.header,
  });

  final String username;
  final bool isAdmin;
  final VoidCallback onSearch;
  final ValueChanged<ModernCreate> onCreate;
  final ValueChanged<ModernUserAction> onUserAction;

  /// The open page (sidebar index). The Dashboard (0) shows the search box;
  /// any other page shows its title instead: the [header] the page sent, or
  /// [pageTitle] when the page has not sent one.
  final int page;
  final String? pageTitle;
  final ValueListenable<ModernPageHeader?>? header;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    PopupMenuItem<ModernCreate> createItem(
            ModernCreate value, IconData icon, String label) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Text(l10n.invoiceMgmtNewDocumentButton(label)),
            ],
          ),
        );

    PopupMenuItem<ModernUserAction> userItem(
            ModernUserAction value, IconData icon, String label) =>
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Flexible(child: Text(label)),
            ],
          ),
        );

    return Container(
      key: const ValueKey('modernTopBar'),
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? scheme.surface : BrandColors.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: page == 0 || header == null
          ? _row(context, null, l10n, scheme, primary, createItem, userItem)
          : ValueListenableBuilder<ModernPageHeader?>(
              valueListenable: header!,
              builder: (context, h, _) => _row(
                  context,
                  h != null && h.page == page ? h : null,
                  l10n,
                  scheme,
                  primary,
                  createItem,
                  userItem),
            ),
    );
  }

  Widget _title(ModernPageHeader? h, ColorScheme scheme) {
    final title = h?.title ?? pageTitle ?? '';
    final subtitle = h?.subtitle;
    return Column(
      key: const ValueKey('modernPageTitle'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A long title (Tamil) shrinks a little to fit.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(title,
              maxLines: 1,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
        ),
        if (subtitle != null && subtitle.isNotEmpty)
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant, height: 1.3)),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    ModernPageHeader? h,
    AppLocalizations l10n,
    ColorScheme scheme,
    Color primary,
    PopupMenuItem<ModernCreate> Function(ModernCreate, IconData, String)
        createItem,
    PopupMenuItem<ModernUserAction> Function(ModernUserAction, IconData, String)
        userItem,
  ) {
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (h != null && h.actions.isNotEmpty)
          for (final a in h.actions) ...[a, const SizedBox(width: 4)],
        if (h?.createButton != null) ...[
          const SizedBox(width: 8),
          h!.createButton!,
        ] else
          PopupMenuButton<ModernCreate>(
            key: const ValueKey('modernCreateMenu'),
            tooltip: l10n.modernCreateNewTooltip,
            offset: const Offset(0, 48),
            onSelected: onCreate,
            itemBuilder: (context) => [
              createItem(ModernCreate.invoice, Icons.description_outlined,
                  l10n.labelInvoice),
              createItem(ModernCreate.quotation, Icons.request_quote_outlined,
                  l10n.labelQuotation),
              createItem(ModernCreate.receipt, Icons.point_of_sale_outlined,
                  l10n.labelReceipt),
            ],
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        // The language is chosen in Settings (Company Info); Help & Support
        // is in the sidebar.
        const SizedBox(width: 12),
        PopupMenuButton<ModernUserAction>(
          key: const ValueKey('modernUserMenu'),
          tooltip: username,
          offset: const Offset(0, 48),
          onSelected: onUserAction,
          itemBuilder: (context) => [
            userItem(ModernUserAction.settings, Icons.settings_outlined,
                l10n.navSettings),
            // Every user, not only admins, can change their own password.
            userItem(ModernUserAction.changePassword, Icons.lock_reset_outlined,
                l10n.userMgmtChangePasswordTitle),
            userItem(ModernUserAction.coffee, Icons.coffee_outlined,
                l10n.buyMeCoffeeLabel),
            userItem(ModernUserAction.help, Icons.help_outline,
                l10n.modernHelpSupport),
            const PopupMenuDivider(),
            userItem(ModernUserAction.logout, Icons.logout_rounded,
                l10n.dashboardLogoutTooltip),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: primary.withValues(alpha: 0.14),
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                          isAdmin
                              ? l10n.dashboardRoleAdmin
                              : l10n.dashboardRoleUser,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down,
                    size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
    return LayoutBuilder(
        builder: (context, box) => Row(
              children: [
                if (page != 0 && h?.onBack != null) ...[
                  IconButton(
                    key: const ValueKey('modernHeaderBack'),
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(Icons.chevron_left, size: 26),
                    onPressed: h!.onBack,
                  ),
                  const SizedBox(width: 4),
                ],
                if (page != 0)
                  Expanded(child: _title(h, scheme))
                else ...[
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: Material(
                        key: const ValueKey('modernSearch'),
                        color: scheme.surfaceContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: onSearch,
                          child: SizedBox(
                            height: 40,
                            child: Row(
                              children: [
                                const SizedBox(width: 12),
                                Icon(Icons.search,
                                    size: 20, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.modernTopBarSearchHint,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: scheme.onSurfaceVariant),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
                if (page != 0) ...[
                  // The buttons and menus take the room they need (up to 75% of the
                  // bar) and the title gets the rest. When they do not fit (Tamil
                  // labels, a narrow window) they shrink a little instead of being
                  // pushed off the edge.
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * 0.75),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: trailing,
                    ),
                  ),
                ] else
                  trailing,
              ],
            ));
  }
}
