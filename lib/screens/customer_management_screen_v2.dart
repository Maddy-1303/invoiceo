import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoiceo/providers/repositories.dart';
import 'package:invoiceo/utils/formatters.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/common/supported_currencies.dart';
import 'package:flutter/material.dart';
import 'package:invoiceo/theme/brand_colors.dart';
import 'package:flutter/services.dart';
import 'package:invoiceo/common/constants.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/customer_list_stats.dart';
import 'package:invoiceo/models/company_info.dart';
import 'package:invoiceo/models/user.dart';
import 'package:invoiceo/widgets/apply_customer_payment_dialog.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/widgets/customer_info_button.dart';
import 'package:invoiceo/widgets/fit_text.dart';
import 'package:uuid/uuid.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';

import 'package:invoiceo/common/app_config.dart';
import 'package:invoiceo/services/pdf/pdf_font_service.dart';
class CustomerManagementScreenV2 extends ConsumerStatefulWidget {
  final User user;
  final void Function(Customer customer)? onViewCustomerStatement;

  /// Opens the "new customer" form as soon as the page shows (Modern
  /// dashboard's "Add Customer").
  final bool startWithAddPanel;

  /// The Modern layout's page design (see _buildModern).
  final bool modern;
  const CustomerManagementScreenV2(
      {super.key,
      required this.user,
      this.onViewCustomerStatement,
      this.startWithAddPanel = false,
      this.modern = false});

  @override
  ConsumerState<CustomerManagementScreenV2> createState() =>
      _CustomerManagementScreenV2State();
}

class _CustomerManagementScreenV2State extends ConsumerState<CustomerManagementScreenV2>
    with ModernHeaderPublisher {
  // Only the visible page is held in memory (Issues.md #43) — see _loadPageV2.
  List<Customer> _pageCustomers = [];
  int _filteredTotal = 0;
  int _pageRequestId = 0;
  CustomerListStats _statsV2 =
      (all: 0, businesses: 0, individuals: 0, taxRegistered: 0);
  int _withOutstandingCount = 0;
  String _searchQuery = '';
  Timer? _searchDebounce;
  String _sortBy = 'name';
  bool _isAscending = true;
  int _pageSize = 10;
  int _currentPage = 0;
  bool _isLoading = false;
  String? _companyCountry;
  String get _taxWord => isIndiaCountry(_companyCountry)
      ? AppLocalizations.of(context)!.taxWordGst
      : AppLocalizations.of(context)!.taxWordTax;
  Map<String, double> _outstandingByCustomer = {};
  String _outstandingCurrencySymbol = '';
  List<String> _outstandingCurrencies = [];
  String? _selectedOutstandingCurrency;
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _horizontalScrollController = ScrollController();

  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstinController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── V2 state ──────────────────────────────────────────────────────────
  int _activeTabV2 = 0; // 0 all, 1 businesses, 2 individuals, 3 gst reg, 4 without gst
  bool _showAddPanelV2 = false;
  bool _addAnotherAfterSavingV2 = false;
  bool _showStatsCardsV2 = true;
  final Map<String, bool> _visibleColumnsV2 = {
    'phone': true,
    'email': true,
    'gstin': true,
    'address': true,
    'outstanding': true,
  };

  @override
  void initState() {
    super.initState();
    if (widget.startWithAddPanel) _showAddPanelV2 = true;
    _loadCustomers();
    _loadStatsCardsVisibilityV2();
    if (widget.modern) _loadHiddenColsModern();
  }

  Future<void> _loadStatsCardsVisibilityV2() async {
    final v = await ref
        .read(settingsRepositoryProvider)
        .getSetting(SettingKey.showCustomerStatsCards);
    if (!mounted) return;
    setState(() => _showStatsCardsV2 = v != 'false');
  }

  Future<void> _toggleStatsCardsV2() async {
    final next = !_showStatsCardsV2;
    setState(() => _showStatsCardsV2 = next);
    await ref
        .read(settingsRepositoryProvider)
        .setSetting(SettingKey.showCustomerStatsCards, next.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    _businessNameController.dispose();
    _searchFocusNode.dispose();
    _horizontalScrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    if(!mounted) return;
    setState(() => _isLoading = true);
    try {
      if(!mounted) return;
      final customerRepo = ref.read(customerRepositoryProvider);
      final companyRepo = ref.read(companyInfoRepositoryProvider);
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final reportRepo = ref.read(reportRepositoryProvider);
      final results = await Future.wait([
        customerRepo.getCustomerListStats(),
        companyRepo.getCompanyInfo(),
        settingsRepo.getCurrency(),
        reportRepo.getInvoiceCurrencies(),
      ]);
      final stats = results[0] as CustomerListStats;
      final company = results[1] as CompanyInfo?;
      final defaultCurrency = results[2] as CurrencyOption;
      final currencies = results[3] as List<String>;

      // Keep the user's chosen currency across a refresh; otherwise default
      // to the shop's currency if it has invoices, else the first one that does.
      final prevSelected = _selectedOutstandingCurrency;
      final String selected = prevSelected != null && currencies.contains(prevSelected)
          ? prevSelected
          : (currencies.contains(defaultCurrency.code)
              ? defaultCurrency.code
              : (currencies.isNotEmpty ? currencies.first : defaultCurrency.code));
      final outstanding = await reportRepo.getOutstandingByCustomer(currencyCode: selected);
      final withOutstanding = await _countWithOutstanding(outstanding);

      if(!mounted) return;
      setState(() {
        _statsV2 = stats;
        _withOutstandingCount = withOutstanding;
        _companyCountry = company?.country;
        _outstandingCurrencies = currencies;
        _selectedOutstandingCurrency = selected;
        _outstandingByCustomer = outstanding;
        _outstandingCurrencySymbol = SupportedCurrencies.fromCode(selected).symbol;
      });
      // The page is kept (after an edit, delete or payment); _loadPageV2
      // moves back to the last page when this one no longer exists.
      await _loadPageV2();
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(AppLocalizations.of(context)!.customerMgmtLoadErrorMessage(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onOutstandingCurrencyChangedV2(String code) async {
    if (!mounted || code == _selectedOutstandingCurrency) return;
    setState(() => _selectedOutstandingCurrency = code);
    final outstanding =
        await ref.read(reportRepositoryProvider).getOutstandingByCustomer(currencyCode: code);
    final withOutstanding = await _countWithOutstanding(outstanding);
    if (!mounted) return;
    setState(() {
      _outstandingByCustomer = outstanding;
      _withOutstandingCount = withOutstanding;
      _outstandingCurrencySymbol = SupportedCurrencies.fromCode(code).symbol;
      _currentPage = 0;
    });
    await _loadPageV2();
  }

  // Saved customers whose outstanding (built from invoices — Issues.md #41)
  // is non-zero. Loads ids only, not customer rows.
  Future<int> _countWithOutstanding(Map<String, double> outstanding) async {
    if (outstanding.isEmpty) return 0;
    final ids = await ref.read(customerRepositoryProvider).getCustomerListIds();
    return ids.where((id) => (outstanding[id] ?? 0) > 0.005).length;
  }

  // _activeTabV2 index → CustomerService list tab key (5 = with outstanding,
  // filtered in Dart on top of 'all').
  String get _tabKeyV2 =>
      const ['all', 'business', 'individual', 'tax', 'no_tax', 'all'][_activeTabV2];

  bool get _needsOutstandingOrderV2 =>
      _activeTabV2 == 5 || _sortBy == 'outstanding';

  // Every matching customer id in list order (ids only). Outstanding tab and
  // sort are applied here from _outstandingByCustomer until invoice totals
  // are stored (Issues.md #41).
  Future<List<String>> _orderedIdsV2() async {
    var ids = await ref.read(customerRepositoryProvider).getCustomerListIds(
        query: _searchQuery,
        tab: _tabKeyV2,
        orderBy: _sortBy,
        ascending: _isAscending);
    if (_activeTabV2 == 5) {
      ids = ids.where((id) => (_outstandingByCustomer[id] ?? 0) > 0.005).toList();
    }
    if (_sortBy == 'outstanding') {
      final pos = {for (var i = 0; i < ids.length; i++) ids[i]: i};
      ids.sort((a, b) {
        final r = (_outstandingByCustomer[a] ?? 0)
            .compareTo(_outstandingByCustomer[b] ?? 0);
        if (r != 0) return _isAscending ? r : -r;
        return pos[a]!.compareTo(pos[b]!); // stable
      });
    }
    return ids;
  }

  // Loads only the visible page (Issues.md #43): search, tab and name/id
  // sort in SQL; outstanding tab/sort via _orderedIdsV2, then just this
  // page's customers are fetched.
  Future<void> _loadPageV2() async {
    final requestId = ++_pageRequestId;
    final repo = ref.read(customerRepositoryProvider);
    try {
      Future<(List<Customer>, int)> load() async {
        if (_needsOutstandingOrderV2) {
          final ids = await _orderedIdsV2();
          final pageIds =
              ids.skip(_currentPage * _pageSize).take(_pageSize).toList();
          return (await repo.getCustomersByIds(pageIds), ids.length);
        }
        final results = await Future.wait([
          repo.getCustomerListPage(
              offset: _currentPage * _pageSize,
              limit: _pageSize,
              query: _searchQuery,
              tab: _tabKeyV2,
              orderBy: _sortBy,
              ascending: _isAscending),
          repo.getCustomerListCount(query: _searchQuery, tab: _tabKeyV2),
        ]);
        return (results[0] as List<Customer>, results[1] as int);
      }

      var (page, total) = await load();
      // Current page fell off the end (e.g. last row on the last page deleted).
      final maxPage = total == 0 ? 0 : (total - 1) ~/ _pageSize;
      if (_currentPage > maxPage) {
        _currentPage = maxPage;
        (page, total) = await load();
      }
      if (requestId != _pageRequestId || !mounted) return;
      setState(() {
        _pageCustomers = page;
        _filteredTotal = total;
        // Modern: only rows on the shown page stay ticked.
        final ids = page.map((c) => c.id).toSet();
        _selectedModern.removeWhere((id) => !ids.contains(id));
      });
    } catch (e) {
      if (requestId != _pageRequestId || !mounted) return;
      _showSnackBar(AppLocalizations.of(context)!.customerMgmtLoadErrorMessage(e.toString()), isError: true);
    }
  }

  void _changePage(int page) {
    if(!mounted) return;
    setState(() => _currentPage = page);
    _loadPageV2();
  }

  Future<void> _handleAddOrUpdateCustomer([Customer? customer]) async {
    if (!_formKey.currentState!.validate() || !mounted) return;
    final l10n = AppLocalizations.of(context)!;

    // One phone number, one customer (as on the New Invoice screen).
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      final owner = await ref.read(customerRepositoryProvider).findByPhone(phone);
      if (!mounted) return;
      if (owner != null && owner.id != customer?.id) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.createInvoicePhoneAlreadyInUseTitle),
            content: Text(l10n.createInvoicePhoneAlreadyInUseMessage(owner.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.actionClose),
              ),
            ],
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final newCustomer = Customer(
        id: customer?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        gstin: _gstinController.text.trim(),
        businessName: _businessNameController.text.trim(),
      );

      if (customer == null) {
        await ref.read(customerRepositoryProvider).insertCustomer(newCustomer);
        _showSnackBar(l10n.customerMgmtAddedMessage);
      } else {
        await ref.read(customerRepositoryProvider).updateCustomer(newCustomer);
        _showSnackBar(l10n.customerMgmtUpdatedMessage);
      }

      _clearForm();
      await _loadCustomers();
    } catch (e) {
      _showSnackBar(l10n.customerMgmtSaveErrorMessage(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _gstinController.clear();
    _businessNameController.clear();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showCustomerDialog(Customer customer, bool isEdit) async {
    //final isEdit = customer != null;
    final nameCtrl = TextEditingController(text: customer.name);
    final emailCtrl = TextEditingController(text: customer.email);
    final phoneCtrl = TextEditingController(text: customer.phone);
    final addressCtrl = TextEditingController(text: customer.address);
    final gstinCtrl = TextEditingController(text: customer.gstin);
    final businessNameCtrl = TextEditingController(text: customer.businessName);
    final dialogFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isEdit ? Icons.edit : Icons.visibility,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Text(isEdit
                ? AppLocalizations.of(context)!.customerMgmtEditCustomerTitle
                : AppLocalizations.of(context)!.customerMgmtViewCustomerTitle),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.4,
          child: Form(
            key: dialogFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTextField(nameCtrl, AppLocalizations.of(context)!.fieldNameLabel, Icons.person,
                      readOnly: !isEdit),
                  const SizedBox(height: 16),
                  _buildDialogTextField(businessNameCtrl, AppLocalizations.of(context)!.fieldBusinessNameLabel, Icons.business_center,
                      readOnly: !isEdit, maxLength: 100),
                  const SizedBox(height: 16),
                  _buildDialogTextField(emailCtrl, AppLocalizations.of(context)!.fieldEmailLabel, Icons.email,
                      readOnly: !isEdit, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildDialogTextField(phoneCtrl, AppLocalizations.of(context)!.fieldPhoneLabel, Icons.phone,
                      readOnly: !isEdit,
                      keyboardType: TextInputType.phone,
                      maxLength: 12),
                  const SizedBox(height: 16),
                  _buildDialogTextField(gstinCtrl, AppLocalizations.of(context)!.fieldTaxVatNumberLabel(_taxWord), Icons.receipt_long,
                      readOnly: !isEdit, maxLength: 50),
                  const SizedBox(height: 16),
                  _buildDialogTextField(addressCtrl, AppLocalizations.of(context)!.fieldAddressLabel, Icons.location_on,
                      readOnly: !isEdit, maxLines: 3, maxLength: 100),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.actionClose),
          ),
          if (isEdit)
            FilledButton.icon(
              onPressed: isSaving ? null : () async {
                if (!dialogFormKey.currentState!.validate()) return;
                final l10n = AppLocalizations.of(context)!;
                setDialogState(() => isSaving = true);
                try {
                  final updatedCustomer = Customer(
                    id: customer.id,
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    gstin: gstinCtrl.text.trim(),
                    businessName: businessNameCtrl.text.trim(),
                  );

                  await ref.read(customerRepositoryProvider).updateCustomer(updatedCustomer);
                  await _loadCustomers();
                  if (context.mounted) Navigator.pop(context);
                  _showSnackBar(l10n.customerMgmtUpdatedMessage);
                } finally {
                  setDialogState(() => isSaving = false);
                }
              },
              icon: isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(isSaving
                  ? AppLocalizations.of(context)!.createInvoiceSavingEllipsisLabel
                  : AppLocalizations.of(context)!.actionUpdate),
            ),
        ],
        );
        });
      },
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
      }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        filled: readOnly,
        fillColor: readOnly ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
      ),
      validator: (value) {
        if (label == AppLocalizations.of(context)!.fieldNameLabel &&
            (value == null || value.trim().isEmpty)) {
          return AppLocalizations.of(context)!.fieldRequiredMessage(label);
        }
        return null;
      },
    );
  }

  Future<void> _confirmDelete(Customer customer) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.customerMgmtConfirmDeleteTitle),
          ],
        ),
        content: Text(AppLocalizations.of(context)!.customerMgmtDeleteConfirmBody(customer.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.actionDelete),
          ),
        ],
      ),
    );

    if (result == true) {
      await ref.read(customerRepositoryProvider).deleteCustomer(customer.id);
      await _loadCustomers();
      _showSnackBar(l10n.customerMgmtDeletedMessage);
    }
  }

  Future<void> _downloadSampleCSV() async {
    const sample = '"name","email","phone","address","business_name","tax_number"\n'
        '"John Smith","john@example.com","+27821234567","123 Main St, Cape Town","Acme (Pty) Ltd","ZA123456789"\n'
        '"Jane Doe","jane@example.com","+27831234567","456 Oak Ave, Johannesburg","",""\n';
    final l10n = AppLocalizations.of(context)!;

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: l10n.customerMgmtSaveSampleCsvDialogTitle,
      fileName: 'customers_sample.csv',
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

  static const _csvMaxRows = 200;
  static const _csvHeaders = ['name', 'email', 'phone', 'address', 'business_name', 'tax_number'];

  Future<void> _showImportDialog() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.upload_file, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context)!.customerMgmtImportCsvDialogTitle),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.45,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.customerMgmtCsvFormatInstructionMessage,
                ),
                const SizedBox(height: 12),
                // Columns table
                Table(
                  border: TableBorder.all(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(6)),
                  columnWidths: const {
                    0: FlexColumnWidth(1.4),
                    1: FlexColumnWidth(0.7),
                    2: FlexColumnWidth(2),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                      children: [
                        _TableHeader(AppLocalizations.of(context)!.customerMgmtCsvColColumnHeader),
                        _TableHeader(AppLocalizations.of(context)!.customerMgmtCsvColRequiredHeader),
                        _TableHeader(AppLocalizations.of(context)!.customerMgmtCsvColDescriptionHeader),
                      ],
                    ),
                    _csvRuleRow(context, 'name',          AppLocalizations.of(context)!.commonYesLabel, AppLocalizations.of(context)!.customerMgmtCsvDescName, required: true),
                    _csvRuleRow(context, 'email',         AppLocalizations.of(context)!.commonNoLabel,  AppLocalizations.of(context)!.customerMgmtCsvDescEmail),
                    _csvRuleRow(context, 'phone',         AppLocalizations.of(context)!.commonNoLabel,  AppLocalizations.of(context)!.customerMgmtCsvDescPhone),
                    _csvRuleRow(context, 'address',       AppLocalizations.of(context)!.commonNoLabel,  AppLocalizations.of(context)!.customerMgmtCsvDescAddress),
                    _csvRuleRow(context, 'business_name', AppLocalizations.of(context)!.commonNoLabel,  AppLocalizations.of(context)!.customerMgmtCsvDescBusinessName),
                    _csvRuleRow(context, 'tax_number',    AppLocalizations.of(context)!.commonNoLabel,  AppLocalizations.of(context)!.customerMgmtCsvDescTaxNumber),
                  ],
                ),
                const SizedBox(height: 16),
                // Notes
                _ruleNote(context, Icons.info_outline, AppLocalizations.of(context)!.customerMgmtCsvMaxRowsNote(_csvMaxRows)),
                _ruleNote(context, Icons.info_outline, AppLocalizations.of(context)!.customerMgmtCsvDuplicatesNote),
                _ruleNote(context, Icons.info_outline, AppLocalizations.of(context)!.customerMgmtCsvMissingNameNote),
                _ruleNote(context, Icons.info_outline, AppLocalizations.of(context)!.customerMgmtCsvEncodingNote),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx, false);
                    await _downloadSampleCSV();
                  },
                  icon: const Icon(Icons.download),
                  label: Text(AppLocalizations.of(context)!.customerMgmtDownloadSampleCsvButton),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.actionCancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.folder_open),
            label: Text(AppLocalizations.of(context)!.customerMgmtChooseFileButton),
          ),
        ],
      ),
    );
    if (proceed == true) await _importFromCSV();
  }

  static TableRow _csvRuleRow(BuildContext context, String col, String req, String desc, {bool required = false}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(col, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            req,
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
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface))),
        ],
      ),
    );
  }

  Future<void> _importFromCSV() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      dialogTitle: l10n.customerMgmtSelectCsvDialogTitle,
    );
    if (result == null || result.files.single.path == null || !mounted) return;

    setState(() => _isLoading = true);

    var progressDialogShown = false;
    try {
      final bytes = await File(result.files.single.path!).readAsBytes();
      // Strip UTF-8 BOM if present
      final content = utf8.decode(
        bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF
            ? bytes.sublist(3)
            : bytes,
      );

      // Windows line ends (\r\n) become \n so rows never merge, and every cell
      // stays text so phone numbers keep a leading 0 or '+'.
      final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(content.replaceAll('\r\n', '\n'));
      if (rows.isEmpty) {
        _showSnackBar(l10n.customerMgmtCsvEmptyMessage, isError: true);
        if(!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      // Parse and validate headers
      final headers = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
      if (!headers.contains('name')) {
        _showSnackBar(l10n.customerMgmtCsvMissingNameColumnMessage, isError: true);
        if(!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      for (final col in headers) {
        if (!_csvHeaders.contains(col)) {
          _showSnackBar(l10n.customerMgmtUnknownColumnMessage(col, _csvHeaders.join(', ')), isError: true);
          if(!mounted) return;
          setState(() => _isLoading = false);
          return;
        }
      }

      final dataRows = rows.skip(1).toList();

      // Hard limit
      if (dataRows.length > _csvMaxRows) {
        _showSnackBar(l10n.customerMgmtCsvTooManyRowsMessage(dataRows.length, _csvMaxRows), isError: true);
        if(!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      String getField(List<dynamic> row, String col) {
        final i = headers.indexOf(col);
        return i < 0 || i >= row.length ? '' : stripCsvFormulaGuard(row[i].toString().trim());
      }

      // Categorise rows
      final List<Customer> valid = [];
      final List<Customer> duplicates = [];
      final List<String> errors = [];

      final progress = ValueNotifier<int>(0);
      if (!mounted) return;
      progressDialogShown = true;
      unawaited(showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(l10n.customerMgmtImportingTitle),
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
        if (name.isEmpty) {
          errors.add(l10n.customerMgmtRowMissingNameMessage(i + 2));
          continue;
        }
        final email = getField(row, 'email');
        final phone = getField(row, 'phone');
        final existing = await ref.read(customerRepositoryProvider).findDuplicate(email, phone);
        final customer = Customer(
          id: existing?.id ?? const Uuid().v4(),
          name: name,
          email: email,
          phone: phone,
          address: getField(row, 'address'),
          gstin: getField(row, 'tax_number'),
          businessName: getField(row, 'business_name'),
        );
        if (existing != null) {
          duplicates.add(customer);
        } else {
          valid.add(customer);
        }
      }
      if (progressDialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if(!mounted) return;
      setState(() => _isLoading = false);

      if (!mounted) return;
      await _showImportPreviewDialog(valid, duplicates, errors);
    } catch (e) {
      if (progressDialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if(!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(l10n.customerMgmtCsvReadErrorMessage(e.toString()), isError: true);
    }
  }

  Future<void> _showImportPreviewDialog(
    List<Customer> newCustomers,
    List<Customer> duplicates,
    List<String> errors,
  ) async {
    // Per-row overwrite flags: true = overwrite, false = skip
    final overwriteFlags = List<bool>.filled(duplicates.length, false);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final total = newCustomers.length + overwriteFlags.where((f) => f).length;

          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.customerMgmtImportPreviewTitle),
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
                          label: Text(AppLocalizations.of(context)!.customerMgmtNewCountChip(newCustomers.length)),
                          backgroundColor: Colors.green.shade100,
                          avatar: const Icon(Icons.person_add, size: 16),
                        ),
                        Chip(
                          label: Text(AppLocalizations.of(context)!.customerMgmtDuplicatesCountChip(duplicates.length)),
                          backgroundColor: Colors.orange.shade100,
                          avatar: const Icon(Icons.warning_amber, size: 16),
                        ),
                        if (errors.isNotEmpty)
                          Chip(
                            label: Text(AppLocalizations.of(context)!.customerMgmtErrorsCountChip(errors.length)),
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
                            child: Text(AppLocalizations.of(context)!.customerMgmtDuplicatesMatchedLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          TextButton(
                            onPressed: () => setDialogState(() {
                              for (int i = 0; i < overwriteFlags.length; i++) { overwriteFlags[i] = true; }
                            }),
                            child: Text(AppLocalizations.of(context)!.customerMgmtOverwriteAllButton),
                          ),
                          TextButton(
                            onPressed: () => setDialogState(() {
                              for (int i = 0; i < overwriteFlags.length; i++) { overwriteFlags[i] = false; }
                            }),
                            child: Text(AppLocalizations.of(context)!.customerMgmtSkipAllButton),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(duplicates.length, (i) {
                        final c = duplicates[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text('${c.name}${c.businessName.isNotEmpty ? ' — ${c.businessName}' : ''}'),
                            subtitle: Text('${c.email} · ${c.phone}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(AppLocalizations.of(context)!.actionSkip, style: const TextStyle(fontSize: 12)),
                                Switch(
                                  value: overwriteFlags[i],
                                  onChanged: (v) => setDialogState(() => overwriteFlags[i] = v),
                                ),
                                Text(AppLocalizations.of(context)!.customerMgmtOverwriteLabel, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    if (errors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context)!.customerMgmtSkippedRowsLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 8),
                      ...errors.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(AppLocalizations.of(context)!.customerMgmtErrorBulletLabel(e),
                                style: const TextStyle(fontSize: 12, color: Colors.red)),
                          )),
                    ],

                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context)!.customerMgmtWillImportMessage(total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context)!.actionCancel),
              ),
              FilledButton.icon(
                onPressed: total == 0
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _executeImport(newCustomers, duplicates, overwriteFlags);
                      },
                icon: const Icon(Icons.upload),
                label: Text(AppLocalizations.of(context)!.customerMgmtImportCountButton(total)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeImport(
    List<Customer> newCustomers,
    List<Customer> duplicates,
    List<bool> overwriteFlags,
  ) async {
    if(!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      if (newCustomers.isNotEmpty) {
        await ref.read(customerRepositoryProvider).insertBatch(newCustomers);
      }
      for (int i = 0; i < duplicates.length; i++) {
        if (overwriteFlags[i]) {
          await ref.read(customerRepositoryProvider).updateCustomer(duplicates[i]);
        }
      }
      await _loadCustomers();
      final imported = newCustomers.length + overwriteFlags.where((f) => f).length;
      _showSnackBar(l10n.customerMgmtImportedMessage(imported));
    } catch (e) {
      if(!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(l10n.customerMgmtImportErrorMessage(e.toString()), isError: true);
    }
  }

  // ── Delete All ────────────────────────────────────────────────────────────

  Future<void> _confirmDeleteAll() async {
    final l10n = AppLocalizations.of(context)!;
    if (_statsV2.all == 0) {
      _showSnackBar(l10n.customerMgmtNoCustomersToDeleteMessage);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.customerMgmtDeleteAllTitle),
        content: Text(
          l10n.customerMgmtDeleteAllBody(_statsV2.all),
        ),
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
      await ref.read(customerRepositoryProvider).deleteAllCustomers();
      await _loadCustomers();
      _showSnackBar(l10n.customerMgmtAllDeletedMessage);
    } catch (e) {
      if(!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar(l10n.customerMgmtDeleteAllErrorMessage(e.toString()), isError: true);
    }
  }

  // Export = every customer matching the current search/tab/sort, fetched
  // only when the user exports (the screen itself holds one page).
  Future<List<Customer>> _filteredForExportV2() async => ref
      .read(customerRepositoryProvider)
      .getCustomersByIds(await _orderedIdsV2());

  Future<void> _exportToCSV() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final customers = await _filteredForExportV2();
      List<List<String>> csvData = [
        ['name', 'email', 'phone', 'address', 'business_name', 'tax_number'],
        ...customers.map((c) => [
          c.name,
          c.email,
          c.phone,
          c.address,
          c.businessName,
          c.gstin,
        ]),
      ];

      final csv = buildQuotedCsv(csvData);
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.customerMgmtSaveCsvDialogTitle,
        fileName: 'customers.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (savePath == null) return;
      await File(savePath).writeAsBytes(utf8.encode('\uFEFF$csv'));
      _showSnackBar(l10n.customerMgmtCsvExportedMessage);
    } catch (e) {
      _showSnackBar(l10n.customerMgmtCsvExportErrorMessage(e.toString()), isError: true);
    }
  }

  Future<void> _exportToPDF() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final customers = await _filteredForExportV2();
      final totalCount = customers.length;
      // The app's PDF fonts, so non-Latin names (Tamil, Hindi...) are not blank.
      final pdf = pw.Document(theme: await PdfFontService.loadTheme());
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Customer Export - $totalCount customer${totalCount == 1 ? '' : 's'}',
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
                ['#', 'Name', 'Business Name', 'Email', 'Phone', 'Tax/VAT No', 'Address'],
                ...customers.indexed.map(((int, dynamic) e) => [
                      e.$1 + 1,
                      e.$2.name,
                      e.$2.businessName,
                      e.$2.email,
                      e.$2.phone,
                      e.$2.gstin,
                      e.$2.address,
                    ]),
              ],
            ),
          ],
        ),
      );

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.customerMgmtSavePdfDialogTitle,
        fileName: 'customers.pdf',
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

  // ============================================================
  // V2 — flat / modern layout. Reuses all v1 state, controllers,
  // validation, and repository calls (_handleAddOrUpdateCustomer,
  // _showCustomerDialog, _confirmDelete, import/export). Tabs, search,
  // sort and paging load one page at a time (_loadPageV2); stat cards come
  // from one SQL aggregate (_statsV2). Also a slide-out "New Customer"
  // panel and a flat table.
  // ============================================================

  int get _businessesCountV2 => _statsV2.businesses;
  int get _individualsCountV2 => _statsV2.individuals;
  int get _gstRegisteredCountV2 => _statsV2.taxRegistered;
  int get _withoutGstCountV2 => _statsV2.all - _gstRegisteredCountV2;
  int get _withOutstandingCountV2 => _withOutstandingCount;

  void _onSearchChangedV2(String value) {
    // Debounced: each change queries the database (Issues.md #43).
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value;
        _currentPage = 0;
      });
      _loadPageV2();
    });
  }

  void _onSortSelectionV2(String field, bool ascending) {
    if (!mounted) return;
    setState(() {
      _sortBy = field;
      _isAscending = ascending;
      _currentPage = 0;
    });
    _loadPageV2();
  }

  void _selectTabV2(int index) {
    if (!mounted) return;
    setState(() {
      _activeTabV2 = index;
      _currentPage = 0;
    });
    _loadPageV2();
  }

  Future<void> _addCustomerV2() async {
    final nameBefore = _nameController.text;
    await _handleAddOrUpdateCustomer();
    final succeeded = _nameController.text.isEmpty && nameBefore.trim().isNotEmpty;
    if (succeeded) {
      if (!mounted) return;
      setState(() {
        if (!_addAnotherAfterSavingV2) _showAddPanelV2 = false;
      });
    }
  }

  Future<void> _viewCustomerV2(Customer c) async {
    await _showCustomerDialog(c, false);
  }

  Future<void> _editCustomerV2(Customer c) async {
    // _showCustomerDialog reloads via _loadCustomers on save, which keeps the
    // active tab/search/sort.
    await _showCustomerDialog(c, true);
  }

  Future<void> _deleteCustomerV2(Customer c) async {
    await _confirmDelete(c); // reloads via _loadCustomers
  }

  Future<void> _receivePayment(Customer c) async {
    await showDialog(
      context: context,
      builder: (_) => ApplyCustomerPaymentDialog(
        customer: c,
        onPaymentApplied: _loadCustomers,
      ),
    );
  }

  BoxDecoration _flatCardDecorationV2(BuildContext context) => BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      );

  // A PopupMenuButton's `child` should stay non-interactive (PopupMenuButton
  // itself provides the tap-to-open handling) — a real OutlinedButton with
  // onPressed: null there would render as visually disabled/greyed out.
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

  Widget _statCardV2({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
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
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
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
    final cards = [
      _statCardV2(
        label: AppLocalizations.of(context)!.customerMgmtTotalCustomersLabel,
        value: '${_statsV2.all}',
        subtitle: AppLocalizations.of(context)!.customerMgmtAllCustomersSubtitle,
        icon: Icons.groups_outlined,
        accent: Theme.of(context).primaryColor,
      ),
      _statCardV2(
        label: AppLocalizations.of(context)!.customerMgmtBusinessesLabel,
        value: '$_businessesCountV2',
        subtitle: AppLocalizations.of(context)!.customerMgmtRegisteredBusinessesSubtitle,
        icon: Icons.apartment_outlined,
        accent: Colors.green,
      ),
      _statCardV2(
        label: AppLocalizations.of(context)!.customerMgmtIndividualsLabel,
        value: '$_individualsCountV2',
        subtitle: AppLocalizations.of(context)!.customerMgmtIndividualCustomersSubtitle,
        icon: Icons.person_outline,
        accent: Colors.deepPurple,
      ),
      _statCardV2(
        label: AppLocalizations.of(context)!.customerMgmtTaxRegisteredLabel(_taxWord),
        value: '$_gstRegisteredCountV2',
        subtitle: AppLocalizations.of(context)!.customerMgmtWithTaxNumberSubtitle(_taxWord),
        icon: Icons.receipt_long_outlined,
        accent: Colors.orange,
      ),
    ];

    // Responsive: fit as many equal-width cards per row as the available
    // width allows (min ~170px each), wrapping to additional rows instead
    // of squeezing/overflowing on narrow screens.
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

    Future<void> onMore(String value) async {
      if (value == 'import') await _showImportDialog();
      if (value == 'export') await _exportToCSV();
      if (value == 'refresh') await _loadCustomers();
      if (value == 'export_pdf') await _exportToPDF();
      if (value == 'delete_all') await _confirmDeleteAll();
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

    const buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 14);
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
                Text(l10n.customerMgmtTitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(l10n.customerMgmtSubtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!compact) ...[
            OutlinedButton.icon(
              onPressed: _showImportDialog,
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
                    l10n.customerMgmtDeleteAllTitle,
                    color: Colors.red),
              ],
            ],
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => setState(() => _showAddPanelV2 = true),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.customerMgmtNewCustomerButton),
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
      {'label': l10n.customerMgmtSortIdOldest, 'field': 'id', 'asc': true},
      {'label': l10n.customerMgmtSortIdNewest, 'field': 'id', 'asc': false},
      {'label': l10n.customerMgmtSortOutstandingHighLow, 'field': 'outstanding', 'asc': false},
      {'label': l10n.customerMgmtSortOutstandingLowHigh, 'field': 'outstanding', 'asc': true},
    ];
    final currentLabel = sortOptions.firstWhere(
      (o) => o['field'] == _sortBy && o['asc'] == _isAscending,
      orElse: () => sortOptions.first,
    )['label'] as String;

    final searchField = TextField(
      focusNode: _searchFocusNode,
      onChanged: _onSearchChangedV2,
      decoration: InputDecoration(
        hintText: l10n.customerMgmtSearchHint(_taxWord),
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
      tooltip: l10n.invoiceMgmtFilterLabel,
      onSelected: (value) {
        if (!mounted) return;
        setState(() {
          _currentPage = 0;
          _activeTabV2 = switch (value) {
            'gst' => 3,
            'no_gst' => 4,
            _ => _activeTabV2 >= 3 ? 0 : _activeTabV2,
          };
        });
        _loadPageV2();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'all', child: Text(l10n.customerMgmtAllTaxStatusesLabel(_taxWord))),
        PopupMenuItem(value: 'gst', child: Text(l10n.customerMgmtTaxRegisteredLowerLabel(_taxWord))),
        PopupMenuItem(value: 'no_gst', child: Text(l10n.customerMgmtWithoutTaxLabel(_taxWord))),
      ],
      child: _menuButtonLookV2(Icons.filter_list, l10n.invoiceMgmtFilterLabel),
    );

    final currencyMenu = _outstandingCurrencies.length > 1
        ? PopupMenuButton<String>(
            tooltip: 'Outstanding currency',
            onSelected: _onOutstandingCurrencyChangedV2,
            itemBuilder: (ctx) => _outstandingCurrencies
                .map((code) => PopupMenuItem(value: code, child: Text(code)))
                .toList(),
            child: _menuButtonLookV2(Icons.currency_exchange,
                'Currency: ${_selectedOutstandingCurrency ?? ''}'),
          )
        : null;

    final sortMenu = PopupMenuButton<Map<String, Object>>(
      tooltip: l10n.invoiceMgmtSortLabel,
      onSelected: (opt) =>
          _onSortSelectionV2(opt['field'] as String, opt['asc'] as bool),
      itemBuilder: (ctx) => sortOptions
          .map((o) => PopupMenuItem(value: o, child: Text(o['label'] as String)))
          .toList(),
      child: _menuButtonLookV2(Icons.swap_vert, l10n.customerMgmtSortWithLabel(currentLabel)),
    );

    final columnsMenu = PopupMenuButton<String>(
      tooltip: l10n.customerMgmtColumnsLabel,
      onSelected: (key) {
        if (!mounted) return;
        setState(() => _visibleColumnsV2[key] = !(_visibleColumnsV2[key] ?? true));
      },
      itemBuilder: (ctx) => [
        _columnMenuItemV2('phone', l10n.fieldPhoneLabel),
        _columnMenuItemV2('email', l10n.fieldEmailLabel),
        _columnMenuItemV2('gstin', l10n.customerMgmtTaxVatNoColumnLabel(_taxWord)),
        _columnMenuItemV2('address', l10n.fieldAddressLabel),
        _columnMenuItemV2('outstanding', l10n.invoiceMgmtColOutstanding),
      ],
      child: _menuButtonLookV2(Icons.view_column_outlined, l10n.customerMgmtColumnsLabel),
    );

    final statsToggle = IconButton(
      tooltip: _showStatsCardsV2 ? l10n.customerMgmtHideStatCardsTooltip : l10n.customerMgmtShowStatCardsTooltip,
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
            if (currencyMenu != null) ...[const SizedBox(width: 8), currencyMenu],
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
            children: [
              filterMenu,
              if (currencyMenu != null) currencyMenu,
              sortMenu,
              columnsMenu,
              statsToggle,
            ],
          ),
        ],
      );
    });
  }

  PopupMenuItem<String> _columnMenuItemV2(String key, String label) {
    final visible = _visibleColumnsV2[key] ?? true;
    return PopupMenuItem<String>(
      value: key,
      child: Row(
        children: [
          Icon(visible ? Icons.check_box : Icons.check_box_outline_blank, size: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _tabChipV2(String label, int count, int index) {
    final selected = _activeTabV2 == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: () => _selectTabV2(index),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? Theme.of(context).primaryColor : null,
          foregroundColor:
              selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tabChipV2(AppLocalizations.of(context)!.invoiceMgmtStatusAllLabel, _statsV2.all, 0),
          _tabChipV2(AppLocalizations.of(context)!.customerMgmtBusinessesLabel, _businessesCountV2, 1),
          _tabChipV2(AppLocalizations.of(context)!.customerMgmtIndividualsLabel, _individualsCountV2, 2),
          _tabChipV2(AppLocalizations.of(context)!.customerMgmtTaxRegisteredLabel(_taxWord), _gstRegisteredCountV2, 3),
          _tabChipV2(AppLocalizations.of(context)!.customerMgmtWithOutstandingLabel, _withOutstandingCountV2, 5),
          _tabChipV2(AppLocalizations.of(context)!.customerMgmtWithoutTaxLabel(_taxWord), _withoutGstCountV2, 4),
        ],
      ),
    );
  }

  static const List<MaterialColor> _avatarColorsV2 = [
    Colors.blue,
    Colors.green,
    Colors.deepPurple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  Widget _avatarV2(Customer c) {
    final initials = c.name.trim().isEmpty
        ? '?'
        : c.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((s) => s.isNotEmpty ? s[0] : '')
            .join()
            .toUpperCase();
    final color = _avatarColorsV2[c.name.hashCode.abs() % _avatarColorsV2.length];
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(initials,
          style: TextStyle(color: color.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _tableRowV2(Customer c, int index) {
    final serial = _currentPage * _pageSize + index + 1;
    final outstanding = _outstandingByCustomer[c.id] ?? 0;
    final hasOutstanding = outstanding > 0.005;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
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
            child: Padding(padding: const EdgeInsets.only(right: 12), child: Row(
              children: [
                _avatarV2(c),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (c.businessName.trim().isNotEmpty)
                        Text(c.businessName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            )),
          ),
          if (_visibleColumnsV2['phone'] ?? true)
            Expanded(
              flex: 2,
              child: Padding(padding: const EdgeInsets.only(right: 12), child: Text(c.phone.isEmpty ? '—' : c.phone)),
            ),
          if (_visibleColumnsV2['email'] ?? true)
            Expanded(
              flex: 3,
              child: Padding(padding: const EdgeInsets.only(right: 12), child: Text(c.email.isEmpty ? '—' : c.email,
                  overflow: TextOverflow.ellipsis)),
            ),
          if (_visibleColumnsV2['gstin'] ?? true)
            Expanded(
              flex: 2,
              child: Padding(padding: const EdgeInsets.only(right: 12), child: Text(c.gstin.isEmpty ? '—' : c.gstin,
                  overflow: TextOverflow.ellipsis)),
            ),
          if (_visibleColumnsV2['address'] ?? true)
            Expanded(
              flex: 3,
              child: Padding(padding: const EdgeInsets.only(right: 12), child: Text(c.address.isEmpty ? '—' : c.address,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            ),
          if (_visibleColumnsV2['outstanding'] ?? true)
            Expanded(
              flex: 2,
              child: Padding(padding: const EdgeInsets.only(right: 12), child: Text(
                hasOutstanding
                    ? AppFormatters.formatAmount(outstanding, _outstandingCurrencySymbol)
                    : '—',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: hasOutstanding ? FontWeight.w600 : FontWeight.normal,
                    color: hasOutstanding
                        ? Colors.orange.shade800
                        : Theme.of(context).colorScheme.onSurfaceVariant),
              )),
            ),
          SizedBox(
            width: 200,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _viewCustomerV2(c),
                  tooltip: AppLocalizations.of(context)!.actionView,
                ),
                if (widget.onViewCustomerStatement != null)
                  IconButton(
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => widget.onViewCustomerStatement!(c),
                    tooltip: AppLocalizations.of(context)!.customerMgmtViewStatementTooltip,
                  ),
                IconButton(
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _receivePayment(c),
                  tooltip: AppLocalizations.of(context)!.mCustReceivePayment,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editCustomerV2(c),
                  tooltip: AppLocalizations.of(context)!.actionEdit,
                ),
                if (widget.user.isAdmin())
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () => _deleteCustomerV2(c),
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
          SizedBox(
              width: 56,
              child: Text(l10n.customerMgmtColSlNo,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          cell(3, l10n.customerMgmtColNameBusiness),
          if (_visibleColumnsV2['phone'] ?? true) cell(2, l10n.customerMgmtColPhone),
          if (_visibleColumnsV2['email'] ?? true) cell(3, l10n.customerMgmtColEmail),
          if (_visibleColumnsV2['gstin'] ?? true)
            cell(2, l10n.customerMgmtColTaxVatNo(_taxWord.toUpperCase())),
          if (_visibleColumnsV2['address'] ?? true) cell(3, l10n.customerMgmtColAddress),
          if (_visibleColumnsV2['outstanding'] ?? true)
            cell(2, l10n.invoiceMgmtColOutstanding.toUpperCase()),
          SizedBox(width: 200, child: Text(l10n.customerMgmtColActions, style: style)),
        ],
      ),
    );
  }


  Widget _paginationV2(List<Customer> pageItems, int totalPages) {
    final total = _filteredTotal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      // A plain Row with no Expanded/Wrap will overflow horizontally on a
      // narrow table. A horizontally-scrolling Row keeps this bar's height
      // constant and never overflows regardless of how narrow it gets.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Text(
            AppLocalizations.of(context)!.customerMgmtShowingRangeLabel(
                total == 0 ? 0 : _currentPage * _pageSize + 1,
                (_currentPage * _pageSize + _pageSize).clamp(0, total),
                total),
            style: TextStyle(
                fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 24),
          Row(
            children: [
              Text(AppLocalizations.of(context)!.customerMgmtRowsPerPageLabel,
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
                  _loadPageV2();
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _currentPage > 0 ? () => _changePage(_currentPage - 1) : null,
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
              Text(AppLocalizations.of(context)!.customerMgmtOfTotalPagesLabel(totalPages),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              IconButton(
                onPressed: _currentPage < totalPages - 1
                    ? () => _changePage(_currentPage + 1)
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

  // This widget sizes itself naturally instead of relying on `Expanded` to
  // fill whatever space a bounded ancestor gives it — the page itself is a
  // CustomScrollView (see _buildV2), so the list here is shrink-wrapped
  // (its own scrolling disabled) and the page just scrolls further if the
  // natural content (header + rows + pagination) doesn't fit the viewport.
  Widget _tableSectionV2() {
    final totalPages =
        _filteredTotal == 0 ? 1 : (_filteredTotal / _pageSize).ceil();
    final pageItems = _pageCustomers;

    return Container(
      decoration: _flatCardDecorationV2(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tableHeaderRowV2(),
          _isLoading && _pageCustomers.isEmpty
              ? const SizedBox(
                  height: 240, child: Center(child: CircularProgressIndicator()))
              : pageItems.isEmpty
                  ? SizedBox(height: 240, child: _buildEmptyState())
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pageItems.length,
                      itemBuilder: (context, index) => _tableRowV2(pageItems[index], index),
                    ),
          _paginationV2(pageItems, totalPages),
        ],
      ),
    );
  }

  // ── Slide-out "New Customer" panel ──────────────────────────────────
  // The customer model only has these six fields — there's no secondary
  // "advanced" data set the way products have metadata/discount/tax, so
  // this is a single section rather than a tabbed panel.

  Widget _addPanelV2() {
    // Width is now controlled by the Positioned wrapper in _buildV2 (scales
    // with the window, capped between 520–680px, full width on narrow
    // screens), so this no longer hardcodes its own width.
    return Container(
      decoration: _flatCardDecorationV2(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 10, 16),
            child: Row(
              children: [
                Text(AppLocalizations.of(context)!.customerMgmtNewCustomerButton,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormField(_nameController, AppLocalizations.of(context)!.fieldNameLabel, Icons.person, true,
                          maxLength: 50),
                      const SizedBox(height: 16),
                      _buildFormField(_businessNameController, AppLocalizations.of(context)!.fieldBusinessNameLabel,
                          Icons.business_center, false,
                          maxLength: 100),
                      const SizedBox(height: 16),
                      _buildFormField(_phoneController, AppLocalizations.of(context)!.fieldPhoneLabel, Icons.phone, true,
                          keyboardType: TextInputType.phone, maxLength: 12),
                      const SizedBox(height: 16),
                      _buildFormField(_emailController, AppLocalizations.of(context)!.fieldEmailLabel, Icons.email, false,
                          maxLength: 100, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 16),
                      _buildFormField(_gstinController, AppLocalizations.of(context)!.fieldTaxVatNumberLabel(_taxWord),
                          Icons.receipt_long, false,
                          maxLength: 50),
                      const SizedBox(height: 16),
                      _buildFormField(_addressController, AppLocalizations.of(context)!.fieldAddressLabel, Icons.location_on,
                          false,
                          maxLines: 3, maxLength: 500),
                    ],
                  ),
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
                      onChanged: (v) =>
                          setState(() => _addAnotherAfterSavingV2 = v ?? false),
                    ),
                    Expanded(child: Text(AppLocalizations.of(context)!.customerMgmtAddAnotherLabel)),
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
                        child: Text(AppLocalizations.of(context)!.actionCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _addCustomerV2,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(AppLocalizations.of(context)!.customerMgmtSaveCustomerButton),
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

  Widget _buildV2(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Add/Edit panel width: was a flat 400px, squeezed into a Row
            // next to the main content (which could force the main
            // content's Expanded to near-zero on narrow windows). Now the
            // panel floats as an overlay instead, so it never steals width
            // from the table, and its own width scales a bit with the
            // window on large screens (capped so it doesn't get unwieldy)
            // while dropping to full width (minus margins) on narrow ones.
            final panelWidth = constraints.maxWidth < 750
                ? constraints.maxWidth - 32
                : (constraints.maxWidth * 0.42).clamp(520.0, 680.0);

            return Stack(
              children: [
                // The table section no longer relies on `Expanded` to fill
                // leftover space — it sizes itself naturally (header row +
                // actual row heights + pagination row), and sits in a plain
                // SliverToBoxAdapter below the rest of the page's content,
                // inside this CustomScrollView. Nothing here is forced into
                // a box smaller than it needs, so there's nothing to
                // overflow: if the natural content is taller than the
                // visible viewport, the page scrolls further to show it,
                // and if it fits (only a couple of customers), it fits with
                // no extra scrolling.
                CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                    width: panelWidth,
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
  // Title, subtitle, Import / Export / ⋯ and "+ New Customer" in the Modern
  // top bar; four tinted stat cards; a filter card (search, Customer Type ▾,
  // Columns ▾ and the chips; sort by the Name / Outstanding headings); the
  // table (avatar, contact,
  // GST / VAT No, type, outstanding; eye, statement, edit, ⋮) with a
  // "Showing x to y" footer and numbered pages. The Standard page above is
  // unchanged.

  /// Columns that Columns ▾ can hide (Name / Business and Actions always show).
  static const _optionalColsModern = ['contact', 'gstin', 'type', 'outstanding', 'address'];
  Set<String> _hiddenColsModern = const {'address'};
  final Set<String> _selectedModern = {};

  bool _colOnModern(String c) => !_hiddenColsModern.contains(c);

  String _colLabelModern(AppLocalizations l10n, String c) => switch (c) {
        'contact' => l10n.mCustColContact,
        'gstin' => l10n.customerMgmtTaxVatNoColumnLabel(_taxWord),
        'type' => l10n.mCustColType,
        'outstanding' => l10n.invoiceMgmtColOutstanding,
        _ => l10n.fieldAddressLabel,
      };

  Future<void> _loadHiddenColsModern() async {
    final v = await ref
        .read(settingsRepositoryProvider)
        .getSetting(SettingKey.customerListHiddenColumns);
    if (!mounted || v == null) return;
    setState(() => _hiddenColsModern =
        v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet());
  }

  void _toggleColModern(String c) {
    setState(() {
      _hiddenColsModern = {..._hiddenColsModern};
      if (!_hiddenColsModern.remove(c)) _hiddenColsModern.add(c);
    });
    ref.read(settingsRepositoryProvider).setSetting(
        SettingKey.customerListHiddenColumns, _hiddenColsModern.join(','));
  }

  // ── Top bar ──────────────────────────────────────────────────────────────

  Future<void> _onMoreModern(String value) async {
    if (value == 'import') await _showImportDialog();
    if (value == 'export') await _exportToCSV();
    if (value == 'refresh') await _loadCustomers();
    if (value == 'toggle_stats') await _toggleStatsCardsV2();
    if (value.startsWith('cur:')) await _onOutstandingCurrencyChangedV2(value.substring(4));
    if (value == 'export_pdf') await _exportToPDF();
    if (value == 'delete_all') await _confirmDeleteAll();
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
        soft('modernCustomerImport', Icons.upload_file_outlined, l10n.actionImport,
            _showImportDialog),
        const SizedBox(width: 8),
        soft('modernCustomerExport', Icons.file_download_outlined, l10n.actionExport,
            _exportToCSV),
        const SizedBox(width: 8),
      ],
      PopupMenuButton<String>(
        key: const ValueKey('modernCustomerMore'),
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
          // The outstanding amounts' currency (only with invoices in more
          // than one currency).
          if (_outstandingCurrencies.length > 1) ...[
            const PopupMenuDivider(),
            _menuHeadingModern(l10n.mCustOutstandingCurrency),
            for (final code in _outstandingCurrencies)
              CheckedPopupMenuItem<String>(
                  value: 'cur:$code',
                  checked: _selectedOutstandingCurrency == code,
                  child: Text(code)),
          ],
          if (widget.user.isAdmin()) ...[
            const PopupMenuDivider(),
            item('export_pdf', Icons.picture_as_pdf_outlined, l10n.customerMgmtExportPdfMenuLabel),
            item('delete_all', Icons.delete_sweep, l10n.customerMgmtDeleteAllTitle,
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

  Widget _newCustomerButtonModern() {
    final l10n = AppLocalizations.of(context)!;
    return FilledButton.icon(
      key: const ValueKey('modernNewCustomer'),
      onPressed: () => setState(() => _showAddPanelV2 = true),
      icon: const Icon(Icons.add, size: 18),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: Text(l10n.customerMgmtNewCustomerButton,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Stat cards ───────────────────────────────────────────────────────────

  Widget _statCardsModern() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cards = <(IconData, Color, String, int, String)>[
      (Icons.groups_outlined, Theme.of(context).primaryColor, l10n.customerMgmtTotalCustomersLabel,
          _statsV2.all, l10n.customerMgmtAllCustomersSubtitle),
      (Icons.apartment_outlined, const Color(0xFF16A34A), l10n.customerMgmtBusinessesLabel,
          _businessesCountV2, l10n.customerMgmtRegisteredBusinessesSubtitle),
      (Icons.person_outline, const Color(0xFF7C3AED), l10n.customerMgmtIndividualsLabel,
          _individualsCountV2, l10n.customerMgmtIndividualCustomersSubtitle),
      (Icons.receipt_long_outlined, const Color(0xFFF59E0B),
          l10n.customerMgmtTaxRegisteredLabel(_taxWord), _gstRegisteredCountV2,
          l10n.customerMgmtWithTaxNumberSubtitle(_taxWord)),
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
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12)),
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
                Text('$value',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
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
        key: const ValueKey('modernCustomerStats'),
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
          side: BorderSide(
              color: active ? primary.withValues(alpha: 0.5) : scheme.outlineVariant),
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

  PopupMenuItem<String> _menuHeadingModern(String text) => PopupMenuItem<String>(
        enabled: false,
        height: 30,
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Future<void> _openTypeMenuModern(BuildContext anchor) async {
    final l10n = AppLocalizations.of(context)!;
    final v = await showMenu<int>(
      context: context,
      position: _menuAtModern(anchor),
      items: [
        for (final (i, label) in [
          (0, l10n.mCustAllTypes),
          (1, l10n.customerMgmtBusinessesLabel),
          (2, l10n.customerMgmtIndividualsLabel),
        ])
          CheckedPopupMenuItem<int>(value: i, checked: _activeTabV2 == i, child: Text(label)),
      ],
    );
    if (v != null && mounted) _selectTabV2(v);
  }

  Future<void> _openColumnsMenuModern(BuildContext anchor) async {
    final l10n = AppLocalizations.of(context)!;
    final v = await showMenu<String>(
      context: context,
      position: _menuAtModern(anchor),
      items: [
        for (final c in _optionalColsModern)
          CheckedPopupMenuItem<String>(
              value: c, checked: _colOnModern(c), child: Text(_colLabelModern(l10n, c))),
      ],
    );
    if (v != null && mounted) _toggleColModern(v);
  }

  Widget _chipModern(String label, int count, int index) {
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    final selected = _activeTabV2 == index;
    return Material(
      color: selected ? primary : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? primary : scheme.outlineVariant),
      ),
      child: InkWell(
        key: ValueKey('modernCustChip_$index'),
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () => _selectTabV2(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(AppLocalizations.of(context)!.customerMgmtTabChipLabel(label, count),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : scheme.onSurface)),
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
        key: const ValueKey('modernCustomerSearch'),
        focusNode: _searchFocusNode,
        onChanged: _onSearchChangedV2,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: l10n.customerMgmtSearchHint(_taxWord),
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
    final typeLabel = switch (_activeTabV2) {
      1 => l10n.customerMgmtBusinessesLabel,
      2 => l10n.customerMgmtIndividualsLabel,
      _ => l10n.mCustTypeLabel,
    };
    // Filtering is by Customer Type and the chips; sorting by clicking the
    // Name or Outstanding heading.
    final buttons = <Widget>[
      _menuButtonModern(
          key: 'modernCustomerType',
          icon: Icons.person_outline,
          label: typeLabel,
          active: _activeTabV2 == 1 || _activeTabV2 == 2,
          onTapAt: _openTypeMenuModern),
      _menuButtonModern(
          key: 'modernCustomerColumns',
          icon: Icons.view_column_outlined,
          label: l10n.customerMgmtColumnsLabel,
          onTapAt: _openColumnsMenuModern),
    ];
    final chips = <Widget>[
      _chipModern(l10n.invoiceMgmtStatusAllLabel, _statsV2.all, 0),
      _chipModern(l10n.customerMgmtBusinessesLabel, _businessesCountV2, 1),
      _chipModern(l10n.customerMgmtIndividualsLabel, _individualsCountV2, 2),
      _chipModern(l10n.customerMgmtTaxRegisteredLabel(_taxWord), _gstRegisteredCountV2, 3),
      _chipModern(l10n.customerMgmtWithOutstandingLabel, _withOutstandingCountV2, 5),
      _chipModern(l10n.customerMgmtWithoutTaxLabel(_taxWord), _withoutGstCountV2, 4),
    ];
    return Container(
      key: const ValueKey('modernCustomerFilters'),
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
  static const double _typeWidthModern = 124;

  Widget _sortHeaderModern(String key, String text, String field, TextStyle style,
      {bool defaultAscending = true}) {
    final sorted = _sortBy == field;
    return InkWell(
      key: ValueKey(key),
      onTap: () => _onSortSelectionV2(field, sorted ? !_isAscending : defaultAscending),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        const SizedBox(width: 4),
        Icon(
            !sorted
                ? Icons.unfold_more
                : (_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
            size: 14,
            color: style.color),
      ]),
    );
  }

  Widget _tableHeaderModern() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant);
    final pageIds = _pageCustomers.map((c) => c.id).toSet();
    final allOn = pageIds.isNotEmpty && pageIds.every(_selectedModern.contains);
    final someOn = pageIds.any(_selectedModern.contains);
    Widget cell(int flex, Widget child) =>
        Expanded(flex: flex, child: Padding(padding: const EdgeInsets.only(right: 12), child: child));
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
            key: const ValueKey('modernCustomerSelectAll'),
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
        cell(4, _sortHeaderModern('modernCustSortName', l10n.mCustColNameBusiness, 'name', style)),
        if (_colOnModern('contact'))
          cell(3, Text(l10n.mCustColContact,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        if (_colOnModern('gstin'))
          cell(2, Text(l10n.customerMgmtTaxVatNoColumnLabel(_taxWord),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        if (_colOnModern('type'))
          SizedBox(
              width: _typeWidthModern,
              child: Text(l10n.mCustColType,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        if (_colOnModern('address'))
          cell(2, Text(l10n.fieldAddressLabel,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
        if (_colOnModern('outstanding'))
          cell(2, _sortHeaderModern('modernCustSortOutstanding', l10n.invoiceMgmtColOutstanding,
              'outstanding', style, defaultAscending: false)),
        SizedBox(
            width: _actionsWidthModern,
            child: Text(l10n.invoiceMgmtColActions,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ]),
    );
  }

  Widget _rowButtonModern(String key, IconData icon, String tooltip, VoidCallback onTap,
      {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          key: ValueKey(key),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onTap: onTap,
          child: SizedBox(
              width: 38, height: 38, child: Icon(icon, size: 19, color: color ?? scheme.onSurface)),
        ),
      ),
    );
  }

  Widget _rowModern(Customer c, int index) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    final serial = _currentPage * _pageSize + index + 1;
    final outstanding = _outstandingByCustomer[c.id] ?? 0;
    final hasOutstanding = outstanding > 0.005;
    final isBusiness = c.businessName.trim().isNotEmpty;
    final selected = _selectedModern.contains(c.id);
    final muted = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    Widget cell(int flex, Widget child) =>
        Expanded(flex: flex, child: Padding(padding: const EdgeInsets.only(right: 12), child: child));
    Widget line(IconData icon, String text) => Row(children: [
          Icon(icon, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text.isEmpty ? '—' : text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5,
                    color: text.isEmpty ? scheme.onSurfaceVariant : scheme.onSurface)),
          ),
        ]);
    const purple = Color(0xFF7C3AED);
    const green = Color(0xFF16A34A);
    final typeColor = isBusiness ? green : purple;
    return Container(
      key: ValueKey('custRow_${c.id}'),
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
              if (!_selectedModern.remove(c.id)) _selectedModern.add(c.id);
            }),
          ),
        ),
        SizedBox(width: 40, child: Text('$serial', style: muted)),
        cell(
          4,
          Row(children: [
            _avatarV2(c),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    const SizedBox(width: 4),
                    CustomerInfoButton(customer: c),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(isBusiness ? Icons.apartment_outlined : Icons.person_outline,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(isBusiness ? c.businessName : l10n.mCustIndividual,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                    ),
                  ]),
                ],
              ),
            ),
          ]),
        ),
        if (_colOnModern('contact'))
          cell(
            3,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                line(Icons.phone_outlined, c.phone),
                const SizedBox(height: 4),
                line(Icons.mail_outline, c.email),
              ],
            ),
          ),
        if (_colOnModern('gstin'))
          // The whole GSTIN (15 characters) always shows: it shrinks a
          // little on a narrow window instead of being cut.
          cell(2, Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(c.gstin.isEmpty ? '—' : c.gstin,
                    maxLines: 1,
                    style: c.gstin.isEmpty ? muted : const TextStyle(fontSize: 13.5)),
              ))),
        if (_colOnModern('type'))
          SizedBox(
            width: _typeWidthModern,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(isBusiness ? l10n.mCustBusiness : l10n.mCustIndividual,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: typeColor)),
              ),
            ),
          ),
        if (_colOnModern('address'))
          cell(2, Text(c.address.isEmpty ? '—' : c.address,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: muted)),
        if (_colOnModern('outstanding'))
          cell(
            2,
            // A long amount shrinks to fit instead of being cut.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                hasOutstanding
                    ? AppFormatters.formatAmount(outstanding, _outstandingCurrencySymbol)
                    : '—',
                maxLines: 1,
                style: hasOutstanding
                    ? const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFFEA580C))
                    : muted,
              ),
            ),
          ),
        SizedBox(
          width: _actionsWidthModern,
          child: Row(children: [
            _rowButtonModern('custView_${c.id}', Icons.visibility_outlined, l10n.actionView,
                () => _viewCustomerV2(c)),
            const SizedBox(width: 8),
            if (widget.onViewCustomerStatement != null) ...[
              _rowButtonModern('custStatement_${c.id}', Icons.receipt_long_outlined,
                  l10n.customerMgmtViewStatementTooltip,
                  () => widget.onViewCustomerStatement!(c)),
              const SizedBox(width: 8),
            ],
            _rowButtonModern('custEdit_${c.id}', Icons.edit_outlined, l10n.actionEdit,
                () => _editCustomerV2(c)),
            PopupMenuButton<String>(
              key: ValueKey('custMenu_${c.id}'),
              tooltip: l10n.invoiceMgmtMoreActionsTooltip,
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'pay') _receivePayment(c);
                if (v == 'delete') _deleteCustomerV2(c);
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'pay',
                  child: Row(children: [
                    const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 10),
                    Text(l10n.mCustReceivePayment),
                  ]),
                ),
                if (widget.user.isAdmin())
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 18, color: scheme.error),
                      const SizedBox(width: 10),
                      Text(l10n.actionDelete, style: TextStyle(color: scheme.error)),
                    ]),
                  ),
              ],
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _footerModern() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    final total = _filteredTotal;
    final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();
    // Up to five page numbers around the current one.
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
            key: ValueKey('custPage_${p + 1}'),
            borderRadius: BorderRadius.circular(9),
            onTap: on ? null : () => _changePage(p),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Text('${p + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : scheme.onSurface)),
              ),
            ),
          ),
        ),
      );
    }

    final left = Text(
      l10n.customerMgmtShowingRangeLabel(
          total == 0 ? 0 : _currentPage * _pageSize + 1,
          (_currentPage * _pageSize + _pageSize).clamp(0, total),
          total),
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
            key: const ValueKey('custRowsPerPage'),
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
              _loadPageV2();
            },
          ),
        ),
      ),
      const SizedBox(width: 18),
      IconButton(
        key: const ValueKey('custPagePrev'),
        onPressed: _currentPage > 0 ? () => _changePage(_currentPage - 1) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      for (var p = first; p <= last; p++) pageButton(p),
      IconButton(
        key: const ValueKey('custPageNext'),
        onPressed: _currentPage < totalPages - 1 ? () => _changePage(_currentPage + 1) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ]);
    return Container(
      key: const ValueKey('modernCustomerFooter'),
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 720) {
          return Row(children: [Expanded(child: left), right]);
        }
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
    // room grows with the columns shown (about 44px per flex share), so the
    // default columns fit a 1280px window without scrolling.
    final flex = 4 +
        (_colOnModern('contact') ? 3 : 0) +
        (_colOnModern('gstin') ? 2 : 0) +
        (_colOnModern('address') ? 2 : 0) +
        (_colOnModern('outstanding') ? 2 : 0);
    final fixed = 20.0 + 44 + 40 + _actionsWidthModern +
        (_colOnModern('type') ? _typeWidthModern : 0);
    final minTableWidth = math.max(900.0, fixed + flex * 44);
    final placeholder = _isLoading && _pageCustomers.isEmpty
        ? const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()))
        : (_pageCustomers.isEmpty ? SizedBox(height: 240, child: _buildEmptyState()) : null);
    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tableHeaderModern(),
        if (placeholder == null)
          for (var i = 0; i < _pageCustomers.length; i++) _rowModern(_pageCustomers[i], i),
      ],
    );
    return Container(
      key: const ValueKey('modernCustomerTable'),
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
        title: Text(l10n.mCustDeleteSelectedTitle(ids.length)),
        content: Text(l10n.mCustDeleteSelectedBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.actionCancel)),
          FilledButton(
            key: const ValueKey('custDeleteSelectedOk'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final repo = ref.read(customerRepositoryProvider);
    for (final id in ids) {
      await repo.deleteCustomer(id);
    }
    if (!mounted) return;
    setState(_selectedModern.clear);
    await _loadCustomers();
    if (mounted) _showSnackBar(l10n.mCustDeletedCount(ids.length));
  }

  Widget _selectionBarModern() {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).primaryColor;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('modernCustomerSelection'),
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
            key: const ValueKey('custDeleteSelected'),
            onPressed: _deleteSelectedModern,
            icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
            label: Text(l10n.userMgmtDeleteSelectedMenuLabel,
                style: TextStyle(color: scheme.error)),
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
          publishModernHeader((page) => ModernPageHeader(
                page: page,
                title: AppLocalizations.of(context)!.customerMgmtTitle,
                subtitle: AppLocalizations.of(context)!.customerMgmtSubtitle,
                actions: _headerActionsModern(compact),
                createButton: _newCustomerButtonModern(),
              ));
        }
        final panelWidth = constraints.maxWidth < 750
            ? constraints.maxWidth - 32
            : (constraints.maxWidth * 0.42).clamp(520.0, 680.0);
        return Stack(children: [
          SingleChildScrollView(
            key: const ValueKey('modernCustomerScroll'),
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
            Positioned(
              top: 16,
              right: 16,
              bottom: 16,
              width: panelWidth,
              child: _addPanelV2(),
            ),
          ],
        ]);
      }),
    );
  }

  Widget _buildFormField(
      TextEditingController controller,
      String label,
      IconData icon,
      bool required, {
        int maxLines = 1,
        int? maxLength,
        TextInputType? keyboardType,
      }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: keyboardType == TextInputType.phone
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        counterText: '',
      ),
      validator: required
          ? (value) {
        if (value == null || value.trim().isEmpty) {
          return AppLocalizations.of(context)!.fieldRequiredMessage(label);
        }
        return null;
      }
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 80, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.createInvoiceNoCustomersFoundMessage,
            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? AppLocalizations.of(context)!.customerMgmtTryAdjustingSearchSubtitle
                // A chip / type filter is on: nothing matches it.
                : _activeTabV2 != 0
                    ? AppLocalizations.of(context)!.invoiceMgmtTryAdjustingFiltersMessage
                    : AppLocalizations.of(context)!.customerMgmtAddFirstCustomerSubtitle,
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
