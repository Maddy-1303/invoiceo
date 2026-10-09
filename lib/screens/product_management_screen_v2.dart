import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoiceo/common/constants.dart';
import 'package:invoiceo/providers/repositories.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';

import 'package:intl/intl.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/models/product_list_stats.dart';
import 'package:invoiceo/models/user.dart';
import 'package:invoiceo/utils/formatters.dart';
import 'package:invoiceo/screens/settings/product_columns_settings_screen.dart';

import 'package:invoiceo/common/app_config.dart';
import 'package:invoiceo/services/pdf/pdf_font_service.dart';
import 'package:invoiceo/theme/brand_colors.dart';
import 'package:invoiceo/utils/app_date.dart';
import 'package:invoiceo/widgets/fit_text.dart';
class ProductManagementScreenV2 extends ConsumerStatefulWidget {
  final User user;

  /// Opens the "new product" form as soon as the page shows (Modern
  /// dashboard's "Add Product").
  final bool startWithAddPanel;

  /// The Modern layout's page design (see _buildModern): one page per
  /// [kind], 'product' (Products) or 'service' (Services).
  final bool modern;
  final String kind;

  /// Standard page: the tab it opens on (0 all, 1 products, 2 services...).
  final int initialTab;
  const ProductManagementScreenV2(
      {super.key,
      required this.user,
      this.startWithAddPanel = false,
      this.modern = false,
      this.kind = 'product',
      this.initialTab = 0});

  @override
  ConsumerState<ProductManagementScreenV2> createState() =>
      _ProductManagementScreenV2State();
}

class _ProductManagementScreenV2State extends ConsumerState<ProductManagementScreenV2>
    with ModernHeaderPublisher {
  List<Product> _products = [];

  // Pagination
  int _currentPage = 0;
  int _pageSize = 10;
  int _totalProducts = 0;
  int _allProductsCount = 0;

  // Search and Sort
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _isAscending = true;
  bool _isLoading = false;
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _horizontalScrollController = ScrollController();
  Timer? _searchDebounce;
  int _loadRequestId = 0;

  // Form controllers
  final _nameController = TextEditingController();
  final _aliasNameController = TextEditingController();
  final _defaultDiscountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _hsnCodeController = TextEditingController();
  final _taxRateController = TextEditingController();
  final _customUnitController = TextEditingController();
  String _selectedUnit = '';
  final _formKey = GlobalKey<FormState>();

  // Metadata form controllers (add form)
  final _storageLocationController = TextEditingController();
  final _containerNumberController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _manufactureNameController = TextEditingController();
  final _supplierNameController = TextEditingController();
  final _skuCodeController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _expiryDate;
  DateTime? _manufactureDate;
  String _datePattern = 'dd/MM/yyyy';

  String _currencySymbol = '₹';
  BusinessType _businessType = BusinessType.both;
  String _newItemType = 'product'; // type for the add-product form
  bool _unlimitedStock = false;
  bool _priceIncludesTax = false;

  // ── V2 state ──────────────────────────────────────────────────────────
  // Only the visible page is loaded (tab/search/sort/paging in SQL, see
  // _loadProducts); stat cards / tab counts come from one aggregate query
  // (_statsV2) — never the whole catalog (Issues.md #42).
  ProductListStats _statsV2 = (
    all: 0,
    products: 0,
    services: 0,
    lowStock: 0,
    outOfStock: 0,
    expired: 0,
  );
  Map<String, ProductMetadata> _productMetadataV2 = {};
  bool _statsLoadingV2 = false;
  int _activeTabV2 = 0; // 0 all, 1 products, 2 services, 3 low stock, 4 out of stock
  bool _showAddPanelV2 = false;
  int _addPanelTabV2 = 0; // 0 Basic Information, 1 Advanced
  bool _addAnotherAfterSavingV2 = false;
  bool _showStatsCardsV2 = true;

  static const _csvMaxRows = 500;
  static const _csvHeaders = [
    'name',
    'hsn_code',
    'description',
    'price',
    'tax_rate',
    'stock',
    'type',
    'default_discount',
    'purchase_price',
    'alias_name',
    'unit',
    'unlimited_stock',
    'price_includes_tax',
    'storage_location',
    'container_number',
    'batch_number',
    'expiry_date',
    'manufacture_date',
    'manufacture_name',
    'supplier_name',
    'sku_code',
    'notes',
  ];

  // The CSV columns stored in product_metadata (not on the product row).
  static const _csvMetadataHeaders = [
    'storage_location',
    'container_number',
    'batch_number',
    'expiry_date',
    'manufacture_date',
    'manufacture_name',
    'supplier_name',
    'sku_code',
    'notes',
  ];

  @override
  void initState() {
    super.initState();
    _activeTabV2 = widget.initialTab.clamp(0, 5);
    if (widget.modern) {
      // The New button and the panel make this page's kind.
      _newItemType = widget.kind;
      _unlimitedStock = widget.kind == 'service';
      if (widget.kind == 'service') _loadSvcColsModern();
    }
    if (widget.startWithAddPanel) _showAddPanelV2 = true;
    _taxRateController.text = "18";
    _defaultDiscountController.text = "0";
    _loadBusinessType();
    _loadCurrency();
    _loadDateFormat();
    _loadStatsV2();
    _loadStatsCardsVisibilityV2();
  }

  Future<void> _loadStatsCardsVisibilityV2() async {
    final v = await ref
        .read(settingsRepositoryProvider)
        .getSetting(SettingKey.showProductStatsCards);
    if (!mounted) return;
    setState(() => _showStatsCardsV2 = v != 'false');
  }

  Future<void> _toggleStatsCardsV2() async {
    final next = !_showStatsCardsV2;
    setState(() => _showStatsCardsV2 = next);
    await ref
        .read(settingsRepositoryProvider)
        .setSetting(SettingKey.showProductStatsCards, next.toString());
  }

  Future<void> _loadDateFormat() async {
    if (!mounted) return;
    final fmt = await ref.read(settingsRepositoryProvider).getDateFormat();
    if (!mounted) return;
    setState(() => _datePattern = fmt.key);
    _loadColumnsConfig();
    _loadListColumnsV2();
    _loadColumnsBannerDismissed();
  }

  ProductColumnsConfig _columnsConfig = const ProductColumnsConfig();
  bool _showColumnsBanner = false;

  // Which optional columns show in the list table. Independent of the
  // form-field config above; a column still needs its form field on too.
  // 'aliasName' is not a column — it shows "(alias)" under the product name —
  // so it is excluded from the max-columns count.
  static const int _maxVisibleListColumns = 10;
  static const Map<String, bool> _listColumnDefaults = {
    'aliasName': true,
    'description': false,
    'hsncode': true,
    'purchasePrice': true,
    'stock': true,
    'taxRate': true,
    'unit': false,
    'defaultDiscount': false,
    'storageLocation': false,
    'containerNumber': false,
    'batchNumber': false,
    'expiryDate': true,
    'manufactureDate': false,
    'manufactureName': false,
    'supplierName': false,
    'skuCode': false,
    'notes': false,
  };
  Map<String, bool> _listColumnsV2 = Map.of(_listColumnDefaults);

  Future<void> _loadColumnsConfig() async {
    final config = await ref.read(settingsRepositoryProvider).getProductColumnsConfig();
    if (!mounted) return;
    setState(() {
      _columnsConfig = config;
      if (!config.stock) _unlimitedStock = true;
    });
  }

  Future<void> _loadListColumnsV2() async {
    final saved =
        await ref.read(settingsRepositoryProvider).getProductListColumns();
    if (!mounted) return;
    setState(() => _listColumnsV2 = {..._listColumnDefaults, ...saved});
  }

  // A form field being disabled hides its list column entirely (as before).
  bool _listColumnFieldEnabled(String key) {
    final c = _columnsConfig;
    switch (key) {
      case 'aliasName':
        return c.aliasName;
      case 'description':
        return c.description;
      case 'hsncode':
        return c.hsncode;
      case 'purchasePrice':
        return c.purchasePrice;
      case 'stock':
        return c.stock;
      case 'taxRate':
        return c.taxRate;
      case 'unit':
        return c.unit;
      case 'defaultDiscount':
        return c.defaultDiscount;
      case 'storageLocation':
        return c.productMetadata && c.metaStorageLocation;
      case 'containerNumber':
        return c.productMetadata && c.metaContainerNumber;
      case 'batchNumber':
        return c.productMetadata && c.metaBatchNumber;
      case 'expiryDate':
        return c.productMetadata && c.metaExpiryDate;
      case 'manufactureDate':
        return c.productMetadata && c.metaManufactureDate;
      case 'manufactureName':
        return c.productMetadata && c.metaManufactureName;
      case 'supplierName':
        return c.productMetadata && c.metaSupplierName;
      case 'skuCode':
        return c.productMetadata && c.metaSkuCode;
      case 'notes':
        return c.productMetadata && c.metaNotes;
      default:
        return false;
    }
  }

  bool _showListCol(String key) =>
      _listColumnFieldEnabled(key) && (_listColumnsV2[key] ?? false);

  // 'aliasName' is a name-cell subtitle, not a table column — excluded here.
  int get _visibleListColumnCount => _listColumnDefaults.keys
      .where((k) => k != 'aliasName' && _showListCol(k))
      .length;

  Future<void> _toggleListColumnV2(String key) async {
    final currentlyOn = _showListCol(key);
    if (key != 'aliasName' &&
        !currentlyOn &&
        _visibleListColumnCount >= _maxVisibleListColumns) {
      return;
    }
    final next = {..._listColumnsV2, key: !(_listColumnsV2[key] ?? false)};
    setState(() => _listColumnsV2 = next);
    await ref.read(settingsRepositoryProvider).setProductListColumns(next);
  }

  Future<void> _loadColumnsBannerDismissed() async {
    final dismissed = await ref
        .read(settingsRepositoryProvider)
        .getSetting(SettingKey.productColumnsBannerDismissed);
    if (!mounted) return;
    setState(() => _showColumnsBanner = dismissed != '1');
  }

  Future<void> _dismissColumnsBanner() async {
    await ref
        .read(settingsRepositoryProvider)
        .setSetting(SettingKey.productColumnsBannerDismissed, '1');
    if (mounted) setState(() => _showColumnsBanner = false);
  }

  Widget _buildColumnsDiscoveryBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: _showColumnsBanner
          ? Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: BrandColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: BrandColors.primaryBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: BrandColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.productMgmtColumnsBannerTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)!.productMgmtColumnsBannerSubtitle,
                          style: const TextStyle(fontSize: 12, color: BrandColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ProductColumnsSettingsScreen()));
                      _loadColumnsConfig();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: BrandColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(AppLocalizations.of(context)!.productMgmtConfigureAction,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    color: Color(0xFF93C5FD),
                    onPressed: _dismissColumnsBanner,
                    tooltip: AppLocalizations.of(context)!.actionDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Future<void> _loadBusinessType() async {
    if(!mounted) return;
    final bt = await ref.read(settingsRepositoryProvider).getBusinessType();
    setState(() {
      _businessType = bt;
      _newItemType = widget.modern
          ? widget.kind
          : (bt == BusinessType.service ? 'service' : 'product');
    });
  }

  Future<void> _loadCurrency() async {
    if(!mounted) return;
    final currency = await ref.read(settingsRepositoryProvider).getCurrency();
    setState(() {
      _currencySymbol = currency.symbol;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _purchasePriceController.dispose();
    _defaultDiscountController.dispose();
    _stockController.dispose();
    _taxRateController.dispose();
    _hsnCodeController.dispose();
    _customUnitController.dispose();
    _storageLocationController.dispose();
    _containerNumberController.dispose();
    _batchNumberController.dispose();
    _manufactureNameController.dispose();
    _supplierNameController.dispose();
    _skuCodeController.dispose();
    _notesController.dispose();
    _searchFocusNode.dispose();
    _horizontalScrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // Loads just the visible page — active tab, search, sort and paging all
  // in SQL — plus metadata for those rows only (Issues.md #42).
  Future<void> _loadProducts() async {
    final requestId = ++_loadRequestId;
    if(!mounted) return;
    setState(() => _isLoading = true);
    try {
      final productRepo = ref.read(productRepositoryProvider);
      // Modern: this page's kind only, with its own tabs.
      final tab = widget.modern ? _mTab : _tabKeyV2;
      final type = widget.modern ? widget.kind : null;
      Future<List<Product>> page() => productRepo.getProductListPage(
          offset: _currentPage * _pageSize,
          limit: _pageSize,
          query: _searchQuery,
          tab: tab,
          orderBy: _sortBy,
          ascending: _isAscending,
          type: type);
      final results = await Future.wait([
        page(),
        productRepo.getProductListCount(query: _searchQuery, tab: tab, type: type),
      ]);
      var result = results[0] as List<Product>;
      final total = results[1] as int;
      // Current page fell off the end (e.g. last row on the last page deleted).
      final maxPage = total == 0 ? 0 : (total - 1) ~/ _pageSize;
      if (_currentPage > maxPage) {
        _currentPage = maxPage;
        result = await page();
      }
      final metadata = await productRepo
          .getProductMetadataForIds(result.map((p) => p.id).toList());

      if (requestId != _loadRequestId || !mounted) return;
      setState(() {
        _products = result;
        _totalProducts = total;
        _productMetadataV2 = metadata;
        // Modern: only rows on the shown page stay ticked.
        final ids = result.map((p) => p.id).toSet();
        _selectedModern.removeWhere((id) => !ids.contains(id));
      });
    } catch (e) {
      if (requestId != _loadRequestId || !mounted) return;
      _showSnackBar(AppLocalizations.of(context)!.productMgmtLoadErrorMessage(e.toString()), isError: true);
    } finally {

      if (requestId == _loadRequestId && mounted) setState(() => _isLoading = false);
    }
  }

  /// A typed stock ("12.5") as a number, 3 decimals at most; blank is 0.
  static double _parseStock(String text) =>
      Product.roundStock(double.tryParse(text.trim()) ?? 0);

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.parse(_priceController.text.trim());
    final purchasePrice =
        double.tryParse(_purchasePriceController.text.trim()) ?? 0.0;
    if (!await _confirmIfSellingAtLoss(price, purchasePrice)) return;
    if(!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final newProduct = Product(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        stock: _unlimitedStock ? 0 : _parseStock(_stockController.text),
        hsncode: _hsnCodeController.text.trim(),
        tax_rate: int.parse(_taxRateController.text.trim()),
        type: _newItemType,
        defaultDiscount:
            double.tryParse(_defaultDiscountController.text.trim()) ?? 0.0,
        purchasePrice: purchasePrice,
        aliasName: _aliasNameController.text.trim().isEmpty
            ? null
            : _aliasNameController.text.trim(),
        unit: _selectedUnit.trim(),
        unlimitedStock: _unlimitedStock,
        priceIncludesTax: _priceIncludesTax,
      );

      await ref.read(productRepositoryProvider).insertProduct(newProduct);
      await ref.read(productRepositoryProvider).upsertProductMetadata(
            ProductMetadata(
              productId: newProduct.id,
              storageLocation: _storageLocationController.text.trim(),
              containerNumber: _containerNumberController.text.trim(),
              batchNumber: _batchNumberController.text.trim(),
              expiryDate: _isoDate(_expiryDate),
              manufactureDate: _isoDate(_manufactureDate),
              manufactureName: _manufactureNameController.text.trim(),
              supplierName: _supplierNameController.text.trim(),
              skuCode: _skuCodeController.text.trim(),
              notes: _notesController.text.trim(),
            ),
          );
      _clearForm();
      await _loadProducts();
      _showSnackBar(_servicesWording ? l10n.mSvcAdded : l10n.productMgmtAddedMessage);
    } catch (e) {
      _showSnackBar(l10n.productMgmtAddErrorMessage(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _aliasNameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _purchasePriceController.clear();
    _defaultDiscountController.clear();
    _stockController.clear();
    _hsnCodeController.clear();
    _taxRateController.clear();
    _taxRateController.text = "18";
    _customUnitController.clear();
    _storageLocationController.clear();
    _containerNumberController.clear();
    _batchNumberController.clear();
    _manufactureNameController.clear();
    _supplierNameController.clear();
    _skuCodeController.clear();
    _notesController.clear();
    if (mounted) {
      setState(() {
      _selectedUnit = '';
      _unlimitedStock = (widget.modern && _newItemType == 'service') || !_columnsConfig.stock; // Standard keeps its reset
      _priceIncludesTax = false;
      _expiryDate = null;
      _manufactureDate = null;
    });
    }
  }

  // Stored as yyyy-MM-dd with ASCII digits whatever the UI language (Nepali
  // would otherwise write Devanagari digits that cannot be read back).
  static String _isoDate(DateTime? d) => d == null ? '' : AppDate.dateKey(d);

  // Also reads dates saved on a Nepali UI before that fix (Devanagari digits
  // '२०२६-१०-०८'), so they show and the next save writes them back in ASCII
  // instead of losing them.
  static DateTime? _parseIsoDate(String? s) {
    if (s == null || s.isEmpty) return null;
    final ascii = s.replaceAllMapped(RegExp('[०-९]'),
        (m) => '${m[0]!.codeUnitAt(0) - 0x0966}');
    return DateTime.tryParse(ascii);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Returns true if it's fine to proceed with saving. Warns (with a
  /// cancel option) when purchase price exceeds sale price, since that
  /// means selling at a loss.
  Future<bool> _confirmIfSellingAtLoss(double price, double purchasePrice) async {
    if (purchasePrice <= 0 || purchasePrice <= price) return true;
    final l10n = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.productMgmtSellingAtLossTitle),
        content: Text(
          l10n.productMgmtSellingAtLossMessage(
            AppFormatters.formatAmount(purchasePrice, _currencySymbol),
            AppFormatters.formatAmount(price, _currencySymbol),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionSaveAnyway),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Widget _buildMetadataSection({
    required TextEditingController storageLocationCtrl,
    required TextEditingController containerNumberCtrl,
    required TextEditingController batchNumberCtrl,
    required TextEditingController manufactureNameCtrl,
    required TextEditingController supplierNameCtrl,
    required TextEditingController skuCodeCtrl,
    required TextEditingController notesCtrl,
    required DateTime? expiryDate,
    required DateTime? manufactureDate,
    required String datePattern,
    required ValueChanged<DateTime?> onExpiryChanged,
    required ValueChanged<DateTime?> onManufactureChanged,
    bool readOnly = false,
  }) {
    Widget field(TextEditingController ctrl, String label, IconData icon,
        {int maxLines = 1}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: ctrl,
          readOnly: readOnly,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
            filled: readOnly,
            fillColor:
                readOnly ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
          ),
        ),
      );
    }

    Widget dateField(String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
      final display = value == null ? '' : DateFormat(datePattern).format(value);
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          readOnly: true,
          controller: TextEditingController(text: display),
          onTap: readOnly
              ? null
              : () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) onChanged(picked);
                },
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            suffixIcon: (!readOnly && value != null)
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => onChanged(null),
                  )
                : null,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
            filled: readOnly,
            fillColor:
                readOnly ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(l10n.productMgmtAdvancedInformationLabel),
        leading: const Icon(Icons.more_horiz),
        childrenPadding: const EdgeInsets.only(top: 8),
        children: [
          if (_columnsConfig.metaStorageLocation)
            field(storageLocationCtrl, l10n.productMgmtStorageLocationLabel, Icons.place_outlined),
          if (_columnsConfig.metaContainerNumber)
            field(containerNumberCtrl, l10n.productMgmtContainerNumberLabel, Icons.inventory_2_outlined),
          if (_columnsConfig.metaBatchNumber)
            field(batchNumberCtrl, l10n.productMgmtBatchNumberLabel, Icons.tag),
          if (_columnsConfig.metaExpiryDate)
            dateField(l10n.productMgmtExpiryDateLabel, expiryDate, onExpiryChanged),
          if (_columnsConfig.metaManufactureDate)
            dateField(l10n.productMgmtManufactureDateLabel, manufactureDate, onManufactureChanged),
          if (_columnsConfig.metaManufactureName)
            field(manufactureNameCtrl, l10n.productMgmtManufactureNameLabel, Icons.factory_outlined),
          if (_columnsConfig.metaSupplierName)
            field(supplierNameCtrl, l10n.productMgmtSupplierNameLabel, Icons.local_shipping_outlined),
          if (_columnsConfig.metaSkuCode)
            field(skuCodeCtrl, l10n.productMgmtSkuCodeLabel, Icons.qr_code_2),
          if (_columnsConfig.metaNotes)
            field(notesCtrl, l10n.productMgmtNotesLabel, Icons.notes, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool readOnly = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    bool isPrice = false,
    bool isStock = false,
    bool isTaxRate = false,
    bool isRequired = false,
    String? prefixText,
    String? helperText,
    VoidCallback? onSubmitted,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
      inputFormatters: isPrice
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))]
          : isStock
              // Stock can be a decimal (12.5 kg).
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : isTaxRate
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixText == null ? Icon(icon) : null,
        prefixText: prefixText,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        filled: readOnly,
        fillColor: readOnly ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
        counterText: '',
          helper: helperText != null ? Tooltip(
            message: helperText,
            textStyle: TextStyle(fontSize: 15),
            decoration: BoxDecoration(
              color: Colors.grey.shade900, // Background color
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(10),
            child: InkWell(
              onTap: null,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Icon(Icons.info_outline, size: 18, color: BrandColors.accent),
              ),
            ),
          ) : null
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          if (isRequired) return l10n.fieldRequiredMessage(label);
        }
        if (isPrice) {
          final price = double.tryParse(value!);
          if (price == null || price < 0) return l10n.fieldEnterValidPriceMessage;
        }
        if (isStock) {
          // A decimal is fine: 12.5 kg.
          final stock = double.tryParse(value!.trim());
          if (stock == null || !stock.isFinite || stock < 0) {
            return l10n.fieldEnterValidStockMessage;
          }
        }
        if (isTaxRate) {
          final tax = int.tryParse(value!);
          if (tax == null || tax < 0 || tax > 100) return l10n.fieldTaxRangeMessage;
        }
        return null;
      },
    );
  }

  Future<void> _confirmDelete(Product product) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(l10n.customerMgmtConfirmDeleteTitle),
          ],
        ),
        content: Text(l10n.customerMgmtDeleteConfirmBody(product.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );

    if (result == true) {
      await ref.read(productRepositoryProvider).deleteProduct(product.id);
      await _loadProducts();
      _showSnackBar(l10n.productMgmtDeletedMessage);
    }
  }

  // ── Sample CSV ────────────────────────────────────────────────────────────

  Future<void> _downloadSampleCSV() async {
    const sample =
        '"name","hsn_code","description","price","tax_rate","stock","type","default_discount","purchase_price","alias_name","unit","unlimited_stock","price_includes_tax","storage_location","container_number","batch_number","expiry_date","manufacture_date","manufacture_name","supplier_name","sku_code","notes"\n'
        '"Wireless Mouse","84716010","Ergonomic wireless mouse","599.00","18","50","product","5.00","400.00","","pcs","0","0","Rack A1","","","","","","",""\n'
        '"USB Hub","84734000","4-port USB 3.0 hub","299.00","18","100","product","0","180.00","","pcs","0","0","","CNT-1023","","","","","",""\n'
        '"Annual Support","998314","Annual technical support plan","4999.00","18","0","service","10.00","0","","unit","1","1","","","","","","","",""\n';

    final l10n = AppLocalizations.of(context)!;
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.customerMgmtSaveSampleCsvDialogTitle,
      fileName: 'products_sample.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (savePath == null) return;

    try {
      await File(savePath).writeAsBytes(utf8.encode('\uFEFF$sample'));
      _showSnackBar(l10n.customerMgmtSampleSavedMessage);
    } catch (e) {
      _showSnackBar(l10n.customerMgmtErrorSavingSampleMessage(e.toString()), isError: true);
    }
  }

  // ── CSV Import ────────────────────────────────────────────────────────────

  Future<void> _showImportDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.upload_file, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            Text(_servicesWording
                ? l10n.mSvcImportCsvTitle
                : l10n.productMgmtImportProductsCsvTitle),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.45,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.customerMgmtCsvFormatInstructionMessage),
                const SizedBox(height: 12),
                Table(
                  border: TableBorder.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(6)),
                  columnWidths: const {
                    0: FlexColumnWidth(1.4),
                    1: FlexColumnWidth(0.7),
                    2: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                      children: [
                        _TableHeader(l10n.customerMgmtCsvColColumnHeader),
                        _TableHeader(l10n.customerMgmtCsvColRequiredHeader),
                        _TableHeader(l10n.customerMgmtCsvColDescriptionHeader),
                      ],
                    ),
                    _csvRuleRow(context, 'name', true, l10n.productMgmtCsvDescName),
                    _csvRuleRow(context, 'price', true, l10n.productMgmtCsvDescPrice),
                    _csvRuleRow(context, 'hsn_code', false, l10n.productMgmtCsvDescHsnCode),
                    _csvRuleRow(context, 'description', false, l10n.productMgmtCsvDescDescription),
                    _csvRuleRow(context, 'tax_rate', false, l10n.productMgmtCsvDescTaxRate),
                    _csvRuleRow(context, 'stock', false, l10n.productMgmtCsvDescStock),
                    _csvRuleRow(context, 'type', false, l10n.productMgmtCsvDescType),
                    _csvRuleRow(context, 'default_discount', false, l10n.productMgmtCsvDescDefaultDiscount),
                    _csvRuleRow(context, 'purchase_price', false, l10n.productMgmtCsvDescPurchasePrice),
                    _csvRuleRow(context, 'alias_name', false, l10n.productMgmtCsvDescAliasName),
                    _csvRuleRow(context, 'unit', false, l10n.productMgmtCsvDescUnit),
                    _csvRuleRow(context, 'unlimited_stock', false, l10n.productMgmtCsvDescUnlimitedStock),
                    _csvRuleRow(context, 'price_includes_tax', false, l10n.productMgmtCsvDescPriceIncludesTax),
                    _csvRuleRow(context, 'storage_location', false, l10n.productMgmtCsvDescStorageLocation),
                    _csvRuleRow(context, 'container_number', false, l10n.productMgmtCsvDescContainerNumber),
                    _csvRuleRow(context, 'batch_number', false, l10n.productMgmtCsvDescBatchNumber),
                    _csvRuleRow(context, 'expiry_date', false, l10n.productMgmtCsvDescExpiryDate),
                    _csvRuleRow(context, 'manufacture_date', false, l10n.productMgmtCsvDescManufactureDate),
                    _csvRuleRow(context, 'manufacture_name', false, l10n.productMgmtCsvDescManufactureName),
                    _csvRuleRow(context, 'supplier_name', false, l10n.productMgmtCsvDescSupplierName),
                    _csvRuleRow(context, 'sku_code', false, l10n.productMgmtCsvDescSkuCode),
                    _csvRuleRow(context, 'notes', false, l10n.productMgmtCsvDescNotes),
                  ],
                ),
                const SizedBox(height: 16),
                _ruleNote(context, Icons.info_outline,
                    l10n.customerMgmtCsvMaxRowsNote(_csvMaxRows)),
                _ruleNote(context, Icons.info_outline,
                    l10n.productMgmtCsvDuplicateNote),
                _ruleNote(context, Icons.info_outline,
                    l10n.productMgmtCsvMissingRequiredNote),
                _ruleNote(context, Icons.info_outline,
                    l10n.customerMgmtCsvEncodingNote),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx, false);
                    await _downloadSampleCSV();
                  },
                  icon: const Icon(Icons.download),
                  label: Text(l10n.customerMgmtDownloadSampleCsvButton),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.folder_open),
            label: Text(l10n.customerMgmtChooseFileButton),
          ),
        ],
      ),
    );
    if (proceed == true) await _importFromCSV();
  }

  static TableRow _csvRuleRow(BuildContext context, String col, bool required, String desc) {
    final l10n = AppLocalizations.of(context)!;
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(col,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            required ? l10n.commonYesLabel : l10n.commonNoLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: required ? Colors.red.shade700 : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(desc, style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  static Widget _ruleNote(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface))),
        ],
      ),
    );
  }

  Future<void> _importFromCSV() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      dialogTitle: l10n.productMgmtSelectCsvDialogTitle,
    );
    if (result == null || result.files.single.path == null || !mounted) return;
    setState(() => _isLoading = true);

    var progressDialogShown = false;
    try {
      final bytes = await File(result.files.single.path!).readAsBytes();
      // Strip UTF-8 BOM if present
      final content = utf8.decode(
        bytes.length >= 3 &&
                bytes[0] == 0xEF &&
                bytes[1] == 0xBB &&
                bytes[2] == 0xBF
            ? bytes.sublist(3)
            : bytes,
      );

      // Windows line ends (\r\n) become \n so rows never merge, and every cell
      // stays text so HSN codes keep a leading 0 (numbers are parsed below).
      final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(content.replaceAll('\r\n', '\n'));
      if (rows.isEmpty) {
        _showSnackBar(l10n.customerMgmtCsvEmptyMessage, isError: true);
        if(!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      // Parse and validate headers
      final headers =
          rows.first.map((h) => h.toString().trim().toLowerCase()).toList();

      if (!headers.contains('name')) {
        _showSnackBar(l10n.customerMgmtCsvMissingNameColumnMessage, isError: true);
        if(!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      if (!headers.contains('price')) {
        _showSnackBar(l10n.productMgmtCsvMissingPriceColumnMessage, isError: true);
        if(!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      for (final col in headers) {
        if (!_csvHeaders.contains(col)) {
          _showSnackBar(
              l10n.customerMgmtUnknownColumnMessage(col, _csvHeaders.join(', ')),
              isError: true);
          if(!mounted) return;
          setState(() => _isLoading = false);
          return;
        }
      }

      final dataRows = rows.skip(1).toList();

      if (dataRows.length > _csvMaxRows) {
        _showSnackBar(
            l10n.customerMgmtCsvTooManyRowsMessage(dataRows.length, _csvMaxRows),
            isError: true);
        if(!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      String getField(List<dynamic> row, String col) {
        final i = headers.indexOf(col);
        return i < 0 || i >= row.length ? '' : stripCsvFormulaGuard(row[i].toString().trim());
      }

      final List<Product> valid = [];
      final List<Product> duplicates = [];
      final List<String> errors = [];
      final Map<String, ProductMetadata> metadataById = {};

      final progress = ValueNotifier<int>(0);
      if (!mounted) return;
      progressDialogShown = true;
      unawaited(showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.productMgmtImportingTitle),
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (_, done, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.customerMgmtValidatingRowsMessage(dataRows.length)),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: dataRows.isEmpty ? null : done / dataRows.length,
                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  '$done / ${dataRows.length}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ));

      for (int i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];
        progress.value = i + 1;
        final name = getField(row, 'name');
        final priceStr = getField(row, 'price');

        if (name.isEmpty) {
          errors.add(l10n.customerMgmtRowMissingNameMessage(i + 2));
          continue;
        }
        final price = double.tryParse(priceStr);
        if (price == null || price < 0) {
          errors.add(l10n.productMgmtRowInvalidPriceMessage(i + 2, priceStr));
          continue;
        }

        final taxStr = getField(row, 'tax_rate');
        final stockStr = getField(row, 'stock');
        final typeStr = getField(row, 'type');
        final discountStr = getField(row, 'default_discount');
        final purchasePriceStr = getField(row, 'purchase_price');
        final aliasNameStr = getField(row, 'alias_name');
        final unitStr = getField(row, 'unit');
        final unlimitedStockStr = getField(row, 'unlimited_stock');
        final priceIncludesTaxStr = getField(row, 'price_includes_tax');
        // "18.0" / "10.0" (as Excel and Sheets write them) read as 18 / 10.
        int wholeNumber(String v) =>
            int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.round() ?? 0;
        final taxRate = taxStr.isEmpty ? 0 : wholeNumber(taxStr);
        // Stock can be a decimal: "12.5" kg.
        final stock = stockStr.isEmpty ? 0.0 : _parseStock(stockStr);
        // Modern Products / Services page: a blank or unknown type is this
        // page's kind, and a service without an unlimited_stock value has
        // unlimited stock (like the New Service panel).
        final typeKey = typeStr.trim().toLowerCase();
        final type = widget.modern
            ? (typeKey == 'service' || typeKey == 'product' ? typeKey : widget.kind)
            : ((typeStr == 'service') ? 'service' : 'product');
        final unlimitedStock = widget.modern && unlimitedStockStr.isEmpty
            ? type == 'service'
            : unlimitedStockStr == '1' || unlimitedStockStr.toLowerCase() == 'true';
        final priceIncludesTax = priceIncludesTaxStr == '1' || priceIncludesTaxStr.toLowerCase() == 'true';
        final discount = discountStr.isEmpty ? 0.0 : (double.tryParse(discountStr) ?? 0.0);
        final purchasePrice = purchasePriceStr.isEmpty ? 0.0 : (double.tryParse(purchasePriceStr) ?? 0.0);

        final existing = await ref.read(productRepositoryProvider).findDuplicateByName(name);
        // Overwrite: a column the CSV does not have keeps the saved value
        // (instead of wiping it to blank or 0).
        bool keep(String col) => existing != null && !headers.contains(col);
        final product = Product(
          id: existing?.id ?? const Uuid().v4(),
          name: name,
          hsncode: keep('hsn_code') ? existing!.hsncode : getField(row, 'hsn_code'),
          description:
              keep('description') ? existing!.description : getField(row, 'description'),
          price: price,
          tax_rate: keep('tax_rate') ? existing!.tax_rate : taxRate.clamp(0, 100),
          stock: keep('stock') ? existing!.stock : (stock < 0 ? 0 : stock),
          type: keep('type') ? existing!.type : type,
          defaultDiscount: keep('default_discount')
              ? existing!.defaultDiscount
              : (discount < 0 ? 0.0 : discount),
          purchasePrice: keep('purchase_price')
              ? existing!.purchasePrice
              : (purchasePrice < 0 ? 0.0 : purchasePrice),
          aliasName: keep('alias_name')
              ? existing!.aliasName
              : (aliasNameStr.isEmpty ? null : aliasNameStr),
          unit: keep('unit') ? existing!.unit : unitStr,
          unlimitedStock: keep('unlimited_stock') ? existing!.unlimitedStock : unlimitedStock,
          priceIncludesTax:
              keep('price_includes_tax') ? existing!.priceIncludesTax : priceIncludesTax,
        );

        // The saved details (batch, expiry...) only when a column is missing.
        final savedMeta = existing != null && _csvMetadataHeaders.any((c) => !headers.contains(c))
            ? await ref.read(productRepositoryProvider).getProductMetadata(existing.id)
            : null;
        String? metaField(String col, String? saved) =>
            keep(col) ? saved : getField(row, col);
        metadataById[product.id] = ProductMetadata(
          productId: product.id,
          storageLocation: metaField('storage_location', savedMeta?.storageLocation),
          containerNumber: metaField('container_number', savedMeta?.containerNumber),
          batchNumber: metaField('batch_number', savedMeta?.batchNumber),
          expiryDate: metaField('expiry_date', savedMeta?.expiryDate),
          manufactureDate: metaField('manufacture_date', savedMeta?.manufactureDate),
          manufactureName: metaField('manufacture_name', savedMeta?.manufactureName),
          supplierName: metaField('supplier_name', savedMeta?.supplierName),
          skuCode: metaField('sku_code', savedMeta?.skuCode),
          notes: metaField('notes', savedMeta?.notes),
        );

        if (existing != null) {
          duplicates.add(product);
        } else {
          valid.add(product);
        }
      }
      if (progressDialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if(!mounted) return;
      setState(() => _isLoading = false);
      if (!mounted) return;
      await _showImportPreviewDialog(valid, duplicates, errors, metadataById);
    } catch (e) {
      if (progressDialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() => _isLoading = false);
      _showSnackBar(l10n.customerMgmtCsvReadErrorMessage(e.toString()), isError: true);
    }
  }

  Future<void> _showImportPreviewDialog(
    List<Product> newProducts,
    List<Product> duplicates,
    List<String> errors,
    Map<String, ProductMetadata> metadataById,
  ) async {
    final overwriteFlags = List<bool>.filled(duplicates.length, false);
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final total =
              newProducts.length + overwriteFlags.where((f) => f).length;

          return AlertDialog(
            title: Text(l10n.customerMgmtImportPreviewTitle),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.55,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(l10n.customerMgmtNewCountChip(newProducts.length)),
                          backgroundColor: Colors.green.shade100,
                          avatar: const Icon(Icons.add_box_outlined, size: 16),
                        ),
                        Chip(
                          label: Text(l10n.customerMgmtDuplicatesCountChip(duplicates.length)),
                          backgroundColor: Colors.orange.shade100,
                          avatar: const Icon(Icons.warning_amber, size: 16),
                        ),
                        if (errors.isNotEmpty)
                          Chip(
                            label: Text(l10n.customerMgmtErrorsCountChip(errors.length)),
                            backgroundColor: Colors.red.shade100,
                            avatar: const Icon(Icons.error_outline, size: 16),
                          ),
                      ],
                    ),
                    if (duplicates.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(l10n.productMgmtDuplicatesMatchedByNameLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () => setDialogState(() {
                              for (int i = 0; i < overwriteFlags.length; i++) {
                                overwriteFlags[i] = true;
                              }
                            }),
                            child: Text(l10n.customerMgmtOverwriteAllButton),
                          ),
                          TextButton(
                            onPressed: () => setDialogState(() {
                              for (int i = 0; i < overwriteFlags.length; i++) {
                                overwriteFlags[i] = false;
                              }
                            }),
                            child: Text(l10n.customerMgmtSkipAllButton),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(duplicates.length, (i) {
                        final p = duplicates[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text(p.name),
                            subtitle: Text(
                                '$_currencySymbol${p.price.toStringAsFixed(2)} · HSN/SAC: ${p.hsncode.isEmpty ? '—' : p.hsncode}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(l10n.actionSkip,
                                    style: const TextStyle(fontSize: 12)),
                                Switch(
                                  value: overwriteFlags[i],
                                  onChanged: (v) => setDialogState(
                                      () => overwriteFlags[i] = v),
                                ),
                                Text(l10n.customerMgmtOverwriteLabel,
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    if (errors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(l10n.customerMgmtSkippedRowsLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 8),
                      ...errors.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(l10n.customerMgmtErrorBulletLabel(e),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.red)),
                          )),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      l10n.productMgmtWillImportMessage(total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.actionCancel),
              ),
              FilledButton.icon(
                onPressed: total == 0
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _executeImport(
                            newProducts, duplicates, overwriteFlags, metadataById);
                      },
                icon: const Icon(Icons.upload),
                label: Text(l10n.customerMgmtImportCountButton(total)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeImport(
    List<Product> newProducts,
    List<Product> duplicates,
    List<bool> overwriteFlags,
    Map<String, ProductMetadata> metadataById,
  ) async {
    if(!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      if (newProducts.isNotEmpty) {
        await repo.insertBatch(newProducts);
        for (final p in newProducts) {
          final meta = metadataById[p.id];
          if (meta != null) await repo.upsertProductMetadata(meta);
        }
      }
      for (int i = 0; i < duplicates.length; i++) {
        if (overwriteFlags[i]) {
          await repo.updateProduct(duplicates[i]);
          final meta = metadataById[duplicates[i].id];
          if (meta != null) await repo.upsertProductMetadata(meta);
        }
      }
      // Stats too (cards, chips): the import's writes are done by now.
      await _loadStatsV2();
      final imported =
          newProducts.length + overwriteFlags.where((f) => f).length;
      _showSnackBar(_servicesWording
          ? l10n.mSvcImported(imported)
          : l10n.productMgmtImportedMessage(imported));
    } catch (e) {
      if(!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(l10n.customerMgmtImportErrorMessage(e.toString()), isError: true);
    }
  }

  // ── Delete All ────────────────────────────────────────────────────────────

  Future<void> _confirmDeleteAll() async {
    final l10n = AppLocalizations.of(context)!;
    if (_allProductsCount == 0) {
      _showSnackBar(l10n.productMgmtNoProductsToDeleteMessage);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.productMgmtDeleteAllTitle),
        content: Text(l10n.productMgmtDeleteAllBody(_allProductsCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.customerMgmtDeleteAllButton),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(productRepositoryProvider).deleteAllProducts();
      await _loadProducts();
      _showSnackBar(l10n.productMgmtAllDeletedMessage);
    } catch (e) {
      if(!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(l10n.productMgmtDeleteAllErrorMessage(e.toString()), isError: true);
    }
  }

  Future<void> _exportToCSV() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final repo = ref.read(productRepositoryProvider);
      final allProducts = _ofThisKind(await repo.getAllProducts());
      final allMetadata = await repo.getAllProductMetadata();
      final List<List<dynamic>> rows = [
        ['name', 'hsn_code', 'description', 'price', 'tax_rate', 'stock', 'type', 'default_discount', 'purchase_price', 'alias_name', 'unit', 'unlimited_stock', 'price_includes_tax', 'storage_location', 'container_number', 'batch_number', 'expiry_date', 'manufacture_date', 'manufacture_name', 'supplier_name', 'sku_code', 'notes'],
        ...allProducts.map((p) {
          final meta = allMetadata[p.id];
          return [
              p.name,
              p.hsncode,
              p.description,
              p.price,
              p.tax_rate,
              AppFormatters.formatStock(p.stock),
              p.type,
              p.defaultDiscount,
              p.purchasePrice,
              p.aliasName ?? '',
              p.unit,
              p.unlimitedStock ? 1 : 0,
              p.priceIncludesTax ? 1 : 0,
              meta?.storageLocation ?? '',
              meta?.containerNumber ?? '',
              meta?.batchNumber ?? '',
              meta?.expiryDate ?? '',
              meta?.manufactureDate ?? '',
              meta?.manufactureName ?? '',
              meta?.supplierName ?? '',
              meta?.skuCode ?? '',
              meta?.notes ?? '',
            ];
        }),
      ];
      final csvData = buildQuotedCsv(rows);
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.productMgmtSaveProductsCsvDialogTitle,
        fileName: 'products.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (savePath == null) return;
      await File(savePath).writeAsBytes(utf8.encode('\uFEFF$csvData'));
      _showSnackBar(l10n.customerMgmtCsvExportedMessage);
    } catch (e) {
      _showSnackBar(l10n.customerMgmtCsvExportErrorMessage(e.toString()), isError: true);
    }
  }

  Future<void> _exportToPDF() async {
    final l10n = AppLocalizations.of(context)!;
    // Ask user: current page or all products
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.productMgmtExportToPdfTitle),
        content: Text(
          _servicesWording
              ? l10n.mSvcExportPdfChoice(_pageSize, _countModern('all'))
              : l10n.productMgmtExportPdfChoiceMessage(
                  _pageSize, widget.modern ? _countModern('all') : _allProductsCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'page'),
            child: Text(l10n.productMgmtCurrentPageLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'all'),
            child: Text(_servicesWording
                ? l10n.mSvcAllServicesLabel
                : l10n.productMgmtAllProductsLabel),
          ),
        ],
      ),
    );
    if (choice == null) return;

    try {
      final productsToExport =
          choice == 'all'
              ? _ofThisKind(await ref.read(productRepositoryProvider).getAllProducts())
              : _products;

      // The app's PDF fonts, so non-Latin names (Tamil, Hindi...) are not blank.
      final pdf = pw.Document(theme: await PdfFontService.loadTheme());
      final totalCount = productsToExport.length;
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Product Export - $totalCount product${totalCount == 1 ? '' : 's'}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by ${AppConfig.brandName}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),
          build: (context) => [
            pw.TableHelper.fromTextArray(
              context: context,
              data: [
                ['#', 'Name', 'HSN/SAC', 'Description', 'Price', 'Tax Rate', 'Stock', 'Type', 'Discount', 'Unit'],
                ...productsToExport.indexed.map(((int, dynamic) e) => [
                      e.$1 + 1,
                      e.$2.name,
                      e.$2.hsncode,
                      e.$2.description,
                      e.$2.price.toStringAsFixed(2),
                      '${e.$2.tax_rate}%',
                      e.$2.unlimitedStock ? 'Unlimited' : AppFormatters.formatStock(e.$2.stock),
                      e.$2.type,
                      e.$2.defaultDiscount > 0 ? e.$2.defaultDiscount.toStringAsFixed(2) : '-',
                      e.$2.unit,
                    ]),
              ],
            ),
          ],
        ),
      );

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.productMgmtSaveProductsPdfDialogTitle,
        fileName: 'products.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (savePath == null) return;
      await File(savePath).writeAsBytes(await pdf.save());
      _showSnackBar(l10n.customerMgmtPdfExportedMessage);
    } catch (e) {
      _showSnackBar(l10n.customerMgmtPdfExportErrorMessage(e.toString()), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.modern ? _buildModern(context) : _buildV2(context);

  /// The Modern Services page: messages and buttons say "service".
  bool get _servicesWording => widget.modern && widget.kind == 'service';

  /// Exports: the Modern Products / Services page has only its own kind.
  List<Product> _ofThisKind(List<Product> all) =>
      widget.modern ? all.where((p) => p.type == widget.kind).toList() : all;

  // ============================================================
  // V2 — flat / modern layout. Reuses all v1 state, controllers,
  // validation, and repository calls. New pieces:
  //  - stat counts from one SQL aggregate; the table loads one page at a
  //    time (see _loadProducts)
  //  - a slide-out "Add New Product" panel (Basic/Advanced tabs)
  //    instead of the always-visible left sidebar form
  //  - flat table/cards instead of Card/DataTable chrome
  // ============================================================

  Future<void> _loadStatsV2() async {
    if (!mounted) return;
    setState(() => _statsLoadingV2 = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      final results = await Future.wait([
        repo.getProductListStats(),
        _loadProducts(),
        if (widget.modern) repo.getProductListTabCounts(_countTabsModern, type: widget.kind),
      ]);
      final stats = results[0] as ProductListStats;
      if (!mounted) return;
      setState(() {
        _statsV2 = stats;
        _allProductsCount = stats.all;
        if (widget.modern) _countsModern = results[2] as Map<String, int>;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(AppLocalizations.of(context)!.productMgmtLoadErrorMessage(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _statsLoadingV2 = false);
    }
  }

  DateTime? _expiryDateOfV2(Product p) {
    return _parseIsoDate(_productMetadataV2[p.id]?.expiryDate);
  }

  int get _allCountV2 => _statsV2.all;
  int get _productsCountV2 => _statsV2.products;
  int get _servicesCountV2 => _statsV2.services;
  int get _lowStockCountV2 => _statsV2.lowStock;
  int get _outOfStockCountV2 => _statsV2.outOfStock;
  int get _expiredCountV2 => _statsV2.expired;

  // _activeTabV2 index → ProductService list tab key.
  String get _tabKeyV2 =>
      const ['all', 'product', 'service', 'low', 'out', 'expired'][_activeTabV2];

  void _selectTabV2(int index) {
    if (!mounted) return;
    setState(() {
      _activeTabV2 = index;
      _currentPage = 0;
    });
    _loadProducts();
  }

  void _onSearchChangedV2(String query) {
    if (!mounted) return;
    setState(() {
      _searchQuery = query;
      _currentPage = 0;
    });
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 300), _loadProducts);
  }

  // Combines v1's separate sort-field + sort-direction controls into the
  // single "Sort: Name A-Z" style dropdown shown in the mockup.
  void _onSortSelectionV2(String field, bool ascending) {
    if (!mounted) return;
    setState(() {
      _sortBy = field;
      _isAscending = ascending;
      _currentPage = 0;
    });
    _loadProducts();
  }

  void _changePageV2(int page) {
    if (!mounted) return;
    setState(() => _currentPage = page);
    _loadProducts();
  }

  Future<void> _addProductV2() async {
    final nameBefore = _nameController.text;
    await _addProduct();
    final succeeded = _nameController.text.isEmpty && nameBefore.trim().isNotEmpty;
    if (succeeded) {
      await _loadStatsV2();
      if (!mounted) return;
      if (!_addAnotherAfterSavingV2) {
        setState(() => _showAddPanelV2 = false);
      }
    }
  }

  Future<void> _editProductV2(Product product) async {
    await _showDetailDialogV2(product, startInEdit: true);
  }

  Future<void> _viewProductV2(Product product) async {
    await _showDetailDialogV2(product, startInEdit: false);
  }

  Future<void> _deleteProductV2(Product product) async {
    await _confirmDelete(product);
    await _loadStatsV2();
  }

  Future<void> _openColumnsSettingsV2() async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProductColumnsSettingsScreen()));
    await _loadColumnsConfig();
    if (mounted && widget.modern && _mTab == 'expired' && !_expiryOnModern) {
      setState(() {
        _mTab = 'all';
        _currentPage = 0;
      });
    }
    await _loadStatsV2();
  }

  BoxDecoration _flatCardDecorationV2(BuildContext context) => BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      );

  Widget _sectionLabelV2(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  // A PopupMenuButton's `child` should stay non-interactive (PopupMenuButton
  // itself provides the tap-to-open handling) — using a real OutlinedButton
  // with onPressed: null there would render as visually disabled/greyed.
  Widget _menuButtonLookV2(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        border:
            Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13.5, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down,
              size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  String _listColLabel(AppLocalizations l10n, String key) {
    switch (key) {
      case 'aliasName':
        return l10n.productColumnsAliasNameLabel;
      case 'description':
        return l10n.productColumnsDescriptionLabel;
      case 'hsncode':
        return l10n.productColumnsHsnSacLabel;
      case 'purchasePrice':
        return l10n.productColumnsPurchasePriceLabel;
      case 'stock':
        return l10n.productColumnsStockLabel;
      case 'taxRate':
        return l10n.productColumnsTaxRateLabel;
      case 'unit':
        return l10n.productColumnsUnitLabel;
      case 'defaultDiscount':
        return l10n.productColumnsDefaultDiscountLabel;
      case 'storageLocation':
        return l10n.productColumnsMetaStorageLocationLabel;
      case 'containerNumber':
        return l10n.productColumnsMetaContainerNumberLabel;
      case 'batchNumber':
        return l10n.productColumnsMetaBatchNumberLabel;
      case 'expiryDate':
        return l10n.productColumnsMetaExpiryDateLabel;
      case 'manufactureDate':
        return l10n.productColumnsMetaManufactureDateLabel;
      case 'manufactureName':
        return l10n.productColumnsMetaManufactureNameLabel;
      case 'supplierName':
        return l10n.productColumnsMetaSupplierNameLabel;
      case 'skuCode':
        return l10n.productColumnsMetaSkuCodeLabel;
      case 'notes':
        return l10n.productColumnsMetaNotesLabel;
      default:
        return key;
    }
  }

  int _listColFlex(String key) {
    switch (key) {
      case 'stock':
      case 'taxRate':
      case 'unit':
      case 'defaultDiscount':
        return 1;
      case 'description':
      case 'notes':
        return 3;
      default:
        return 2;
    }
  }

  String _fmtMetaDateV2(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final d = _parseIsoDate(raw);
    return d == null ? raw : DateFormat(_datePattern).format(d);
  }

  // Header cells for the optional list columns, in _listColumnDefaults order.
  List<Widget> _optionalHeaderCellsV2(TextStyle style) {
    final l10n = AppLocalizations.of(context)!;
    final cells = <Widget>[];
    for (final key in _listColumnDefaults.keys) {
      if (key == 'aliasName' || !_showListCol(key)) continue;
      cells.add(Expanded(
        flex: _listColFlex(key),
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(_listColLabel(l10n, key).toUpperCase(),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ),
      ));
    }
    return cells;
  }

  // Row cells matching _optionalHeaderCellsV2, same order/flex.
  List<Widget> _optionalRowCellsV2(Product p) {
    final meta = _productMetadataV2[p.id];
    final muted =
        TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    Widget text(String v) => Text(v.isEmpty ? '—' : v,
        maxLines: 1, overflow: TextOverflow.ellipsis, style: muted);

    final cells = <Widget>[];
    for (final key in _listColumnDefaults.keys) {
      if (key == 'aliasName' || !_showListCol(key)) continue;
      Widget child;
      switch (key) {
        case 'description':
          child = text(p.description);
          break;
        case 'hsncode':
          child = text(p.hsncode);
          break;
        case 'purchasePrice':
          child = text(p.purchasePrice > 0
              ? AppFormatters.formatAmount(p.purchasePrice, _currencySymbol)
              : '');
          break;
        case 'stock':
          child = _stockCellV2(p);
          break;
        case 'taxRate':
          child = Text('${p.tax_rate}%');
          break;
        case 'unit':
          child = text(p.unit);
          break;
        case 'defaultDiscount':
          child = text(p.defaultDiscount > 0
              ? p.defaultDiscount.toStringAsFixed(2)
              : '');
          break;
        case 'storageLocation':
          child = text(meta?.storageLocation ?? '');
          break;
        case 'containerNumber':
          child = text(meta?.containerNumber ?? '');
          break;
        case 'batchNumber':
          child = text(meta?.batchNumber ?? '');
          break;
        case 'expiryDate':
          child = _expiryCellV2(p);
          break;
        case 'manufactureDate':
          child = text(_fmtMetaDateV2(meta?.manufactureDate));
          break;
        case 'manufactureName':
          child = text(meta?.manufactureName ?? '');
          break;
        case 'supplierName':
          child = text(meta?.supplierName ?? '');
          break;
        case 'skuCode':
          child = text(meta?.skuCode ?? '');
          break;
        case 'notes':
          child = text(meta?.notes ?? '');
          break;
        default:
          continue;
      }
      cells.add(Expanded(
          flex: _listColFlex(key),
          child: Padding(padding: const EdgeInsets.only(right: 12), child: child)));
    }
    return cells;
  }

  Widget _expiryCellV2(Product p) {
    final expiryDate = _expiryDateOfV2(p);
    if (expiryDate == null) {
      return Text('—',
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    final isExpired = expiryDate.isBefore(DateTime.now());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isExpired)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.error_outline, size: 14, color: Colors.red),
          ),
        Text(DateFormat(_datePattern).format(expiryDate),
            style: TextStyle(
                fontWeight: isExpired ? FontWeight.bold : FontWeight.normal,
                color: isExpired
                    ? Colors.red
                    : Theme.of(context).colorScheme.onSurface)),
      ],
    );
  }

  PopupMenuItem<String> _listColMenuItemV2(String key, String label) {
    final visible = _showListCol(key);
    final canToggle = key == 'aliasName' ||
        visible ||
        _visibleListColumnCount < _maxVisibleListColumns;
    return PopupMenuItem<String>(
      value: key,
      enabled: canToggle,
      child: Row(
        children: [
          Icon(visible ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: canToggle
                  ? null
                  : Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _statCardV2({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    String? subtitle,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.all(16),
      decoration: _flatCardDecorationV2(context),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(subtitle ?? '',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
          ],
        ),
    );
  }

  Widget _statCardsRowV2() {
    final l10n = AppLocalizations.of(context)!;
    final cards = [
      _statCardV2(
        label: l10n.productMgmtAllProductsLabel,
        value: '$_allCountV2',
        subtitle: l10n.productMgmtTotalItemsSubtitle,
        icon: Icons.inventory_2_outlined,
        accent: Theme.of(context).primaryColor,
      ),
      _statCardV2(
        label: l10n.navProducts,
        value: '$_productsCountV2',
        subtitle: l10n.productMgmtTangibleProductsSubtitle,
        icon: Icons.widgets_outlined,
        accent: Colors.green,
      ),
      _statCardV2(
        label: l10n.productMgmtServicesTabLabel,
        value: '$_servicesCountV2',
        subtitle: l10n.productMgmtNonTangibleServicesSubtitle,
        icon: Icons.design_services_outlined,
        accent: Colors.orange,
      ),
      _statCardV2(
        label: l10n.productMgmtLowStockTabLabel,
        value: '$_lowStockCountV2',
        subtitle: l10n.productMgmtNeedAttentionSubtitle,
        icon: Icons.warning_amber_rounded,
        accent: Colors.red,
      ),
    ];

    // Responsive: fit as many equal-width cards per row as the available
    // width allows (min ~170px each, see _statCardV2), wrapping to
    // additional rows instead of squeezing/overflowing on narrow screens.
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const minCardWidth = 170.0;
        final perRow = (constraints.maxWidth + spacing) ~/ (minCardWidth + spacing);
        final columns = perRow.clamp(1, cards.length);
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }

  Widget _headerBarV2() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = widget.user.isAdmin();

    Future<void> importProducts() async {
      await _showImportDialog();
      await _loadStatsV2();
    }

    Future<void> onMore(String value) async {
      if (value == 'import') await importProducts();
      if (value == 'export') await _exportToCSV();
      if (value == 'refresh') await _loadStatsV2();
      if (value == 'export_pdf') await _exportToPDF();
      if (value == 'delete_all') {
        await _confirmDeleteAll();
        await _loadStatsV2();
      }
    }

    PopupMenuItem<String> menuItem(String value, IconData icon, String label,
            {Color? color}) =>
        PopupMenuItem<String>(
          value: value,
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(label, style: color == null ? null : TextStyle(color: color)),
            ],
          ),
        );

    final buttonPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    final buttonShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.xsmall));

    return LayoutBuilder(builder: (context, c) {
      // Import and Export sit beside the main button on a normal window and
      // fold into the "more" menu on a narrow one.
      final compact = c.maxWidth < 860;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.productMgmtTitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(l10n.productMgmtSubtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!compact) ...[
            OutlinedButton.icon(
              onPressed: importProducts,
              icon: const Icon(Icons.upload_file_outlined, size: 16),
              label: Text(l10n.actionImport),
              style: OutlinedButton.styleFrom(
                  padding: buttonPadding, shape: buttonShape),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _exportToCSV,
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: Text(l10n.actionExport),
              style: OutlinedButton.styleFrom(
                  padding: buttonPadding, shape: buttonShape),
            ),
            const SizedBox(width: 4),
          ],
          PopupMenuButton<String>(
            tooltip: l10n.invoiceMgmtMoreActionsTooltip,
            icon: const Icon(Icons.more_horiz),
            onSelected: onMore,
            itemBuilder: (ctx) => [
              if (compact) ...[
                menuItem('import', Icons.upload_file_outlined, l10n.actionImport),
                menuItem('export', Icons.file_download_outlined, l10n.actionExport),
              ],
              menuItem('refresh', Icons.refresh, l10n.actionRefresh),
              if (isAdmin) ...[
                const PopupMenuDivider(),
                menuItem('export_pdf', Icons.picture_as_pdf_outlined,
                    l10n.customerMgmtExportPdfMenuLabel),
                menuItem('delete_all', Icons.delete_sweep,
                    l10n.productMgmtDeleteAllTitle,
                    color: Colors.red),
              ],
            ],
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _showAddPanelV2 = true;
                _addPanelTabV2 = 0;
              });
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.productMgmtNewProductButton),
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: buttonShape),
          ),
        ],
      );
    });
  }

  Widget _searchFilterRowV2() {
    final l10n = AppLocalizations.of(context)!;
    final sortOptions = [
      {'label': l10n.customerMgmtSortNameAZ, 'field': 'name', 'asc': true},
      {'label': l10n.customerMgmtSortNameZA, 'field': 'name', 'asc': false},
      {'label': l10n.productMgmtSortPriceLowHigh, 'field': 'price', 'asc': true},
      {'label': l10n.productMgmtSortPriceHighLow, 'field': 'price', 'asc': false},
      {'label': l10n.productMgmtSortStockLowHigh, 'field': 'stock', 'asc': true},
      {'label': l10n.productMgmtSortStockHighLow, 'field': 'stock', 'asc': false},
    ];
    final currentLabel = sortOptions.firstWhere(
      (o) => o['field'] == _sortBy && o['asc'] == _isAscending,
      orElse: () => sortOptions.first,
    )['label'] as String;

    final searchField = TextField(
      focusNode: _searchFocusNode,
      onChanged: _onSearchChangedV2,
      decoration: InputDecoration(
        hintText: l10n.productMgmtSearchHint,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
    );

    final filterMenu = PopupMenuButton<String>(
      tooltip: l10n.productMgmtFilterByStockStatusTooltip,
      onSelected: (value) {
        if (!mounted) return;
        setState(() {
          _currentPage = 0;
          _activeTabV2 = switch (value) {
            'low' => 3,
            'out' => 4,
            'expired' => 5,
            _ => (_activeTabV2 >= 3 && _activeTabV2 <= 5) ? 0 : _activeTabV2,
          };
        });
        _loadProducts();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'all', child: Text(l10n.productMgmtAllStockLevelsLabel)),
        PopupMenuItem(value: 'low', child: Text(l10n.productMgmtLowStockLabel)),
        PopupMenuItem(value: 'out', child: Text(l10n.productMgmtOutOfStockLabel)),
        if (_columnsConfig.productMetadata && _columnsConfig.metaExpiryDate)
          PopupMenuItem(value: 'expired', child: Text(l10n.productMgmtExpiredLabel)),
      ],
      child: _menuButtonLookV2(Icons.filter_list, l10n.invoiceMgmtFilterLabel),
    );

    final sortMenu = PopupMenuButton<Map<String, Object>>(
      tooltip: l10n.invoiceMgmtSortLabel,
      onSelected: (opt) =>
          _onSortSelectionV2(opt['field'] as String, opt['asc'] as bool),
      itemBuilder: (ctx) => sortOptions
          .map((o) => PopupMenuItem(value: o, child: Text(o['label'] as String)))
          .toList(),
      child: _menuButtonLookV2(
          Icons.swap_vert, l10n.customerMgmtSortWithLabel(currentLabel)),
    );

    // One "columns" menu: tick the columns to show, and customise them.
    final columnsMenu = PopupMenuButton<String>(
      tooltip: l10n.productMgmtShowColumnsLabel,
      onSelected: (value) {
        if (value == '__customize__') {
          _openColumnsSettingsV2();
        } else {
          _toggleListColumnV2(value);
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
              l10n.productMgmtShowColumnsMaxHint(_maxVisibleListColumns),
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        for (final key in _listColumnDefaults.keys)
          if (_listColumnFieldEnabled(key))
            _listColMenuItemV2(key, _listColLabel(l10n, key)),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: '__customize__',
          child: Row(
            children: [
              const Icon(Icons.tune, size: 18),
              const SizedBox(width: 10),
              Text(l10n.productMgmtCustomizeColumnsLabel),
            ],
          ),
        ),
      ],
      child: _menuButtonLookV2(
          Icons.view_column_outlined, l10n.productMgmtShowColumnsLabel),
    );

    final statsToggle = IconButton(
      tooltip: _showStatsCardsV2
          ? l10n.customerMgmtHideStatCardsTooltip
          : l10n.customerMgmtShowStatCardsTooltip,
      onPressed: _toggleStatsCardsV2,
      icon: Icon(
        _showStatsCardsV2 ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
      ),
    );

    // One tidy line on a normal window: search, then Filter, Sort and
    // Columns. On a narrow window the search takes its own line.
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 820) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 10),
            filterMenu,
            const SizedBox(width: 8),
            sortMenu,
            const SizedBox(width: 8),
            columnsMenu,
            const SizedBox(width: 4),
            statsToggle,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          searchField,
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [filterMenu, sortMenu, columnsMenu, statsToggle],
          ),
        ],
      );
    });
  }

  Widget _tabChipV2(String label, int count, int index) {
    final selected = _activeTabV2 == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: () => _selectTabV2(index),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? Theme.of(context).primaryColor : null,
          foregroundColor: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          side: BorderSide(
              color: selected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        ),
        child: Text(AppLocalizations.of(context)!.customerMgmtTabChipLabel(label, count)),
      ),
    );
  }

  Widget _tabsRowV2() {
    final l10n = AppLocalizations.of(context)!;
    final showExpiredTab = _columnsConfig.productMetadata && _columnsConfig.metaExpiryDate;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tabChipV2(l10n.invoiceMgmtStatusAllLabel, _allCountV2, 0),
          _tabChipV2(l10n.navProducts, _productsCountV2, 1),
          _tabChipV2(l10n.productMgmtServicesTabLabel, _servicesCountV2, 2),
          _tabChipV2(l10n.productMgmtLowStockTabLabel, _lowStockCountV2, 3),
          _tabChipV2(l10n.productMgmtOutOfStockTabLabel, _outOfStockCountV2, 4),
          if (showExpiredTab) _tabChipV2(l10n.productMgmtExpiredLabel, _expiredCountV2, 5),
        ],
      ),
    );
  }

  Widget _typeTagV2(String type) {
    final isService = type == 'service';
    final color = isService ? Colors.orange : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isService ? AppLocalizations.of(context)!.labelService : AppLocalizations.of(context)!.labelProduct,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color.shade700),
      ),
    );
  }

  Widget _stockCellV2(Product p) {
    if (p.unlimitedStock) {
      return const Text('∞');
    }
    final color = p.stock > 10
        ? null
        : p.stock > 0
            ? Colors.orange[700]
            : Colors.red[700];
    return Text(AppFormatters.formatStock(p.stock),
        style: TextStyle(color: color, fontWeight: FontWeight.w600));
  }

  Widget _tableRowV2(Product p, int index) {
    final serial = _currentPage * _pageSize + index + 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text('$serial',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (_businessType == BusinessType.both && _columnsConfig.type)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _typeTagV2(p.type),
                  ),
                if (_showListCol('aliasName') && (p.aliasName ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('(${p.aliasName})',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
              ],
            ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(AppFormatters.formatAmount(p.price, _currencySymbol),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          ..._optionalRowCellsV2(p),
          SizedBox(
            width: 124, // three compact icon buttons (40 each)
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _viewProductV2(p),
                  tooltip: AppLocalizations.of(context)!.actionView,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editProductV2(p),
                  tooltip: AppLocalizations.of(context)!.actionEdit,
                ),
                if (widget.user.isAdmin())
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () => _deleteProductV2(p),
                    tooltip: AppLocalizations.of(context)!.actionDelete,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeaderRowV2() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    TextStyle style = TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: scheme.onSurfaceVariant);
    Widget cell(int flex, String text) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        ));
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHighest : BrandColors.tableHeader,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text(l10n.productMgmtColSlNo, style: style)),
          cell(3, l10n.productMgmtColNameAlias),
          cell(2, l10n.productMgmtColPrice),
          ..._optionalHeaderCellsV2(style),
          const SizedBox(width: 124),
        ],
      ),
    );
  }

  // This widget now sizes itself naturally instead of relying on `Expanded`
  // to fill whatever space a bounded ancestor gives it. The list is
  // shrink-wrapped (its own scrolling disabled) because the *page* is
  // already inside a CustomScrollView — so instead of this Column being
  // squeezed into a fixed box and overflowing when its fixed rows (header +
  // pagination) don't fit, it just reports its true height and the page
  // scrolls further if needed. A naturally-sized widget can't overflow.
  Widget _tableSectionV2() {
    final totalPages = _totalProducts == 0 ? 1 : ((_totalProducts - 1) ~/ _pageSize) + 1;
    return Container(
      decoration: _flatCardDecorationV2(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tableHeaderRowV2(),
          _statsLoadingV2 && _products.isEmpty
              ? const SizedBox(
                  height: 240, child: Center(child: CircularProgressIndicator()))
              : _products.isEmpty
                  ? SizedBox(height: 240, child: _buildEmptyState())
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _products.length,
                      itemBuilder: (context, index) =>
                          _tableRowV2(_products[index], index),
                    ),
          _paginationV2(totalPages),
        ],
      ),
    );
  }

  Widget _paginationV2(int totalPages) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      // Was a Wrap(alignment: spaceBetween, ...): when the row got narrow it
      // would silently wrap onto a second line, growing this widget's
      // height and stealing space the table's Expanded(ListView) needed —
      // the direct cause of the reported "RenderFlex overflowed by 55
      // pixels" error. A horizontally-scrolling Row keeps this bar's
      // height constant no matter how narrow the table gets.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Text(
            l10n.productMgmtShowingRangeLabel(
                _totalProducts == 0 ? 0 : _currentPage * _pageSize + 1,
                (_currentPage * _pageSize + _pageSize).clamp(0, _totalProducts),
                _totalProducts),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.customerMgmtRowsPerPageLabel,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _pageSize,
                underline: const SizedBox(),
                itemHeight: 48,
                items: [10, 25, 50, 100]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (n) {
                  if (n == null || !mounted) return;
                  setState(() {
                    _pageSize = n;
                    _currentPage = 0;
                  });
                  _loadProducts();
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed:
                    _currentPage > 0 ? () => _changePageV2(_currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_currentPage + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              Text(l10n.customerMgmtOfTotalPagesLabel(totalPages),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              IconButton(
                onPressed: _currentPage < totalPages - 1
                    ? () => _changePageV2(_currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }

  // ── Slide-out "Add New Product" panel ──────────────────────────────────

  // Sectioned form used by the Add panel — same section grouping/order as
  // the View/Edit dialog (General / Pricing / Inventory / Advanced
  // Information) instead of the old Basic Information / Advanced tabs.
  Widget _addPanelFormV2() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabelV2(l10n.productMgmtSectionGeneral),
        _buildFormField(_nameController, l10n.fieldNameLabel, Icons.inventory_2,
            maxLength: 100, onSubmitted: _addProductV2),
        if (_columnsConfig.aliasName) ...[
          const SizedBox(height: 16),
          _buildFormField(_aliasNameController,
              l10n.productMgmtAliasNameLabel, Icons.translate,
              maxLength: 100,
              required: false,
              helperText: l10n.productMgmtAliasHelperText),
        ],
        if (_columnsConfig.description) ...[
          const SizedBox(height: 16),
          _buildFormField(
              _descriptionController, l10n.productMgmtDescriptionLabel, Icons.description,
              maxLines: 3, maxLength: 500, required: false),
        ],
        if (_columnsConfig.hsncode) ...[
          const SizedBox(height: 16),
          _buildFormField(_hsnCodeController, l10n.productMgmtHsnSacLabel, Icons.qr_code,
              maxLength: 100, required: false),
        ],
        const SizedBox(height: 20),
        _sectionLabelV2(l10n.productMgmtSectionPricing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildFormField(_priceController, l10n.productMgmtSalePriceLabel, Icons.attach_money,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  isPrice: true,
                  prefixText: '$_currencySymbol ',
                  onSubmitted: _addProductV2),
            ),
            if (_columnsConfig.purchasePrice) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormField(
                    _purchasePriceController, l10n.productMgmtPurchasePriceLabel, Icons.shopping_cart_outlined,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    isPrice: true,
                    required: _newItemType != 'service',
                    prefixText: '$_currencySymbol '),
              ),
            ],
          ],
        ),
        if (_columnsConfig.defaultDiscount) ...[
          const SizedBox(height: 16),
          _buildFormField(
              _defaultDiscountController, l10n.productMgmtDefaultDiscountLabel, Icons.discount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              isPrice: true,
              required: false,
              prefixText: '$_currencySymbol '),
        ],
        if (_columnsConfig.taxRate) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _buildFormField(_taxRateController, l10n.productMgmtTaxPercentLabel, Icons.percent,
                    keyboardType: TextInputType.number, isTaxRate: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _priceIncludesTax,
                      onChanged: (v) {
                        if (!mounted) return;
                        setState(() => _priceIncludesTax = v ?? false);
                      },
                    ),
                    Flexible(
                      child: Text(l10n.fieldPriceIncludesTaxLabel,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(l10n.productMgmtPerItemTaxModeOnlyLabel,
                style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
        if (_columnsConfig.stock || _columnsConfig.unit) ...[
          const SizedBox(height: 12),
          _sectionLabelV2(l10n.productMgmtSectionInventory),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_columnsConfig.stock)
                Expanded(
                  child: _buildFormField(_stockController, l10n.labelStock, Icons.inventory,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      isStock: true,
                      required: !_unlimitedStock,
                      enabled: !_unlimitedStock),
                ),
              if (_columnsConfig.stock && _columnsConfig.unit) const SizedBox(width: 12),
              if (_columnsConfig.unit)
                Expanded(
                  child: _buildUnitField(
                    selectedUnit: _selectedUnit,
                    customController: _customUnitController,
                    onUnitChanged: (v) {
                      if (!mounted) return;
                      setState(() => _selectedUnit = v);
                    },
                  ),
                ),
            ],
          ),
          if (_columnsConfig.stock)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: _unlimitedStock,
              onChanged: (v) {
                if (!mounted) return;
                setState(() => _unlimitedStock = v ?? false);
              },
              title: Text(l10n.productMgmtUnlimitedStockLabel),
              subtitle: Text(l10n.productMgmtTrackInfiniteStockSubtitle),
            ),
        ],
        if (_columnsConfig.productMetadata) ...[
          const SizedBox(height: 8),
          _buildMetadataSection(
            storageLocationCtrl: _storageLocationController,
            containerNumberCtrl: _containerNumberController,
            batchNumberCtrl: _batchNumberController,
            manufactureNameCtrl: _manufactureNameController,
            supplierNameCtrl: _supplierNameController,
            skuCodeCtrl: _skuCodeController,
            notesCtrl: _notesController,
            expiryDate: _expiryDate,
            manufactureDate: _manufactureDate,
            datePattern: _datePattern,
            onExpiryChanged: (d) {
              if (!mounted) return;
              setState(() => _expiryDate = d);
            },
            onManufactureChanged: (d) {
              if (!mounted) return;
              setState(() => _manufactureDate = d);
            },
          ),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l10n.productMgmtTipEnableCustomFieldsMessage,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _addPanelV2() {
    // Width is now controlled by the Positioned wrapper in _buildV2 (fixed
    // 400 on wide screens, screen-width-minus-margins on narrow ones), so
    // this no longer hardcodes its own width.
    final l10n = AppLocalizations.of(context)!;
    final showTypeToggle = !widget.modern && _businessType == BusinessType.both && _columnsConfig.type; // Modern pages add their own kind
    return Container(
      decoration: _flatCardDecorationV2(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          l10n.productMgmtAddNewItemTitle(_newItemType == 'service'
                              ? l10n.labelService
                              : l10n.labelProduct),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(l10n.productMgmtEnterProductDetailsSubtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (showTypeToggle) ...[
                  const SizedBox(width: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'product',
                          label: Text(l10n.labelProduct),
                          icon: const Icon(Icons.inventory_2_outlined, size: 14)),
                      ButtonSegment(
                          value: 'service',
                          label: Text(l10n.labelService),
                          icon: const Icon(Icons.design_services_outlined, size: 14)),
                    ],
                    selected: {_newItemType},
                    onSelectionChanged: (val) {
                      if (!mounted) return;
                      setState(() {
                        _newItemType = val.first;
                        _unlimitedStock = _newItemType == 'service' || !_columnsConfig.stock;
                      });
                    },
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _showAddPanelV2 = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: FocusTraversalGroup(
                child: Form(
                  key: _formKey,
                  child: _addPanelFormV2(),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _addAnotherAfterSavingV2,
                      onChanged: (v) => setState(
                          () => _addAnotherAfterSavingV2 = v ?? false),
                    ),
                    Expanded(child: Text(l10n.customerMgmtAddAnotherLabel)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _clearForm();
                          setState(() => _showAddPanelV2 = false);
                        },
                        child: Text(l10n.actionCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _addProductV2,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(_servicesWording
                            ? l10n.mSvcSaveButton
                            : l10n.productMgmtSaveProductButton),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── View/Edit dialog ─────────────────────────────────────────────────
  // Same content/layout as the old right-side panel (sectioned General/
  // Pricing/Inventory groups, Product/Service toggle, Advanced Info,
  // tip banner) but shown as a proper Dialog instead. Each open creates
  // fresh local controllers scoped to this call (same pattern as the
  // original _showProductDialog) so there's no shared-controller state
  // to accidentally double-dispose between opens — that was the bug
  // that made the panel stop reopening after being closed.

  Future<void> _showDetailDialogV2(Product product, {required bool startInEdit}) async {
    final metadata =
        await ref.read(productRepositoryProvider).getProductMetadata(product.id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;

    final nameCtrl = TextEditingController(text: product.name);
    final aliasCtrl = TextEditingController(text: product.aliasName ?? '');
    final descCtrl = TextEditingController(text: product.description);
    final hsnCtrl = TextEditingController(text: product.hsncode);
    final priceCtrl = TextEditingController(text: product.price.toString());
    final purchaseCtrl = TextEditingController(
        text: product.purchasePrice > 0 ? product.purchasePrice.toString() : '0.0');
    final discountCtrl = TextEditingController(
        text: product.defaultDiscount > 0 ? product.defaultDiscount.toString() : '0.0');
    final taxCtrl = TextEditingController(text: product.tax_rate.toString());
    final stockCtrl =
        TextEditingController(text: AppFormatters.formatStock(product.stock));
    final customUnitCtrl = TextEditingController(
        text: ProductUnits.presets.contains(product.unit) ? '' : product.unit);
    final storageCtrl = TextEditingController(text: metadata?.storageLocation ?? '');
    final containerCtrl = TextEditingController(text: metadata?.containerNumber ?? '');
    final batchCtrl = TextEditingController(text: metadata?.batchNumber ?? '');
    final manufactureNameCtrl =
        TextEditingController(text: metadata?.manufactureName ?? '');
    final supplierCtrl = TextEditingController(text: metadata?.supplierName ?? '');
    final skuCtrl = TextEditingController(text: metadata?.skuCode ?? '');
    final notesCtrl = TextEditingController(text: metadata?.notes ?? '');
    final formKey = GlobalKey<FormState>();

    String itemType = product.type;
    String unit = product.unit;
    bool priceIncludesTax = product.priceIncludesTax;
    bool unlimitedStock = !_columnsConfig.stock ? true : product.unlimitedStock;
    DateTime? expiryDate = _parseIsoDate(metadata?.expiryDate);
    DateTime? manufactureDate = _parseIsoDate(metadata?.manufactureDate);
    bool isEdit = startInEdit;
    bool isSaving = false;

    void disposeAll() {
      nameCtrl.dispose();
      aliasCtrl.dispose();
      descCtrl.dispose();
      hsnCtrl.dispose();
      priceCtrl.dispose();
      purchaseCtrl.dispose();
      discountCtrl.dispose();
      taxCtrl.dispose();
      stockCtrl.dispose();
      customUnitCtrl.dispose();
      storageCtrl.dispose();
      containerCtrl.dispose();
      batchCtrl.dispose();
      manufactureNameCtrl.dispose();
      supplierCtrl.dispose();
      skuCtrl.dispose();
      notesCtrl.dispose();
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          Widget field(
            TextEditingController controller,
            String label,
            IconData icon, {
            int maxLines = 1,
            int? maxLength,
            TextInputType? keyboardType,
            bool isPrice = false,
            bool isStock = false,
            bool isTaxRate = false,
            bool isRequired = false,
            String? prefixText,
          }) {
            return _buildDialogTextField(
              controller,
              label,
              icon,
              readOnly: !isEdit,
              maxLines: maxLines,
              maxLength: maxLength,
              keyboardType: keyboardType,
              isPrice: isPrice,
              isStock: isStock,
              isTaxRate: isTaxRate,
              isRequired: isRequired,
              prefixText: prefixText,
            );
          }

          Widget sectionLabel(String text) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                text.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          Future<void> save() async {
            if (isSaving) return;
            if (!formKey.currentState!.validate()) return;
            final price = double.parse(priceCtrl.text.trim());
            final purchasePrice = double.tryParse(purchaseCtrl.text.trim()) ?? 0.0;
            if (!await _confirmIfSellingAtLoss(price, purchasePrice)) return;
            setDialogState(() => isSaving = true);
            try {
              final updated = Product(
                id: product.id,
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim(),
                price: price,
                stock: unlimitedStock ? 0 : _parseStock(stockCtrl.text),
                hsncode: hsnCtrl.text.trim(),
                tax_rate: int.parse(taxCtrl.text.trim()),
                type: itemType,
                defaultDiscount: double.tryParse(discountCtrl.text.trim()) ?? 0.0,
                purchasePrice: purchasePrice,
                aliasName: aliasCtrl.text.trim().isEmpty ? null : aliasCtrl.text.trim(),
                unit: unit.trim(),
                unlimitedStock: unlimitedStock,
                priceIncludesTax: priceIncludesTax,
              );
              await ref.read(productRepositoryProvider).updateProduct(updated);
              await ref.read(productRepositoryProvider).upsertProductMetadata(
                    ProductMetadata(
                      productId: updated.id,
                      storageLocation: storageCtrl.text.trim(),
                      containerNumber: containerCtrl.text.trim(),
                      batchNumber: batchCtrl.text.trim(),
                      expiryDate: _isoDate(expiryDate),
                      manufactureDate: _isoDate(manufactureDate),
                      manufactureName: manufactureNameCtrl.text.trim(),
                      supplierName: supplierCtrl.text.trim(),
                      skuCode: skuCtrl.text.trim(),
                      notes: notesCtrl.text.trim(),
                    ),
                  );
              await _loadStatsV2();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _showSnackBar(l10n.productMgmtUpdatedMessage);
            } finally {
              setDialogState(() => isSaving = false);
            }
          }

          final showTypeToggle = _businessType == BusinessType.both && _columnsConfig.type;
          final screenSize = MediaQuery.of(dialogContext).size;
          final dialogWidth = (screenSize.width * 0.55).clamp(560.0, 760.0);
          final dialogMaxHeight = (screenSize.height * 0.88).clamp(500.0, 880.0);

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: dialogMaxHeight),
              child: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isEdit ? l10n.productMgmtEditProductTitle : l10n.productMgmtViewProductTitle,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(isEdit
                                      ? l10n.productMgmtUpdateProductDetailsSubtitle
                                      : l10n.productMgmtProductDetailsSubtitle,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Theme.of(dialogContext).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (showTypeToggle) ...[
                          const SizedBox(width: 8),
                          if (isEdit)
                            SegmentedButton<String>(
                              segments: [
                                ButtonSegment(
                                    value: 'product',
                                    label: Text(l10n.labelProduct),
                                    icon: const Icon(Icons.inventory_2_outlined, size: 14)),
                                ButtonSegment(
                                    value: 'service',
                                    label: Text(l10n.labelService),
                                    icon:
                                        const Icon(Icons.design_services_outlined, size: 14)),
                              ],
                              selected: {itemType},
                              onSelectionChanged: (val) =>
                                  setDialogState(() => itemType = val.first),
                            )
                          else
                            Chip(
                              avatar: Icon(
                                  itemType == 'service'
                                      ? Icons.design_services_outlined
                                      : Icons.inventory_2_outlined,
                                  size: 14),
                              label: Text(itemType == 'service' ? l10n.labelService : l10n.labelProduct),
                            ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionLabel(l10n.productMgmtSectionGeneral),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: field(nameCtrl, l10n.productMgmtProductNameLabel,
                                      Icons.inventory_2, maxLength: 100, isRequired: true),
                                ),
                                if (_columnsConfig.aliasName) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: field(aliasCtrl,
                                        l10n.productMgmtAliasNameLabel, Icons.translate,
                                        maxLength: 100),
                                  ),
                                ],
                              ],
                            ),
                            if (_columnsConfig.description) ...[
                              const SizedBox(height: 16),
                              field(descCtrl, l10n.productMgmtDescriptionLabel, Icons.description,
                                  maxLines: 3, maxLength: 500),
                            ],
                            if (_columnsConfig.hsncode) ...[
                              const SizedBox(height: 16),
                              field(hsnCtrl, l10n.productMgmtColHsnSac, Icons.qr_code, maxLength: 100),
                            ],
                            const SizedBox(height: 20),
                            sectionLabel(l10n.productMgmtSectionPricing),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: field(priceCtrl, l10n.productMgmtPriceLabel, Icons.attach_money,
                                      keyboardType: const TextInputType.numberWithOptions(
                                          decimal: true),
                                      isPrice: true,
                                      isRequired: true,
                                      prefixText: '$_currencySymbol '),
                                ),
                                if (_columnsConfig.purchasePrice) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: field(purchaseCtrl, l10n.productMgmtPurchasePriceLabel,
                                        Icons.shopping_cart_outlined,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                                decimal: true),
                                        isPrice: true,
                                        isRequired: true,
                                        prefixText: '$_currencySymbol '),
                                  ),
                                ],
                              ],
                            ),
                            if (_columnsConfig.defaultDiscount) ...[
                              const SizedBox(height: 16),
                              field(discountCtrl, l10n.productMgmtDefaultDiscountLabel, Icons.discount,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(decimal: true),
                                  isPrice: true,
                                  prefixText: '$_currencySymbol '),
                            ],
                            if (_columnsConfig.taxRate) ...[
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: field(
                                        taxCtrl, l10n.fieldTaxRateLabel, Icons.percent,
                                        keyboardType: TextInputType.number,
                                        isTaxRate: true,
                                        isRequired: true),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Checkbox(
                                          value: priceIncludesTax,
                                          onChanged: !isEdit
                                              ? null
                                              : (v) => setDialogState(
                                                  () => priceIncludesTax = v ?? false),
                                        ),
                                        Flexible(
                                          child: Text(l10n.fieldPriceIncludesTaxLabel,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(dialogContext)
                                                  .textTheme
                                                  .bodyMedium),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 4, top: 2),
                                child: Text(l10n.productMgmtPerItemTaxModeOnlyLabel,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color:
                                            Theme.of(dialogContext).colorScheme.onSurfaceVariant)),
                              ),
                            ],
                            if (_columnsConfig.stock || _columnsConfig.unit) ...[
                              const SizedBox(height: 12),
                              sectionLabel(l10n.productMgmtSectionInventory),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_columnsConfig.stock)
                                    Expanded(
                                      child: field(stockCtrl, l10n.labelStock, Icons.inventory,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          isStock: !unlimitedStock,
                                          isRequired: !unlimitedStock),
                                    ),
                                  if (_columnsConfig.stock && _columnsConfig.unit)
                                    const SizedBox(width: 12),
                                  if (_columnsConfig.unit)
                                    Expanded(
                                      child: _buildUnitField(
                                        selectedUnit: unit,
                                        customController: customUnitCtrl,
                                        onUnitChanged: (v) =>
                                            setDialogState(() => unit = v),
                                        readOnly: !isEdit,
                                      ),
                                    ),
                                ],
                              ),
                              if (_columnsConfig.stock)
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  value: unlimitedStock,
                                  onChanged: !isEdit
                                      ? null
                                      : (v) => setDialogState(
                                          () => unlimitedStock = v ?? false),
                                  title: Text(l10n.productMgmtUnlimitedStockLabel),
                                  subtitle:
                                      Text(l10n.productMgmtTrackInfiniteStockSubtitle),
                                ),
                            ],
                            if (_columnsConfig.productMetadata) ...[
                              const SizedBox(height: 8),
                              _buildMetadataSection(
                                storageLocationCtrl: storageCtrl,
                                containerNumberCtrl: containerCtrl,
                                batchNumberCtrl: batchCtrl,
                                manufactureNameCtrl: manufactureNameCtrl,
                                supplierNameCtrl: supplierCtrl,
                                skuCodeCtrl: skuCtrl,
                                notesCtrl: notesCtrl,
                                expiryDate: expiryDate,
                                manufactureDate: manufactureDate,
                                datePattern: _datePattern,
                                readOnly: !isEdit,
                                onExpiryChanged: (d) =>
                                    setDialogState(() => expiryDate = d),
                                onManufactureChanged: (d) =>
                                    setDialogState(() => manufactureDate = d),
                              ),
                            ],
                            if (isEdit) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.08),
                                  borderRadius:
                                      BorderRadius.circular(AppBorderRadius.xsmall),
                                  border: Border.all(
                                      color: Colors.amber.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.lightbulb_outline,
                                        size: 16, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                          l10n.productMgmtTipEnableCustomFieldsMessage,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(dialogContext)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: Theme.of(dialogContext).colorScheme.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (widget.user.isAdmin())
                          OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              await _deleteProductV2(product);
                            },
                            icon: const Icon(Icons.delete_outline,
                                size: 18, color: Colors.red),
                            label: Text(l10n.productMgmtDeleteProductButton,
                                style: const TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        const Spacer(),
                        if (isEdit) ...[
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(l10n.actionCancel),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: isSaving ? null : save,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_outlined, size: 18),
                            label: Text(l10n.productMgmtSaveChangesButton),
                          ),
                        ] else ...[
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(l10n.actionClose),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => setDialogState(() => isEdit = true),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(l10n.actionEdit),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              ),
            ),
          );
        });
      },
    );
    // showDialog's future completes on Navigator.pop, before the dialog's
    // close (exit) animation finishes rebuilding the still-mounted subtree.
    // Delay disposal past that or the fields get used-after-dispose.
    Future.delayed(const Duration(milliseconds: 300), disposeAll);
  }


  Widget _buildV2(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The table section (`_tableSectionV2`) no longer relies on
            // `Expanded` to fill leftover space — it sizes itself naturally
            // (header row + actual row heights + pagination row), and sits
            // in a plain SliverToBoxAdapter below the rest of the page's
            // content, inside this CustomScrollView. Since nothing here
            // is forced into a box smaller than it needs, there is nothing
            // to overflow: if the natural content is taller than the
            // visible viewport, the page simply scrolls further to show it,
            // and if it fits (e.g. only a couple of products), it fits with
            // no extra scrolling — no guessed heights involved anywhere.
            final isNarrow = constraints.maxWidth < 700;

            return Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildColumnsDiscoveryBanner(),
                            _headerBarV2(),
                            const SizedBox(height: 12),
                            if (_showStatsCardsV2) ...[
                              _statCardsRowV2(),
                              const SizedBox(height: 12),
                            ],
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: _flatCardDecorationV2(context),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _searchFilterRowV2(),
                                  const SizedBox(height: 12),
                                  Divider(
                                      height: 1,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                  const SizedBox(height: 12),
                                  _tabsRowV2(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverToBoxAdapter(
                        child: _tableSectionV2(),
                      ),
                    ),
                  ],
                ),
                // The Add/Edit panel now floats as an overlay on top of the
                // page instead of living in a Row next to the main content.
                // Previously it was a fixed-width (400px) sibling in a Row,
                // which forced the main content's Expanded down to almost
                // nothing (and could itself overflow) on narrower windows.
                // As an overlay it never steals width from the table.
                if (_showAddPanelV2) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() => _showAddPanelV2 = false),
                      child: Container(color: Colors.black.withValues(alpha: 0.3)),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    bottom: 16,
                    width: isNarrow
                        ? constraints.maxWidth - 32
                        : 550,
                    child: _addPanelV2(),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══ Modern layout (October 2026 design) ═════════════════════════════════
  // One page per kind: Products (widget.kind 'product') and Services
  // ('service'). Title, subtitle, Import / Export / ⋯ and "+ New Product /
  // Service" in the Modern top bar; four tinted stat cards; a filter card
  // (search, Columns ▾ and the chips; sort by the column headings); the
  // table (eye, edit, duplicate, delete) with "Showing x to y" and numbered
  // pages. The Standard page above is unchanged.

  String _mTab = 'all';
  Map<String, int> _countsModern = const {};
  final Set<String> _selectedModern = {};

  bool get _isServicesModern => widget.kind == 'service';

  /// Counted for the cards and chips (keys of ProductService list tabs).
  List<String> get _countTabsModern => _isServicesModern
      ? const ['all', 'taxed', 'tax_free', 'no_hsn']
      : const ['all', 'in_stock', 'low', 'out', 'expired'];

  bool get _expiryOnModern =>
      _columnsConfig.productMetadata && _columnsConfig.metaExpiryDate;

  /// The chips (and Stock ▾ / Filter ▾ choices) of this page.
  List<(String, String)> _tabChoicesModern(AppLocalizations l10n) => _isServicesModern
      ? [
          ('all', l10n.invoiceMgmtStatusAllLabel),
          ('taxed', l10n.mSvcWithTax),
          ('tax_free', l10n.mSvcTaxFree),
          ('no_hsn', l10n.mSvcNoSac),
        ]
      : [
          ('all', l10n.invoiceMgmtStatusAllLabel),
          ('in_stock', l10n.mProdInStock),
          ('low', l10n.productMgmtLowStockTabLabel),
          ('out', l10n.productMgmtOutOfStockTabLabel),
          if (_expiryOnModern) ('expired', l10n.productMgmtExpiredLabel),
        ];

  int _countModern(String tab) => _countsModern[tab] ?? 0;

  void _selectTabModern(String tab) {
    if (!mounted) return;
    setState(() {
      _mTab = tab;
      _currentPage = 0;
    });
    _loadProducts();
  }

  /// Opens the New Product / New Service panel for this page's kind.
  void _openAddPanelModern() {
    setState(() {
      _newItemType = widget.kind;
      _unlimitedStock = widget.kind == 'service' || !_columnsConfig.stock;
      _showAddPanelV2 = true;
    });
  }

  // ── Columns ──────────────────────────────────────────────────────────────

  /// Optional columns of this page, in the design's order. They use the same
  /// show / hide choice (and limit of 10) as the Standard page.
  List<String> get _colKeysModern => _isServicesModern
      ? const [
          'aliasName', 'skuCode', 'hsncode', 'description', 'purchasePrice',
          'taxRate', 'unit', 'defaultDiscount', 'supplierName', 'notes',
        ]
      : const [
          'aliasName', 'skuCode', 'hsncode', 'description', 'purchasePrice',
          'stock', 'taxRate', 'unit', 'defaultDiscount', 'expiryDate',
          'batchNumber', 'manufactureDate', 'manufactureName', 'supplierName',
          'storageLocation', 'containerNumber', 'notes',
        ];

  /// Services keep their own column choice (products' stock / expiry
  /// columns never count toward it).
  static const _svcColDefaults = <String, bool>{
    'aliasName': true, 'skuCode': false, 'hsncode': true, 'description': false,
    'purchasePrice': false, 'taxRate': true, 'unit': false,
    'defaultDiscount': false, 'supplierName': false, 'notes': false,
  };
  Map<String, bool> _svcColsModern = Map.of(_svcColDefaults);

  Future<void> _loadSvcColsModern() async {
    final v = await ref
        .read(settingsRepositoryProvider)
        .getSetting(SettingKey.serviceListColumnsConfig);
    if (!mounted || v == null || v.isEmpty) return;
    try {
      final saved = (jsonDecode(v) as Map)
          .map((k, val) => MapEntry(k as String, val == true));
      setState(() => _svcColsModern = {..._svcColDefaults, ...saved});
    } catch (_) {
      // a damaged value: keep the defaults
    }
  }

  /// Column [k] shows on this Modern page.
  bool _colOnModern(String k) => _isServicesModern
      ? _listColumnFieldEnabled(k) && (_svcColsModern[k] ?? false)
      : _showListCol(k);

  Future<void> _toggleColModern(String k) async {
    if (!_isServicesModern) return _toggleListColumnV2(k);
    setState(() => _svcColsModern = {..._svcColsModern, k: !(_svcColsModern[k] ?? false)});
    await ref.read(settingsRepositoryProvider).setSetting(
        SettingKey.serviceListColumnsConfig, jsonEncode(_svcColsModern));
  }

  PopupMenuItem<String> _colMenuItemModern(String k, String label) {
    if (!_isServicesModern) return _listColMenuItemV2(k, label);
    final on = _colOnModern(k);
    return PopupMenuItem<String>(
      value: k,
      child: Row(children: [
        Icon(on ? Icons.check_box : Icons.check_box_outline_blank, size: 18),
        const SizedBox(width: 8),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  /// Columns shown before the Selling Price (the rest come after it).
  static const _beforePriceModern = {'skuCode', 'hsncode', 'description', 'purchasePrice'};

  /// Products page: In Stock / Low Stock / Out of Stock (needs stock tracking).
  bool get _statusColModern =>
      !_isServicesModern && _listColumnFieldEnabled('stock');

  Widget _optionalCellModern(Product p, String key) {
    final meta = _productMetadataV2[p.id];
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant);
    Widget text(String v, {TextStyle? style}) => Text(v.isEmpty ? '—' : v,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: v.isEmpty ? muted : (style ?? const TextStyle(fontSize: 13.5)));
    return switch (key) {
      'skuCode' => text(meta?.skuCode ?? ''),
      'hsncode' => text(p.hsncode),
      'description' => text(p.description, style: muted),
      'purchasePrice' => text(p.purchasePrice > 0
          ? AppFormatters.formatAmount(p.purchasePrice, _currencySymbol)
          : ''),
      'stock' => p.unlimitedStock
          ? Text('∞', style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant))
          : Text(AppFormatters.formatStock(p.stock),
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: p.stock > 10
                      ? const Color(0xFF16A34A)
                      : p.stock > 0
                          ? const Color(0xFFEA580C)
                          : const Color(0xFFDC2626))),
      'taxRate' => text('${p.tax_rate}%'),
      'unit' => text(p.unit),
      'defaultDiscount' =>
        text(p.defaultDiscount > 0 ? p.defaultDiscount.toStringAsFixed(2) : ''),
      'expiryDate' => _expiryCellModern(p),
      'batchNumber' => text(meta?.batchNumber ?? ''),
      'manufactureDate' => text(_fmtMetaDateV2(meta?.manufactureDate)),
      'manufactureName' => text(meta?.manufactureName ?? ''),
      'supplierName' => text(meta?.supplierName ?? ''),
      'storageLocation' => text(meta?.storageLocation ?? ''),
      'containerNumber' => text(meta?.containerNumber ?? ''),
      'notes' => text(meta?.notes ?? '', style: muted),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _expiryCellModern(Product p) {
    final scheme = Theme.of(context).colorScheme;
    final d = _expiryDateOfV2(p);
    if (d == null) {
      return Text('—', style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant));
    }
    final expired = d.isBefore(DateTime.now());
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (expired) ...[
        const Icon(Icons.error_outline, size: 14, color: Colors.red),
        const SizedBox(width: 4),
      ],
      Flexible(
        child: Text(DateFormat(_datePattern).format(d),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: expired ? FontWeight.w700 : FontWeight.normal,
                color: expired ? Colors.red : scheme.onSurface)),
      ),
    ]);
  }

  // ── Top bar ──────────────────────────────────────────────────────────────

  Future<void> _importModern() async {
    await _showImportDialog();
    await _loadStatsV2();
  }

  Future<void> _onMoreModern(String value) async {
    if (value == 'import') await _importModern();
    if (value == 'export') await _exportToCSV();
    if (value == 'refresh') await _loadStatsV2();
    if (value == 'toggle_stats') await _toggleStatsCardsV2();
    if (value == 'export_pdf') await _exportToPDF();
    if (value == 'delete_all') await _deleteAllOfKindModern();
  }

  List<Widget> _headerActionsModern(bool compact) {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).primaryColor;
    final scheme = Theme.of(context).colorScheme;
    PopupMenuItem<String> item(String value, IconData icon, String label, {Color? color}) =>
        PopupMenuItem<String>(
          value: value,
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: color == null ? null : TextStyle(color: color))),
          ]),
        );
    Widget soft(String key, IconData icon, String label, VoidCallback onTap) => TextButton.icon(
          key: ValueKey(key),
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor: primary,
            backgroundColor: primary.withValues(alpha: 0.08),
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
    return [
      if (!compact) ...[
        soft('modernProductImport', Icons.upload_file_outlined, l10n.actionImport,
            _importModern),
        const SizedBox(width: 8),
        soft('modernProductExport', Icons.file_download_outlined, l10n.actionExport,
            _exportToCSV),
        const SizedBox(width: 8),
      ],
      PopupMenuButton<String>(
        key: const ValueKey('modernProductMore'),
        tooltip: l10n.invoiceMgmtMoreActionsTooltip,
        onSelected: _onMoreModern,
        itemBuilder: (ctx) => [
          if (compact) ...[
            item('import', Icons.upload_file_outlined, l10n.actionImport),
            item('export', Icons.file_download_outlined, l10n.actionExport),
          ],
          item('refresh', Icons.refresh, l10n.actionRefresh),
          // Show / hide the stat cards (remembered, same setting as Standard).
          item(
              'toggle_stats',
              _showStatsCardsV2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              _showStatsCardsV2
                  ? l10n.customerMgmtHideStatCardsTooltip
                  : l10n.customerMgmtShowStatCardsTooltip),
          if (widget.user.isAdmin()) ...[
            const PopupMenuDivider(),
            item('export_pdf', Icons.picture_as_pdf_outlined, l10n.customerMgmtExportPdfMenuLabel),
            item('delete_all', Icons.delete_sweep,
                _isServicesModern ? l10n.mSvcDeleteAllTitle : l10n.productMgmtDeleteAllTitle,
                color: Colors.red),
          ],
        ],
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.more_horiz, color: scheme.onSurfaceVariant),
        ),
      ),
    ];
  }

  Widget _newButtonModern() {
    final l10n = AppLocalizations.of(context)!;
    return FilledButton.icon(
      key: const ValueKey('modernNewProduct'),
      onPressed: _openAddPanelModern,
      icon: const Icon(Icons.add, size: 18),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: Text(
            _isServicesModern ? l10n.mSvcNewService : l10n.productMgmtNewProductButton,
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Delete All on the Modern page: only this page's kind.
  Future<void> _deleteAllOfKindModern() async {
    final l10n = AppLocalizations.of(context)!;
    final count = _countModern('all');
    if (count == 0) {
      _showSnackBar(_isServicesModern
          ? l10n.mSvcNoneToDelete
          : l10n.productMgmtNoProductsToDeleteMessage);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isServicesModern ? l10n.mSvcDeleteAllTitle : l10n.productMgmtDeleteAllTitle),
        content: Text(_isServicesModern
            ? l10n.mSvcDeleteAllBody(count)
            : l10n.productMgmtDeleteAllBody(count)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.actionCancel)),
          FilledButton(
            key: const ValueKey('prodDeleteAllOk'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.customerMgmtDeleteAllButton),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(productRepositoryProvider).deleteProductsByType(widget.kind);
      if (!mounted) return;
      setState(_selectedModern.clear);
      await _loadStatsV2();
      _showSnackBar(
          _isServicesModern ? l10n.mSvcAllDeleted : l10n.productMgmtAllDeletedMessage);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
          _isServicesModern
              ? l10n.mSvcDeleteAllError(e.toString())
              : l10n.productMgmtDeleteAllErrorMessage(e.toString()),
          isError: true);
    }
  }

  // ── Stat cards ───────────────────────────────────────────────────────────

  Widget _statCardsModern() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final cards = <(IconData, Color, String, int, String)>[
      if (_isServicesModern) ...[
        (Icons.design_services_outlined, primary, l10n.mSvcTotal, _countModern('all'),
            l10n.mSvcAllSub),
        (Icons.percent, const Color(0xFF16A34A), l10n.mSvcWithTax, _countModern('taxed'),
            l10n.mSvcWithTaxSub),
        (Icons.money_off_outlined, const Color(0xFF7C3AED), l10n.mSvcTaxFree,
            _countModern('tax_free'), l10n.mSvcTaxFreeSub),
        (Icons.tag, const Color(0xFFF59E0B), l10n.mSvcNoSac, _countModern('no_hsn'),
            l10n.mSvcNoSacSub),
      ] else ...[
        (Icons.inventory_2_outlined, primary, l10n.mProdTotalProducts, _countModern('all'),
            l10n.mProdAllProductsSub),
        (Icons.check_circle_outline, const Color(0xFF16A34A), l10n.mProdInStock,
            _countModern('in_stock'), l10n.mProdInStockSub),
        (Icons.warning_amber_rounded, const Color(0xFFDC2626),
            l10n.productMgmtLowStockTabLabel, _countModern('low'), l10n.mProdLowStockSub),
        (Icons.remove_shopping_cart_outlined, const Color(0xFF7C3AED),
            l10n.productMgmtOutOfStockTabLabel, _countModern('out'), l10n.mProdOutOfStockSub),
      ],
    ];
    Widget card((IconData, Color, String, int, String) c) {
      final (icon, color, label, value, sub) = c;
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surfaceContainerHighest
              : Color.alphaBlend(color.withValues(alpha: 0.05), Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FitText(label,
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text('$value', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                FitText(sub,
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ]),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
      const gap = 14.0;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        key: const ValueKey('modernProductStats'),
        spacing: gap,
        runSpacing: gap,
        children: [for (final x in cards) SizedBox(width: w, child: card(x))],
      );
    });
  }

  // ── Filter card ──────────────────────────────────────────────────────────

  /// A menu right under the button that was tapped ([anchor]).
  RelativeRect _menuAtModern(BuildContext anchor) {
    final box = anchor.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    if (box == null) return const RelativeRect.fromLTRB(100, 100, 100, 100);
    final topLeft = box.localToGlobal(Offset(0, box.size.height + 4), ancestor: overlay);
    return RelativeRect.fromLTRB(
        topLeft.dx, topLeft.dy, overlay.size.width - topLeft.dx - box.size.width, 0);
  }

  Widget _menuButtonModern(
      {required String key,
      required IconData icon,
      required String label,
      required void Function(BuildContext anchor) onTapAt,
      bool active = false}) {
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    return Builder(
      builder: (anchor) => Material(
        color: active ? primary.withValues(alpha: 0.08) : scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: active ? primary.withValues(alpha: 0.5) : scheme.outlineVariant),
        ),
        child: InkWell(
          key: ValueKey(key),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onTap: () => onTapAt(anchor),
          child: SizedBox(
            height: 46,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: primary),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: active ? primary : scheme.onSurface)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 18, color: scheme.onSurfaceVariant),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openColumnsMenuModern(BuildContext anchor) async {
    final l10n = AppLocalizations.of(context)!;
    final v = await showMenu<String>(
      context: context,
      position: _menuAtModern(anchor),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 30,
          child: Text(l10n.productMgmtShowColumnsMaxHint(_maxVisibleListColumns),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        for (final k in _colKeysModern)
          if (_listColumnFieldEnabled(k)) _colMenuItemModern(k, _listColLabel(l10n, k)),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: '__customize__',
          child: Row(children: [
            const Icon(Icons.tune, size: 18),
            const SizedBox(width: 8),
            Flexible(
                child: Text(l10n.productMgmtCustomizeColumnsLabel,
                    overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ],
    );
    if (v == null || !mounted) return;
    if (v == '__customize__') {
      await _openColumnsSettingsV2();
    } else {
      await _toggleColModern(v);
    }
  }

  Widget _chipModern(String key, String label) {
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    final selected = _mTab == key;
    final warn = key == 'low' || key == 'out' || key == 'expired';
    return Material(
      color: selected ? primary : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? primary : scheme.outlineVariant),
      ),
      child: InkWell(
        key: ValueKey('modernProdChip_$key'),
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () => _selectTabModern(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (warn && !selected && _countModern(key) > 0) ...[
              Container(
                width: 8,
                height: 8,
                decoration:
                    const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Text(
                AppLocalizations.of(context)!.customerMgmtTabChipLabel(label, _countModern(key)),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? Colors.white : scheme.onSurface)),
          ]),
        ),
      ),
    );
  }

  Widget _filterCardModern(bool isWide) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final search = SizedBox(
      height: 46,
      child: TextField(
        key: const ValueKey('modernProductSearch'),
        focusNode: _searchFocusNode,
        onChanged: _onSearchChangedV2,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: _isServicesModern ? l10n.mSvcSearchHint : l10n.productMgmtSearchHint,
          prefixIcon: Icon(Icons.search, size: 20, color: scheme.onSurfaceVariant),
          isDense: true,
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: scheme.outlineVariant)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: scheme.outlineVariant)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.6)),
        ),
      ),
    );
    final choices = _tabChoicesModern(l10n);
    // Filtering is by the chips; sorting by clicking a column heading.
    final buttons = <Widget>[
      _menuButtonModern(
          key: 'modernProductColumns',
          icon: Icons.view_column_outlined,
          label: l10n.customerMgmtColumnsLabel,
          onTapAt: _openColumnsMenuModern),
    ];
    final chips = <Widget>[
      for (final (k, label) in choices) _chipModern(k, label),
    ];
    return Container(
      key: const ValueKey('modernProductFilters'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (isWide)
          Row(children: [
            Expanded(child: search),
            for (final b in buttons) ...[const SizedBox(width: 10), b],
          ])
        else ...[
          search,
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: buttons),
        ],
        const SizedBox(height: 16),
        Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: chips),
      ]),
    );
  }

  // ── Table ────────────────────────────────────────────────────────────────

  static const double _actionsWidthModern = 184;
  static const double _statusWidthModern = 124;

  /// Column share in the Modern table: Stock has a sort arrow, so it needs
  /// two shares to show its heading in full.
  int _colFlexModern(String key) => key == 'stock' ? 2 : _listColFlex(key);

  Widget _sortHeaderModern(String key, String text, String field, TextStyle style,
      {bool defaultAscending = true}) {
    final sorted = _sortBy == field;
    return InkWell(
      key: ValueKey(key),
      onTap: () => _onSortSelectionV2(field, sorted ? !_isAscending : defaultAscending),
      // Up to two lines, with the sort arrow after the last word, so a
      // two-word (Tamil) label wraps at the space instead of being cut.
      child: Text.rich(
        TextSpan(text: '$text ', children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(
                !sorted ? Icons.unfold_more : (_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
                size: 14,
                color: style.color),
          ),
        ]),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }

  /// The visible optional columns, split around the Selling Price.
  (List<String>, List<String>) _visibleColsModern() {
    final before = <String>[];
    final after = <String>[];
    for (final k in _colKeysModern) {
      if (k == 'aliasName' || !_colOnModern(k)) continue;
      (_beforePriceModern.contains(k) ? before : after).add(k);
    }
    return (before, after);
  }

  Widget _tableHeaderModern() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant);
    final pageIds = _products.map((p) => p.id).toSet();
    final allOn = pageIds.isNotEmpty && pageIds.every(_selectedModern.contains);
    final someOn = pageIds.any(_selectedModern.contains);
    final (before, after) = _visibleColsModern();
    Widget cell(int flex, Widget child) => Expanded(
        flex: flex, child: Padding(padding: const EdgeInsets.only(right: 12), child: child));
    Widget label(String k) {
      if (k == 'stock') {
        return _sortHeaderModern('modernProdSortStock', _listColLabel(l10n, k), 'stock', style);
      }
      // "Tax" (not "Tax Rate"): the column is narrow and the cell is a % anyway.
      final text = k == 'taxRate' ? l10n.fieldTaxLabel : _listColLabel(l10n, k);
      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHighest : BrandColors.tableHeader,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(children: [
        SizedBox(
          width: 44,
          child: Checkbox(
            key: const ValueKey('modernProductSelectAll'),
            value: allOn ? true : (someOn ? null : false),
            tristate: true,
            onChanged: (_) => setState(() {
              if (allOn) {
                _selectedModern.removeAll(pageIds);
              } else {
                _selectedModern.addAll(pageIds);
              }
            }),
          ),
        ),
        SizedBox(width: 40, child: Text('#', style: style)),
        cell(3, _sortHeaderModern('modernProdSortName',
            _isServicesModern ? l10n.labelService : l10n.labelProduct, 'name', style)),
        for (final k in before) cell(_colFlexModern(k), label(k)),
        cell(2, _sortHeaderModern('modernProdSortPrice', l10n.mProdColSellingPrice, 'price', style)),
        for (final k in after) ...[
          cell(_colFlexModern(k), label(k)),
          if (k == 'stock' && _statusColModern)
            SizedBox(width: _statusWidthModern, child: Text(l10n.invoiceMgmtColStatus, style: style)),
        ],
        if (_statusColModern && !after.contains('stock'))
          SizedBox(width: _statusWidthModern, child: Text(l10n.invoiceMgmtColStatus, style: style)),
        SizedBox(width: _actionsWidthModern, child: Text(l10n.invoiceMgmtColActions, style: style)),
      ]),
    );
  }

  Widget _statusPillModern(Product p) {
    final l10n = AppLocalizations.of(context)!;
    final (String text, Color color) = p.unlimitedStock || p.stock > 10
        ? (l10n.mProdInStock, const Color(0xFF16A34A))
        : p.stock > 0
            ? (l10n.productMgmtLowStockTabLabel, const Color(0xFFEA580C))
            : (l10n.productMgmtOutOfStockTabLabel, const Color(0xFFDC2626));
    // The right padding keeps a gap before the next column.
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          // A long word (Tamil) shrinks to fit instead of being cut.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(text,
                maxLines: 1,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
          ),
        ),
      ),
    );
  }

  Widget _rowButtonModern(String key, IconData icon, String tooltip, VoidCallback onTap,
      {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? Theme.of(context).primaryColor;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          key: ValueKey(key),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onTap: onTap,
          child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, size: 19, color: color == null ? c : scheme.error)),
        ),
      ),
    );
  }

  Widget _rowModern(Product p, int index) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    final serial = _currentPage * _pageSize + index + 1;
    final selected = _selectedModern.contains(p.id);
    final alias = p.aliasName?.trim() ?? '';
    final (before, after) = _visibleColsModern();
    Widget cell(int flex, Widget child) => Expanded(
        flex: flex, child: Padding(padding: const EdgeInsets.only(right: 12), child: child));
    return Container(
      key: ValueKey('prodRow_${p.id}'),
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
      decoration: BoxDecoration(
        color: selected ? primary.withValues(alpha: 0.06) : null,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(children: [
        SizedBox(
          width: 44,
          child: Checkbox(
            value: selected,
            onChanged: (_) => setState(() {
              if (!_selectedModern.remove(p.id)) _selectedModern.add(p.id);
            }),
          ),
        ),
        SizedBox(
            width: 40,
            child: Text('$serial', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))),
        cell(
          3,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (alias.isNotEmpty && _colOnModern('aliasName'))
                Text('($alias)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        for (final k in before) cell(_colFlexModern(k), _optionalCellModern(p, k)),
        cell(
          2,
          Text(AppFormatters.formatAmount(p.price, _currencySymbol),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: primary)),
        ),
        for (final k in after) ...[
          cell(_colFlexModern(k), _optionalCellModern(p, k)),
          if (k == 'stock' && _statusColModern)
            SizedBox(width: _statusWidthModern, child: _statusPillModern(p)),
        ],
        if (_statusColModern && !after.contains('stock'))
          SizedBox(width: _statusWidthModern, child: _statusPillModern(p)),
        SizedBox(
          width: _actionsWidthModern,
          child: Row(children: [
            _rowButtonModern('prodView_${p.id}', Icons.visibility_outlined, l10n.actionView,
                () => _viewProductV2(p)),
            const SizedBox(width: 6),
            _rowButtonModern('prodEdit_${p.id}', Icons.edit_outlined, l10n.actionEdit,
                () => _editProductV2(p)),
            const SizedBox(width: 6),
            _rowButtonModern('prodDuplicate_${p.id}', Icons.copy_all_outlined,
                l10n.actionDuplicate, () => _duplicateModern(p)),
            if (widget.user.isAdmin()) ...[
              const SizedBox(width: 6),
              _rowButtonModern('prodDelete_${p.id}', Icons.delete_outline, l10n.actionDelete,
                  () => _deleteProductV2(p),
                  color: scheme.error),
            ],
          ]),
        ),
      ]),
    );
  }

  /// A copy of [p] (name "… (copy)", no stock), then its edit dialog.
  Future<void> _duplicateModern(Product p) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(productRepositoryProvider);
    final copy = Product(
      id: const Uuid().v4(),
      name: l10n.mProdCopyName(p.name),
      description: p.description,
      price: p.price,
      stock: 0,
      hsncode: p.hsncode,
      tax_rate: p.tax_rate,
      type: p.type,
      defaultDiscount: p.defaultDiscount,
      purchasePrice: p.purchasePrice,
      aliasName: p.aliasName,
      unit: p.unit,
      unlimitedStock: p.unlimitedStock,
      priceIncludesTax: p.priceIncludesTax,
    );
    try {
      await repo.insertProduct(copy);
      final meta = await repo.getProductMetadata(p.id);
      if (meta != null) {
        await repo.upsertProductMetadata(meta.copy()..productId = copy.id);
      }
      await _loadStatsV2();
      if (!mounted) return;
      _showSnackBar(l10n.mProdDuplicated);
      await _showDetailDialogV2(copy, startInEdit: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(l10n.productMgmtAddErrorMessage(e.toString()), isError: true);
    }
  }

  Widget _footerModern() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    final total = _totalProducts;
    final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();
    var first = (_currentPage - 2).clamp(0, (totalPages - 5).clamp(0, totalPages));
    final last = (first + 4).clamp(0, totalPages - 1);
    first = first.clamp(0, last);
    Widget pageButton(int p) {
      final on = p == _currentPage;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: on ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            key: ValueKey('prodPage_${p + 1}'),
            borderRadius: BorderRadius.circular(9),
            onTap: on ? null : () => _changePageV2(p),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Text('${p + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: on ? Colors.white : scheme.onSurface)),
              ),
            ),
          ),
        ),
      );
    }

    final from = total == 0 ? 0 : _currentPage * _pageSize + 1;
    final to = (_currentPage * _pageSize + _pageSize).clamp(0, total);
    final left = Text(
      _isServicesModern
          ? l10n.mSvcShowingRange(from, to, total)
          : l10n.productMgmtShowingRangeLabel(from, to, total),
      style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
    );
    final right = Row(mainAxisSize: MainAxisSize.min, children: [
      Text(l10n.customerMgmtRowsPerPageLabel,
          style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
      const SizedBox(width: 10),
      Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            key: const ValueKey('prodRowsPerPage'),
            value: _pageSize,
            items: [10, 25, 50, 100]
                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                .toList(),
            onChanged: (n) {
              if (n == null || !mounted) return;
              setState(() {
                _pageSize = n;
                _currentPage = 0;
              });
              _loadProducts();
            },
          ),
        ),
      ),
      const SizedBox(width: 18),
      IconButton(
        key: const ValueKey('prodPagePrev'),
        onPressed: _currentPage > 0 ? () => _changePageV2(_currentPage - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      for (var p = first; p <= last; p++) pageButton(p),
      IconButton(
        key: const ValueKey('prodPageNext'),
        onPressed: _currentPage < totalPages - 1 ? () => _changePageV2(_currentPage + 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ]);
    return Container(
      key: const ValueKey('modernProductFooter'),
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 720) return Row(children: [Expanded(child: left), right]);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          left,
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: right),
        ]);
      }),
    );
  }

  Widget _tableModern(double width) {
    final scheme = Theme.of(context).colorScheme;
    // A narrow window: the columns keep their room and scroll sideways. The
    // room grows with the columns shown (about 48px per flex share), so the
    // default columns fit a 1366px laptop without scrolling.
    final (before, after) = _visibleColsModern();
    final flex = 5 + [...before, ...after].fold<int>(0, (s, k) => s + _colFlexModern(k));
    final fixed = 20.0 + 44 + 40 + _actionsWidthModern +
        (_statusColModern ? _statusWidthModern : 0);
    final minTableWidth = math.max(980.0, fixed + flex * 48);
    final placeholder = (_statsLoadingV2 || _isLoading) && _products.isEmpty
        ? const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
        : (_products.isEmpty ? SizedBox(height: 240, child: _buildEmptyState()) : null);
    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tableHeaderModern(),
        if (placeholder == null)
          for (var i = 0; i < _products.length; i++) _rowModern(_products[i], i),
      ],
    );
    return Container(
      key: const ValueKey('modernProductTable'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (width >= minTableWidth)
          rows
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minTableWidth, child: rows),
          ),
        // The empty message / spinner at the visible width (not off-screen
        // in the middle of the wide scrolled table).
        if (placeholder != null) placeholder,
        _footerModern(),
      ]),
    );
  }

  // ── Selection ────────────────────────────────────────────────────────────

  Future<void> _deleteSelectedModern() async {
    final l10n = AppLocalizations.of(context)!;
    final ids = _selectedModern.toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mProdDeleteSelectedTitle(ids.length)),
        content: Text(l10n.mProdDeleteSelectedBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.actionCancel)),
          FilledButton(
            key: const ValueKey('prodDeleteSelectedOk'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final repo = ref.read(productRepositoryProvider);
    for (final id in ids) {
      await repo.deleteProduct(id);
    }
    if (!mounted) return;
    setState(_selectedModern.clear);
    await _loadStatsV2();
    if (mounted) _showSnackBar(l10n.mProdDeletedCount(ids.length));
  }

  Widget _selectionBarModern() {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).primaryColor;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('modernProductSelection'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.check_circle, size: 18, color: primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(l10n.invoiceMgmtSelectedCountLabel(_selectedModern.length),
              style: TextStyle(fontWeight: FontWeight.w700, color: primary)),
        ),
        if (widget.user.isAdmin())
          TextButton.icon(
            key: const ValueKey('prodDeleteSelected'),
            onPressed: _deleteSelectedModern,
            icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
            label: Text(l10n.userMgmtDeleteSelectedMenuLabel, style: TextStyle(color: scheme.error)),
          ),
        TextButton(
          onPressed: () => setState(_selectedModern.clear),
          child: Text(l10n.actionClear),
        ),
      ]),
    );
  }

  // ── Page ─────────────────────────────────────────────────────────────────

  Widget _buildModern(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inTopBar = hasModernTopBar;
    return Scaffold(
      backgroundColor: isDark ? null : BrandColors.page,
      body: LayoutBuilder(builder: (context, constraints) {
        final pad = constraints.maxWidth >= 700 ? 24.0 : 14.0;
        final inner = constraints.maxWidth - pad * 2;
        if (inTopBar) {
          final compact = constraints.maxWidth < 900;
          publishModernHeader((page) {
            final l10n = AppLocalizations.of(context)!;
            return ModernPageHeader(
              page: page,
              title: _isServicesModern ? l10n.mSvcTitle : l10n.productMgmtTitle,
              subtitle: _isServicesModern ? l10n.mSvcSubtitle : l10n.mProdSubtitle,
              actions: _headerActionsModern(compact),
              createButton: _newButtonModern(),
            );
          });
        }
        final panelWidth = constraints.maxWidth < 750
            ? constraints.maxWidth - 32
            : (constraints.maxWidth * 0.42).clamp(520.0, 680.0);
        return Stack(children: [
          SingleChildScrollView(
            key: const ValueKey('modernProductScroll'),
            padding: EdgeInsets.fromLTRB(pad, 20, pad, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!inTopBar) ...[_headerBarV2(), const SizedBox(height: 16)],
                if (_showStatsCardsV2) ...[
                  _statCardsModern(),
                  const SizedBox(height: 16),
                ],
                _filterCardModern(inner >= 900),
                if (_selectedModern.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _selectionBarModern(),
                ],
                const SizedBox(height: 16),
                _tableModern(inner),
              ],
            ),
          ),
          if (_showAddPanelV2) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showAddPanelV2 = false),
                child: Container(color: Colors.black.withValues(alpha: 0.3)),
              ),
            ),
            Positioned(top: 16, right: 16, bottom: 16, width: panelWidth, child: _addPanelV2()),
          ],
        ]);
      }),
    );
  }

  Widget _buildUnitField({
    required String selectedUnit,
    required TextEditingController customController,
    required ValueChanged<String> onUnitChanged,
    bool readOnly = false,
  }) {
    return _UnitField(
      initialUnit: selectedUnit,
      customController: customController,
      onUnitChanged: onUnitChanged,
      readOnly: readOnly,
    );
  }

  Widget _buildFormField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    bool required = true,
    bool isPrice = false,
    bool isStock = false,
    bool isTaxRate = false,
    String? prefixText,
    String? helperText,
    bool enabled = true,
    VoidCallback? onSubmitted,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      onFieldSubmitted: (value) {
        if (onSubmitted != null) {
          onSubmitted();
        } else {
          FocusScope.of(context).nextFocus();
        }
      },
      inputFormatters: isPrice
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))]
          : isStock
              // Stock can be a decimal (12.5 kg).
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : isTaxRate
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixText == null ? Icon(icon) : null,
        prefixText: prefixText,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        counterText: '',
        helper: helperText != null ? Tooltip(
          message: helperText,
          textStyle: TextStyle(fontSize: 15),
          decoration: BoxDecoration(
            color: Colors.grey.shade900, // Background color
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(10),
          child: InkWell(
            onTap: null,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.info_outline, size: 18, color: BrandColors.accent),
            ),
          ),
        ) : null
      ),
      validator: (value) {
        if (!required) return null;
        if (value == null || value.trim().isEmpty) {
          return l10n.fieldRequiredMessage(label);
        }
        if (isPrice) {
          final price = double.tryParse(value);
          if (price == null || price < 0) return l10n.fieldEnterValidPriceMessage;
        }
        if (isStock) {
          // A decimal is fine: 12.5 kg.
          final stock = double.tryParse(value.trim());
          if (stock == null || !stock.isFinite || stock < 0) {
            return l10n.fieldEnterValidStockMessage;
          }
        }
        if (isTaxRate) {
          final tax = int.tryParse(value);
          if (tax == null || tax < 0 || tax > 100) {
            return l10n.fieldTaxRangeMessage;
          }
        }
        return null;
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 80, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            widget.modern && widget.kind == 'service'
                ? AppLocalizations.of(context)!.mSvcNoServicesFound
                : AppLocalizations.of(context)!.createInvoiceNoProductsFoundMessage,
            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            widget.modern && _mTab != 'all'
                ? AppLocalizations.of(context)!.invoiceMgmtTryAdjustingFiltersMessage
                : _searchQuery.isNotEmpty
                ? AppLocalizations.of(context)!.customerMgmtTryAdjustingSearchSubtitle
                : (widget.modern && widget.kind == 'service'
                    ? AppLocalizations.of(context)!.mSvcAddFirstService
                    : AppLocalizations.of(context)!.productMgmtAddFirstProductSubtitle),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

/// Unit dropdown + "Custom…" text field. Whether the custom field is shown
/// is tracked as sticky local state (set the moment "Custom…" is picked) —
/// NOT re-derived from the current unit string each rebuild, since that
/// string is still empty right after picking "Custom…" and would otherwise
/// make the field disappear before the user can type anything into it.
class _UnitField extends StatefulWidget {
  final String initialUnit;
  final TextEditingController customController;
  final ValueChanged<String> onUnitChanged;
  final bool readOnly;

  const _UnitField({
    required this.initialUnit,
    required this.customController,
    required this.onUnitChanged,
    this.readOnly = false,
  });

  @override
  State<_UnitField> createState() => _UnitFieldState();
}

class _UnitFieldState extends State<_UnitField> {
  late bool _isCustom;
  late String _presetValue;

  @override
  void initState() {
    super.initState();
    _isCustom = widget.initialUnit.isNotEmpty &&
        !ProductUnits.presets.contains(widget.initialUnit);
    _presetValue = _isCustom ? '' : widget.initialUnit;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _isCustom ? 'custom' : _presetValue,
          decoration: InputDecoration(
            labelText: l10n.fieldUnitLabel,
            prefixIcon: const Icon(Icons.straighten),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
            filled: widget.readOnly,
            fillColor: widget.readOnly ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
          ),
          items: [
            DropdownMenuItem(value: '', child: Text(l10n.commonNoneLabel)),
            for (final u in ProductUnits.presets)
              DropdownMenuItem(value: u, child: Text(u.toUpperCase())),
            DropdownMenuItem(value: 'custom', child: Text(l10n.commonCustomEllipsisLabel)),
          ],
          onChanged: widget.readOnly
              ? null
              : (val) {
                  if (val == null) return;
                  setState(() {
                    _isCustom = val == 'custom';
                    _presetValue = _isCustom ? '' : val;
                  });
                  widget.onUnitChanged(
                      _isCustom ? widget.customController.text.trim() : val);
                },
        ),
        if (_isCustom) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.customController,
            readOnly: widget.readOnly,
            decoration: InputDecoration(
              labelText: l10n.fieldCustomUnitLabel,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
              filled: widget.readOnly,
              fillColor: widget.readOnly ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
            ),
            onChanged: widget.onUnitChanged,
          ),
        ],
      ],
    );
  }
}
