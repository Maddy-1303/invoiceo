// The Modern layout's dashboard (the only dashboard design in Modern: no
// Default / Classic / Bento / Simple choice here). See docs/LAYOUTS.md.
//
//  * Header: title, greeting, and the date range the cards and the invoice
//    status work on (this month by default).
//  * Four cards: revenue collected, outstanding, invoices (each compared with
//    the period before) and products (with how many are low on stock).
//  * Sales overview (collected / outstanding per month) and invoice status.
//  * Recent invoices and low-stock products.
//  * Quick actions.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/domain/invoice_calculator.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/models/report_models.dart';
import 'package:invoiceo/models/user.dart';
import 'package:invoiceo/providers/repositories.dart';
import 'package:invoiceo/services/invoice_pdf_services.dart';
import 'package:invoiceo/theme/brand_colors.dart';
import 'package:invoiceo/utils/formatters.dart';

// ── Small pure helpers (tested in test/modern_dashboard_test.dart) ──────────

/// The calendar month containing [day].
DateTimeRange modernMonthRange(DateTime day) => DateTimeRange(
    start: DateTime(day.year, day.month, 1),
    end: DateTime(day.year, day.month + 1, 0));

/// True when [range] is exactly one calendar month.
bool modernIsWholeMonth(DateTimeRange range) {
  final s = range.start, e = range.end;
  return s.day == 1 &&
      s.year == e.year &&
      s.month == e.month &&
      e.day == DateTime(e.year, e.month + 1, 0).day;
}

/// The period just before [range], of the same length. A whole calendar month
/// gives the whole previous month (so October compares with September).
DateTimeRange modernPreviousRange(DateTimeRange range) {
  if (modernIsWholeMonth(range)) {
    return modernMonthRange(DateTime(range.start.year, range.start.month - 1, 1));
  }
  final start = DateTime(range.start.year, range.start.month, range.start.day);
  final end = DateTime(range.end.year, range.end.month, range.end.day);
  final days = end.difference(start).inDays + 1;
  final prevEnd = DateTime(start.year, start.month, start.day - 1);
  return DateTimeRange(
      start: DateTime(prevEnd.year, prevEnd.month, prevEnd.day - (days - 1)),
      end: prevEnd);
}

/// Percent change from [before] to [now]; null when there is nothing to
/// compare with (the earlier period was zero and this one is not).
double? modernPercentChange(num now, num before) {
  if (before == 0) return now == 0 ? 0 : null;
  return (now - before) / before * 100;
}

/// Invoice counts for the status donut. An overdue invoice counts only as
/// overdue (not also as unpaid / partial), so the four add up to the total.
class ModernStatusCounts {
  const ModernStatusCounts(
      {this.paid = 0, this.unpaid = 0, this.partial = 0, this.overdue = 0});

  final int paid;
  final int unpaid;
  final int partial;
  final int overdue;

  int get total => paid + unpaid + partial + overdue;

  factory ModernStatusCounts.fromRows(List<InvoiceStatusRow> rows) {
    var paid = 0, unpaid = 0, partial = 0, overdue = 0;
    for (final r in rows) {
      if (r.isOverdue) {
        overdue++;
      } else if (r.status == 'Paid') {
        paid++;
      } else if (r.status == 'Partial') {
        partial++;
      } else {
        unpaid++;
      }
    }
    return ModernStatusCounts(
        paid: paid, unpaid: unpaid, partial: partial, overdue: overdue);
  }
}

/// One month of the sales overview chart.
class ModernTrendPoint {
  const ModernTrendPoint(this.month, this.collected, this.outstanding);
  final DateTime month;
  final double collected;
  final double outstanding;
}

/// Every month from [from] to [to], filled from [points] (months without data
/// are zero, so the chart has no gaps).
List<ModernTrendPoint> modernFillMonths(
    DateTime from, DateTime to, List<MonthlyPoint> points) {
  final byMonth = {for (final p in points) p.month: p};
  final out = <ModernTrendPoint>[];
  var m = DateTime(from.year, from.month);
  final last = DateTime(to.year, to.month);
  while (!m.isAfter(last)) {
    // Built by hand: DateFormat follows the app language and would give
    // native digits (Nepali), which never match the stored '2026-10'.
    final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
    final p = byMonth[key];
    out.add(ModernTrendPoint(m, p?.collected ?? 0, p?.outstanding ?? 0));
    m = DateTime(m.year, m.month + 1);
  }
  return out;
}

// ── Colours used only on this page ──────────────────────────────────────────

class _C {
  static const blue = Color(0xFF2563EB);
  static const red = Color(0xFFEF4444);
  static const orange = Color(0xFFF59E0B);
  static const green = Color(0xFF22C55E);
  static const teal = Color(0xFF2DD4A0);
  static const purple = Color(0xFF7C3AED);
  static const pink = Color(0xFFE11D48);
  static const indigo = Color(0xFF4F46E5);
}

/// What the page asks the dashboard to do.
class ModernDashboard extends ConsumerStatefulWidget {
  const ModernDashboard({
    super.key,
    required this.user,
    required this.onEditInvoice,
    required this.onCloneInvoice,
    required this.onCreateDocument,
    required this.onOpenPage,
    required this.onAddCustomer,
    required this.onAddProduct,
  });

  final User user;
  final void Function(Invoice invoice) onEditInvoice;
  final void Function(Invoice invoice, String type) onCloneInvoice;

  /// 'Invoice' | 'Quotation' | 'Receipt'
  final void Function(String type) onCreateDocument;

  /// Opens a page by the dashboard's page number (2 Invoices, 6 Products,
  /// 7 Reports, 8 Settings, ...).
  final void Function(int page) onOpenPage;
  final VoidCallback onAddCustomer;
  final VoidCallback onAddProduct;

  @override
  ConsumerState<ModernDashboard> createState() => _ModernDashboardState();
}

class _ModernDashboardState extends ConsumerState<ModernDashboard> {
  late DateTimeRange _range = modernMonthRange(DateTime.now());
  int _trendMonths = 6;

  bool _loading = true;
  String _currency = '₹';
  String _currencyCode = 'INR';
  RevenueKpi _kpi = RevenueKpi.empty;
  RevenueKpi _prevKpi = RevenueKpi.empty;
  int _productCount = 0;
  int _lowStockCount = 0;
  ModernStatusCounts _status = const ModernStatusCounts();
  List<ModernTrendPoint> _trend = const [];
  List<Invoice> _recent = const [];
  List<Product> _lowStock = const [];
  int _loadId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_loadId;
    final reports = ref.read(reportRepositoryProvider);
    final products = ref.read(productRepositoryProvider);
    final invoices = ref.read(invoiceRepositoryProvider);
    final prev = modernPreviousRange(_range);
    final now = DateTime.now();
    final trendFrom = DateTime(now.year, now.month - (_trendMonths - 1), 1);
    final trendTo = modernMonthRange(now).end;

    // Only the home currency is added up (as on Reports), so invoices in
    // another currency are not counted under the home symbol.
    final currency = await ref.read(settingsRepositoryProvider).getCurrency();
    if (!mounted || id != _loadId) return;
    final code = currency.code;

    final r = await Future.wait([
      Future.value(currency), // 0
      reports.getRevenueSummary(_range.start, _range.end, currencyCode: code), // 1
      reports.getRevenueSummary(prev.start, prev.end, currencyCode: code), // 2
      products.getProductListCount(type: 'product'), // 3 (services have their own page)
      // Products only, matching the Products page that "See all" opens.
      products.getProductListCount(tab: 'low', type: 'product'), // 4
      products.getProductListCount(tab: 'out', type: 'product'), // 5
      reports.getInvoiceStatusList(_range.start, _range.end,
          currencyCode: code), // 6
      reports.getMonthlyRevenueTrend(trendFrom, trendTo,
          currencyCode: code), // 7
      // "Recent Invoices": invoices only (no quotations shown as Unpaid).
      invoices.getRecentInvoices(limit: 5, type: 'Invoice'), // 8
      products.getProductListPage(
          offset: 0, limit: 5, tab: 'out', orderBy: 'stock', type: 'product'), // 9
      products.getProductListPage(
          offset: 0, limit: 5, tab: 'low', orderBy: 'stock', type: 'product'), // 10
    ]);
    if (!mounted || id != _loadId) return;
    setState(() {
      _currency = (r[0] as CurrencyOption).symbol;
      _currencyCode = code;
      _kpi = r[1] as RevenueKpi;
      _prevKpi = r[2] as RevenueKpi;
      _productCount = r[3] as int;
      _lowStockCount = (r[4] as int) + (r[5] as int);
      _status = ModernStatusCounts.fromRows(r[6] as List<InvoiceStatusRow>);
      _trend = modernFillMonths(
          trendFrom, trendTo, r[7] as List<MonthlyPoint>);
      _recent = r[8] as List<Invoice>;
      // Out of stock first, then the lowest stock: the five most urgent.
      _lowStock = [...r[9] as List<Product>, ...r[10] as List<Product>]
          .take(5)
          .toList();
      _loading = false;
    });
  }

  String _money(double v) =>
      '$_currency ${NumberFormat('#,##0.00').format(v)}';

  String _compact(double v) {
    // Lakh / crore only for rupees; other currencies use the usual K / M.
    // English symbols, like the rupee labels: the axis is only 44 px wide,
    // and e.g. Hindi/Nepali '१० हजार' or Spanish '100 mil' would wrap there.
    if (_currencyCode != 'INR') {
      return NumberFormat.compact(locale: 'en').format(v);
    }
    if (v.abs() >= 10000000) return '${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v.abs() >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(v.abs() >= 10000 ? 0 : 1)}K';
    return v.toStringAsFixed(0);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      key: const ValueKey('modernDashboard'),
      color: isDark ? Theme.of(context).scaffoldBackgroundColor : BrandColors.page,
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 1100;
        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 20),
                _kpiCards(c.maxWidth - 48),
                const SizedBox(height: 18),
                _pair(wide, _salesOverview(), _invoiceStatus(sideBySide: wide), 3, 2),
                const SizedBox(height: 18),
                _pair(wide, _recentInvoices(), _lowStockCard(), 3, 2),
                const SizedBox(height: 18),
                _quickActions(),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _pair(bool wide, Widget a, Widget b, int fa, int fb) => wide
      ? IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: fa, child: a),
              const SizedBox(width: 18),
              Expanded(flex: fb, child: b),
            ],
          ),
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [a, const SizedBox(height: 18), b],
        );

  Widget _card({required Widget child, EdgeInsets? padding, Key? key}) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: key,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHighest : BrandColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: child,
    );
  }

  Widget _cardTitle(String title, {Widget? trailing}) => Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing,
        ],
      );

  // ── Header ─────────────────────────────────────────────────────────────

  String _greeting(AppLocalizations l10n) {
    final h = DateTime.now().hour;
    final name = widget.user.username;
    if (h < 12) return l10n.modernDashGreetingMorning(name);
    if (h < 17) return l10n.modernDashGreetingAfternoon(name);
    return l10n.modernDashGreetingEvening(name);
  }

  Widget _header() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.navDashboard,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('${_greeting(l10n)} 👋',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(l10n.modernDashSubtitle,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.start,
      runSpacing: 12,
      spacing: 12,
      children: [title, _rangePicker()],
    );
  }

  Widget _rangePicker() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('MMM dd, yyyy');
    final now = DateTime.now();
    final presets = <String, DateTimeRange>{
      l10n.modernDashThisMonth: modernMonthRange(now),
      l10n.modernDashLastMonth: modernMonthRange(DateTime(now.year, now.month - 1, 1)),
      l10n.reportsPresetLast3MonthsLabel: DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1), end: modernMonthRange(now).end),
      l10n.reportsPresetThisYearLabel:
          DateTimeRange(start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31)),
    };
    return PopupMenuButton<Object>(
      key: const ValueKey('modernDashRange'),
      tooltip: '',
      offset: const Offset(0, 48),
      onSelected: (v) async {
        if (v is DateTimeRange) {
          setState(() => _range = v);
          _load();
        } else {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            initialDateRange: _range,
          );
          if (picked == null || !mounted) return;
          setState(() => _range = picked);
          _load();
        }
      },
      itemBuilder: (_) => [
        for (final e in presets.entries)
          PopupMenuItem<Object>(value: e.value, child: Text(e.key)),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
            value: 'custom', child: Text(l10n.reportsCustomRangeLabel)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? scheme.surfaceContainerHighest
              : BrandColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('${fmt.format(_range.start)} - ${fmt.format(_range.end)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down, size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  // ── KPI cards ──────────────────────────────────────────────────────────

  Widget _kpiCards(double width) {
    final l10n = AppLocalizations.of(context)!;
    final versus = modernIsWholeMonth(_range)
        ? l10n.modernDashVsLastMonth
        : l10n.modernDashVsPreviousPeriod;
    final cards = [
      _kpi1(Icons.insights_outlined, _C.blue, l10n.dashboardRevenueCollectedLabel,
          _money(_kpi.collected),
          _changeChip(modernPercentChange(_kpi.collected, _prevKpi.collected), versus)),
      _kpi1(Icons.hourglass_bottom_outlined, _C.red, l10n.dashboardOutstandingLabel,
          _money(_kpi.outstanding),
          _changeChip(modernPercentChange(_kpi.outstanding, _prevKpi.outstanding), versus)),
      _kpi1(Icons.description_outlined, _C.orange, l10n.dashboardTotalInvoicesLabel,
          '${_kpi.invoiceCount}',
          _changeChip(modernPercentChange(_kpi.invoiceCount, _prevKpi.invoiceCount), versus)),
      _kpi1(Icons.inventory_2_outlined, _C.green, l10n.navProducts, '$_productCount',
          _lowStockChip()),
    ];
    final perRow = width >= 900 ? 4 : (width >= 560 ? 2 : 1);
    const gap = 16.0;
    final w = (width - gap * (perRow - 1)) / perRow;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [for (final c in cards) SizedBox(width: w, child: c)],
    );
  }

  Widget _kpi1(IconData icon, Color color, String label, String value, Widget foot) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHighest
            : Color.alphaBlend(color.withValues(alpha: 0.035), Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                foot,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _changeChip(double? pct, String versus) {
    final scheme = Theme.of(context).colorScheme;
    final Widget badge;
    if (pct == null) {
      badge = const SizedBox.shrink();
    } else {
      final up = pct >= 0;
      final color = up ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(up ? Icons.arrow_upward : Icons.arrow_downward, size: 13, color: color),
            const SizedBox(width: 2),
            Text('${pct.abs().round()}%',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        badge,
        Text(versus, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _lowStockChip() {
    final l10n = AppLocalizations.of(context)!;
    final color = _lowStockCount > 0 ? _C.orange : const Color(0xFF16A34A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(l10n.modernDashLowStockCount(_lowStockCount),
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ── Sales overview ─────────────────────────────────────────────────────

  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );

  Widget _salesOverview() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final hasData = _trend.any((p) => p.collected > 0 || p.outstanding > 0);
    final maxY = _trend.fold<double>(
        0, (m, p) => [m, p.collected, p.outstanding].reduce((a, b) => a > b ? a : b));
    final top = maxY <= 0 ? 1000.0 : maxY * 1.2;
    final fmt = DateFormat('MMM yyyy');

    LineChartBarData series(Color color, double Function(ModernTrendPoint) v) =>
        LineChartBarData(
          spots: [
            for (var i = 0; i < _trend.length; i++) FlSpot(i.toDouble(), v(_trend[i])),
          ],
          isCurved: true,
          curveSmoothness: 0.3,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2.6,
          dotData: FlDotData(
            show: true,
            getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                radius: 3.6, color: color, strokeWidth: 2, strokeColor: Colors.white),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.0)],
            ),
          ),
        );

    final chart = !hasData || _trend.isEmpty
        ? Center(
            child: Text(l10n.modernDashNoData,
                style: TextStyle(color: scheme.onSurfaceVariant)))
        : LineChart(
            LineChartData(
              minY: 0,
              maxY: top,
              minX: 0,
              maxX: (_trend.length - 1).toDouble(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: top / 3,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: scheme.outlineVariant.withValues(alpha: 0.6), strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: top / 3,
                    getTitlesWidget: (v, meta) => Text(_compact(v),
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: _trend.length > 8 ? 2 : 1,
                    getTitlesWidget: (v, meta) {
                      final i = v.round();
                      if (i < 0 || i >= _trend.length || v != i.toDouble()) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(fmt.format(_trend[i].month),
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Theme.of(context).brightness == Brightness.dark
                      ? scheme.surfaceContainerHighest
                      : Colors.white,
                  tooltipBorder: BorderSide(color: scheme.outlineVariant),
                  tooltipRoundedRadius: 10,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => [
                    for (var k = 0; k < spots.length; k++)
                      LineTooltipItem(
                        k == 0 ? '${fmt.format(_trend[spots[k].x.round()].month)}\n' : '',
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        textAlign: TextAlign.left,
                        children: [
                          TextSpan(
                            text: '${spots[k].barIndex == 0 ? l10n.dashboardCollectedLabel : l10n.dashboardOutstandingLabel}  ',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                          TextSpan(
                            text: _money(spots[k].y),
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                series(_C.blue, (p) => p.collected),
                series(_C.teal, (p) => p.outstanding),
              ],
            ),
          );

    return _card(
      key: const ValueKey('modernDashSales'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Text(l10n.modernDashSalesOverview,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _legendDot(_C.blue, l10n.dashboardCollectedLabel),
                  _legendDot(_C.teal, l10n.dashboardOutstandingLabel),
                  PopupMenuButton<int>(
                    key: const ValueKey('modernDashTrendMonths'),
                    tooltip: '',
                    onSelected: (m) {
                      setState(() => _trendMonths = m);
                      _load();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 6, child: Text(l10n.reportsPresetLast6MonthsLabel)),
                      PopupMenuItem(value: 12, child: Text(l10n.modernDashLast12Months)),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            _trendMonths == 6
                                ? l10n.reportsPresetLast6MonthsLabel
                                : l10n.modernDashLast12Months,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 18),
                      ]),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(height: 230, child: _loading ? const SizedBox.shrink() : chart),
        ],
      ),
    );
  }

  // ── Invoice status ─────────────────────────────────────────────────────

  /// [sideBySide]: the card sits next to the sales chart (inside an
  /// IntrinsicHeight, which cannot hold a LayoutBuilder), so the donut and
  /// the legend always go side by side.
  Widget _invoiceStatus({required bool sideBySide}) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final s = _status;
    final rows = [
      (l10n.paymentStatusPaid, s.paid, _C.teal),
      (l10n.paymentStatusUnpaid, s.unpaid, _C.blue),
      (l10n.paymentStatusPartial, s.partial, const Color(0xFFFBBF24)),
      (l10n.invoiceMgmtOverdueBadge, s.overdue, _C.red),
    ];
    String pct(int n) => s.total == 0 ? '0%' : '${(n * 100 / s.total).round()}%';

    final donut = SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: s.total == 0 ? 0 : 2,
              centerSpaceRadius: 56,
              sections: s.total == 0
                  ? [
                      PieChartSectionData(
                          value: 1, color: scheme.outlineVariant, radius: 22, showTitle: false)
                    ]
                  : [
                      for (final r in rows)
                        if (r.$2 > 0)
                          PieChartSectionData(
                              value: r.$2.toDouble(), color: r.$3, radius: 22, showTitle: false),
                    ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${s.total}',
                  key: const ValueKey('modernDashStatusTotal'),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              Text(l10n.navInvoices,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );

    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(color: r.$3, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 14.5))),
                SizedBox(
                  width: 40,
                  child: Text('${r.$2}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                ),
                SizedBox(
                  width: 52,
                  child: Text(pct(r.$2),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
      ],
    );

    return _card(
      key: const ValueKey('modernDashStatus'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(l10n.reportsNavInvoiceStatusLabel),
          const SizedBox(height: 18),
          if (sideBySide)
            Row(children: [
              donut,
              const SizedBox(width: 24),
              Expanded(child: legend),
            ])
          else
            LayoutBuilder(builder: (context, c) {
              if (c.maxWidth >= 380) {
                return Row(children: [
                  donut,
                  const SizedBox(width: 24),
                  Expanded(child: legend),
                ]);
              }
              return Column(children: [donut, const SizedBox(height: 12), legend]);
            }),
        ],
      ),
    );
  }

  // ── Recent invoices ────────────────────────────────────────────────────

  (String, Color) _statusOf(Invoice inv, AppLocalizations l10n) {
    if (InvoiceCalculator.isOverdue(
        dueDate: inv.dueDate, outstanding: inv.outstandingBalance)) {
      return (l10n.invoiceMgmtOverdueBadge, const Color(0xFFDC2626));
    }
    return switch (inv.paymentStatus) {
      PaymentStatus.paid => (l10n.paymentStatusPaid, const Color(0xFF16A34A)),
      PaymentStatus.partial => (l10n.paymentStatusPartial, const Color(0xFFD97706)),
      PaymentStatus.unpaid => (l10n.paymentStatusUnpaid, const Color(0xFFE11D48)),
    };
  }

  Widget _tableHead(List<(String, int, TextAlign)> cols, {double trailing = 0}) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainer : BrandColors.tableHeader.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        for (final c in cols)
          Expanded(
              flex: c.$2,
              child: Text(c.$1, textAlign: c.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        if (trailing > 0) SizedBox(width: trailing),
      ]),
    );
  }

  Widget _seeAll(int page) {
    final l10n = AppLocalizations.of(context)!;
    return TextButton(
      onPressed: () => widget.onOpenPage(page),
      child: Text(l10n.dashboardViewAllAction),
    );
  }

  Widget _recentInvoices() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd MMM yyyy');
    return _card(
      key: const ValueKey('modernDashRecent'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(l10n.modernDashRecentInvoices, trailing: _seeAll(2)),
          const SizedBox(height: 8),
          _tableHead([
            (l10n.modernDashInvoiceNo, 4, TextAlign.left),
            (l10n.labelCustomer, 3, TextAlign.left),
            (l10n.invoiceMgmtColDate, 3, TextAlign.left),
            (l10n.labelAmount, 3, TextAlign.left),
            (l10n.invoiceMgmtColStatus, 2, TextAlign.left),
          ], trailing: 128),
          if (!_loading && _recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                  child: Text(l10n.dashboardNoInvoicesYetTitle,
                      style: TextStyle(color: scheme.onSurfaceVariant))),
            ),
          for (final inv in _recent) _invoiceRow(inv, l10n, fmt),
        ],
      ),
    );
  }

  Widget _invoiceRow(Invoice inv, AppLocalizations l10n, DateFormat fmt) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = _statusOf(inv, l10n);
    final symbol = inv.currencySymbol.isNotEmpty ? inv.currencySymbol : _currency;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.description_outlined, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text('#${inv.invoiceNumber ?? inv.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ]),
          ),
          Expanded(
            flex: 3,
            child: Text(inv.customer.name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            flex: 3,
            child: Text(fmt.format(inv.date),
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            flex: 3,
            child: Text('$symbol ${NumberFormat('#,##0.00').format(inv.total)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              ),
            ),
          ),
          SizedBox(
            width: 128,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: l10n.actionView,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.visibility_outlined, size: 19, color: scheme.onSurfaceVariant),
                  onPressed: () => InvoicePdfServices.previewPDF(context, inv),
                ),
                IconButton(
                  tooltip: l10n.actionPrint,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.print_outlined, size: 19, color: scheme.onSurfaceVariant),
                  onPressed: () => InvoicePdfServices.generatePDF(context, inv),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.dashboardActionsTooltip,
                  icon: Icon(Icons.more_vert, size: 19, color: scheme.onSurfaceVariant),
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        widget.onEditInvoice(inv);
                      case 'duplicate':
                        widget.onCloneInvoice(inv, inv.type);
                      case 'details':
                        InvoicePdfServices.showInvoiceDetails(context, inv);
                    }
                  },
                  itemBuilder: (_) => [
                    // A declined invoice has given its stock back; editing it
                    // would give it back again (the Invoices list hides it too).
                    if (!(inv.type == 'Invoice' && inv.status == 'declined'))
                      PopupMenuItem(value: 'edit', child: Text(l10n.actionEdit)),
                    PopupMenuItem(value: 'duplicate', child: Text(l10n.actionDuplicate)),
                    PopupMenuItem(value: 'details', child: Text(l10n.createInvoiceViewDetailsLabel)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Low stock ──────────────────────────────────────────────────────────

  Widget _lowStockCard() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return _card(
      key: const ValueKey('modernDashLowStock'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(l10n.modernDashLowStockProducts, trailing: _seeAll(6)),
          const SizedBox(height: 8),
          _tableHead([
            (l10n.labelProduct, 5, TextAlign.left),
            (l10n.labelStock, 2, TextAlign.center),
          ], trailing: 96),
          if (!_loading && _lowStock.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                  child: Text(l10n.modernDashNoLowStock,
                      style: TextStyle(color: scheme.onSurfaceVariant))),
            ),
          for (final p in _lowStock) _stockRow(p, l10n),
        ],
      ),
    );
  }

  Widget _stockRow(Product p, AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final color = p.stock <= 5 ? _C.red : _C.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(children: [
              // Product pictures come later; a neutral tile holds the place.
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Icon(Icons.inventory_2_outlined, size: 18, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(minWidth: 34),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(AppFormatters.formatStock(p.stock),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: l10n.modernDashUpdateStock,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.edit_outlined, size: 18, color: scheme.onSurfaceVariant),
                  onPressed: () => _updateStock(p),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.dashboardActionsTooltip,
                  icon: Icon(Icons.more_vert, size: 19, color: scheme.onSurfaceVariant),
                  onSelected: (v) {
                    if (v == 'stock') _updateStock(p);
                    if (v == 'products') widget.onOpenPage(6);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'stock', child: Text(l10n.modernDashUpdateStock)),
                    PopupMenuItem(value: 'products', child: Text(l10n.navProducts)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStock(Product p) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _StockDialog(product: p),
    );
    if (value == null || !mounted) return;
    await ref.read(productRepositoryProvider).updateProductStock(p.id, value);
    await _load();
  }

  // ── Quick actions ──────────────────────────────────────────────────────

  Widget _quickActions() {
    final l10n = AppLocalizations.of(context)!;
    final actions = <(IconData, String, Color, bool, VoidCallback)>[
      (Icons.description_outlined, l10n.navNewInvoice, _C.blue, true,
          () => widget.onCreateDocument('Invoice')),
      (Icons.request_quote_outlined,
          l10n.invoiceMgmtNewDocumentButton(l10n.labelQuotation), _C.green, false,
          () => widget.onCreateDocument('Quotation')),
      (Icons.person_add_alt_outlined, l10n.modernDashAddCustomer, _C.purple, false,
          widget.onAddCustomer),
      (Icons.inventory_2_outlined, l10n.modernDashAddProduct, _C.orange, false,
          widget.onAddProduct),
      (Icons.bar_chart_outlined, l10n.modernDashViewReports, _C.pink, false,
          () => widget.onOpenPage(7)),
      (Icons.settings_outlined, l10n.navSettings, _C.indigo, false,
          () => widget.onOpenPage(8)),
    ];
    return _card(
      key: const ValueKey('modernDashQuickActions'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(l10n.dashboardQuickActionsTitle),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final perRow = c.maxWidth >= 980 ? 6 : (c.maxWidth >= 640 ? 3 : 2);
            const gap = 12.0;
            final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final a in actions)
                  SizedBox(width: w, height: 46, child: _actionButton(a)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _actionButton((IconData, String, Color, bool, VoidCallback) a) {
    final (icon, label, color, primary, onTap) = a;
    return Material(
      key: ValueKey('modernDashAction_$label'),
      color: primary ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: primary ? Colors.white : color),
              const SizedBox(width: 10),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primary ? Colors.white : color)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a product's new stock. Owns its text box, so the box lives exactly
/// as long as the dialog (including its closing animation).
class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.product});
  final Product product;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: AppFormatters.formatStock(widget.product.stock));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // A decimal is fine (12.5 kg); text that is not a number saves nothing.
  void _save() {
    final v = double.tryParse(_controller.text.trim());
    Navigator.pop(context, v == null || !v.isFinite || v < 0 ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.modernDashUpdateStock),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('modernDashStockField'),
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
                labelText: l10n.modernDashNewStockLabel,
                border: const OutlineInputBorder()),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(onPressed: _save, child: Text(l10n.actionSave)),
      ],
    );
  }
}
