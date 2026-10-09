// The "Modern" Create Invoice layout (the default).
//
// Started as a copy of the V2 screen so that V2 keeps working exactly as it
// always did while this one evolves on its own. What differs from V2:
//  * the Customer box sits at the top of the right-hand panel, above the
//    Invoice details box, and the items table takes the whole left side;
//  * the right-hand panel scrolls as one column (customer, invoice details,
//    costs / notes / tax) with the totals pinned under it;
//  * Create prints the new invoice automatically (Settings > Invoice >
//    "Print automatically after creating"), and Ctrl+P or F11 create the
//    invoice and print it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:invoiceo/utils/formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:invoiceo/common/common.dart';
import 'package:invoiceo/domain/invoice_calculator.dart';
import 'package:invoiceo/domain/invoice_totals_calculator.dart';
import 'package:invoiceo/l10n/app_localizations.dart';
import 'package:invoiceo/services/backend_services.dart';
import 'package:invoiceo/layouts/modern/modern_page_header.dart';
import 'package:invoiceo/providers/app_config_provider.dart';
import 'package:invoiceo/providers/repositories.dart';
import 'package:uuid/uuid.dart';
import 'package:invoiceo/models/customer.dart';
import 'package:invoiceo/models/invoice.dart';
import 'package:invoiceo/models/invoice_item.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/models/additional_cost.dart';
import 'package:invoiceo/models/custom_field_def.dart';
import 'package:invoiceo/models/custom_field_value.dart';
import 'package:invoiceo/services/invoice_pdf_services.dart';
import 'package:invoiceo/services/pdf_service.dart';
import 'package:invoiceo/common/constants.dart';
import 'package:invoiceo/utils/scanner_capture.dart';
import 'package:invoiceo/screens/create_invoice_screen_v2.dart' show InvoiceFormGuard;
import 'package:invoiceo/theme/brand_colors.dart';
import 'package:invoiceo/models/invoice_draft.dart';
import 'package:invoiceo/services/usage_stats_service.dart';

class CreateInvoiceScreenModern extends ConsumerStatefulWidget {
  final Invoice? invoiceToEdit;

  /// When set, the form is pre-populated from this invoice and saved as a NEW
  /// invoice (cloneFrom != null implies invoiceToEdit == null).
  final Invoice? cloneFrom;

  /// The invoice type to use for the clone ('Invoice' or 'Quotation').
  /// Defaults to the source invoice type when null.
  final String? cloneType;

  /// Document type to preselect for a brand-new form ('Invoice' | 'Quotation'
  /// | 'Receipt'). Ignored when editing or cloning.
  final String? initialType;

  /// Set when this form is a quotation→invoice conversion: the id of the source
  /// quotation. On save the quotation is stamped 'converted' and linked, and
  /// the new invoice records it as its source. Implies cloneFrom is that
  /// quotation and cloneType == 'Invoice'.
  final String? convertFromQuotationId;

  /// Called when the user taps "New Invoice" while in edit mode.
  /// The parent (DashboardScreen) resets invoiceToEdit to null.
  final VoidCallback? onCreateNewInvoice;
  // Opens the list page of a document type ("Go to Receipts" on the created
  // screen, and its back arrow in the top bar).
  final void Function(String type)? onGoToList;
  final InvoiceFormGuard? guard;

  /// Set when the form was opened from a saved draft ([cloneFrom] is the
  /// draft's content). Saving the draft again updates it; creating the
  /// document deletes it.
  final String? draftId;

  /// The back arrow in the page header (to the list of this document type).
  final VoidCallback? onBack;

  const CreateInvoiceScreenModern({
    super.key,
    this.invoiceToEdit,
    this.cloneFrom,
    this.cloneType,
    this.initialType,
    this.convertFromQuotationId,
    this.onCreateNewInvoice,
    this.onGoToList,
    this.guard,
    this.draftId,
    this.onBack,
  });

  @override
  ConsumerState<CreateInvoiceScreenModern> createState() => _CreateInvoiceScreenModernState();
}

class _CreateInvoiceScreenModernState extends ConsumerState<CreateInvoiceScreenModern>
    with ModernHeaderPublisher {
  final FocusNode _screenFocusNode = FocusNode();
  ProductColumnsConfig _columnsConfig = const ProductColumnsConfig();
  bool _showDescriptionInPdf = false;

  Future<void> _loadColumnsConfig() async {
    final repo = ref.read(settingsRepositoryProvider);
    final config = await repo.getProductColumnsConfig();
    final showDesc = await repo.getSetting(SettingKey.showDescriptionInPdf);
    if (!mounted) return;
    setState(() {
      _columnsConfig = config;
      _showDescriptionInPdf = showDesc == 'true';
    });
  }

  Customer? selectedCustomer;
  List<Customer> customers = [];
  List<Product> products = [];
  List<Product> filteredProducts = [];
  Map<String, ProductMetadata> _productMetadata = {};

  // Freeze a detached copy of the product's current metadata onto a new line so
  // it can print on the PDF and never shift if the catalogue product is edited.
  ProductMetadata? _snapshotMetadata(String productId) {
    final m = _productMetadata[productId];
    return (m == null || m.isEmpty) ? null : m.copy();
  }

  Timer? _productSearchDebounce;
  int _productSearchRequestId = 0;
  // The exact text the current [filteredProducts] was searched with. Enter
  // may only trust that list when it still matches what is in the box.
  String? _loadedProductQuery;
  // A scanner may send Enter twice (CR + LF); ignore the second while the
  // first is still resolving.
  bool _productSubmitInFlight = false;
  // Codes scanned while the add-product prompt was open (a different product
  // than the one being added); each opens its own prompt in turn afterwards.
  final List<String> _queuedScans = [];
  // While the add-product prompt is open, scans are delegated to it.
  void Function(String code)? _addPromptScan;
  late final ScannerCapture _scanner;
  static const int _productFetchLimit = 30;
  static const int _customerFetchLimit = 30;

  /// Puts [c] into the local customer list (replaced by id, else prepended)
  /// instead of re-fetching every customer after one add/edit — the list is
  /// only ever the first [_customerFetchLimit] anyway (Issues.md #43).
  void _upsertLocalCustomer(Customer c) {
    customers = customers.any((x) => x.id == c.id)
        ? [for (final x in customers) x.id == c.id ? c : x]
        : [c, ...customers];
  }
  List<InvoiceItem> invoiceItems = [];
  final Set<String> _savedAdHocIds =
      {}; // tracks custom item IDs already saved to products
  final List<({TextEditingController label, TextEditingController amount})>
      _additionalCostControllers = [];
  bool _showAdditionalCosts = false;
  InvoiceDiscountType _invoiceDiscountType = InvoiceDiscountType.percent;
  final _invoiceDiscountController = TextEditingController();

  final notesController = TextEditingController();
  final customInvoiceNumberController = TextEditingController();
  bool _hideInvoiceNumber = false;
  final searchController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final gstinController = TextEditingController();
  final businessNameController = TextEditingController();
  final taxRateController = TextEditingController();
  final dateController = TextEditingController();
  final dueDateController = TextEditingController();
  DateTime _selectedOrderDate = DateTime.now();
  DateTime? _selectedDueDate;

  final _productScrollController = ScrollController();
  final _invoiceItemsScrollController = ScrollController();

  bool _isTaxEnabled = true;
  bool _isPerItem = false;
  bool _isInterState = false; // India: interstate supply → IGST instead of CGST/SGST
  bool isEditing = false;
  bool _saveAndPrintInFlight = false; // one create-and-print at a time
  // Settings > "Print automatically after creating": when on, Create
  // already prints, so Create ▾ leaves out "Save & Print".
  bool _autoPrintOn = false;
  // Invoice Settings prefix ("INV-") and leading zeros, for the number on
  // the Created screen. Null until loaded.
  String? _numberPrefix;
  bool _numberLeadingZeros = true;
  bool _productArrowed = false; // arrow keys used on the product list

  // The right-hand panel folds to a slim strip, like the left sidebar.
  bool _rightPanelOpen = true;
  static const double _rightPanelWidth = 360;
  static const double _rightStripWidth = 64;
  final ScrollController _itemsHScroll = ScrollController();

  // Customer name box: all customers on focus, narrowing as you type.
  final FocusNode _customerNameFocus = FocusNode();
  final LayerLink _customerNameLink = LayerLink();
  final OverlayPortalController _customerListPortal = OverlayPortalController();
  // Keeps the portal's State (and the text box inside it) alive when the window
  // crosses the wide/narrow breakpoint and the name box is rebuilt elsewhere.
  final GlobalKey _customerPortalKey = GlobalKey();
  final GlobalKey _customerFieldKey = GlobalKey();
  final ScrollController _customerListScroll = ScrollController();
  List<Customer> _customerMatches = const [];
  int _customerHighlight = 0;
  bool _customerArrowed = false; // moved the highlight with the arrow keys
  int _customerMatchRequest = 0;
  Timer? _customerMatchDebounce;
  Timer? _customerBlurTimer;
  // Customer strip above the product search: closed it shows the name alone,
  // open it is one row of name, phone and address. Name, phone and address
  // live ONLY here (the CUSTOMER DETAILS card in the right panel keeps the
  // rest: business name, GSTIN / VAT, email).
  // The saved draft this form belongs to (null = not saved as a draft yet).
  late String? _draftId = widget.draftId;
  bool _savingDraft = false;
  // The quotation this form converts, and whether the form started as a
  // duplicate. Kept here (not read from the widget) so "Create New" can clear
  // them: the next document must not be linked to that quotation too.
  late String? _convertFromId = widget.convertFromQuotationId;
  late bool _fromClone = widget.cloneFrom != null;
  // Right panel: the "Advanced Options" and "Charges & Adjustments" sections.
  bool _advancedOpen = false;
  bool? _chargesOpen; // null = open only when something is filled in
  // Inline editing in the items table: one box per item and field.
  final Map<String, _CellBinding> _qtyBindings = {};
  final Map<String, _CellBinding> _priceBindings = {};
  final Map<String, _CellBinding> _discBindings = {};
  bool isLoading = false;
  // V2: inline product search dropdown (replaces click-to-open popup;
  // the popup dialog is now reserved for the Ctrl+F shortcut only).
  bool _showProductDropdownV2 = false;
  int _highlightedProductIndexV2 = 0;
  final FocusNode _productSearchFocusNodeV2 = FocusNode();
  final ScrollController _productDropdownScrollControllerV2 = ScrollController();

  String invoiceType = 'Invoice';
  String? invoiceTitle;
  double taxRate = Tax.defaultTaxRate;
  Invoice? _invoice;
  String currentInvoiceNumber = "";
  String _currencyCode = 'INR';
  String _currencySymbol = '₹';
  List<UpiEntry> _upiEntries = [];
  UpiEntry? _selectedUpi;
  List<BankAccount> _bankAccounts = [];
  BankAccount? _selectedBankAccount;
  bool _showGstFields = true;
  bool _fractionalQuantity = false;
  String _quantityLabel = '';
  bool _showQuantity = true;
  bool _showPreviousBalance = false;
  bool _showTimeInPdf = false; // order-time field shown only when PDFs print the time
  String _pdfTimeFormat = '24'; // '12' | '24'
  bool _showAliasNameInPdf = false;
  bool _allowDuplicateInvoiceItems = false;
  double _previousBalanceDue = 0.0;
  bool _isPreviousBalanceLoading = false;
  bool _isSavingCustomer = false;
  /// The name box shows the picked customer's name unchanged (no search
  /// list then: a click is to see / edit the details, not to search).
  bool get _nameIsPickedCustomer =>
      selectedCustomer != null &&
      nameController.text.trim() == selectedCustomer!.name.trim();
  int _previousBalanceRequestSerial = 0;
  BusinessType _businessType = BusinessType.both;
  String _datePattern = 'dd/MM/yyyy';
  String _adHocItemType = 'product'; // type for custom items added inline
  String? _cleanFormSnapshot;
  int _pendingInitialLoads = 2;
  // What a fresh form starts with (from the settings); "Create New" goes
  // back to these after a duplicate, draft or conversion.
  String? _defaultInvoiceTitle;
  bool _hideInvoiceNumberByDefault = false;
  bool _taxEnabledByDefault = true;
  bool _perItemTaxByDefault = false;
  String _defaultQuantityLabel = '';
  String _defaultCurrencyCode = 'INR';
  String _defaultCurrencySymbol = '₹';
  // Lines loaded from a saved document, draft or duplicate. They carry no
  // stock of their own (see _availableStock).
  final Set<String> _loadedItemIds = {};
  // Editing: how much of each product the saved document already took from
  // stock. Copied when the form opens, because the table edits those same
  // line objects in place (their quantities change as the user types).
  final Map<String, double> _stockHeldByEdited = {};
  bool _customFieldsEnabled = false;
  List<CustomFieldDef> _customFieldDefs = [];
  Map<String, String> _customFieldValues = {}; // defId -> value, filled via _showCustomFieldsDialogV2
  bool _customFieldsCollapsed = false;

  TaxMode get _taxMode {
    if (!_isTaxEnabled) return TaxMode.none;
    return _isPerItem ? TaxMode.perItem : TaxMode.global;
  }

  @override
  void initState() {
    super.initState();
    Future.wait([
      BackendServices.settings.getSetting(SettingKey.invoicePrefix),
      BackendServices.settings.getSetting(SettingKey.invoiceLeadingZeros),
    ]).then((r) {
      if (!mounted) return;
      final raw = (r[0] ?? 'INV').trim();
      setState(() {
        _numberPrefix = raw.isNotEmpty ? '$raw-' : '';
        _numberLeadingZeros = r[1] != 'false';
      });
    }).catchError((_) {});
    InvoicePdfServices.autoPrintAfterCreateEnabled().then((on) {
      if (mounted && on != _autoPrintOn) setState(() => _autoPrintOn = on);
    });
    // Barcode scanners type into whatever has focus. Watch the keyboard for
    // the whole screen so a scan works with the search box, another box, or
    // nothing focused.
    _scanner = ScannerCapture(isActive: _scannerActive, onScan: _handleScannedCode)
      ..attach();
    widget.guard?.canLeave = _confirmLeaveIfDirty;
    widget.guard?.saveDraftOnTimeout = _saveDraftOnTimeout;
    // V2: close the inline product dropdown a beat after the field loses
    // focus, so a tap on a dropdown row still registers as a selection
    // before the list disappears.
    _productSearchFocusNodeV2.addListener(() {
      // Adding items: the customer box closes to the name.
      if (_productSearchFocusNodeV2.hasFocus && _customerStripOpen) {
        setState(() => _customerStripOpen = false);
      }
      if (!_productSearchFocusNodeV2.hasFocus) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          setState(() => _showProductDropdownV2 = false);
          // Give the keyboard shortcuts their focus back, but never take it
          // from a text box the user has just clicked (a customer field...).
          if (!_productSearchFocusNodeV2.hasFocus &&
              !_aTextBoxHasFocus() &&
              (ModalRoute.of(context)?.isCurrent ?? true)) {
            _screenFocusNode.requestFocus();
          }
        });
      }
    });
    _loadRightPanelPref();
    _customerNameFocus.addListener(() {
      if (_customerNameFocus.hasFocus) {
        _customerArrowed = false;
        _refreshCustomerMatches();
        // Clicking the customer box opens the details (to type them for a
        // walk-in, or to change a picked customer's).
        if (!_customerStripOpen) setState(() => _customerStripOpen = true);
      } else {
        // A beat later, so a tap on a suggestion still registers first.
        _customerBlurTimer?.cancel();
        _customerBlurTimer = Timer(const Duration(milliseconds: 150), () {
          if (!mounted || _customerNameFocus.hasFocus) return;
          _syncCustomerList();
          _returnFocusToScreen();
        });
      }
    });
    taxRateController.text = (taxRate * 100).toStringAsFixed(1);
    // Resolve the document type before the first load so the previewed number
    // uses the right series — Invoice and Quotation have separate sequences,
    // and _loadCustomersAndProducts peeks the next number using invoiceType.
    if (widget.invoiceToEdit == null) {
      if (widget.cloneFrom != null) {
        invoiceType = widget.cloneType ?? widget.cloneFrom!.type;
      } else if (widget.initialType != null) {
        invoiceType = widget.initialType!;
      }
    }
    _loadCustomersAndProducts(widget.invoiceToEdit != null);
    _loadColumnsConfig();
    _selectedOrderDate = DateTime.now();
    dateController.text = DateFormat(_datePattern).format(_selectedOrderDate);
    _setAdditionalNote();
    if (widget.invoiceToEdit != null) {
      _invoice = widget.invoiceToEdit;
      isEditing = true;
      selectedCustomer = _invoice!.customer;
      invoiceItems = List.from(_invoice!.items);
      // A quotation or a declined invoice took no stock.
      if (_invoice!.type != 'Quotation' && _invoice!.status != 'declined') {
        for (final line in _invoice!.items) {
          final q = line.quantity;
          _stockHeldByEdited.update(line.product.id, (held) => held + q,
              ifAbsent: () => q);
        }
      }
      nameController.text = _invoice!.customer.name;
      emailController.text = _invoice!.customer.email;
      phoneController.text = _invoice!.customer.phone;
      addressController.text = _invoice!.customer.address;
      gstinController.text = _invoice!.customer.gstin;
      businessNameController.text = _invoice!.customer.businessName;
      taxRate = _invoice!.taxRate;
      taxRateController.text = (taxRate * 100).toStringAsFixed(1);
      _isTaxEnabled = _invoice!.taxMode != TaxMode.none;
      _isPerItem = _invoice!.taxMode == TaxMode.perItem;
      _isInterState = _invoice!.isInterState;
      invoiceType = _invoice!.type;
      invoiceTitle = _invoice!.invoiceTitle;
      currentInvoiceNumber = _invoice!.invoiceNumber ?? _invoice!.id;
      _selectedOrderDate = _invoice!.date;
      dateController.text = DateFormat(_datePattern).format(_selectedOrderDate);
      if (_invoice!.dueDate != null) {
        _selectedDueDate = _invoice!.dueDate;
        dueDateController.text =
            DateFormat(_datePattern).format(_invoice!.dueDate!);
      }
      _quantityLabel = _invoice!.quantityLabel ?? '';
      _hideInvoiceNumber = _invoice!.hideInvoiceNumber;
      customInvoiceNumberController.text = _invoice!.customInvoiceNumber ?? '';
      for (final c in _invoice!.additionalCosts) {
        _additionalCostControllers.add((
          label: TextEditingController(text: c.label),
          amount: TextEditingController(text: c.amount.toStringAsFixed(2)),
        ));
      }
      if (_additionalCostControllers.isNotEmpty) _showAdditionalCosts = true;
      _customFieldValues = {
        for (final cf in _invoice!.customFields) cf.defId: cf.value,
      };
      _invoiceDiscountType = _invoice!.invoiceDiscountType;
      if (_invoice!.invoiceDiscountValue > 0) {
        _invoiceDiscountController.text =
            _invoice!.invoiceDiscountValue.toStringAsFixed(2);
      }
    } else if (widget.cloneFrom != null) {
      // Clone: pre-populate fields but treat as a brand-new invoice.
      // isEditing stays false → _createInvoice() will be called on save.
      final src = widget.cloneFrom!;
      selectedCustomer = src.customer;
      invoiceItems = src.items
          .map((i) => InvoiceItem(
                product: i.product,
                quantity: i.quantity,
                discount: i.discount,
                unitPrice: i.unitPrice,
                extraCost: i.extraCost,
                unit: i.unit,
                description: i.description,
                metadata: i.metadata,
                discountPerUnit: i.discountPerUnit,
                isProductSaved: i.isProductSaved,
              ))
          .toList();
      nameController.text = src.customer.name;
      emailController.text = src.customer.email;
      phoneController.text = src.customer.phone;
      addressController.text = src.customer.address;
      gstinController.text = src.customer.gstin;
      businessNameController.text = src.customer.businessName;
      taxRate = src.taxRate;
      taxRateController.text = (taxRate * 100).toStringAsFixed(1);
      _isTaxEnabled = src.taxMode != TaxMode.none;
      _isPerItem = src.taxMode == TaxMode.perItem;
      _isInterState = src.isInterState;
      invoiceType = widget.cloneType ?? src.type;
      invoiceTitle = invoiceType == src.type ? src.invoiceTitle : null;
      _quantityLabel = src.quantityLabel ?? '';
      // Custom PDF number is invoice-specific; don't carry it into a clone.
      // Same reasoning for custom fields (Vehicle No, Delivery Note, etc.) —
      // shipment-specific, left blank for the user to fill fresh.
      for (final c in src.additionalCosts) {
        _additionalCostControllers.add((
          label: TextEditingController(text: c.label),
          amount: TextEditingController(text: c.amount.toStringAsFixed(2)),
        ));
      }
      if (_additionalCostControllers.isNotEmpty) _showAdditionalCosts = true;
      _invoiceDiscountType = src.invoiceDiscountType;
      if (src.invoiceDiscountValue > 0) {
        _invoiceDiscountController.text =
            src.invoiceDiscountValue.toStringAsFixed(2);
      }
      // date stays as today; currentInvoiceNumber is generated in _loadCustomersAndProducts
      if (widget.draftId != null) {
        // A draft comes back exactly as it was saved (a duplicate starts
        // fresh): its dates, the PDF number and the custom fields too.
        _selectedOrderDate = src.date;
        _selectedDueDate = src.dueDate;
        _hideInvoiceNumber = src.hideInvoiceNumber;
        customInvoiceNumberController.text = src.customInvoiceNumber ?? '';
        _customFieldValues = {
          for (final cf in src.customFields) cf.defId: cf.value,
        };
        invoiceTitle = src.invoiceTitle;
      }
    }
    _loadedItemIds.addAll(invoiceItems.map((i) => i.id));
  }

  @override
  void didUpdateWidget(covariant CreateInvoiceScreenModern oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guard != widget.guard) {
      if (oldWidget.guard?.canLeave == _confirmLeaveIfDirty) {
        oldWidget.guard?.canLeave = null;
      }
      if (oldWidget.guard?.saveDraftOnTimeout == _saveDraftOnTimeout) {
        oldWidget.guard?.saveDraftOnTimeout = null;
      }
      widget.guard?.canLeave = _confirmLeaveIfDirty;
      widget.guard?.saveDraftOnTimeout = _saveDraftOnTimeout;
    }
  }

  Future<void> _setAdditionalNote({bool forceDefault = false}) async {
    final String addNote;
    if (!forceDefault && widget.invoiceToEdit != null) {
      addNote = widget.invoiceToEdit!.notes ?? '';
    } else if (!forceDefault && widget.cloneFrom != null) {
      addNote = widget.cloneFrom!.notes ?? '';
    } else {
      if(!mounted) return;
      addNote = await ref.read(settingsRepositoryProvider).getSetting(SettingKey.additionalInfo) ??
          ref.read(appEditionConfigProvider).additionalNote;
    }
    if(!mounted) return;
    final taxRateSetting = await ref.read(settingsRepositoryProvider).getSetting(SettingKey.defaultTaxRate);
    final parsedRate = double.tryParse(taxRateSetting ?? '') ?? 18.0;
    // forceDefault: "Create New" after an edit, duplicate, draft or
    // conversion starts from the company's rate, not the source's.
    if (forceDefault ||
        (widget.invoiceToEdit == null && widget.cloneFrom == null)) {
      taxRate = parsedRate / 100.0;
      taxRateController.text = parsedRate.toStringAsFixed(1);
    }
    if(!mounted) return;
    setState(() {
      notesController.text = addNote;
    });
    _completeInitialLoad();
  }

  @override
  void dispose() {
    for (final m in [_qtyBindings, _priceBindings, _discBindings]) {
      for (final b in m.values) {
        b.controller.dispose();
      }
    }
    _scanner.detach();
    _screenFocusNode.dispose();
    _productSearchFocusNodeV2.dispose();
    _customerMatchDebounce?.cancel();
    _customerBlurTimer?.cancel();
    _itemsHScroll.dispose();
    _customerNameFocus.dispose();
    _customerListScroll.dispose();
    _productDropdownScrollControllerV2.dispose();
    _productSearchDebounce?.cancel();
    if (widget.guard?.canLeave == _confirmLeaveIfDirty) {
      widget.guard?.canLeave = null;
    }
    if (widget.guard?.saveDraftOnTimeout == _saveDraftOnTimeout) {
      widget.guard?.saveDraftOnTimeout = null;
    }
    notesController.dispose();
    customInvoiceNumberController.dispose();
    searchController.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    taxRateController.dispose();
    dateController.dispose();
    dueDateController.dispose();
    _productScrollController.dispose();
    _invoiceItemsScrollController.dispose();
    gstinController.dispose();
    businessNameController.dispose();
    for (final row in _additionalCostControllers) {
      row.label.dispose();
      row.amount.dispose();
    }
    _invoiceDiscountController.dispose();
    super.dispose();
  }

  Future<void> _loadRightPanelPref() async {
    try {
      final v = await ref
          .read(settingsRepositoryProvider)
          .getSetting(SettingKey.modernRightPanelOpen);
      if (!mounted || v != 'false') return;
      setState(() => _rightPanelOpen = false);
    } catch (_) {/* keep the default: open */}
  }

  void _toggleRightPanel() {
    if (!mounted) return;
    setState(() => _rightPanelOpen = !_rightPanelOpen);
    ref
        .read(settingsRepositoryProvider)
        .setSetting(SettingKey.modernRightPanelOpen, _rightPanelOpen.toString());
  }

  /// Ctrl+S / Ctrl+P / F11 only reach the screen while it holds the focus, so
  /// hand it back once the cashier is done with a text box (never taking it
  /// from another text box, a dialog, or the product search).
  void _returnFocusToScreen() {
    if (!mounted) return;
    if (_productSearchFocusNodeV2.hasFocus || _aTextBoxHasFocus()) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    _screenFocusNode.requestFocus();
  }

  bool _aTextBoxHasFocus() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.findAncestorStateOfType<EditableTextState>() != null ||
        (ctx is StatefulElement && ctx.state is EditableTextState);
  }

  void _completeInitialLoad() {
    if (_pendingInitialLoads <= 0) return;
    _pendingInitialLoads--;
    if (_pendingInitialLoads == 0) {
      _markFormClean();
    }
  }

  void _markFormClean() {
    _cleanFormSnapshot = _currentFormSnapshot();
  }

  bool get _hasUnsavedChanges {
    if (!isEditing && _invoice != null) return false;
    final clean = _cleanFormSnapshot;
    if (clean == null) return false;
    return _currentFormSnapshot() != clean;
  }

  String _currentFormSnapshot() {
    return jsonEncode({
      'mode': widget.invoiceToEdit != null
          ? 'edit:${widget.invoiceToEdit!.id}'
          : widget.cloneFrom != null
              ? 'clone:${widget.cloneFrom!.id}:$invoiceType'
              : 'create',
      'selectedCustomerId': selectedCustomer?.id ?? '',
      'customer': {
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
        'gstin': gstinController.text.trim(),
        'businessName': businessNameController.text.trim(),
      },
      'items': invoiceItems.map((item) {
        final product = item.product;
        return {
          'productId': product.id,
          'name': product.name,
          'price': product.price,
          'unitPrice': item.effectivePrice,
          // The unit that prints: picking the product's own unit again (or
          // pressing Update in the edit dialog) is not a change.
          'unit': item.effectiveUnit.trim(),
          'description': item.effectiveDescription,
          'quantity': item.quantity,
          'discount': item.discount,
          'discountPerUnit': item.discountPerUnit,
          'extraCost': item.extraCost ?? 0.0,
          'taxRate': product.tax_rate,
          'hsn': product.hsncode,
          'type': product.type,
          'isProductSaved': item.isProductSaved,
        };
      }).toList(),
      'additionalCosts': _additionalCostControllers
          .map((row) => {
                'label': row.label.text.trim(),
                'amount': row.amount.text.trim(),
              })
          .toList(),
      'showAdditionalCosts': _showAdditionalCosts,
      'notes': notesController.text.trim(),
      'invoiceType': invoiceType,
      'taxEnabled': _isTaxEnabled,
      'perItemTax': _isPerItem,
      'interState': _isInterState,
      'taxRate': taxRate,
      'taxRateText': taxRateController.text.trim(),
      'date': _selectedOrderDate.toIso8601String(),
      'dueDate': _selectedDueDate?.toIso8601String() ?? '',
      'currencyCode': _currencyCode,
      'upiId': _selectedUpi?.id ?? '',
      'bankAccount': _selectedBankAccount?.accountNumber ?? '',
      'quantityLabel': _quantityLabel.trim(),
      'hideInvoiceNumber': _hideInvoiceNumber,
      'customInvoiceNumber': customInvoiceNumberController.text.trim(),
      'invoiceTitle': invoiceTitle ?? '',
      'invoiceDiscountType': _invoiceDiscountType.name,
      'invoiceDiscountValue': _invoiceDiscountController.text.trim(),
      // Only filled-in values: opening and saving the dialog with nothing
      // typed is not a change.
      'customFields': {
        for (final e in _customFieldValues.entries)
          if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
      },
    });
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_hasUnsavedChanges || isLoading) return true;

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.createInvoiceUnsavedChangesTitle),
        content: Text(
          AppLocalizations.of(context)!.createInvoiceUnsavedChangesMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'keep'),
            child: Text(AppLocalizations.of(context)!.createInvoiceKeepEditingButton),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'discard'),
            child: Text(AppLocalizations.of(context)!.actionDiscard),
          ),
          // A new document can be kept as a draft instead (not when editing
          // a saved one).
          if (widget.invoiceToEdit == null)
            OutlinedButton.icon(
              key: const ValueKey('leaveSaveDraft'),
              onPressed: () => Navigator.pop(dialogContext, 'draft'),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(AppLocalizations.of(context)!.mInvSaveDraft),
            ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'save'),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(AppLocalizations.of(context)!.actionSave),
          ),
        ],
      ),
    );

    switch (action) {
      case 'discard':
        return true;
      case 'draft':
        return await _saveDraft();
      case 'save':
        return widget.invoiceToEdit != null
            ? await _updateInvoice()
            : await _createInvoice();
      default:
        return false;
    }
  }

  Future<void> _loadCustomersAndProducts(bool isEditing) async {
    if(!mounted) return;
    setState(() => isLoading = true);

    try {
      final settingsRepo = ref.read(settingsRepositoryProvider);
      final results = await Future.wait([
        ref.read(customerRepositoryProvider).getCustomersPaginated(
            offset: 0, limit: _customerFetchLimit), // 0
        ref.read(productRepositoryProvider).getProductsPaginated(
            offset: 0, limit: _productFetchLimit, type: _businessType.key), // 1
        isEditing
            ? Future.value(widget.invoiceToEdit?.invoiceNumber ?? widget.invoiceToEdit?.id)
            : ref.read(invoiceRepositoryProvider).peekNextInvoiceNumber(invoiceType), // 2
        settingsRepo.getCurrency(), // 3 — discarded below when editing/cloning
        settingsRepo.getUpiIds(), // 4
        settingsRepo.getBankAccounts(), // 5
        settingsRepo.getShowGstFields(), // 6
        settingsRepo.getFractionalQuantity(), // 7
        settingsRepo.getQuantityLabel(), // 8
        settingsRepo.getShowQuantity(), // 9
        settingsRepo.getBusinessType(), // 10
        settingsRepo.getDateFormat(), // 11
        settingsRepo.getShowPreviousBalance(), // 12
        settingsRepo.getShowAliasNameInPdf(), // 13
        settingsRepo.getShowTaxButtonInInvoicePage(), // 14
        settingsRepo.getDefaultInvoiceTitle(), // 15
        settingsRepo.getAllowDuplicateInvoiceItems(), // 16
        settingsRepo.getDefaultTaxMode(), // 17
        settingsRepo.getHideInvoiceNumberByDefault(), // 18
        settingsRepo.getSetting(SettingKey.customFieldsEnabled), // 19
        settingsRepo.getCustomFieldDefs(), // 20
        settingsRepo.getShowTimeInPdf(), // 21
        settingsRepo.getPdfTimeFormat(), // 22
      ]);

      final c = results[0] as List<Customer>;
      final p = results[1] as List<Product>;
      final metadataIds = {
        ...p.map((e) => e.id),
        ...invoiceItems.map((e) => e.product.id),
      }.toList();
      final productMetadata = await ref
          .read(productRepositoryProvider)
          .getProductMetadataForIds(metadataIds);
      final invNumber = results[2] as String?;

      // Use the existing invoice's currency when editing or cloning,
      // otherwise fall back to the current app-wide currency setting.
      final settingsCurrency = results[3] as CurrencyOption;
      final String loadedCurrencyCode;
      final String loadedCurrencySymbol;
      if (isEditing && widget.invoiceToEdit != null) {
        loadedCurrencyCode = widget.invoiceToEdit!.currencyCode;
        loadedCurrencySymbol = widget.invoiceToEdit!.currencySymbol;
      } else if (widget.cloneFrom != null) {
        loadedCurrencyCode = widget.cloneFrom!.currencyCode;
        loadedCurrencySymbol = widget.cloneFrom!.currencySymbol;
      } else {
        loadedCurrencyCode = settingsCurrency.code;
        loadedCurrencySymbol = settingsCurrency.symbol;
      }

      final upiEntries = results[4] as List<UpiEntry>;
      final bankAccounts = results[5] as List<BankAccount>;
      final showGst = results[6] as bool;
      final fractionalQty = results[7] as bool;
      final quantityLabelSetting = results[8] as String;
      final showQuantity = results[9] as bool;
      final businessType = results[10] as BusinessType;
      final dateFormatOpt = results[11] as DateFormatOption;
      final showPrevBalance = results[12] as bool;
      final showAliasNameInPdf = results[13] as bool;
      final showTaxButtonInInvoicePage = results[14] as bool;
      final defaultInvoiceTitle = results[15] as String?;
      final allowDuplicateInvoiceItems = results[16] as bool;
      final defaultTaxMode = results[17] as String;
      final hideInvoiceNumberByDefault = results[18] as bool;
      final customFieldsEnabled = (results[19] as String?) == 'true';
      final customFieldDefs = results[20] as List<CustomFieldDef>;
      final showTimeInPdf = results[21] as bool;
      final pdfTimeFormat = results[22] as String;

      // Determine which UPI to pre-select.
      String? existingUpiId;
      if (isEditing && widget.invoiceToEdit != null) {
        existingUpiId = widget.invoiceToEdit!.upiId;
      } else if (widget.cloneFrom != null) {
        existingUpiId = widget.cloneFrom!.upiId;
      }

      UpiEntry? preselectedUpi;
      if (existingUpiId != null && existingUpiId.isNotEmpty) {
        preselectedUpi =
            upiEntries.where((e) => e.id == existingUpiId).firstOrNull;
      }
      preselectedUpi ??= upiEntries.where((e) => e.isDefault).firstOrNull ??
          upiEntries.firstOrNull;

      // Determine which bank account to pre-select.
      String? existingBankId;
      if (isEditing && widget.invoiceToEdit != null) {
        existingBankId = widget.invoiceToEdit!.bankAccountId;
      } else if (widget.cloneFrom != null) {
        existingBankId = widget.cloneFrom!.bankAccountId;
      }
      BankAccount? preselectedBank;
      if (existingBankId != null && existingBankId.isNotEmpty) {
        preselectedBank = bankAccounts
            .where((e) => e.accountNumber == existingBankId)
            .firstOrNull;
      }
      preselectedBank ??= bankAccounts.where((e) => e.isDefault).firstOrNull ??
          bankAccounts.firstOrNull;

      // Pre-mark custom items that were already saved to the product list,
      // using the persisted is_product_saved flag on each InvoiceItem.
      _savedAdHocIds.addAll(
        invoiceItems
            .where((item) =>
                item.product.id.startsWith('custom-') && item.isProductSaved)
            .map((item) => item.product.id),
      );
      if(!mounted) return;
      setState(() {
        customers = c;
        products = p;
        filteredProducts = List.from(p);
        _productMetadata = productMetadata;
        if (invNumber != null) {
          currentInvoiceNumber = invNumber;
        }
        _currencyCode = loadedCurrencyCode;
        _currencySymbol = loadedCurrencySymbol;
        _upiEntries = upiEntries;
        _selectedUpi = preselectedUpi;
        _bankAccounts = bankAccounts;
        _selectedBankAccount = preselectedBank;
        _showGstFields = showGst;
        _fractionalQuantity = fractionalQty;
        _showQuantity = showQuantity;
        _showPreviousBalance = showPrevBalance;
        _showAliasNameInPdf = showAliasNameInPdf;
        _allowDuplicateInvoiceItems = allowDuplicateInvoiceItems;
        _defaultInvoiceTitle = defaultInvoiceTitle;
        _hideInvoiceNumberByDefault = hideInvoiceNumberByDefault;
        _taxEnabledByDefault = showTaxButtonInInvoicePage;
        _perItemTaxByDefault = defaultTaxMode == 'perItem';
        _defaultQuantityLabel = quantityLabelSetting;
        _defaultCurrencyCode = settingsCurrency.code;
        _defaultCurrencySymbol = settingsCurrency.symbol;
        if (!isEditing && widget.cloneFrom == null) {
          _isTaxEnabled = showTaxButtonInInvoicePage;
          _isPerItem = defaultTaxMode == 'perItem';
          _hideInvoiceNumber = hideInvoiceNumberByDefault;
        }
        _customFieldsEnabled = customFieldsEnabled;
        _customFieldDefs = customFieldDefs;
        _businessType = businessType;
        _adHocItemType =
            businessType == BusinessType.service ? 'service' : 'product';
        // For new invoices, use the global setting. Edit/clone already set _quantityLabel in initState.
        if (!isEditing && widget.cloneFrom == null) {
          _quantityLabel = quantityLabelSetting;
          invoiceTitle = invoiceType == 'Invoice' ? defaultInvoiceTitle : null;
        }
        // A quotation converted (or duplicated) into an invoice has no
        // title of its own yet: give it the company's default one.
        if (widget.cloneFrom != null &&
            widget.draftId == null &&
            invoiceType == 'Invoice' &&
            widget.cloneFrom!.type != 'Invoice') {
          invoiceTitle = defaultInvoiceTitle;
        }
        _datePattern = dateFormatOpt.key;
        _showTimeInPdf = showTimeInPdf;
        _pdfTimeFormat = pdfTimeFormat;
        dateController.text =
            DateFormat(_datePattern).format(_selectedOrderDate);
        if (_selectedDueDate != null) {
          dueDateController.text =
              DateFormat(_datePattern).format(_selectedDueDate!);
        }
        isLoading = false;
      });
      // Edit/clone may have preloaded selectedCustomer from an invoice
      // snapshot whose id was never actually saved to the customers table
      // (see _resolveInvoiceCustomer). Confirm it still exists so the UI
      // doesn't silently treat an unsaved customer as saved.
      if ((isEditing || widget.cloneFrom != null) && selectedCustomer != null) {
        final stillExists = await ref
            .read(customerRepositoryProvider)
            .getCustomerById(selectedCustomer!.id);
        if (!mounted) return;
        if (stillExists == null) {
          setState(() => selectedCustomer = null);
        }
      }
      if (showPrevBalance && selectedCustomer != null) {
        await _loadPreviousBalanceDue(selectedCustomer);
      }
      _completeInitialLoad();
    } catch (e) {
      if(!mounted) return;
      setState(() => isLoading = false);
      _completeInitialLoad();
      if (mounted) {
        if(kDebugMode) print(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.createInvoiceErrorLoadingDataMessage(e.toString())),showCloseIcon: true,),
        );
      }
    }
  }

  void addInvoiceProductPrompt(Product product)
  {
    final quantityController = TextEditingController();
    final discountController = TextEditingController(
        text: product.defaultDiscount > 0
            ? product.defaultDiscount.toString()
            : '0');
    final unitPriceController =
        TextEditingController(text: product.price.toString());
    final extraCostController = TextEditingController();
    final unitController = TextEditingController(text: product.unit);
    // Seed from the product's own description so the user starts from it and
    // can tweak it for this line; what they leave is snapshotted on the item.
    // Only when the field is actually shown, else nothing is silently stored.
    final descriptionController = TextEditingController(
        text: _showDescriptionInPdf ? product.description : '');

    bool discountPerUnit = true;
    String dialogUnit = product.unit;
    int insertAt = invoiceItems.length + 1;

    // A scan while this prompt is open must not become the quantity (it used
    // to: scanning twice gave e.g. 1001 units). The screen-wide scanner
    // capture delivers it here instead.
    _addPromptScan = (code) {
      final own = product.hsncode.trim().toLowerCase();
      if (own.isNotEmpty && code.trim().toLowerCase() == own) {
        // The item being added, scanned again: one more of it.
        final next = (double.tryParse(quantityController.text) ?? 1.0) + 1;
        final text = next == next.roundToDouble()
            ? next.toInt().toString()
            : next.toString();
        quantityController.value = TextEditingValue(
            text: text, selection: TextSelection.collapsed(offset: text.length));
      } else {
        _queuedScans.add(code);
      }
    };

    Future<void> addInvoiceProductImpl() async
    {
      final typedQty = !_showQuantity
          ? 1.0
          : _fractionalQuantity
          ? (double.tryParse(quantityController.text) ?? 1.0)
          : (int.tryParse(quantityController.text) ?? 1)
          .toDouble();
      // 0 or less is not a sale: use 1, as the table's quantity cell does.
      final qty = typedQty > 0 ? typedQty : 1.0;
      final discount =
          double.tryParse(discountController.text) ?? 0.0;
      final parsedUnitPrice =
      double.tryParse(unitPriceController.text);
      final unitPrice = (parsedUnitPrice != null &&
          parsedUnitPrice != product.price)
          ? parsedUnitPrice
          : null;
      final extraCost = double.tryParse(extraCostController.text);

      // Check stock
      if (!product.unlimitedStock &&
          product.stock > 0 &&
          qty > product.stock) {
        // Insufficient stock — ask user if they want to add anyway
        Navigator.pop(context);
        final addAnyway = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.createInvoiceInsufficientStockTitle),
            content: Text(
              AppLocalizations.of(context)!.createInvoiceInsufficientStockMessage(
                  AppFormatters.formatStock(product.stock), AppFormatters.formatStock(qty)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.actionCancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange),
                child: Text(AppLocalizations.of(context)!.createInvoiceAddAnywayButton),
              ),
            ],
          ),
        );
        _screenFocusNode.requestFocus();
        if (addAnyway == true) {
          addInvoiceProduct(
              InvoiceItem(
                  product: product,
                  quantity: qty,
                  discount: discount,
                  unitPrice: unitPrice,
                  extraCost: extraCost,
                  unit: dialogUnit.trim(),
                  description: descriptionController.text.trim(),
                  metadata: _snapshotMetadata(product.id),
                  discountPerUnit: discountPerUnit),
              insertAt: insertAt);
        }
      } else if (!product.unlimitedStock && product.stock <= 0) {
        Navigator.pop(context);
        final addAnyway = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.createInvoiceOutOfStockTitle),
            content:
            Text(AppLocalizations.of(context)!.createInvoiceOutOfStockMessage(product.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(context)!.actionCancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange),
                child: Text(AppLocalizations.of(context)!.createInvoiceAddAnywayButton),
              ),
            ],
          ),
        );
        _screenFocusNode.requestFocus();
        if (addAnyway == true) {
          addInvoiceProduct(
              InvoiceItem(
                  product: product,
                  quantity: qty,
                  discount: discount,
                  unitPrice: unitPrice,
                  extraCost: extraCost,
                  unit: dialogUnit.trim(),
                  description: descriptionController.text.trim(),
                  metadata: _snapshotMetadata(product.id),
                  discountPerUnit: discountPerUnit),
              insertAt: insertAt);
        }
      } else {
        Navigator.pop(context);
        addInvoiceProduct(
            InvoiceItem(
                product: product,
                quantity: qty,
                discount: discount,
                unitPrice: unitPrice,
                extraCost: extraCost,
                unit: dialogUnit.trim(),
                description: descriptionController.text.trim(),
                metadata: _snapshotMetadata(product.id),
                discountPerUnit: discountPerUnit),
            insertAt: insertAt);
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) =>
        AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shopping_cart,
                    color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${product.name} ($_currencySymbol ${product.price})',
                  style: const TextStyle(fontSize: AppFontSize.xlarge),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (product.unlimitedStock)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      border: Border.all(color: Colors.green[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.all_inclusive,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.createInvoiceUnlimitedStockLabel,
                            style: const TextStyle(color: Colors.green)),
                      ],
                    ),
                  )
                else if (product.stock <= 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.createInvoiceOutOfStockTitle,
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      border: Border.all(color: Colors.green[200]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.createInvoiceAvailableStockLabel(
                                AppFormatters.formatStock(product.stock)),
                            style: const TextStyle(color: Colors.green)),
                      ],
                    ),
                  ),
                Builder(builder: (context) {
                  if (!_columnsConfig.productMetadata) return const SizedBox.shrink();
                  final meta = _productMetadata[product.id];
                  final expiryDate = (_columnsConfig.metaExpiryDate &&
                          (meta?.expiryDate?.isNotEmpty ?? false))
                      ? DateTime.tryParse(meta!.expiryDate!)
                      : null;
                  final isExpired =
                      expiryDate != null && expiryDate.isBefore(DateTime.now());
                  final storageLocation =
                      _columnsConfig.metaStorageLocation ? meta?.storageLocation : null;
                  if ((storageLocation == null || storageLocation.isEmpty) &&
                      expiryDate == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (storageLocation != null && storageLocation.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.place_outlined,
                                size: 14, color: Colors.blueGrey),
                            label: Text(storageLocation,
                                style: const TextStyle(fontSize: AppFontSize.xsmall)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: Colors.blueGrey[50],
                          ),
                        if (expiryDate != null)
                          Chip(
                            avatar: Icon(
                                isExpired ? Icons.error_outline : Icons.event_outlined,
                                size: 14,
                                color: isExpired ? Colors.red : Colors.orange[800]),
                            label: Text(
                                _expiryText(expiryDate, isExpired),
                                style: TextStyle(
                                    fontSize: AppFontSize.xsmall,
                                    color: isExpired ? Colors.red : null)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: isExpired ? Colors.red[50] : Colors.orange[50],
                          ),
                      ],
                    ),
                  );
                }),
                if (_showQuantity) ...[
                  TextField(
                    controller: quantityController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: _quantityLabel.trim().isNotEmpty
                          ? _quantityLabel.trim()
                          : AppLocalizations.of(context)!.createInvoiceQuantityLabel,
                      hintText: '1',
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.xsmall)),
                      prefixIcon: const Icon(Icons.numbers),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    keyboardType: _fractionalQuantity
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onSubmitted: (_) => addInvoiceProductImpl(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_showQuantity && _columnsConfig.unit) ...[
                  _buildUnitPicker(
                    selectedUnit: dialogUnit,
                    customController: unitController,
                    onUnitChanged: (v) => setDialogState(() => dialogUnit = v),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_columnsConfig.defaultDiscount || product.defaultDiscount > 0) ...[
                  TextField(
                    controller: discountController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldDiscountLabel,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.xsmall)),
                      prefixIcon: const Icon(Icons.discount),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDiscountPerUnitToggle(discountPerUnit,
                      (val) => setDialogState(() => discountPerUnit = val)),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: unitPriceController,
                  autofocus: !_showQuantity,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.fieldUnitPriceOverrideLabel,
                    helperText: AppLocalizations.of(context)!
                        .createInvoiceDefaultPriceHelper('$_currencySymbol${product.price}'),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.xsmall)),
                    prefixText: '$_currencySymbol ',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onSubmitted: (_) => addInvoiceProductImpl(),
                ),
                if (_columnsConfig.extraCost) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: extraCostController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldExtraCostLabel,
                      hintText: '0.00',
                      helperText: AppLocalizations.of(context)!.createInvoiceExtraCostHelper,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.xsmall)),
                      prefixIcon: const Icon(Icons.add_circle_outline, size: 18),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ],
                if (_showDescriptionInPdf) ...[
                  const SizedBox(height: 16),
                  _buildItemDescriptionField(descriptionController),
                ],
                if (invoiceItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.format_list_numbered,
                          size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.fieldInsertAtPositionLabel,
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: insertAt > 1
                            ? () => setDialogState(() => insertAt--)
                            : null,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text('$insertAt',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: insertAt < invoiceItems.length + 1
                            ? () => setDialogState(() => insertAt++)
                            : null,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.actionCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => addInvoiceProductImpl(),
              child: Text(AppLocalizations.of(context)!.actionAdd),
            ),
          ],
        ),
      ),
    ).then((_) {
      _addPromptScan = null;
      if (!mounted) return;
      // Back to the search box (not the bare screen), so the next barcode
      // scan is typed straight into it. The product list stays closed until
      // the cashier clicks the box or starts typing.
      _productSearchFocusNodeV2.requestFocus();
      _runQueuedScan();
    });
  }

  /// Scans are ours while this screen is on top, or while its add-product
  /// prompt (a dialog above it) is open. Other dialogs and screens keep their
  /// keyboard input to themselves.
  bool _scannerActive() {
    if (!mounted) return false;
    if (!isEditing && _invoice != null) return false; // 'invoice saved' screen
    if (_addPromptScan != null) return true;
    return ModalRoute.of(context)?.isCurrent ?? false;
  }

  /// A barcode was scanned (see [ScannerCapture]): look the product up and
  /// open its quantity prompt, whichever box had focus.
  void _handleScannedCode(String code) {
    if (!mounted) return;
    final promptScan = _addPromptScan;
    if (promptScan != null) {
      promptScan(code);
      return;
    }
    _productSearchDebounce?.cancel();
    _productSearchRequestId++;
    setState(() => _showProductDropdownV2 = false);
    searchController.text = code; // shows what was scanned
    _submitProductSearch().then((found) {
      if (found || !mounted) return;
      searchController.clear();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(
            '${AppLocalizations.of(context)!.createInvoiceNoProductsFoundMessage}: $code'),
      ));
    });
  }

  /// Opens the prompt for the next product scanned while another prompt was
  /// open, if any.
  void _runQueuedScan() {
    if (_queuedScans.isEmpty || !mounted) return;
    searchController.text = _queuedScans.removeAt(0);
    _submitProductSearch();
  }

  void addInvoiceProduct(InvoiceItem invoiceItem, {int? insertAt}) {
    final isAdHoc = invoiceItem.product.id.startsWith('custom-');
    final exists = !isAdHoc &&
        !_allowDuplicateInvoiceItems &&
        invoiceItems.any((item) => item.product.id == invoiceItem.product.id);

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.createInvoiceProductAlreadyAddedMessage),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        ),
      );
    } else {
      final isAppend = insertAt == null || insertAt >= invoiceItems.length + 1;
      if(!mounted) return;
      setState(() {
        if (!isAppend) {
          invoiceItems.insert(insertAt - 1, invoiceItem);
        } else {
          invoiceItems.add(invoiceItem);
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_invoiceItemsScrollController.hasClients && isAppend) {
          _invoiceItemsScrollController.animateTo(
            _invoiceItemsScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Builds the Customer to attach to the invoice. If the form fields no
  /// longer match `selectedCustomer`'s saved record (edited but not saved
  /// via _saveCustomer), the invoice must NOT keep pointing at that
  /// customer's id — doing so would link invoiceId -> customerId while the
  /// snapshot's name/address/etc silently disagree with that customer's
  /// actual row. Falls back to a fresh, unlinked id in that case.
  /// Address is excluded (edited often, not identity-bearing) and the rest
  /// compare case-insensitively so minor casing/whitespace edits don't
  /// fragment the same customer into a new id.
  bool get _customerFormMatchesSelected {
    final sel = selectedCustomer;
    if (sel == null) return false;
    bool eq(String a, String b) => a.trim().toLowerCase() == b.trim().toLowerCase();
    return eq(sel.name, nameController.text) &&
        eq(sel.email, emailController.text) &&
        eq(sel.phone, phoneController.text) &&
        eq(sel.gstin, gstinController.text) &&
        eq(sel.businessName, businessNameController.text);
  }

  Customer _resolveInvoiceCustomer() {
    final name = nameController.text;
    final email = emailController.text;
    final phone = phoneController.text;
    final address = addressController.text;
    final gstin = gstinController.text;
    final businessName = businessNameController.text;

    final matchesSelected = _customerFormMatchesSelected;
    final sel = selectedCustomer;

    return Customer(
      id: matchesSelected ? sel!.id : const Uuid().v4(),
      name: name,
      email: email,
      phone: phone,
      address: address,
      gstin: gstin,
      businessName: businessName,
    );
  }

  /// The document as the form describes it right now. [id] / [number] are
  /// the real ones when creating; a draft has none.
  Invoice _invoiceFromForm({required String id, String? number}) => Invoice(
        id: id,
        invoiceNumber: number,
        customer: _resolveInvoiceCustomer(),
        items: List.from(invoiceItems),
        date: _selectedOrderDate,
        dueDate: _selectedDueDate,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
        taxRate: _taxMode == TaxMode.global ? taxRate : 0.0,
        type: invoiceType,
        invoiceTitle: invoiceType == 'Invoice' ? invoiceTitle : null,
        currencyCode: _currencyCode,
        currencySymbol: _currencySymbol,
        taxMode: _taxMode,
        isInterState: _isInterState,
        upiId: _selectedUpi?.id,
        bankAccountId: _selectedBankAccount?.accountNumber,
        quantityLabel:
            _quantityLabel.trim().isEmpty ? null : _quantityLabel.trim(),
        additionalCosts: _buildAdditionalCosts(),
        customFields: _buildCustomFields(),
        invoiceDiscountType: _invoiceDiscountType,
        invoiceDiscountValue: _invoiceDiscountValue,
        hideInvoiceNumber: _hideInvoiceNumber,
        customInvoiceNumber: customInvoiceNumberController.text.trim().isEmpty
            ? null
            : customInvoiceNumberController.text.trim(),
        convertedFromInvoiceId: _convertFromId,
      );

  /// "Save Draft": keeps the form in the drafts table (not an invoice: no
  /// number, no stock taken, not in reports). Saving again updates the same
  /// draft. True when it was saved. [quiet]: no messages (nobody is there).
  Future<bool> _saveDraft({bool quiet = false}) async {
    final l10n = AppLocalizations.of(context)!;
    if (_savingDraft) return false;
    if (invoiceItems.isEmpty && nameController.text.trim().isEmpty) {
      if (quiet) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.mInvNothingToSave),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true));
      return false;
    }
    setState(() => _savingDraft = true);
    try {
      final repo = ref.read(invoiceDraftRepositoryProvider);
      final id = _draftId ?? repo.newId();
      await repo.saveDraft(InvoiceDraft(
          id: id, invoice: _invoiceFromForm(id: ''), updatedAt: DateTime.now()));
      if (!mounted) return true;
      setState(() => _draftId = id);
      _markFormClean();
      if (quiet) return true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(l10n.mInvDraftSaved),
          ]),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          // above the bottom bar, so its buttons stay usable
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 96),
          duration: const Duration(seconds: 2),
          showCloseIcon: true));
      return true;
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  /// The session timed out (see [InvoiceFormGuard.saveDraftOnTimeout]): keep
  /// a new, changed form as a draft without asking. A saved document being
  /// edited keeps its last saved copy.
  Future<void> _saveDraftOnTimeout() async {
    if (!mounted || widget.invoiceToEdit != null || isEditing) return;
    if (isLoading || !_hasUnsavedChanges) return;
    if (invoiceItems.isEmpty && nameController.text.trim().isEmpty) return;
    try {
      await _saveDraft(quiet: true);
    } catch (e) {
      // Logging out must still go ahead.
      debugPrint('Could not save the draft on timeout: $e');
    }
  }

  /// False (with a message) when a line's total is below zero, for example a
  /// discount bigger than the price.
  bool _linesNotNegative() {
    if (invoiceItems.every((i) => i.total >= 0)) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context)!.createInvoiceNegativeLineMessage),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
    ));
    return false;
  }

  Future<bool> _createInvoice() async {
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.createInvoiceCustomerNameRequiredMessage),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        ),
      );
      return false;
    }

    if (invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.createInvoiceAtLeastOneItemRequiredMessage),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        ),
      );
      return false;
    }
    if (!_linesNotNegative()) return false;

    if(!mounted) return false;
    setState(() => isLoading = true);

    try {
      final invoiceId = await InvoicePdfServices.generateNextId();
      final invoiceNumber =
          await InvoicePdfServices.generateNextInvoiceNumber(invoiceType);
      final invoice = _invoiceFromForm(id: invoiceId, number: invoiceNumber);

      await ref.read(invoiceRepositoryProvider).insertInvoice(invoice);
      unawaited(UsageStatsService.onDocumentCreated(invoice.type));
      final draftId = _draftId;
      if (draftId != null) {
        await ref.read(invoiceDraftRepositoryProvider).deleteDraft(draftId);
        _draftId = null;
      }

      if (!mounted) return true;
      setState(() {
        _invoice = invoice;
        currentInvoiceNumber = invoice.invoiceNumber ?? invoice.id;
        isLoading = false;
      });
      _markFormClean();

      final l10n = AppLocalizations.of(context)!;
      final convertedFromId = _convertFromId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(convertedFromId != null
                    ? l10n.createInvoiceConvertedSuccessMessage(
                        invoice.invoiceNumber ?? invoice.id)
                    : l10n.createInvoiceCreatedSuccessMessage(
                        _invoiceTypeLabel(invoiceType))),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          duration: convertedFromId != null
              ? const Duration(seconds: 8)
              : const Duration(seconds: 4),
          action: convertedFromId == null
              ? null
              : SnackBarAction(
                  label: l10n.createInvoiceTrashQuotationAction,
                  textColor: Colors.white,
                  onPressed: () async {
                    await ref
                        .read(invoiceRepositoryProvider)
                        .softDeleteInvoice(convertedFromId);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(l10n.createInvoiceQuotationTrashedMessage),
                      behavior: SnackBarBehavior.floating,
                      showCloseIcon: true,
                    ));
                  },
                ),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => isLoading = false);
      if (kDebugMode)  print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.createInvoiceErrorCreatingMessage(e.toString())),showCloseIcon: true,),
      );
      return false;
    }
  }

  /// Creates (or, when editing, updates) the invoice and prints it.
  ///
  /// [forcePrint] is for the Ctrl+P / F11 shortcuts ("save and print"): it
  /// always prints. The Create button and Ctrl+S print only a NEW invoice, and
  /// only while "print automatically after creating" is on (the default).
  /// Saving a half-finished form when leaving the screen never goes through
  /// here, so it never prints.
  Future<void> _saveAndMaybePrint(
      {bool forcePrint = false,
      PrintTarget target = PrintTarget.auto,
      bool preview = false,
      bool startNew = false}) async {
    if (_saveAndPrintInFlight || isLoading) return;
    _saveAndPrintInFlight = true;
    try {
      final isEdit = widget.invoiceToEdit != null;
      // Always save first, even when editing an invoice that looks unchanged:
      // printing the stored copy must never hand the customer a bill that
      // differs from the screen.
      final saved = isEdit ? await _updateInvoice() : await _createInvoice();
      if (!saved || !mounted || _invoice == null) return;
      if (preview) {
        await InvoicePdfServices.previewPDF(context, _invoice!);
        return;
      }
      final shouldPrint = forcePrint ||
          (!isEdit && await InvoicePdfServices.autoPrintAfterCreateEnabled());
      if (!shouldPrint || !mounted) {
        if (startNew && !isEdit && mounted) await resetValues(invoiceType);
        return;
      }
      // Let the "Invoice created" page appear before the print dialog does.
      final shown = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!shown.isCompleted) shown.complete();
      });
      WidgetsBinding.instance.scheduleFrame();
      await shown.future.timeout(const Duration(seconds: 2), onTimeout: () {});
      if (!mounted) return;
      await InvoicePdfServices.generatePDF(context, _invoice!, target: target);
      if (startNew && !isEdit && mounted) await resetValues(invoiceType);
    } finally {
      _saveAndPrintInFlight = false;
    }
  }

  /// Ctrl+P / F11. On the finished page it prints; on the form it saves the
  /// invoice first (checking the same things as the Create button) and prints.
  void _saveAndPrintShortcut(bool showingSuccessScreen) {
    if (showingSuccessScreen) {
      if (_invoice != null) InvoicePdfServices.generatePDF(context, _invoice!);
      return;
    }
    if (isLoading) return;
    if (invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .createInvoiceAddItemBeforeCreatingMessage)),
      );
      return;
    }
    _saveAndMaybePrint(forcePrint: true);
  }

  void _editInvoiceItem(int index) {
    final item = invoiceItems[index];
    final quantityController = TextEditingController(
        text: item.quantity == 1.0
            ? ''
            : item.quantity == item.quantity.roundToDouble()
                ? item.quantity.toInt().toString()
                : item.quantity.toString());
    final discountController =
        TextEditingController(text: item.discount.toString());
    final unitPriceController =
        TextEditingController(text: item.effectivePrice.toString());
    final extraCostController = TextEditingController(
        text: item.extraCost != null ? item.extraCost.toString() : '');
    bool discountPerUnit = item.discountPerUnit;
    final unitController = TextEditingController(text: item.effectiveUnit.toString());
    final descriptionController =
        TextEditingController(text: item.effectiveDescription);
    String dialogUnit = item.effectiveUnit.toString();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          // The extra description field can push this past the viewport on
          // short windows; the add-item dialog already scrolls its content.
          scrollable: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit, color: BrandColors.primary),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.createInvoiceEditItemTitle, style: const TextStyle(fontSize: AppFontSize.xlarge)),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: BrandColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.product.type == 'service'
                            ? Icons.design_services_outlined
                            : Icons.inventory_2,
                        color: BrandColors.primaryDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppFontSize.xlarge),
                        ),
                      ),
                      if (_businessType == BusinessType.both &&
                          _columnsConfig.type) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.product.type == 'service'
                                ? Colors.purple.withValues(alpha: 0.15)
                                : BrandColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.product.type == 'service'
                                ? AppLocalizations.of(context)!.labelService
                                : AppLocalizations.of(context)!.labelProduct,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: item.product.type == 'service'
                                  ? Colors.purple[700]
                                  : BrandColors.accentDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Builder(builder: (context) {
                  if (!_columnsConfig.productMetadata) return const SizedBox.shrink();
                  final meta = _productMetadata[item.product.id];
                  final expiryDate = (_columnsConfig.metaExpiryDate &&
                          (meta?.expiryDate?.isNotEmpty ?? false))
                      ? DateTime.tryParse(meta!.expiryDate!)
                      : null;
                  final isExpired =
                      expiryDate != null && expiryDate.isBefore(DateTime.now());
                  final storageLocation =
                      _columnsConfig.metaStorageLocation ? meta?.storageLocation : null;
                  if ((storageLocation == null || storageLocation.isEmpty) &&
                      expiryDate == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (storageLocation != null && storageLocation.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.place_outlined,
                                size: 14, color: Colors.blueGrey),
                            label: Text(storageLocation,
                                style: const TextStyle(fontSize: AppFontSize.xsmall)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: Colors.blueGrey[50],
                          ),
                        if (expiryDate != null)
                          Chip(
                            avatar: Icon(
                                isExpired ? Icons.error_outline : Icons.event_outlined,
                                size: 14,
                                color: isExpired ? Colors.red : Colors.orange[800]),
                            label: Text(
                                _expiryText(expiryDate, isExpired),
                                style: TextStyle(
                                    fontSize: AppFontSize.xsmall,
                                    color: isExpired ? Colors.red : null)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: isExpired ? Colors.red[50] : Colors.orange[50],
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
                if (_showQuantity) ...[
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: _quantityLabel.trim().isNotEmpty
                          ? _quantityLabel.trim()
                          : AppLocalizations.of(context)!.createInvoiceQuantityLabel,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.xsmall)),
                      prefixIcon: const Icon(Icons.numbers),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    keyboardType: _fractionalQuantity
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ],
                if (_showQuantity && _columnsConfig.unit) ...[
                  const SizedBox(height: 16),
                  _buildUnitPicker(
                    selectedUnit: dialogUnit,
                    customController: unitController,
                    onUnitChanged: (v) => setDialogState(() => dialogUnit = v),
                  ),
                ],
                if (_columnsConfig.defaultDiscount || item.product.defaultDiscount > 0 || item.discount > 0) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: discountController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldDiscountLabel,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.xsmall)),
                      prefixIcon: const Icon(Icons.discount),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDiscountPerUnitToggle(discountPerUnit,
                      (val) => setDialogState(() => discountPerUnit = val)),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: unitPriceController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.fieldUnitPriceOverrideLabel,
                    helperText: AppLocalizations.of(context)!
                        .createInvoiceDefaultPriceHelper('$_currencySymbol${item.product.price}'),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.xsmall)),
                    prefixText: '$_currencySymbol ',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
                if (_columnsConfig.extraCost) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: extraCostController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldExtraCostLabel,
                      hintText: '0.00',
                      helperText: AppLocalizations.of(context)!.createInvoiceExtraCostHelper,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.xsmall)),
                      prefixIcon: const Icon(Icons.add_circle_outline, size: 18),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ],
                if (_showDescriptionInPdf) ...[
                  const SizedBox(height: 16),
                  _buildItemDescriptionField(descriptionController),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.actionCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                final parsedUnitPrice = double.tryParse(unitPriceController.text);
                final unitPrice = (parsedUnitPrice != null &&
                        parsedUnitPrice != item.product.price)
                    ? parsedUnitPrice
                    : null;
                final extraCost = double.tryParse(extraCostController.text);
                final updatedItem = InvoiceItem(
                  product: item.product,
                  quantity: !_showQuantity
                      ? 1.0
                      : _fractionalQuantity
                          ? (double.tryParse(quantityController.text) ??
                              item.quantity)
                          : (int.tryParse(quantityController.text) ??
                                  double.tryParse(quantityController.text)
                                      ?.toInt() ??
                                  item.quantity.toInt())
                              .toDouble(),
                  discount:
                      double.tryParse(discountController.text) ?? item.discount,
                  unitPrice: unitPrice,
                  extraCost: extraCost,
                  unit: dialogUnit.trim(),
                  description: descriptionController.text.trim(),
                  metadata: item.metadata,
                  discountPerUnit: discountPerUnit,
                );
                if(!mounted) return;
                setState(() {
                  // Still a saved line (no stock of its own).
                  if (_loadedItemIds.contains(item.id)) {
                    _loadedItemIds.add(updatedItem.id);
                  }
                  invoiceItems[index] = updatedItem;
                });

                Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.actionUpdate),
            ),
          ],
        ),
      ),
    ).then((_) => _screenFocusNode.requestFocus());
  }

  void _addAdHocItemDialog() {
    final nameController = TextEditingController();
    final aliasNameController = TextEditingController();
    final priceController = TextEditingController();
    final quantityController = TextEditingController();
    final discountController = TextEditingController(text: '0');
    final taxRateController = TextEditingController(text: '0');
    final extraCostController = TextEditingController();
    final unitController = TextEditingController();
    final descriptionController = TextEditingController();

    bool discountPerUnit = true;
    bool dialogPriceIncludesTax = false;
    String dialogItemType = _adHocItemType;
    int insertAt = invoiceItems.length + 1;
    String selectedUnit = '';
    String? nameError;
    String? priceError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void submitAdHocItem() {
            final name = nameController.text.trim();
            final priceText = priceController.text.trim();
            final price = double.tryParse(priceText) ?? 0.0;
            final l10n = AppLocalizations.of(context)!;
            final newNameError =
                name.isEmpty ? l10n.customerMgmtCsvColRequiredHeader : null;
            final newPriceError = priceText.isEmpty
                ? l10n.customerMgmtCsvColRequiredHeader
                : price <= 0
                    ? l10n.createInvoiceMustBeAboveZeroError
                    : null;
            if (newNameError != null || newPriceError != null) {
              setDialogState(() {
                nameError = newNameError;
                priceError = newPriceError;
              });
              return;
            }
            final taxRate = _taxMode == TaxMode.perItem
                ? (int.tryParse(taxRateController.text) ?? 0)
                : 0;

            final adHocProduct = Product(
              id: 'custom-${const Uuid().v4()}',
              name: name,
              description: '',
              price: price,
              stock: 0,
              hsncode: '',
              tax_rate: taxRate,
              unit: selectedUnit.trim(),
              type: dialogItemType,
              aliasName: aliasNameController.text.trim().isEmpty
                  ? null
                  : aliasNameController.text.trim(),
              priceIncludesTax: dialogPriceIncludesTax,
            );
            final extraCost = double.tryParse(extraCostController.text);
            final item = InvoiceItem(
              product: adHocProduct,
              quantity: !_showQuantity
                  ? 1.0
                  : _fractionalQuantity
                      ? (double.tryParse(quantityController.text) ?? 1.0)
                      : (int.tryParse(quantityController.text) ?? 1)
                          .toDouble(),
              discount: double.tryParse(discountController.text) ?? 0.0,
              extraCost: extraCost,
              unit: selectedUnit.trim(),
              description: descriptionController.text.trim(),
              discountPerUnit: discountPerUnit,
            );
            Navigator.pop(context);
            addInvoiceProduct(item, insertAt: insertAt);
          }

          return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.add_box, color: Colors.deepPurple),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.createInvoiceCustomItemTitle,
                  style: const TextStyle(fontSize: AppFontSize.xlarge)),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_businessType == BusinessType.both &&
                      _columnsConfig.type) ...[
                    SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'product',
                          label: Text(AppLocalizations.of(context)!.labelProduct),
                          icon: const Icon(Icons.inventory_2_outlined, size: 16)),
                      ButtonSegment(
                          value: 'service',
                          label: Text(AppLocalizations.of(context)!.labelService),
                          icon: const Icon(Icons.design_services_outlined, size: 16)),
                    ],
                    selected: {dialogItemType},
                    onSelectionChanged: (val) =>
                        setDialogState(() => dialogItemType = val.first),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.fieldItemNameLabel,
                    errorText: nameError,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.xsmall)),
                    prefixIcon: const Icon(Icons.label),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  onChanged: (_) {
                    if (nameError != null) setDialogState(() => nameError = null);
                  },
                  onSubmitted: (_) => submitAdHocItem(),
                ),
                if (_columnsConfig.aliasName) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: aliasNameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldAliasForPdfLabel,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.xsmall)),
                      prefixIcon: const Icon(Icons.translate),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(
                    labelText: _showQuantity ? AppLocalizations.of(context)!.fieldUnitPriceLabel : AppLocalizations.of(context)!.fieldRateLabel,
                    errorText: priceError,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.xsmall)),
                    prefixText: '$_currencySymbol ',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) {
                    if (priceError != null) setDialogState(() => priceError = null);
                  },
                  onSubmitted: (_) => submitAdHocItem(),
                ),
                if (_showQuantity) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: _quantityLabel.trim().isNotEmpty
                          ? _quantityLabel.trim()
                          : AppLocalizations.of(context)!.createInvoiceQuantityLabel,
                      hintText: '1',
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.xsmall)),
                      prefixIcon: const Icon(Icons.numbers),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    keyboardType: _fractionalQuantity
                        ? const TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ],
                if (_showQuantity && _columnsConfig.unit) ...[
                  const SizedBox(height: 16),
                  _buildUnitPicker(
                    selectedUnit: selectedUnit,
                    customController: unitController,
                    onUnitChanged: (v) => setDialogState(() => selectedUnit = v),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: discountController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.fieldDiscountLabel,
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.xsmall)),
                    prefixIcon: const Icon(Icons.discount),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDiscountPerUnitToggle(discountPerUnit,
                    (val) => setDialogState(() => discountPerUnit = val)),
                if (_columnsConfig.extraCost) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: extraCostController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldExtraCostLabel,
                      hintText: '0.00',
                      helperText: AppLocalizations.of(context)!.createInvoiceExtraCostHelper,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.xsmall)),
                      prefixIcon: const Icon(Icons.add_circle_outline, size: 18),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ],
                if (_taxMode == TaxMode.perItem && _columnsConfig.taxRate) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: taxRateController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.fieldTaxRateLabel,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppBorderRadius.xsmall)),
                      prefixIcon: const Icon(Icons.percent),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(AppLocalizations.of(context)!.fieldPriceIncludesTaxLabel),
                    value: dialogPriceIncludesTax,
                    onChanged: (val) => setDialogState(
                        () => dialogPriceIncludesTax = val ?? false),
                  ),
                ],
                if (_showDescriptionInPdf) ...[
                  const SizedBox(height: 16),
                  _buildItemDescriptionField(descriptionController),
                ],
                if (invoiceItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.format_list_numbered,
                          size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.fieldInsertAtPositionLabel,
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: insertAt > 1
                            ? () => setDialogState(() => insertAt--)
                            : null,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text('$insertAt',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: insertAt < invoiceItems.length + 1
                            ? () => setDialogState(() => insertAt++)
                            : null,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.actionCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: submitAdHocItem,
              child: Text(AppLocalizations.of(context)!.actionAdd, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
        },
      ),
    ).then((_) => _screenFocusNode.requestFocus());
  }

  // void _filterProducts(String query) {
  //   setState(() {
  //     if (query.isEmpty) {
  //       filteredProducts = List.from(products);
  //     } else {
  //       filteredProducts = products
  //           .where((product) => product.name.toLowerCase().contains(query.toLowerCase()))
  //           .toList();
  //     }
  //   });
  // }

  void _filterProducts(String query) {
    if (!mounted) return;
    _productSearchDebounce?.cancel();
    _productSearchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final requestId = ++_productSearchRequestId;
      final repo = ref.read(productRepositoryProvider);
      final results = await repo.getProductsPaginated(
          offset: 0, limit: _productFetchLimit, query: query, type: _businessType.key);
      final metadata =
          await repo.getProductMetadataForIds(results.map((e) => e.id).toList());
      if (requestId != _productSearchRequestId || !mounted) return;
      setState(() {
        filteredProducts = results;
        _loadedProductQuery = query;
        _productMetadata = {..._productMetadata, ...metadata};
      });
    });
  }

  /// Picks the product for [text] from [results]: an exact match on the code
  /// (HSN), name or alias wins over a partial match, so a scanned code such
  /// as `1001` is not taken for `10010` just because it sorts first.
  Product? _bestProductMatch(List<Product> results, String text) {
    if (results.isEmpty) return null;
    final t = text.trim().toLowerCase();
    for (final p in results) {
      if (p.hsncode.trim().toLowerCase() == t) return p;
    }
    for (final p in results) {
      if (p.name.trim().toLowerCase() == t ||
          (p.aliasName ?? '').trim().toLowerCase() == t) {
        return p;
      }
    }
    return results.first;
  }

  /// Enter in the product search box (a person typing, or a barcode scanner).
  ///
  /// A scanner types the whole code and presses Enter within a few ms, long
  /// before the 400 ms search debounce has loaded results for that code, so
  /// [filteredProducts] still holds the PREVIOUS search. Selecting from it
  /// added the previous product. Instead, resolve the text that is actually
  /// in the box.
  Future<bool> _submitProductSearch() async {
    final raw = searchController.text;
    final text = raw.trim();
    if (text.isEmpty) {
      // Empty box with the first-nine list open: Enter takes the row picked
      // with the arrow keys (and nothing if the arrows were never used).
      final shown = _dropdownProducts;
      if (_showProductDropdownV2 && _productArrowed && shown.isNotEmpty) {
        _selectProductFromDropdownV2(
            shown[_highlightedProductIndexV2.clamp(0, shown.length - 1)]);
        return true;
      }
      return false;
    }
    if (_productSubmitInFlight) return false;

    // The visible list was searched with exactly this text: honour the row
    // the user highlighted with the arrow keys, else prefer an exact match.
    if (_loadedProductQuery == raw && filteredProducts.isNotEmpty) {
      final highlighted = _highlightedProductIndexV2
          .clamp(0, filteredProducts.length - 1);
      final chosen = highlighted > 0
          ? filteredProducts[highlighted]
          : _bestProductMatch(filteredProducts, text);
      if (chosen != null) _selectProductFromDropdownV2(chosen);
      return chosen != null;
    }

    _productSubmitInFlight = true;
    // Drop the pending debounce and any search still in flight: they belong
    // to an older state of the box.
    _productSearchDebounce?.cancel();
    final requestId = ++_productSearchRequestId;
    try {
      final repo = ref.read(productRepositoryProvider);
      final results = await repo.getProductsPaginated(
          offset: 0, limit: _productFetchLimit, query: raw, type: _businessType.key);
      final metadata =
          await repo.getProductMetadataForIds(results.map((e) => e.id).toList());
      // Typing carried on, or a newer search started: this answer is stale.
      if (!mounted ||
          requestId != _productSearchRequestId ||
          searchController.text != raw) {
        return false;
      }
      setState(() {
        filteredProducts = results;
        _loadedProductQuery = raw;
        _highlightedProductIndexV2 = 0;
        _productMetadata = {..._productMetadata, ...metadata};
      });
      final chosen = _bestProductMatch(results, text);
      if (chosen != null) _selectProductFromDropdownV2(chosen);
      return chosen != null;
    } finally {
      _productSubmitInFlight = false;
    }
  }

  // ── Customer name suggestions ──────────────────────────────────────────
  static const double _customerRowExtent = 56;

  /// Looks up the customers for what is in the name box right now (all of them,
  /// first page, when it is empty) and shows or hides the list.
  Future<void> _refreshCustomerMatches() async {
    final id = ++_customerMatchRequest;
    final text = nameController.text.trim();
    final results = await ref
        .read(customerRepositoryProvider)
        .getCustomersPaginated(
            offset: 0, limit: _customerFetchLimit, query: text);
    if (!mounted || id != _customerMatchRequest) return;
    setState(() {
      _customerMatches = results;
      _customerHighlight = 0;
    });
    _syncCustomerList();
  }

  void _syncCustomerList() {
    final show = _customerNameFocus.hasFocus &&
        !_nameIsPickedCustomer &&
        _customerMatches.isNotEmpty;
    if (show && !_customerListPortal.isShowing) _customerListPortal.show();
    if (!show && _customerListPortal.isShowing) _customerListPortal.hide();
  }

  void _pickCustomerSuggestion(Customer customer) {
    _customerMatchRequest++; // drop any lookup still in flight
    _customerMatchDebounce?.cancel();
    if (_customerListPortal.isShowing) _customerListPortal.hide();
    _customerNameFocus.unfocus();
    _selectCustomer(customer);
    // A customer was picked: show the details.
    setState(() => _customerStripOpen = true);
    _returnFocusToScreen();
  }

  void _moveCustomerHighlight(int delta) {
    if (_customerMatches.isEmpty) return;
    setState(() {
      _customerHighlight =
          (_customerHighlight + delta).clamp(0, _customerMatches.length - 1);
      _customerArrowed = true;
    });
    if (_customerListScroll.hasClients) {
      final top = _customerHighlight * _customerRowExtent;
      final view = _customerListScroll.position.viewportDimension;
      final cur = _customerListScroll.offset;
      if (top < cur) {
        _customerListScroll.jumpTo(top);
      } else if (top + _customerRowExtent > cur + view) {
        _customerListScroll.jumpTo(top + _customerRowExtent - view);
      }
    }
  }

  Widget _customerNameFieldModern() {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      return OverlayPortal(
        key: _customerPortalKey,
        controller: _customerListPortal,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _customerNameLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: _customerSuggestionList(width),
          ),
        ),
        child: CompositedTransformTarget(
          key: _customerFieldKey,
          link: _customerNameLink,
          child: Focus(
            // Arrow keys / Escape drive the list; everything else goes to the
            // text box as usual.
            onKeyEvent: (node, event) {
              if (!_customerListPortal.isShowing) return KeyEventResult.ignored;
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _moveCustomerHighlight(1);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _moveCustomerHighlight(-1);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  _customerListPortal.hide();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              key: const ValueKey('modernCustomerName'),
              controller: nameController,
              focusNode: _customerNameFocus,
              textAlignVertical: TextAlignVertical.center,
              onChanged: (_) {
                _customerArrowed = false;
                setState(() {});
                _customerMatchDebounce?.cancel();
                _customerMatchDebounce = Timer(
                    const Duration(milliseconds: 150), _refreshCustomerMatches);
              },
              // Enter takes the suggestion only after the arrow keys were used,
              // so typing a NEW name and pressing Enter never swaps in a
              // similar existing customer.
              onSubmitted: (_) {
                if (_customerListPortal.isShowing &&
                    _customerArrowed &&
                    _customerHighlight < _customerMatches.length) {
                  _pickCustomerSuggestion(_customerMatches[_customerHighlight]);
                }
              },
              decoration: _searchDecorationModern(l10n.mInvCustomerSearchHint,
                  suffixIcon: const Icon(Icons.keyboard_arrow_down)),
            ),
          ),
        ),
      );
    });
  }

  Widget _customerSuggestionList(double width) {
    final scheme = Theme.of(context).colorScheme;
    // TextFieldTapRegion: a press on the list (or its scrollbar) is part of the
    // name box, so the desktop "tap outside = unfocus" does not close the list
    // under the cashier's finger.
    return TextFieldTapRegion(child: _customerSuggestionListBody(width, scheme));
  }

  Widget _customerSuggestionListBody(double width, ColorScheme scheme) {
    // Never taller than the room under the name box.
    var top = 230.0; // about where the name box ends when nothing is known
    final box = _customerFieldKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.attached && box.hasSize) {
      try {
        top = box.localToGlobal(Offset(0, box.size.height)).dy + 4;
      } catch (_) {
        // not laid out yet (the window was just resized): keep the estimate
      }
    }
    final room = MediaQuery.sizeOf(context).height - top - 12;
    final maxHeight = (9 * _customerRowExtent + 8).clamp(0.0, room < 120 ? 120.0 : room);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
      color: scheme.surface,
      child: Container(
        key: const ValueKey('customerSuggestionList'),
        width: width,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ListView.builder(
          controller: _customerListScroll,
          padding: const EdgeInsets.symmetric(vertical: 4),
          shrinkWrap: true,
          itemExtent: _customerRowExtent,
          itemCount: _customerMatches.length,
          itemBuilder: (context, i) {
            final cust = _customerMatches[i];
            final highlighted = i == _customerHighlight;
            final detail = [
              if (cust.businessName.trim().isNotEmpty) cust.businessName,
              if (cust.phone.trim().isNotEmpty) cust.phone,
            ].join('  •  ');
            return Container(
              color: highlighted
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                  : null,
              child: ListTile(
                dense: true,
                selected: highlighted,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    cust.name.isNotEmpty ? cust.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                title: Text(cust.name, overflow: TextOverflow.ellipsis),
                subtitle: detail.isEmpty
                    ? null
                    : Text(detail,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => _pickCustomerSuggestion(cust),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _selectCustomer(Customer? customer) async {
    if(!mounted) return;
    setState(() {
      selectedCustomer = customer;
      nameController.text = customer?.name ?? '';
      emailController.text = customer?.email ?? '';
      phoneController.text = customer?.phone ?? '';
      addressController.text = customer?.address ?? '';
      gstinController.text = customer?.gstin ?? '';
      businessNameController.text = customer?.businessName ?? '';
    });
    await _loadPreviousBalanceDue(customer);
  }

  Future<void> _loadPreviousBalanceDue(Customer? customer) async {
    final requestId = ++_previousBalanceRequestSerial;

    if (!_showPreviousBalance ||
        customer == null ||
        customer.id.trim().isEmpty ||
        invoiceType != 'Invoice')
    {
      if (!mounted) return;
      setState(() {
        _previousBalanceDue = 0.0;
        _isPreviousBalanceLoading = false;
      });
      return;
    }
    if(!mounted) return;
    setState(() => _isPreviousBalanceLoading = true);
    try {
      final repo = ref.read(invoiceRepositoryProvider);
      // Same-day invoices count when their id (not the per-type display
      // number) is lower. A new document uses the id it is about to get.
      final currentId = _invoice?.id ?? await repo.peekNextId();
      final balance = await repo.getPreviousBalanceDueForCustomer(
        customerId: customer.id,
        currencyCode: _currencyCode,
        asOfDate: _selectedOrderDate,
        currentInvoiceId: currentId,
      );
      if (!mounted || requestId != _previousBalanceRequestSerial) return;
      setState(() {
        _previousBalanceDue = balance;
        _isPreviousBalanceLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _previousBalanceRequestSerial) return;
      setState(() {
        _previousBalanceDue = 0.0;
        _isPreviousBalanceLoading = false;
      });
    }
  }

  Future<void> resetInvoiceType(String invoiceType_) async {
    if(!mounted) return;
    setState(() {
      invoiceType = invoiceType_;
      if (invoiceType_ != 'Invoice') invoiceTitle = null;
    });
    if (!isEditing) {
      final invNumber =
          await InvoicePdfServices.peekNextInvoiceNumber(invoiceType_);
      if (mounted) setState(() => currentInvoiceNumber = invNumber);
    }
    await _loadPreviousBalanceDue(selectedCustomer);
  }

  Future<void> resetValues(String invoiceType_) async {
    if(!mounted) return;
    final invType = await InvoicePdfServices.peekNextInvoiceNumber(invoiceType_);
    if(!mounted) return;
    setState(() {
      invoiceType = invoiceType_;
      currentInvoiceNumber = invType;
      _invoice = null;
      isEditing = false;
      selectedCustomer = null;
      invoiceItems.clear();
      for (final row in _additionalCostControllers) {
        row.label.dispose();
        row.amount.dispose();
      }
      _additionalCostControllers.clear();
      _showAdditionalCosts = false;
      notesController.clear();
      nameController.clear();
      emailController.clear();
      phoneController.clear();
      addressController.clear();
      gstinController.clear();
      businessNameController.clear();
      taxRate = Tax.defaultTaxRate;
      _selectedOrderDate = DateTime.now();
      dateController.text = DateFormat(_datePattern).format(_selectedOrderDate);
      _selectedDueDate = null;
      dueDateController.clear();
      _previousBalanceDue = 0.0;
      _isPreviousBalanceLoading = false;
      // A fresh document: nothing from the last one (or from the quotation,
      // duplicate or draft it came from) carries over.
      _convertFromId = null;
      _fromClone = false;
      _draftId = null;
      _invoiceDiscountController.clear();
      _invoiceDiscountType = InvoiceDiscountType.percent;
      _customFieldValues = {};
      customInvoiceNumberController.clear();
      _chargesOpen = null;
      _hideInvoiceNumber = _hideInvoiceNumberByDefault;
      invoiceTitle = invoiceType_ == 'Invoice' ? _defaultInvoiceTitle : null;
      _isTaxEnabled = _taxEnabledByDefault;
      _isPerItem = _perItemTaxByDefault;
      _isInterState = false;
      _quantityLabel = _defaultQuantityLabel;
      _currencyCode = _defaultCurrencyCode;
      _currencySymbol = _defaultCurrencySymbol;
      _selectedUpi = _upiEntries.where((e) => e.isDefault).firstOrNull ??
          _upiEntries.firstOrNull;
      _selectedBankAccount =
          _bankAccounts.where((e) => e.isDefault).firstOrNull ??
              _bankAccounts.firstOrNull;
      _loadedItemIds.clear();
      _stockHeldByEdited.clear();
    });
    await _setAdditionalNote(forceDefault: true);
    _markFormClean();
  }

  Future<void> _showPhoneTakenError(String ownerName) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)!.createInvoicePhoneAlreadyInUseTitle),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)!.createInvoicePhoneAlreadyInUseMessage(ownerName),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.actionOk),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCustomer() async {
    if (_isSavingCustomer) return;
    if(!mounted) return;
    setState(() => _isSavingCustomer = true);
    try {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.createInvoiceCustomerNameRequiredBeforeSavingMessage),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    final phone = phoneController.text.trim();

    // Editing an already-selected customer whose phone changed: ask whether
    // to overwrite that customer's record or split off a new one, instead
    // of silently matching/creating based on phone alone.
    var forceNew = false;
    final sel = selectedCustomer;
    if (sel != null && sel.id.isNotEmpty && phone != sel.phone) {
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.phone_forwarded, color: Colors.orange),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.createInvoicePhoneChangedTitle),
            ],
          ),
          content: Text(
            AppLocalizations.of(context)!.createInvoicePhoneChangedMessage(sel.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(AppLocalizations.of(context)!.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'new'),
              child: Text(AppLocalizations.of(context)!.createInvoiceSaveAsNewButton),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, 'update'),
              child: Text(AppLocalizations.of(context)!.createInvoiceUpdateExistingButton,
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (choice == null) return;
      if (choice == 'update') {
        final phoneOwner = await ref.read(customerRepositoryProvider).findByPhone(phone);
        if (phoneOwner != null && phoneOwner.id != sel.id) {
          await _showPhoneTakenError(phoneOwner.name);
          return;
        }
        await _updatePickedCustomer(sel, name, phone);
        return;
      }
      // choice == 'new': fall through to the phone-lookup flow below,
      // which still guards against colliding with a *different* customer's phone.
      forceNew = true;
    }

    // A picked customer with the same phone: "Update customer" saves the
    // changes (name, GSTIN, address...) to that customer.
    if (sel != null && sel.id.isNotEmpty && !forceNew) {
      await _updatePickedCustomer(sel, name, phone);
      return;
    }

    final existing = await ref.read(customerRepositoryProvider).findByPhone(phone);

    if (existing != null && forceNew) {
      // User explicitly chose "Save as New" above, but this phone number
      // is already used by a different customer. Phone numbers must be
      // unique — block instead of creating a duplicate.
      await _showPhoneTakenError(existing.name);
      return;
    }

    if (existing != null) {
      if (!mounted) return;
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.person_search, color: Colors.orange),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.createInvoiceCustomerAlreadyExistsTitle),
            ],
          ),
          content: Text(
            AppLocalizations.of(context)!.createInvoiceCustomerAlreadyExistsMessage(existing.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'use'),
              child: Text(AppLocalizations.of(context)!.createInvoiceUseExistingButton),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, 'update'),
              child:
                  Text(AppLocalizations.of(context)!.actionUpdate, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (choice == null) return;

      if (choice == 'use') {
        if (!mounted) return;
        setState(() {
          selectedCustomer = existing;
          nameController.text = existing.name;
          emailController.text = existing.email;
          phoneController.text = existing.phone;
          addressController.text = existing.address;
          gstinController.text = existing.gstin;
          businessNameController.text = existing.businessName;
        });
        await _loadPreviousBalanceDue(existing);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.createInvoiceUsingExistingCustomerMessage(existing.name)),
              behavior: SnackBarBehavior.floating,
              showCloseIcon: true,
            ),
          );
        }
        return;
      }

      final updated = Customer(
        id: existing.id,
        name: name,
        email: emailController.text.trim(),
        phone: phone,
        address: addressController.text.trim(),
        gstin: gstinController.text.trim(),
        businessName: businessNameController.text.trim(),
      );
      await ref.read(customerRepositoryProvider).updateCustomer(updated);
      if(!mounted) return;
      setState(() {
        selectedCustomer = updated;
        _upsertLocalCustomer(updated);
      });
      await _loadPreviousBalanceDue(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.createInvoiceCustomerUpdatedMessage(updated.name)),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    } else {
      final newCustomer = Customer(
        id: const Uuid().v4(),
        name: name,
        email: emailController.text.trim(),
        phone: phone,
        address: addressController.text.trim(),
        gstin: gstinController.text.trim(),
        businessName: businessNameController.text.trim(),
      );
      await ref.read(customerRepositoryProvider).insertCustomer(newCustomer);
      if(!mounted) return;
      setState(() {
        selectedCustomer = newCustomer;
        _upsertLocalCustomer(newCustomer);
      });
      await _loadPreviousBalanceDue(newCustomer);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.createInvoiceCustomerSavedMessage(newCustomer.name)),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
          ),
        );
      }
    }
    } finally {
      if (mounted) setState(() => _isSavingCustomer = false);
    }
  }

  Future<void> _updatePickedCustomer(Customer sel, String name, String phone) async {
    final updated = Customer(
      id: sel.id,
      name: name,
      email: emailController.text.trim(),
      phone: phone,
      address: addressController.text.trim(),
      gstin: gstinController.text.trim(),
      businessName: businessNameController.text.trim(),
    );
    await ref.read(customerRepositoryProvider).updateCustomer(updated);
    if (!mounted) return;
    setState(() {
      selectedCustomer = updated;
      _upsertLocalCustomer(updated);
    });
    await _loadPreviousBalanceDue(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.createInvoiceCustomerUpdatedMessage(updated.name)),
          behavior: SnackBarBehavior.floating,
          showCloseIcon: true,
        ),
      );
    }
  }

  /// Re-reads the selected customer's current record and overwrites the
  /// form fields with it. The invoice keeps whatever was last saved on it
  /// (a snapshot) until this is explicitly triggered — editing an invoice
  /// does NOT silently pull in customer changes made elsewhere since.
  Future<void> _refreshCustomerFromRecord() async {
    final current = selectedCustomer;
    if (current == null || current.id.trim().isEmpty) return;
    final latest = await ref.read(customerRepositoryProvider).getCustomerById(current.id);
    if (!mounted) return;
    if (latest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.createInvoiceCustomerRecordGoneMessage),showCloseIcon: true,),
      );
      return;
    }
    if(!mounted) return;
    setState(() {
      selectedCustomer = latest;
      nameController.text = latest.name;
      emailController.text = latest.email;
      phoneController.text = latest.phone;
      addressController.text = latest.address;
      gstinController.text = latest.gstin;
      businessNameController.text = latest.businessName;
    });
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.createInvoiceCustomerRefreshedMessage),
      showCloseIcon: true,),
    );
  }

  void _clearCustomerSelection() {
    if (!mounted) return;
    setState(() {
      selectedCustomer = null;
      nameController.clear();
      emailController.clear();
      phoneController.clear();
      addressController.clear();
      gstinController.clear();
      businessNameController.clear();
      _previousBalanceDue = 0.0;
      _isPreviousBalanceLoading = false;
    });
  }

  double get _invoiceDiscountValue =>
      double.tryParse(_invoiceDiscountController.text) ?? 0.0;

  List<CustomFieldValue> _buildCustomFields() {
    final values = <CustomFieldValue>[];
    for (final def in _customFieldDefs) {
      final value = (_customFieldValues[def.id] ?? '').trim();
      if (value.isNotEmpty) {
        values.add(CustomFieldValue(defId: def.id, label: def.label, value: value));
      }
    }
    return values;
  }

  // Shown at equal width beside the Customer form (see _buildDesktopLayoutV2)
  // so it reads as a peer section, not a narrow sidebar. Not directly
  // editable inline like the Customer form though — these are optional
  // metadata that shouldn't grow the row unpredictably based on how many
  // fields are defined — so it displays whatever's already filled and a
  // button opens _showCustomFieldsDialogV2 to fill/change values.
  Widget _customFieldsSummaryCardV2() {
    if (!_customFieldsEnabled || _customFieldDefs.isEmpty) {
      return const SizedBox.shrink();
    }
    final filled = _customFieldDefs
        .map((d) => (label: d.label, value: (_customFieldValues[d.id] ?? '').trim()))
        .where((e) => e.value.isNotEmpty)
        .toList();

    Widget tile(({String label, String value})? f) => Expanded(
          child: f == null
              ? const SizedBox()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10, right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text(f.value,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2),
                    ],
                  ),
                ),
        );

    // Fixed height (roughly the Customer Details card's own height) instead
    // of sizing to content — with 1 field or 13 filled, the row this card
    // sits in should still line up with the Customer form, not balloon out
    // or shrink to almost nothing. Overflow scrolls internally.
    return Container(
      height: _customFieldsCollapsed ? null : 165,
      decoration: _flatCardDecorationV2(context),
      padding: const EdgeInsets.all(AppPadding.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:
            _customFieldsCollapsed ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Builder(builder: (context) {
            final title = InkWell(
              onTap: () {
                if (!mounted) return;
                setState(
                    () => _customFieldsCollapsed = !_customFieldsCollapsed);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      _customFieldsCollapsed
                          ? Icons.chevron_right
                          : Icons.expand_more,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Icon(Icons.dashboard_customize_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context)!
                          .customizationCustomFieldsTitle
                          .toUpperCase(),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
            final controls = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${filled.length}/${_customFieldDefs.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _showCustomFieldsDialogV2,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(filled.isEmpty
                      ? AppLocalizations.of(context)!.actionAdd
                      : AppLocalizations.of(context)!.actionEdit),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppBorderRadius.xsmall)),
                  ),
                ),
              ],
            );
            // Original single-row header; falls back to title-above-controls
            // once the column gets too narrow for both to fit side by side
            // (e.g. the Custom Fields card in a 3-column desktop layout).
            return LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth < 260) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [title, const SizedBox(height: 6), controls],
                );
              }
              return Row(
                children: [Expanded(child: title), const SizedBox(width: 8), controls],
              );
            });
          }),
          if (!_customFieldsCollapsed) ...[
            const SizedBox(height: 12),
            Expanded(
              child: filled.isEmpty
                  ? Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        AppLocalizations.of(context)!
                            .createInvoiceNoCustomFieldsFilledMessage,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < filled.length; i += 2)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                tile(filled[i]),
                                tile(i + 1 < filled.length
                                    ? filled[i + 1]
                                    : null),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCustomFieldsDialogV2() {
    final controllers = {
      for (final def in _customFieldDefs)
        def.id: TextEditingController(text: _customFieldValues[def.id] ?? ''),
    };
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                        AppLocalizations.of(context)!
                            .customizationCustomFieldsTitle,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _customFieldDefs.length; i += 2)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: controllers[_customFieldDefs[i].id],
                                    decoration: _flatFieldDecorationV2(
                                        _customFieldDefs[i].label,
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.open_in_full, size: 16),
                                          tooltip: AppLocalizations.of(context)!
                                              .tooltipEditInLargerView,
                                          onPressed: () => _editLongTextDialogV2(
                                            title: _customFieldDefs[i].label,
                                            controller: controllers[_customFieldDefs[i].id]!,
                                          ),
                                        )),
                                  ),
                                ),
                                if (i + 1 < _customFieldDefs.length) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          controllers[_customFieldDefs[i + 1].id],
                                      decoration: _flatFieldDecorationV2(
                                          _customFieldDefs[i + 1].label,
                                          suffixIcon: IconButton(
                                            icon: const Icon(Icons.open_in_full, size: 16),
                                            tooltip: AppLocalizations.of(context)!
                                                .tooltipEditInLargerView,
                                            onPressed: () => _editLongTextDialogV2(
                                              title: _customFieldDefs[i + 1].label,
                                              controller:
                                                  controllers[_customFieldDefs[i + 1].id]!,
                                            ),
                                          )),
                                    ),
                                  ),
                                ] else
                                  const Expanded(child: SizedBox()),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(AppLocalizations.of(context)!.actionCancel),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final updated = {
                          for (final def in _customFieldDefs)
                            def.id: controllers[def.id]!.text,
                        };
                        Navigator.of(dialogContext).pop();
                        if (!mounted) return;
                        setState(() => _customFieldValues = updated);
                      },
                      child: Text(AppLocalizations.of(context)!.actionSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<AdditionalCost> _buildAdditionalCosts() {
    final costs = <AdditionalCost>[];
    for (final row in _additionalCostControllers) {
      final label = row.label.text.trim();
      final amount = double.tryParse(row.amount.text) ?? 0.0;
      // A row with an amount counts even without a label.
      if (amount != 0) {
        costs.add(AdditionalCost(
            label: label.isEmpty
                ? AppLocalizations.of(context)!
                    .createInvoiceExtraCostFallbackLabel
                : label,
            amount: amount));
      }
    }
    return costs;
  }

  /// [showHeader] false: only the rows and "Add row" (the Modern card around
  /// it already has its own header).
  Widget _buildAdditionalCostsSection({bool showHeader = true}) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // Header row — toggles collapse
          if (showHeader)
          InkWell(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppBorderRadius.xsmall)),
            onTap: () {
              if(!mounted) return;
              setState(() => _showAdditionalCosts = !_showAdditionalCosts);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.add_box_outlined,
                      size: 18, color: Colors.teal[700]),
                  const SizedBox(width: 8),
                  // The title shortens (…) on a narrow panel instead of
                  // pushing the arrow out.
                  Expanded(
                    child: Row(children: [
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context)!.mInvChargesAdjustments,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal[800],
                          ),
                        ),
                      ),
                      if (_additionalCostControllers.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_additionalCostControllers.length}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ]),
                  ),
                  Icon(
                    _showAdditionalCosts
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.teal[700],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible body
          if (_showAdditionalCosts || !showHeader) ...[
            if (showHeader) const Divider(height: 1, color: Colors.teal),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        AppLocalizations.of(context)!.createInvoiceChargesMinusHint,
                        style: TextStyle(fontSize: 11, color: Colors.teal[700]),
                      ),
                    ),
                  ),
                  ..._additionalCostControllers.asMap().entries.map((entry) {
                    final i = entry.key;
                    final row = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: row.label,
                              onChanged: (_) {
                                if(!mounted) return;
                                setState(() {});
                                },
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!.fieldLabelLabel,
                                hintText: AppLocalizations.of(context)!.hintLabelExample,
                                isDense: true,
                                suffixIcon: PopupMenuButton<String>(
                                  icon: const Icon(Icons.arrow_drop_down),
                                  tooltip: '',
                                  onSelected: (v) {
                                    if (!mounted) return;
                                    setState(() => row.label.text = v);
                                  },
                                  itemBuilder: (_) => AdjustmentLabels.presets
                                      .map((l) => PopupMenuItem(
                                          value: l, child: Text(l)))
                                      .toList(),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppBorderRadius.xsmall),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: row.amount,
                              onChanged: (_) {
                                if(!mounted) return;
                                setState(() {});
                              },
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true, signed: true),
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!.labelAmount,
                                prefixText: '$_currencySymbol ',
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppBorderRadius.xsmall),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.red, size: 20),
                            tooltip: AppLocalizations.of(context)!.tooltipRemove,
                            onPressed: () {
                              if(!mounted) return;
                              setState(() {
                                _additionalCostControllers[i].label.dispose();
                                _additionalCostControllers[i].amount.dispose();
                                _additionalCostControllers.removeAt(i);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        if(!mounted) return;
                        setState(() {
                          _additionalCostControllers.add((
                            label: TextEditingController(),
                            amount: TextEditingController(),
                          ));
                        });
                      },
                      icon: Icon(Icons.add_circle_outline,
                          color: primary, size: 16),
                      label: Text(AppLocalizations.of(context)!.createInvoiceAddRowButton,
                          style: TextStyle(color: primary, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscountPerUnitToggle(bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.fieldDiscountPerUnitLabel,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            Text(
              value
                  ? AppLocalizations.of(context)!.createInvoiceDiscountPerUnitFormulaOn
                  : AppLocalizations.of(context)!.createInvoiceDiscountPerUnitFormulaOff,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  // Optional per-line description, stored on the invoice item. The
  // add-product dialog seeds it from the product's own description; the
  // ad-hoc dialog starts empty. Whatever is left here is snapshotted on
  // the item and prints under the item name.
  Widget _buildItemDescriptionField(TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.createInvoiceItemDescriptionLabel,
        hintText: AppLocalizations.of(context)!.createInvoiceItemDescriptionHint,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        prefixIcon: const Icon(Icons.notes_outlined, size: 18),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      minLines: 1,
      maxLines: 3,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildUnitPicker({
    required String selectedUnit,
    required TextEditingController customController,
    required ValueChanged<String> onUnitChanged,
  }) {
    return _UnitPicker(
      initialUnit: selectedUnit,
      customController: customController,
      onUnitChanged: onUnitChanged,
    );
  }

  Widget _buildTotalRow(String label, double amount, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 20 : 14.5,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.normal,
            color: isTotal ? Colors.green[700] : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            AppFormatters.formatAmount(amount, _currencySymbol),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isTotal ? 22 : 14.5,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              color: isTotal ? Colors.green[700] : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviousBalanceDueRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 190;
        final value = _isPreviousBalanceLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange[800],
                ),
              )
            : Text(
                AppFormatters.formatAmount(_previousBalanceDue, _currencySymbol),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
            border: Border.all(color: Colors.orange[200]!, width: 0.8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 16,
                color: Colors.orange[800],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  compact ? AppLocalizations.of(context)!.createInvoicePrevBalanceShortLabel : AppLocalizations.of(context)!.createInvoicePreviousBalanceDueLabel,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[900],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                flex: compact ? 2 : 1,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalDueRow(double totalDue) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 170;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange[700],
            borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  compact ? AppLocalizations.of(context)!.createInvoiceDueShortLabel : AppLocalizations.of(context)!.createInvoiceTotalDueLabel,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 11 : 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: compact ? 2 : 1,
                child: Text(
                  AppFormatters.formatAmount(totalDue, _currencySymbol),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: compact ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Paid so far against the edited invoice, and what is left of [liveTotal]
  /// (the total as the form shows it now, not the stored one).
  Widget _buildPaymentSummaryPanel(Invoice invoice, double liveTotal) {
    final l10n = AppLocalizations.of(context)!;
    final amountPaid = invoice.amountPaid;
    final outstanding =
        InvoiceCalculator.outstanding(total: liveTotal, paid: amountPaid);
    final isPaid = outstanding <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                l10n.paymentDialogAmountPaidLabel,
                style: TextStyle(fontSize: 14, color: Colors.green[700]),
              ),
            ),
            Text(
              AppFormatters.formatAmount(amountPaid, _currencySymbol),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (isPaid)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              l10n.createInvoicePaidInFullBadge,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n.createInvoiceAmountDueLabel,
                  style: TextStyle(fontSize: 14, color: Colors.orange[800]),
                ),
              ),
              Text(
                AppFormatters.formatAmount(outstanding, _currencySymbol),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<bool> _updateInvoice() async {
    if (_invoice == null) return false;
    if (!_linesNotNegative()) return false;

    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.createInvoiceCustomerNameRequiredMessage),
            ],
          ),
          backgroundColor: Colors.red,
          showCloseIcon: true,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        ),
      );
      return false;
    }

    if (invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.createInvoiceAtLeastOneItemRequiredMessage),
            ],
          ),
          backgroundColor: Colors.red,
          showCloseIcon: true,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        ),
      );
      return false;
    }
    if(!mounted) return false;
    setState(() => isLoading = true);

    try {
      final updatedInvoice = Invoice(
        id: _invoice!.id,
        invoiceNumber: _invoice!.invoiceNumber,
        customer: _resolveInvoiceCustomer(),
        items: List.from(invoiceItems),
        date: _selectedOrderDate,
        dueDate: _selectedDueDate,
        notes: notesController.text.isNotEmpty ? notesController.text : null,
        taxRate: _taxMode == TaxMode.global ? taxRate : 0.0,
        type: invoiceType,
        invoiceTitle: invoiceType == 'Invoice' ? invoiceTitle : null,
        currencyCode: _currencyCode,
        currencySymbol: _currencySymbol,
        taxMode: _taxMode,
        isInterState: _isInterState,
        upiId: _selectedUpi?.id,
        bankAccountId: _selectedBankAccount?.accountNumber,
        quantityLabel:
            _quantityLabel.trim().isEmpty ? null : _quantityLabel.trim(),
        additionalCosts: _buildAdditionalCosts(),
        customFields: _buildCustomFields(),
        invoiceDiscountType: _invoiceDiscountType,
        invoiceDiscountValue: _invoiceDiscountValue,
        hideInvoiceNumber: _hideInvoiceNumber,
        customInvoiceNumber: customInvoiceNumberController.text.trim().isEmpty
            ? null
            : customInvoiceNumberController.text.trim(),
      );

      // Block edits that drop the total below what's already been paid.
      final paid = await ref
          .read(paymentRepositoryProvider)
          .getTotalPaidForInvoice(updatedInvoice.id);
      if (paid - updatedInvoice.total > InvoiceCalculator.moneyEpsilon) {
        if (!mounted) return false;
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!
              .createInvoiceTotalBelowPaidMessage(
                  AppFormatters.formatAmount(paid, _currencySymbol))),
          backgroundColor: Colors.red,
          showCloseIcon: true,
          behavior: SnackBarBehavior.floating,
        ));
        return false;
      }

      await ref.read(invoiceRepositoryProvider).updateInvoice(updatedInvoice);

      final refreshedInvoice =
          await ref.read(invoiceRepositoryProvider).getInvoiceById(updatedInvoice.id);

      if (!mounted) return true;
      setState(() {
        _invoice = refreshedInvoice ?? updatedInvoice;
        isLoading = false;
      });
      _markFormClean();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context)!.createInvoiceUpdatedSuccessMessage(_invoiceTypeLabel(invoiceType))),
            ],
          ),
          backgroundColor: Colors.green,
          showCloseIcon: true,
          duration: const Duration(milliseconds: 2000),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.createInvoiceErrorUpdatingMessage(e.toString())),showCloseIcon: true,),
      );
      return false;
    }
  }

  Widget buildInvoiceSuccessScreen() {
    // Scrolls when the window is shorter than the card (it used to overflow
    // with "BOTTOM OVERFLOWED BY n PIXELS"). The scroll area fills all the
    // space, so the mouse wheel works beside the card too, and the card stays
    // centred when the window is tall.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: _invoiceSuccessCard(),
        ),
      ),
    );
  }

  // ── Created screen (Modern design) ──────────────────────────────────────
  // A compact white card: a green tick, the number (copy), View / Preview /
  // Download / Print tiles, the two "Create New …" buttons and "Go to …".

  Widget _invoiceSuccessCard() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = _invoiceTypeLabel(invoiceType);
    final showSavePrompt =
        selectedCustomer == null && nameController.text.trim().isNotEmpty;
    return Padding(
      key: const ValueKey('modernSuccess'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
                    key: const ValueKey('modernSuccessCard'),
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
                    decoration: BoxDecoration(
                      color: isDark ? scheme.surfaceContainerHighest : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 32,
                            offset: const Offset(0, 14)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _successBadgeModern(),
                        const SizedBox(height: 14),
                        Text(l10n.createInvoiceCreatedHeadline(type),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(l10n.mSuccessSubtitle(type.toLowerCase()),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 16),
                        _successIdChipModern(type),
                        const SizedBox(height: 18),
                        _successTilesModern(type),
                        if (showSavePrompt) ...[
                          const SizedBox(height: 14),
                          _saveWalkInPromptModern(),
                        ],
                        const SizedBox(height: 16),
                        Divider(height: 1, color: scheme.outlineVariant),
                        const SizedBox(height: 16),
                        _successCreateButtonsModern(),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  String _listLabelModern(String type) {
    final l10n = AppLocalizations.of(context)!;
    return switch (type) {
      'Quotation' => l10n.navQuotations,
      'Receipt' => l10n.navReceipts,
      _ => l10n.navInvoices,
    };
  }

  /// The green tick at the top of the card.
  Widget _successBadgeModern() {
    return Container(
      key: const ValueKey('modernSuccessBadge'),
      width: 60,
      height: 60,
      decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
    );
  }

  /// "Receipt ID  #00000001" with a copy button.
  Widget _successIdChipModern(String type) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    // The number as the PDF prints it (prefix and leading-zero settings),
    // e.g. "INV-00000012"; plain "#00000012" while those are loading.
    final raw = _invoice?.invoiceNumber ?? _invoice?.id ?? '';
    final printed = _numberPrefix == null || _invoice == null
        ? null
        : _invoice!.pdfNumberText(_numberPrefix!,
            showLeadingZeros: _numberLeadingZeros);
    final number = printed ?? '#$raw';
    return Container(
      key: const ValueKey('modernSuccessId'),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.description_outlined, color: primary, size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.mSuccessIdLabel(type),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            Text(number,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(width: 18),
        IconButton(
          key: const ValueKey('modernSuccessCopy'),
          tooltip: l10n.mSuccessCopy,
          icon: Icon(Icons.copy_outlined, size: 20, color: scheme.onSurfaceVariant),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: number));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l10n.mSuccessCopied),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2)));
          },
        ),
      ]),
    );
  }

  /// View details, Preview PDF, Download PDF, Print.
  Widget _successTilesModern(String type) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    Widget tile(String key, IconData icon, Color color, String title,
            VoidCallback onTap, {bool colouredTitle = false}) =>
        InkWell(
          key: ValueKey(key),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: colouredTitle ? color : scheme.onSurface)),
            ]),
          ),
        );
    final tiles = [
      tile('modernSuccessView', Icons.visibility_outlined, const Color(0xFF16A34A),
          l10n.createInvoiceViewDetailsLabel,
          () => InvoicePdfServices.showInvoiceDetails(context, _invoice!)),
      tile('modernSuccessPreview', Icons.picture_as_pdf_outlined, const Color(0xFF9333EA),
          l10n.createInvoicePreviewPdfLabel,
          () => InvoicePdfServices.previewPDF(context, _invoice!), colouredTitle: true),
      tile('modernSuccessDownload', Icons.download_rounded, const Color(0xFF2563EB),
          l10n.actionDownloadPdf,
          () => PDFService.downloadPDF(context, _invoice!), colouredTitle: true),
      tile('modernSuccessPrint', Icons.print_rounded, const Color(0xFFF59E0B),
          l10n.mSuccessPrintType(type),
          () => InvoicePdfServices.generatePDF(context, _invoice!)),
    ];
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 520) {
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(child: tiles[i]),
          ],
        ]);
      }
      return Column(children: [
        Row(children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: 14),
          Expanded(child: tiles[1]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: tiles[2]),
          const SizedBox(width: 14),
          Expanded(child: tiles[3]),
        ]),
      ]);
    });
  }

  /// Ctrl+N: new invoice, Ctrl+R: new receipt.
  String? _newShortcutLabel(String type) => switch (type) {
        'Invoice' => 'Ctrl + N',
        'Receipt' => 'Ctrl + R',
        _ => null,
      };

  /// "Go to {list}" and "Create New {this type}" (the shortcut, Ctrl+N for an
  /// invoice or Ctrl+R for a receipt, is in the button's tooltip).
  Widget _successCreateButtonsModern() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    Widget button(
        {required String key,
        required IconData icon,
        required String label,
        required bool filled,
        required VoidCallback? onTap,
        String? tooltip}) {
      final fg = filled ? Colors.white : primary;
      final b = Material(
        color: filled ? primary : scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: filled ? BorderSide.none : BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          key: ValueKey(key),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, color: fg, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: fg, fontWeight: FontWeight.w700, fontSize: 14.5)),
                ),
              ]),
            ),
          ),
        ),
      );
      return tooltip == null ? b : Tooltip(message: tooltip, child: b);
    }

    final shortcut = _newShortcutLabel(invoiceType);
    final goTo = widget.onGoToList == null
        ? null
        : button(
            key: 'modernSuccessGoToList',
            icon: Icons.list_alt_rounded,
            label: l10n.mSuccessGoToList(_listLabelModern(invoiceType)),
            filled: false,
            onTap: () => widget.onGoToList!(invoiceType));
    final create = button(
        key: 'modernSuccessNew$invoiceType',
        icon: Icons.add,
        label: l10n.mSuccessCreateNew(_invoiceTypeLabel(invoiceType)),
        filled: true,
        tooltip: shortcut,
        onTap: () => resetValues(invoiceType));

    return LayoutBuilder(builder: (context, c) {
      if (goTo == null) return create;
      if (c.maxWidth >= 460) {
        return Row(children: [
          Expanded(child: goTo),
          const SizedBox(width: 16),
          Expanded(child: create),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        create,
        const SizedBox(height: 12),
        goTo,
      ]);
    });
  }

  /// A walk-in customer: offer to save them to the customer list.
  Widget _saveWalkInPromptModern() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.person_add_alt_1_outlined,
              color: Colors.amber.shade800, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!
                  .createInvoiceSaveWalkInPrompt(nameController.text.trim()),
              style: TextStyle(
                  fontSize: 13, color: Colors.amber.shade900),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.amber.shade900,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
            ),
            onPressed: () async {
              if (_isSavingCustomer) return; // a second click
              _isSavingCustomer = true;
              try {
                final phone = phoneController.text.trim();
                final existing = phone.isNotEmpty
                    ? await ref.read(customerRepositoryProvider).findByPhone(phone)
                    : null;
                // The invoice just made already points at its customer id:
                // saving the customer under that id links them.
                final invoiceCustomerId = _invoice?.customer.id.trim() ?? '';
                final newCustomer = existing ??
                    Customer(
                      id: invoiceCustomerId.isNotEmpty
                          ? invoiceCustomerId
                          : const Uuid().v4(),
                      name: nameController.text.trim(),
                      email: emailController.text.trim(),
                      phone: phone,
                      address: addressController.text.trim(),
                      gstin: gstinController.text.trim(),
                      businessName:
                          businessNameController.text.trim(),
                    );
                if (existing == null) {
                  await ref.read(customerRepositoryProvider).insertCustomer(newCustomer);
                } else if (_invoice != null && _invoice!.customer.id != existing.id) {
                  // Already saved under this phone: move the invoice to them.
                  await ref
                      .read(invoiceRepositoryProvider)
                      .setInvoiceCustomer(_invoice!.id, existing.id);
                }
                if (mounted) {
                  setState(() {
                    selectedCustomer = newCustomer;
                    _upsertLocalCustomer(newCustomer);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          AppLocalizations.of(context)!.createInvoiceCustomerSavedMessage(newCustomer.name)),
                      behavior: SnackBarBehavior.floating,
                      showCloseIcon: true,
                    ),
                  );
                }
              } finally {
                _isSavingCustomer = false;
              }
            },
            child: Text(AppLocalizations.of(context)!.actionSave,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
            ),
            onPressed: () {
              if(!mounted) return;
              setState(() =>
              selectedCustomer = Customer(
                id: '',
                name: nameController.text.trim(),
                email: '',
                phone: '',
                address: '',
                gstin: '',
                businessName: '',
              ));
            },
            child: Text(AppLocalizations.of(context)!.actionDismiss),
          ),
        ],
      ),
    );
  }

  Widget _withUnsavedChangesPopScope(Widget child) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmLeaveIfDirty() && mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only during the first load: saving sets isLoading too, and must not
    // swap the form for this page.
    if (isLoading && _pendingInitialLoads > 0) {
      return _withUnsavedChangesPopScope(Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.createInvoiceAppBarTitle(_invoiceTypeLabel(invoiceType))),
          ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.commonLoadingDataMessage),
            ],
          ),
        ),
      ));
    }

    final additionalTotal =
        _buildAdditionalCosts().fold(0.0, (sum, c) => sum + c.amount);
    final totals = InvoiceTotalsCalculator.totals(
      lines: invoiceItems.map((item) => InvoiceTotalsCalculator.line(
            price: item.effectivePrice,
            quantity: item.quantity,
            discount: item.discount,
            discountPerUnit: item.discountPerUnit,
            extraCost: item.extraCost ?? 0.0,
            taxRatePercent: item.product.tax_rate.toDouble(),
            priceIncludesTax: item.product.priceIncludesTax,
            taxMode: _taxMode,
            globalTaxRatePercent: taxRate * 100,
          )),
      taxMode: _taxMode,
      globalTaxRate: taxRate,
      globalTaxRateFormat: TaxRateFormat.fraction,
      additionalCostsTotal: additionalTotal,
      invoiceDiscountType: _invoiceDiscountType,
      invoiceDiscountValue: _invoiceDiscountValue,
    );
    final subtotal = totals.subtotal;
    final grossSubtotal = totals.grossSubtotal;
    final totalDiscount = totals.totalDiscount;
    final tax = totals.tax;
    final invoiceDiscountAmount = totals.invoiceDiscountAmount;
    final total = totals.total;

    final bool showingSuccessScreen = !isEditing && _invoice != null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (showingSuccessScreen) return;
          if (invoiceItems.isNotEmpty && !isLoading) {
            _saveAndMaybePrint();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppLocalizations.of(context)!.createInvoiceAddItemBeforeCreatingMessage)),
            );
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true): () async {
          if (showingSuccessScreen)
          {
            if(mounted) await resetValues('Invoice');
          }
          else if(isEditing)
          {
            if (await _confirmLeaveIfDirty() && mounted) {
              widget.onCreateNewInvoice?.call();
              await resetValues('Invoice');
            }
          }
          else
          {
            if(kDebugMode) print("already in create invoice page !");
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          if (showingSuccessScreen) return;
          _productSearchFocusNodeV2.requestFocus();
          _productArrowed = false;
          _refreshDefaultProducts();
          setState(() {
            _showProductDropdownV2 = true;
            _highlightedProductIndexV2 = 0;
          });
        },
        const SingleActivator(LogicalKeyboardKey.keyM, control: true): () {
          if (showingSuccessScreen) return;
          _addAdHocItemDialog();
        },
        // The created screen: Ctrl+N a new invoice, Ctrl+R a new receipt.
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          if (showingSuccessScreen) resetValues('Invoice');
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          if (showingSuccessScreen) resetValues('Receipt');
        },
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
          if (_invoice == null) return;
          InvoicePdfServices.previewPDF(context, _invoice!);
        },
        // Ctrl+P and F11: finish the invoice and print it. Key repeat is
        // ignored so holding the key down cannot print twice.
        const SingleActivator(LogicalKeyboardKey.keyP,
            control: true, includeRepeats: false): () =>
            _saveAndPrintShortcut(showingSuccessScreen),
        const SingleActivator(LogicalKeyboardKey.f11, includeRepeats: false):
            () => _saveAndPrintShortcut(showingSuccessScreen),
      },
      child: Focus(
        focusNode: _screenFocusNode,
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _screenFocusNode.requestFocus(),
          child: _withUnsavedChangesPopScope(Scaffold(
      // Inside the Modern frame the top bar has the title.
      appBar: showingSuccessScreen && !hasModernTopBar
          ? AppBar(
        title: LayoutBuilder(
          builder: (context, titleConstraints) {
            // The old title Row had three unconstrained children (title +
            // optional button, date, and a 24px-font invoice number +
            // tooltip) with nothing able to shrink — any one of them being
            // a little long (a longer invoice number, "Edit Invoice" plus
            // the button, etc.) pushed the total past the AppBar's
            // available width and overflowed. Now each piece is wrapped in
            // Flexible with ellipsis so it can never force an overflow, the
            // oversized 24px invoice-number font is toned down, and the
            // lowest-priority piece (the date) is dropped entirely on
            // narrow windows instead of fighting for space.
            final compact = titleConstraints.maxWidth < 640;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _invoice != null && !isEditing
                              ? AppLocalizations.of(context)!.createInvoiceCreatedTitleShort(_invoiceTypeLabel(invoiceType))
                              : widget.invoiceToEdit != null
                                  ? AppLocalizations.of(context)!.createInvoiceEditTitle(_invoiceTypeLabel(invoiceType))
                                  : _convertFromId != null
                                      ? AppLocalizations.of(context)!.createInvoiceConvertTitle
                                      : _fromClone
                                          ? AppLocalizations.of(context)!.createInvoiceDuplicateAsTitle(_invoiceTypeLabel(invoiceType))
                                          : AppLocalizations.of(context)!.createInvoiceAppBarTitle(_invoiceTypeLabel(invoiceType)),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (isEditing) ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (await _confirmLeaveIfDirty() && mounted) {
                              widget.onCreateNewInvoice?.call();
                              await resetValues('Invoice');
                            }
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                              compact ? AppLocalizations.of(context)!.createInvoiceNewShortLabel : AppLocalizations.of(context)!.createInvoiceNewInvoiceShortcutLabel,
                              style: const TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.surfaceContainer,
                            foregroundColor: Theme.of(context).primaryColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!compact) Text(DateFormat(_datePattern).format(DateTime.now())),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            style: TextStyle(fontSize: compact ? 15 : 18),
                            AppLocalizations.of(context)!.createInvoiceIdLabel(
                                _invoiceTypeLabel(invoiceType),
                                '#$currentInvoiceNumber'),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Tooltip(
                          message: AppLocalizations.of(context)!.mInvPdfNumberInfo,
                          child: Icon(Icons.info_outline,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        elevation: 0,
      )
          : null,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : BrandColors.page,
      body: !isEditing && _invoice != null
          ? _successBodyModern()
          : LayoutBuilder(
              builder: (context, constraints) {
                // V2 owns every width now — no falling back to the old
                // Card-heavy tablet/mobile layouts. Above the threshold we
                // use the two-column desktop composition (items table +
                // sticky right panel, each scrolling independently). Below
                // it, the same flat V2 pieces stack into one scrollable
                // column instead.
                const wideBreakpoint = 980.0;
                final isWide = constraints.maxWidth >= wideBreakpoint;

                // Inside the Modern frame the title and date are in the top
                // bar; shown on its own, the page draws them itself.
                final inTopBar = hasModernTopBar;
                if (inTopBar) _publishHeaderModern();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!inTopBar) ...[
                        _pageHeaderModern(),
                        const SizedBox(height: 14),
                      ],
                      Expanded(
                        child: isWide
                            ? _buildDesktopLayoutModern(tax, subtotal, total,
                                grossSubtotal, totalDiscount, invoiceDiscountAmount)
                            : SingleChildScrollView(
                                child: _buildStackedLayoutModern(tax, subtotal,
                                    total, grossSubtotal, totalDiscount,
                                    invoiceDiscountAmount),
                              ),
                      ),
                      // Wide: the buttons are in the right panel. Narrow (no
                      // panel): they stay at the bottom of the page.
                      if (!isWide) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: _actionButtonsModern(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    )),
        ),
      ),
    );
  }

  // ============================================================
  // V2 — flat / minimal desktop layout.
  // Reuses all state, controllers and business-logic methods from
  // the original screen. Only presentation (styling + composition)
  // differs: no elevated Cards, hairline borders instead, and the
  // right panel (invoice details + costs/notes/tax/totals) is laid
  // out as its own scrollable column with the totals pinned to the
  // bottom, instead of being folded into the items card.
  // ============================================================

  BoxDecoration _flatCardDecorationV2(BuildContext context) => BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      );

  Widget _flatCardV2({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      decoration: _flatCardDecorationV2(context),
      padding: padding ?? const EdgeInsets.all(AppPadding.medium),
      child: child,
    );
  }

  // `invoiceType` itself ('Invoice'/'Quotation'/'Receipt') is an internal
  // English identifier compared elsewhere in this file's logic — this maps
  // it to a translated display label without touching those comparisons.
  String _invoiceTypeLabel(String type) {
    switch (type) {
      case 'Quotation':
        return AppLocalizations.of(context)!.labelQuotation;
      case 'Receipt':
        return AppLocalizations.of(context)!.labelReceipt;
      default:
        return AppLocalizations.of(context)!.labelInvoice;
    }
  }

  /// "Exp 12/01/2027" or "Expired 12/01/2027" for a product's expiry date.
  String _expiryText(DateTime expiryDate, bool isExpired) {
    final l10n = AppLocalizations.of(context)!;
    final date = DateFormat(_datePattern).format(expiryDate);
    return isExpired
        ? l10n.createInvoiceExpiredOnLabel(date)
        : l10n.createInvoiceExpiresOnLabel(date);
  }

  // Order time, next to the order date. Uses the PDF's 12/24-hour setting.
  Widget _orderTimeFieldV2() {
    final text = DateFormat(_pdfTimeFormat == '12' ? 'h:mm a' : 'HH:mm', 'en_US')
        .format(_selectedOrderDate);
    return TextFormField(
      key: ValueKey('order-time-$text'), // rebuild when the time changes
      initialValue: text,
      readOnly: true,
      decoration: _flatFieldDecorationV2(
          AppLocalizations.of(context)!.createInvoiceOrderTimeLabel,
          suffixIcon: const Icon(Icons.access_time, size: 16)),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_selectedOrderDate),
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx)
                .copyWith(alwaysUse24HourFormat: _pdfTimeFormat != '12'),
            child: child!,
          ),
        );
        if (picked == null || !mounted) return;
        setState(() => _selectedOrderDate = DateTime(
            _selectedOrderDate.year,
            _selectedOrderDate.month,
            _selectedOrderDate.day,
            picked.hour,
            picked.minute));
      },
    );
  }

  InputDecoration _flatFieldDecorationV2(
    String label, {
    String? hint,
    String? helperText,
    Widget? suffixIcon,
    Widget? prefixIcon,
    String? prefixText,
    String? suffixText,
  }) {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
      borderSide:
          BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      labelStyle: TextStyle(fontSize: AppFontSize.small),
      isDense: true,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: outline,
      enabledBorder: outline,
      focusedBorder: outline.copyWith(
        borderSide:
            BorderSide(color: Theme.of(context).primaryColor, width: 1.4),
      ),
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
      prefixText: prefixText,
      suffixText: suffixText
    );
  }

  Widget _sectionLabelV2(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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

  /// [narrow]: laid out for the 420 px right-hand panel (the action buttons on
  /// their own line, the fields in a 2-column grid) instead of the full-width,
  /// three-fields-per-row form the other layouts use.
  /// [showClose]: the card sits in the right panel, whose close button
  /// folds the panel away.
  Widget _invoiceDetailsFormV2({bool showClose = true}) {
    return _flatCardV2(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!
                      .mInvDetailsTitle(_invoiceTypeLabel(invoiceType)),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              if (showClose)
                IconButton(
                  key: const ValueKey('modernHidePanel'),
                  tooltip: AppLocalizations.of(context)!
                      .createInvoiceHideDetailsPanelTooltip,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _toggleRightPanel,
                ),
            ],
          ),
          ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: invoiceType,
            decoration: _flatFieldDecorationV2(
              AppLocalizations.of(context)!.createInvoiceTypeFieldLabel,
              helperText: (isEditing || _convertFromId != null)
                  ? AppLocalizations.of(context)!.createInvoiceTypeLockedHelperText
                  : null,
            ),
            items: [
              DropdownMenuItem(value: 'Invoice', child: Text(AppLocalizations.of(context)!.labelInvoice)),
              DropdownMenuItem(value: 'Quotation', child: Text(AppLocalizations.of(context)!.labelQuotation)),
              DropdownMenuItem(value: 'Receipt', child: Text(AppLocalizations.of(context)!.labelReceipt)),
            ],
            onChanged: (isEditing || _convertFromId != null)
                ? null
                : (value) {
                    if (value != null) resetInvoiceType(value);
                  },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: dateController,
                  readOnly: true,
                  decoration: _flatFieldDecorationV2(AppLocalizations.of(context)!.createInvoiceOrderDateLabel,
                      suffixIcon: const Icon(Icons.calendar_today, size: 16)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedOrderDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      if (!mounted) return;
                      setState(() {
                        // Keep the invoice's existing time — the picker returns midnight.
                        _selectedOrderDate = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            _selectedOrderDate.hour,
                            _selectedOrderDate.minute,
                            _selectedOrderDate.second);
                        dateController.text =
                            DateFormat(_datePattern).format(picked);
                      });
                      await _loadPreviousBalanceDue(selectedCustomer);
                    }
                  },
                ),
              ),
              if (_showTimeInPdf) ...[
                const SizedBox(width: 8),
                Expanded(flex: 2, child: _orderTimeFieldV2()),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dueDateController,
            readOnly: true,
            decoration: _flatFieldDecorationV2(
              AppLocalizations.of(context)!.createInvoiceDueDateLabel,
              suffixIcon: dueDateController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        if (!mounted) return;
                        setState(() {
                          _selectedDueDate = null;
                          dueDateController.clear();
                        });
                      },
                    )
                  : const Icon(Icons.calendar_today, size: 16),
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDueDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                if (!mounted) return;
                setState(() {
                  _selectedDueDate = picked;
                  dueDateController.text =
                      DateFormat(_datePattern).format(picked);
                });
              }
            },
          ),
          if (invoiceType == 'Invoice') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              value: invoiceTitle,
              decoration: _flatFieldDecorationV2(
                  _showGstFields ? AppLocalizations.of(context)!.createInvoiceGstTitleLabel : AppLocalizations.of(context)!.createInvoiceTaxTitleLabel),
              items: [
                DropdownMenuItem(value: null, child: Text(AppLocalizations.of(context)!.labelInvoice)),
                DropdownMenuItem(
                    value: 'Tax Invoice', child: Text(AppLocalizations.of(context)!.gstTitleTaxInvoiceLabel)),
                DropdownMenuItem(
                    value: 'Bill of Supply', child: Text(AppLocalizations.of(context)!.gstTitleBillOfSupplyLabel)),
                DropdownMenuItem(
                    value: 'Invoice-cum-Bill of Supply',
                    child: Text(AppLocalizations.of(context)!.gstTitleInvoiceCumBillLabel)),
                DropdownMenuItem(
                    value: 'Cash Bill', child: Text(AppLocalizations.of(context)!.gstTitleCashBillLabel)),
                DropdownMenuItem(
                    value: 'Credit Note', child: Text(AppLocalizations.of(context)!.gstTitleCreditNoteLabel)),
                DropdownMenuItem(
                    value: 'Debit Note', child: Text(AppLocalizations.of(context)!.gstTitleDebitNoteLabel)),
                DropdownMenuItem(
                    value: 'Revised Invoice', child: Text(AppLocalizations.of(context)!.gstTitleRevisedInvoiceLabel)),
              ],
              onChanged: (value) => setState(() => invoiceTitle = value),
            ),
          ],
          const SizedBox(height: 12),
          _pdfNumberOverrideFieldV2(),
          const SizedBox(height: 12),
          _advancedOptionsModern(),
          ],
        ],
      ),
    );
  }

  /// Rows of the search dropdown: the first nine products while the box is
  /// empty, otherwise only what matches what was typed.
  List<Product> get _dropdownProducts => searchController.text.trim().isEmpty
      ? (_defaultProducts.isNotEmpty ? _defaultProducts : products.take(9).toList())
      : filteredProducts;

  /// The first nine products as they are NOW (stock changes with every
  /// invoice), re-read each time the list is opened.
  List<Product> _defaultProducts = const [];
  Future<void> _refreshDefaultProducts() async {
    final repo = ref.read(productRepositoryProvider);
    final results = await repo.getProductsPaginated(
        offset: 0, limit: 9, query: '', type: _businessType.key);
    final metadata =
        await repo.getProductMetadataForIds(results.map((e) => e.id).toList());
    if (!mounted) return;
    setState(() {
      _defaultProducts = results;
      _productMetadata = {..._productMetadata, ...metadata};
    });
  }

  /// The large search boxes of the page (product search, customer search).
  InputDecoration _searchDecorationModern(String hint, {Widget? suffixIcon}) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
      prefixIcon: Icon(Icons.search, size: 21, color: scheme.onSurfaceVariant),
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border(scheme.outlineVariant, 1),
      enabledBorder: border(scheme.outlineVariant, 1),
      focusedBorder: border(Theme.of(context).primaryColor, 1.6),
    );
  }

  Widget _productQuickAddBarV2() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          // The ancestor Focus intercepts arrow-key / escape events before
          // they reach the TextField, so you can move through the dropdown
          // results with the keyboard instead of only being able to click.
          child: Focus(
            onKeyEvent: (node, event) {
              if (!_showProductDropdownV2 || _dropdownProducts.isEmpty) {
                return KeyEventResult.ignored;
              }
              if (event is KeyDownEvent || event is KeyRepeatEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _productArrowed = true;
                  setState(() {
                    _highlightedProductIndexV2 =
                        (_highlightedProductIndexV2 + 1)
                            .clamp(0, _dropdownProducts.length - 1);
                  });
                  _ensureHighlightedProductVisibleV2();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _productArrowed = true;
                  setState(() {
                    _highlightedProductIndexV2 =
                        (_highlightedProductIndexV2 - 1)
                            .clamp(0, _dropdownProducts.length - 1);
                  });
                  _ensureHighlightedProductVisibleV2();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  setState(() => _showProductDropdownV2 = false);
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: searchController,
              focusNode: _productSearchFocusNodeV2,
              textAlignVertical: TextAlignVertical.center,
              // Clicking the box lists the first nine products; typing narrows
              // the list to the matches. (Focus alone, e.g. after a scan, does
              // not open it.)
              onTap: () {
                if (_showProductDropdownV2) return;
                _productArrowed = false;
                _refreshDefaultProducts();
                setState(() {
                  _showProductDropdownV2 = true;
                  _highlightedProductIndexV2 = 0;
                });
              },
              onChanged: (value) {
                _productArrowed = false;
                _filterProducts(value);
                if (value.trim().isEmpty) _refreshDefaultProducts();
                setState(() {
                  _showProductDropdownV2 = true;
                  _highlightedProductIndexV2 = 0;
                });
              },
              onSubmitted: (_) => _submitProductSearch(),
              decoration: _searchDecorationModern(
                AppLocalizations.of(context)!.createInvoiceSearchProductLabel,
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          searchController.clear();
                          setState(() => _showProductDropdownV2 = false);
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          key: const ValueKey('modernCustomItem'),
          onPressed: _addAdHocItemDialog, // Ctrl+M still works
          icon: const Icon(Icons.add, size: 18),
          label: Text(AppLocalizations.of(context)!.createInvoiceCustomItemTitle, maxLines: 1),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            // From the theme, so the label keeps the app font (and Tamil fallback).
            textStyle: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  void _ensureHighlightedProductVisibleV2() {
    if (!_productDropdownScrollControllerV2.hasClients) return;
    const itemExtent = 58.0;
    final targetTop = _highlightedProductIndexV2 * itemExtent;
    final targetBottom = targetTop + itemExtent;
    final viewport = _productDropdownScrollControllerV2.position.viewportDimension;
    final current = _productDropdownScrollControllerV2.offset;
    if (targetTop < current) {
      _productDropdownScrollControllerV2.jumpTo(targetTop);
    } else if (targetBottom > current + viewport) {
      _productDropdownScrollControllerV2.jumpTo(targetBottom - viewport);
    }
  }

  void _selectProductFromDropdownV2(Product product) {
    // A search typed before this selection may still be pending or in
    // flight; it must not overwrite the list after the box has been cleared.
    _productSearchDebounce?.cancel();
    _productSearchRequestId++;
    _loadedProductQuery = null;
    addInvoiceProductPrompt(product);
    searchController.clear();
    _productSearchFocusNodeV2.unfocus();
    if (!mounted) return;
    setState(() => _showProductDropdownV2 = false);
  }

  Widget _productDropdownListV2({double maxHeight = 9 * 58.0 + 8}) {
    const itemExtent = 58.0;
    final shown = _dropdownProducts;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: shown.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(AppLocalizations.of(context)!.createInvoiceItemNotFoundMessage,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              )
            : ListView.builder(
                controller: _productDropdownScrollControllerV2,
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemExtent: itemExtent,
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final product = shown[index];
                  final outOfStock = product.stock <= 0;
                  final isHighlighted = index == _highlightedProductIndexV2;
                  final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

                  // Same metadata source as the Ctrl+F product picker
                  // dialog — pre-loaded in _productMetadata, keyed by
                  // product id, no extra async fetch needed here.
                  final meta =
                      _columnsConfig.productMetadata ? _productMetadata[product.id] : null;
                  final expiryDate = (_columnsConfig.metaExpiryDate &&
                          (meta?.expiryDate?.isNotEmpty ?? false))
                      ? DateTime.tryParse(meta!.expiryDate!)
                      : null;
                  final isExpired =
                      expiryDate != null && expiryDate.isBefore(DateTime.now());
                  final storageLocation =
                      _columnsConfig.metaStorageLocation ? meta?.storageLocation : null;
                  final hasStorage = storageLocation != null && storageLocation.isNotEmpty;

                  return Container(
                    color: isHighlighted
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                        : null,
                    child: ListTile(
                      dense: true,
                      selected: isHighlighted,
                      title: Text(
                        product.name,
                        overflow: TextOverflow.ellipsis,
                        style: outOfStock
                            ? TextStyle(color: Theme.of(context).colorScheme.error)
                            : null,
                      ),
                      // Everything — price, stock, HSN, storage location,
                      // expiry — on one line. Location and expiry are
                      // bolded/colored to stand out from the plain price/
                      // stock/HSN text; an expired date turns red.
                      subtitle: Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 11, color: mutedColor),
                          children: [
                            TextSpan(
                                text:
                                    '${AppFormatters.formatAmount(product.price, _currencySymbol)}  ·  ${AppLocalizations.of(context)!.dashboardStockLabel(AppFormatters.formatStock(product.stock))}'
                                    '${product.hsncode.trim().isEmpty ? '' : '  ·  HSN ${product.hsncode}'}'),
                            if (hasStorage) ...[
                              const TextSpan(text: '  ·  '),
                              TextSpan(
                                text: '📍 $storageLocation',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.blueGrey),
                              ),
                            ],
                            if (expiryDate != null) ...[
                              const TextSpan(text: '  ·  '),
                              TextSpan(
                                text:
                                    _expiryText(expiryDate, isExpired),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isExpired ? Colors.red : Colors.orange[800],
                                ),
                              ),
                            ],
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectProductFromDropdownV2(product),
                    ),
                  );
                },
              ),
      ),
    );
  }
  Future<void> _saveAdHocItemV2(InvoiceItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final existing = await ref
        .read(productRepositoryProvider)
        .findDuplicateByName(item.product.name);
    if (!mounted) return;
    if (existing != null) {
      setState(() => _savedAdHocIds.add(item.product.id));
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context)!.createInvoiceItemAlreadyInProductListMessage(item.product.name)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final newProduct = Product(
      id: const Uuid().v4(),
      name: item.product.name,
      description: item.effectiveDescription,
      price: item.effectivePrice,
      stock: 0,
      hsncode: item.product.hsncode,
      tax_rate: item.product.tax_rate,
      unit: item.product.unit,
      type: item.product.type,
      aliasName: item.product.aliasName,
      priceIncludesTax: item.product.priceIncludesTax,
    );
    await ref.read(productRepositoryProvider).insertProduct(newProduct);
    item.isProductSaved = true;
    if (isEditing && _invoice != null) {
      await ref
          .read(invoiceItemRepositoryProvider)
          .markProductSaved(_invoice!.id, item.product.id);
    }
    // Was: `await productRepository.getAllProducts()` here — re-fetching
    // every product in the database just to refresh this screen's local
    // list after adding ONE new product. Everywhere else on this screen
    // (initial load, search-as-you-type) is properly paginated (limit
    // _productFetchLimit); this call alone bypassed that and would pull
    // the entire products table into memory on every "Save to product
    // list" tap — fine with a handful of products, but a real slowdown
    // (and needless memory/DB load) once the catalog grows large.
    // We already have the full `newProduct` object from the insert above,
    // so there's nothing to re-fetch — just prepend it locally.
    if (!mounted) return;
    setState(() {
      _savedAdHocIds.add(item.product.id);
      products = [newProduct, ...products];
      filteredProducts = [newProduct, ...filteredProducts];
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.createInvoiceProductSavedMessage(newProduct.name)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Items as a table (Modern) ───────────────────────────────────────────
  //
  // One bordered box per cell. Which columns exist follows the settings: HSN/SAC
  // (product columns), Qty (show quantity), Tax % (per-item tax), Discount and
  // Extra (product columns, or whenever an item on this invoice has one). The
  // Item cell prints the name that goes on the PDF in large type, and the other
  // name (English or alias) small underneath.

  List<_ItemCol> _itemColumns(
      {bool compact = false, bool dropEmpty = false, bool tight = false}) {
    // full / compact / tightest width of a column.
    double w(double full, double mid, [double? least]) =>
        tight ? (least ?? mid) : (compact ? mid : full);
    // [tight]: a narrow table leaves out HSN and Unit (Unit stays in the
    // row's edit dialog) so Total and the row buttons stay in view.
    final showHsn = _columnsConfig.hsncode && !tight;
    final showQty = _showQuantity;
    final showTax = _taxMode == TaxMode.perItem;
    // [dropEmpty]: on a tight window, leave out the Discount / Extra columns
    // while no item on the invoice uses them.
    final showDisc = (_columnsConfig.defaultDiscount && !dropEmpty) ||
        invoiceItems.any((i) => i.discount > 0) ||
        !dropEmpty;
    final showExtra = (_columnsConfig.extraCost && !dropEmpty) ||
        invoiceItems.any((i) => (i.extraCost ?? 0) > 0);
    final anyUnsavedCustom = invoiceItems.any((i) =>
        i.product.id.startsWith('custom-') && !_savedAdHocIds.contains(i.product.id));
    final l10n = AppLocalizations.of(context)!;
    final qtyLabel =
        _quantityLabel.trim().isNotEmpty ? _quantityLabel.trim() : l10n.mItemsColQty;
    return [
      _ItemCol('#', w(48, 40, 34), Alignment.center, (item, i) => Text('${i + 1}',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor))),
      _ItemCol(l10n.reportsProductServiceColumnLabel, null, Alignment.centerLeft, _itemNameCell),
      if (showHsn)
        _ItemCol(l10n.productColumnsHsnSacLabel, w(100, 80, 70), Alignment.centerLeft,
            (item, i) => Text(item.product.hsncode.toString(),
                style: const TextStyle(fontSize: 13.5))),
      if (showQty) ...[
        _ItemCol(qtyLabel, w(86, 76, 64), Alignment.center, _qtyCell),
        if (!tight) _ItemCol(l10n.fieldUnitLabel, w(100, 86), Alignment.center, _unitCell),
      ],
      _ItemCol(l10n.productMgmtPriceLabel, w(116, 100, 84), Alignment.center, _priceCell),
      if (showTax)
        _ItemCol(l10n.fieldTaxLabel, w(72, 54, 48), Alignment.centerRight,
            (item, i) => Text('${item.product.tax_rate}%',
                style: const TextStyle(fontSize: 13.5))),
      if (showDisc)
        _ItemCol(l10n.fieldDiscountLabel, w(112, 98, 90), Alignment.center, _discountCell),
      if (showExtra)
        _ItemCol(l10n.productColumnsExtraCostLabel, w(96, 78, 68), Alignment.centerRight, (item, i) {
          final extra = item.extraCost ?? 0;
          return Text(extra > 0 ? '+${AppFormatters.formatAmount(extra, _currencySymbol)}' : '—',
              style: TextStyle(
                  fontSize: 13.5, color: extra > 0 ? Colors.teal[700] : null));
        }),
      // One line always: a big amount shrinks instead of wrapping ("Rs.1450.0 / 0").
      _ItemCol(l10n.fieldTotalLabel, w(120, 104, 90), Alignment.centerRight,
          (item, i) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(AppFormatters.formatAmount(item.total, _currencySymbol),
                    maxLines: 1,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              )),
      // Tight: the row buttons are one ⋮ menu, too narrow for a heading.
      _ItemCol(tight ? '' : l10n.invoiceMgmtColActions,
          tight ? 44 : (anyUnsavedCustom ? w(148, 136) : w(100, 92)),
          Alignment.center, (item, i) => _itemActionsCell(item, i, asMenu: tight)),
    ];
  }

  /// The big name is what the PDF prints (alias when "show alias name" is on,
  /// else the name); the other one sits under it, small.
  Widget _itemNameCell(InvoiceItem item, int index) {
    final scheme = Theme.of(context).colorScheme;
    final alias = (item.product.aliasName ?? '').trim();
    final name = item.product.name.trim();
    final printed = item.product.displayName(_showAliasNameInPdf);
    String? other;
    if (alias.isNotEmpty && alias != name) {
      other = (_showAliasNameInPdf ? name : alias);
      if (other == printed) other = null;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(printed,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppFontSize.medium, fontWeight: FontWeight.bold)),
            ),
            if (_columnsConfig.type && _businessType == BusinessType.both) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.product.type == 'service'
                      ? AppLocalizations.of(context)!.labelService
                      : AppLocalizations.of(context)!.labelProduct,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ],
        ),
        if (other != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(other,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
        if (_columnsConfig.description && item.effectiveDescription.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(item.effectiveDescription,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant)),
          ),
      ],
    );
  }

  Widget _itemActionsCell(InvoiceItem item, int index, {bool asMenu = false}) {
    final l10n = AppLocalizations.of(context)!;
    final unsavedCustom = item.product.id.startsWith('custom-') &&
        !_savedAdHocIds.contains(item.product.id);
    void remove() {
      if (!mounted) return;
      setState(() => invoiceItems.removeAt(index));
    }

    if (asMenu) {
      return PopupMenuButton<String>(
        tooltip: '',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (v) {
          switch (v) {
            case 'edit':
              _editInvoiceItem(index);
            case 'save':
              _saveAdHocItemV2(item);
            case 'remove':
              remove();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                const Icon(Icons.edit_outlined, size: 18),
                const SizedBox(width: 10),
                Text(l10n.tooltipEditItem),
              ])),
          if (unsavedCustom)
            PopupMenuItem(
                value: 'save',
                child: Row(children: [
                  const Icon(Icons.bookmark_add_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(l10n.createInvoiceSaveToProductListTooltip),
                ])),
          PopupMenuItem(
              value: 'remove',
              child: Row(children: [
                Icon(Icons.delete_outline,
                    size: 18, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 10),
                Text(l10n.tooltipRemoveItem),
              ])),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unsavedCustom)
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            tooltip: l10n.createInvoiceSaveToProductListTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: () => _saveAdHocItemV2(item),
          ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: l10n.tooltipEditItem,
          visualDensity: VisualDensity.compact,
          onPressed: () => _editInvoiceItem(index),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          tooltip: l10n.tooltipRemoveItem,
          visualDensity: VisualDensity.compact,
          color: Theme.of(context).colorScheme.error,
          onPressed: remove,
        ),
      ],
    );
  }

  /// Drops the text boxes of items that are no longer on the invoice
  /// (removed, or replaced by the edit dialog).
  void _pruneItemBindings() {
    final ids = {for (final i in invoiceItems) i.id};
    for (final m in [_qtyBindings, _priceBindings, _discBindings]) {
      final gone = m.keys.where((k) => !ids.contains(k)).toList();
      for (final k in gone) {
        final c = m.remove(k)!.controller;
        WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
      }
    }
  }

  Widget _itemsListModern(double width, {required bool expand}) {
    _pruneItemBindings();
    // Always a table. Roomy widths when they fit, tighter columns when they do
    // not, and a sideways scroll as the last resort — never the stacked cards.
    const minItem = 200.0;
    double fixedOf(List<_ItemCol> c) =>
        c.fold<double>(0, (sum, col) => sum + (col.width ?? 0));
    final tiers = <List<_ItemCol>>[
      _itemColumns(),
      _itemColumns(compact: true),
      _itemColumns(compact: true, dropEmpty: true),
      _itemColumns(compact: true, dropEmpty: true, tight: true),
    ];
    var pick = tiers.length - 1;
    for (var i = 0; i < tiers.length; i++) {
      if (width - fixedOf(tiers[i]) >= (i == 0 ? 240 : minItem)) {
        pick = i;
        break;
      }
    }
    final cols = tiers[pick];
    final fixed = fixedOf(cols);
    final compact = pick > 0;
    final needScroll = width - fixed < minItem;
    final tableWidth = needScroll ? fixed + minItem : width;
    final scheme = Theme.of(context).colorScheme;
    final line = scheme.outlineVariant;
    final hPad = compact ? 6.0 : 10.0;

    Widget cell(_ItemCol col, Widget child,
        {required bool header, required bool last}) {
      final box = Container(
        alignment: col.align,
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: header ? 11 : 9),
        decoration: BoxDecoration(
          border: Border(
              right: last ? BorderSide.none : BorderSide(color: line)),
        ),
        child: child,
      );
      return col.width == null
          ? Expanded(child: box)
          : SizedBox(width: col.width, child: box);
    }

    final headerRow = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? scheme.surfaceContainer
            : BrandColors.tableHeader,
        border: Border.all(color: line),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var k = 0; k < cols.length; k++)
              cell(
                cols[k],
                Text(cols[k].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant)),
                header: true,
                last: k == cols.length - 1,
              ),
          ],
        ),
      ),
    );

    Widget row(int index) {
      final item = invoiceItems[index];
      return Container(
        key: ValueKey('itemRow$index'),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          border: Border(
            left: BorderSide(color: line),
            right: BorderSide(color: line),
            bottom: BorderSide(color: line),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var k = 0; k < cols.length; k++)
                cell(cols[k], cols[k].cell(item, index),
                    header: false, last: k == cols.length - 1),
            ],
          ),
        ),
      );
    }

    final Widget table = expand
        ? Column(
            children: [
              headerRow,
              Expanded(
                child: Scrollbar(
                  controller: _invoiceItemsScrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _invoiceItemsScrollController,
                    itemCount: invoiceItems.length,
                    itemBuilder: (context, index) => row(index),
                  ),
                ),
              ),
            ],
          )
        : Column(
            children: [
              headerRow,
              for (var index = 0; index < invoiceItems.length; index++) row(index),
            ],
          );
    if (!needScroll) return table;
    return Scrollbar(
      controller: _itemsHScroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _itemsHScroll,
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: tableWidth, child: table),
      ),
    );
  }

  Widget _itemsEmptyStateV2() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shopping_cart_outlined,
            size: 48, color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 12),
        Text(AppLocalizations.of(context)!.createInvoiceNoItemsAddedMessage,
            style:
                TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context)!.createInvoiceSearchAboveHintMessage,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  // [expand]=true (desktop/wide): the list fills remaining card height and
  // scrolls independently — needs a bounded parent (used inside Expanded).
  // [expand]=false (stacked/narrow): the list sizes to its content and
  // scrolls along with the rest of the page instead.
  Widget _itemsTableSectionV2({bool expand = true}) {
    // Height of the search block (field + its padding); the dropdown opens
    // right under it.
    const searchBlockHeight = 58.0;
    return KeyedSubtree(
      key: const ValueKey('modernItemsCard'),
      child: _flatCardV2(
      child: LayoutBuilder(builder: (context, c) {
        const nineRows = 9 * 58.0 + 8;
        final room = c.hasBoundedHeight
            ? c.maxHeight - searchBlockHeight - 8
            : nineRows;
        final dropdownMax = room < nineRows ? (room < 120 ? 120.0 : room) : nineRows;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              children: [
                // The product search sits at the top of the card.
                SizedBox(
                  height: searchBlockHeight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _productQuickAddBarV2(),
                  ),
                ),
                // Narrow (stacked) layout: the card is only as tall as its
                // content, so the results take their own space instead of
                // floating below the card where they could not be clicked.
                if (_showProductDropdownV2 && !expand) ...[
                  const SizedBox(height: 4),
                  TextFieldTapRegion(
                      child: _productDropdownListV2(maxHeight: nineRows)),
                ],
                const SizedBox(height: 16),
                _itemsHeaderModern(),
                const SizedBox(height: 12),
                if (expand)
                  Expanded(
                    child: invoiceItems.isEmpty
                        // Scrolls rather than overflowing on a very short window.
                        ? Center(child: SingleChildScrollView(child: _itemsEmptyStateV2()))
                        : _itemsListModern(c.maxWidth, expand: true),
                  )
                else
                  invoiceItems.isEmpty
                      ? SizedBox(
                          height: 160, child: Center(child: _itemsEmptyStateV2()))
                      : _itemsListModern(c.maxWidth, expand: false),
                const SizedBox(height: 8),
              ],
            ),
            // The search results float over the item list, right under the
            // search box. (Ctrl+F in the item list keeps working too.)
            if (_showProductDropdownV2 && expand)
              Positioned(
                left: 0,
                right: 0,
                top: searchBlockHeight + 4,
                child: TextFieldTapRegion(
                    child: _productDropdownListV2(maxHeight: dropdownMax)),
              ),
          ],
        );
      }),
    ));
  }

  /// "Items  3 items" with Clear All on the right.
  Widget _itemsHeaderModern() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(l10n.mInvItems,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text(l10n.dashboardItemCountLabel(invoiceItems.length),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant)),
        ),
        const Spacer(),
        if (invoiceItems.isNotEmpty)
          TextButton.icon(
            key: const ValueKey('modernClearAll'),
            onPressed: _confirmClearAllItems,
            icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
            label: Text(l10n.mInvClearAll,
                style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Future<void> _confirmClearAllItems() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.mInvClearAll),
        content: Text(l10n.mInvClearAllConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.actionCancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.mInvClearAll),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      invoiceItems.clear();
      _forgetAllItemBindings();
    });
  }

  // ── Inline editing in the items table ─────────────────────────────────

  /// The text box of [item]'s [field] in [bindings]. When the value changed
  /// somewhere else (the edit dialog, the same product added again) the box
  /// gets a fresh controller with the new value.
  TextEditingController _bound(Map<String, _CellBinding> bindings,
      InvoiceItem item, double value, String Function(double) format) {
    final b = bindings[item.id];
    if (b != null && b.synced == value) return b.controller;
    if (b != null) {
      final old = b.controller;
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    final fresh = _CellBinding(TextEditingController(text: format(value)), value);
    bindings[item.id] = fresh;
    return fresh.controller;
  }

  void _forgetAllItemBindings() {
    for (final m in [_qtyBindings, _priceBindings, _discBindings]) {
      for (final b in m.values) {
        final c = b.controller;
        WidgetsBinding.instance.addPostFrameCallback((_) => c.dispose());
      }
      m.clear();
    }
  }

  static String _qtyText(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  static String _moneyText(double v) => v.toStringAsFixed(2);

  Widget _cellInput(
    TextEditingController controller,
    ValueChanged<String> onChanged, {
    required Key key,
    String? prefix,
    Color? color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c, width: w));
    return SizedBox(
      height: 36,
      child: TextField(
        key: key,
        controller: controller,
        onChanged: onChanged,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        style: TextStyle(fontSize: 14, color: color),
        decoration: InputDecoration(
          isDense: true,
          prefixText: prefix,
          prefixStyle: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
          border: border(scheme.outlineVariant, 1),
          enabledBorder: border(scheme.outlineVariant, 1),
          focusedBorder: border(Theme.of(context).primaryColor, 1.4),
        ),
      ),
    );
  }

  /// A number typed in a table cell. The comma is the decimal mark only in
  /// French and Spanish; elsewhere it groups thousands ("1,250" = 1250).
  double? _parseNum(String t) {
    final lang = Localizations.localeOf(context).languageCode;
    final commaDecimal = lang == 'fr' || lang == 'es';
    final s = t.trim();
    return double.tryParse(
        commaDecimal ? s.replaceAll(',', '.') : s.replaceAll(',', ''));
  }

  /// A product of this screen's loaded lists (first page, search results).
  Product? _loadedProduct(String id) {
    for (final list in [products, filteredProducts, _defaultProducts]) {
      for (final p in list) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  /// How much of [item]'s product is in stock for this line, or null when
  /// that is not known or does not apply: a custom item, a service, unlimited
  /// stock, or a line loaded from a saved document whose product is not in
  /// the lists loaded here (saved lines carry no stock).
  double? _availableStock(InvoiceItem item) {
    if (item.product.id.startsWith('custom-')) return null;
    final p = _loadedItemIds.contains(item.id)
        ? _loadedProduct(item.product.id)
        : item.product;
    if (p == null || p.type == 'service' || p.unlimitedStock) return null;
    // Editing: this document's own saved quantities were already taken from
    // stock (read from the copy made on open, not from the edited lines).
    return Product.roundStock(
        p.stock + (_stockHeldByEdited[item.product.id] ?? 0));
  }

  Widget _qtyCell(InvoiceItem item, int index) {
    final c = _bound(_qtyBindings, item, item.quantity, _qtyText);
    final available = _availableStock(item);
    final over = available != null && item.quantity > available;
    return _cellInput(c, (t) {
      final v = _parseNum(t);
      if (v == null || v <= 0) return;
      setState(() {
        item.quantity = v;
        _qtyBindings[item.id]!.synced = v;
      });
    }, key: ValueKey('qty_$index'), color: over ? Theme.of(context).colorScheme.error : null);
  }

  Widget _priceCell(InvoiceItem item, int index) {
    final c = _bound(_priceBindings, item, item.effectivePrice, _moneyText);
    return _cellInput(c, (t) {
      final v = _parseNum(t);
      if (v == null || v < 0) return;
      setState(() {
        item.unitPrice = v == item.product.price ? null : v;
        _priceBindings[item.id]!.synced = v;
      });
    }, key: ValueKey('price_$index'));
  }

  Widget _discountCell(InvoiceItem item, int index) {
    final c = _bound(_discBindings, item, item.discount, _moneyText);
    return _cellInput(c, (t) {
      var v = t.trim().isEmpty ? 0.0 : _parseNum(t);
      if (v == null || v < 0) return;
      // Never more than the price (per unit) or the line (flat).
      final cap = item.discountPerUnit
          ? item.effectivePrice
          : item.effectivePrice * item.quantity;
      if (v > cap) v = cap;
      setState(() {
        item.discount = v!;
        _discBindings[item.id]!.synced = v;
      });
    }, key: ValueKey('disc_$index'), prefix: _currencySymbol);
  }

  Widget _unitCell(InvoiceItem item, int index) {
    final scheme = Theme.of(context).colorScheme;
    final current = item.effectiveUnit.trim();
    final units = <String>{...ProductUnits.presets, if (current.isNotEmpty) current}
        .where((u) => u.isNotEmpty)
        .toList();
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: ValueKey('unit_$index'),
          value: current.isEmpty ? null : current,
          isExpanded: true,
          isDense: true,
          hint: const Text('—', style: TextStyle(fontSize: 13.5)),
          style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
          items: [
            for (final u in units)
              DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (u) {
            if (u == null) return;
            setState(() => item.unit = u);
          },
        ),
      ),
    );
  }

  Widget _invoiceDiscountSectionV2() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _invoiceDiscountController,
                  onChanged: (_) {
                    if (!mounted) return;
                    setState(() {});
                  },
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _flatFieldDecorationV2(AppLocalizations.of(context)!.createInvoiceDiscountFieldLabel,
                      hint: '',
                      prefixText: _invoiceDiscountType == InvoiceDiscountType.amount
                        ? '$_currencySymbol '
                        : null,
                      suffixText: _invoiceDiscountType == InvoiceDiscountType.percent
                          ? '%'
                          : null,),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<InvoiceDiscountType>(
                    value: _invoiceDiscountType,
                    isDense: true,
                    selectedItemBuilder: (context) => [
                      const Center(child: Text('%')),
                      Center(child: Text(AppLocalizations.of(context)!.discountTypeAmountShortLabel)),
                    ],
                    items: [
                      const DropdownMenuItem(
                          value: InvoiceDiscountType.percent, child: Text('%')),
                      DropdownMenuItem(
                          value: InvoiceDiscountType.amount, child: Text(AppLocalizations.of(context)!.labelAmount)),
                    ],
                    onChanged: (v) {
                      if (v == null || !mounted) return;
                      setState(() => _invoiceDiscountType = v);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notesFieldV2() {
    return TextField(
      controller: notesController,
      maxLength: DefaultValues.additionalNotesLength,
      maxLines: 3,
      decoration: _flatFieldDecorationV2(AppLocalizations.of(context)!.createInvoiceNotesOptionalLabel,
          hint: AppLocalizations.of(context)!.createInvoiceNotesHint,
          suffixIcon: IconButton(
            icon: const Icon(Icons.open_in_full, size: 18),
            tooltip: AppLocalizations.of(context)!.tooltipEditInLargerView,
            onPressed: _editNotesDialogV2,
          )),
    );
  }

  static const double _notesDialogMinWidth = 320;
  static const double _notesDialogMaxWidth = 800;
  static const double _notesDialogMinHeight = 200;
  static const double _notesDialogMaxHeight = 600;

  Future<void> _editNotesDialogV2() async {
    final controller = TextEditingController(text: notesController.text);
    double dialogWidth = 480;
    double dialogHeight = 320;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.createInvoiceNotesTitle),
          content: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: TextField(
                    controller: controller,
                    maxLength: DefaultValues.additionalNotesLength,
                    expands: true,
                    maxLines: null,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.createInvoiceNotesHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        setDialogState(() {
                          dialogWidth = (dialogWidth + details.delta.dx)
                              .clamp(_notesDialogMinWidth, _notesDialogMaxWidth);
                          dialogHeight = (dialogHeight + details.delta.dy)
                              .clamp(_notesDialogMinHeight, _notesDialogMaxHeight);
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.south_east, size: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(AppLocalizations.of(context)!.actionSave),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      notesController.text = result;
    }
  }

  // Generalized version of _editNotesDialogV2 above, for other single-line
  // fields (e.g. customer address) that also want the resizable large-editor
  // "expand" affordance. maxLength is optional since not every field this
  // is used on restricts length.
  Future<void> _editLongTextDialogV2({
    required String title,
    required TextEditingController controller,
    int? maxLength,
  }) async {
    final dialogController = TextEditingController(text: controller.text);
    double dialogWidth = 480;
    double dialogHeight = 320;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: TextField(
                    controller: dialogController,
                    maxLength: maxLength,
                    expands: true,
                    maxLines: null,
                    autofocus: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        setDialogState(() {
                          dialogWidth = (dialogWidth + details.delta.dx)
                              .clamp(_notesDialogMinWidth, _notesDialogMaxWidth);
                          dialogHeight = (dialogHeight + details.delta.dy)
                              .clamp(_notesDialogMinHeight, _notesDialogMaxHeight);
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.south_east, size: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(context)!.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, dialogController.text),
              child: Text(AppLocalizations.of(context)!.actionSave),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => controller.text = result);
    }
  }

  Widget _pdfNumberOverrideFieldV2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(AppLocalizations.of(context)!.createInvoiceHideNumberInPdfLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: _hideInvoiceNumber,
                onChanged: (value) {
                  if (!mounted) return;
                  setState(() => _hideInvoiceNumber = value);
                },
              ),
            ),
          ],
        ),
        if (_hideInvoiceNumber) ...[
          const SizedBox(height: 10),
          TextField(
            controller: customInvoiceNumberController,
            decoration: _flatFieldDecorationV2(AppLocalizations.of(context)!.createInvoiceCustomNumberLabel,
                hint: AppLocalizations.of(context)!.createInvoiceCustomNumberHint),
          ),
        ],
      ],
    );
  }

  Widget _taxSettingsSectionV2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(AppLocalizations.of(context)!.createInvoiceEnableTaxLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: _isTaxEnabled,
                onChanged: (value) {
                  if (!mounted) return;
                  setState(() => _isTaxEnabled = value);
                },
              ),
            ),
          ],
        ),
        if (_isTaxEnabled) ...[
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment<bool>(
                  value: false,
                  icon: const Icon(Icons.percent, size: 15),
                  tooltip: AppLocalizations.of(context)!.createInvoiceGlobalRateTooltip),
              ButtonSegment<bool>(
                  value: true,
                  icon: const Icon(Icons.list_alt, size: 15),
                  tooltip: AppLocalizations.of(context)!.createInvoicePerItemRateTooltip),
            ],
            selected: {_isPerItem},
            onSelectionChanged: (selection) {
              if (!mounted) return;
              setState(() => _isPerItem = selection.first);
            },
          ),
          const SizedBox(height: 10),
          if (!_isPerItem)
            TextField(
              controller: taxRateController,
              decoration:
                  _flatFieldDecorationV2(AppLocalizations.of(context)!.createInvoiceDefaultTaxRateLabel).copyWith(suffixText: '%'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                if (!mounted) return;
                setState(() {
                  taxRate =
                      (double.tryParse(value) ?? (taxRate * 100)) / 100;
                });
              },
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppBorderRadius.xsmall),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(AppLocalizations.of(context)!.createInvoiceTaxRateFromProductMessage,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          if (_showGstFields) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(AppLocalizations.of(context)!.createInvoiceInterStateLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _isInterState,
                    onChanged: (value) {
                      if (!mounted) return;
                      setState(() => _isInterState = value);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
        if (_upiEntries.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<UpiEntry?>(
            isExpanded: true,
            value: _selectedUpi,
            decoration: _flatFieldDecorationV2(AppLocalizations.of(context)!.createInvoicePaymentUpiAccountLabel),
            items: [
              DropdownMenuItem<UpiEntry?>(
                  value: null, child: Text(AppLocalizations.of(context)!.commonNoneLabel)),
              ..._upiEntries.map((e) => DropdownMenuItem<UpiEntry?>(
                    value: e,
                    child:
                        Text(e.displayLabel, style: const TextStyle(fontSize: 12)),
                  )),
            ],
            onChanged: (val) {
              if (!mounted) return;
              setState(() => _selectedUpi = val);
            },
          ),
        ],
        if (_bankAccounts.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<BankAccount?>(
            isExpanded: true,
            value: _selectedBankAccount,
            decoration: _flatFieldDecorationV2(AppLocalizations.of(context)!.createInvoiceBankAccountLabel),
            items: [
              DropdownMenuItem<BankAccount?>(
                  value: null, child: Text(AppLocalizations.of(context)!.commonNoneLabel)),
              ..._bankAccounts.map((e) => DropdownMenuItem<BankAccount?>(
                    value: e,
                    child:
                        Text(e.displayLabel, style: const TextStyle(fontSize: 12)),
                  )),
            ],
            onChanged: (val) {
              if (!mounted) return;
              setState(() => _selectedBankAccount = val);
            },
          ),
        ],
      ],
    );
  }

  Widget _totalsFooterV2(double tax, double subtotal, double total,
      double grossSubtotal, double totalDiscount, double invoiceDiscountAmount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTotalRow(
              AppLocalizations.of(context)!.fieldSubtotalLabel, totalDiscount > 0 ? grossSubtotal : subtotal, false),
          if (totalDiscount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)!.createInvoiceDiscountColonLabel,
                    style: TextStyle(fontSize: 14, color: Colors.orange[700])),
                Text('-${AppFormatters.formatAmount(totalDiscount, _currencySymbol)}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700])),
              ],
            ),
          ],
          const SizedBox(height: 6),
          _buildTotalRow(_taxLabelModern(), tax, false),
          ..._buildAdditionalCosts().map((c) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildTotalRow(
                    c.label.isEmpty ? AppLocalizations.of(context)!.createInvoiceExtraCostFallbackLabel : c.label, c.amount, false),
              )),
          if (invoiceDiscountAmount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                      _invoiceDiscountType == InvoiceDiscountType.percent
                          ? AppLocalizations.of(context)!.createInvoiceDiscountPercentLabel(_invoiceDiscountValue.toStringAsFixed(1))
                          : AppLocalizations.of(context)!.createInvoiceInvoiceDiscountColonLabel,
                      style:
                          TextStyle(fontSize: 14, color: Colors.orange[700])),
                ),
                Flexible(
                  child: Text(
                      '-${AppFormatters.formatAmount(invoiceDiscountAmount, _currencySymbol)}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700])),
                ),
              ],
            ),
          ],
          if (_showPreviousBalance && selectedCustomer != null) ...[
            const SizedBox(height: 8),
            _buildPreviousBalanceDueRow(),
          ],
          const SizedBox(height: 10),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 10),
          _buildTotalRow(AppLocalizations.of(context)!.fieldTotalLabel, total, true),
          if (_showPreviousBalance &&
              selectedCustomer != null &&
              !_isPreviousBalanceLoading &&
              _previousBalanceDue > 0) ...[
            const SizedBox(height: 8),
            _buildTotalDueRow(total + _previousBalanceDue),
          ],
          if (isEditing &&
              _invoice != null &&
              _invoice!.type == 'Invoice' &&
              _invoice!.payments.isNotEmpty)
            _buildPaymentSummaryPanel(_invoice!, total),
        ],
      ),
    );
  }

  // ═══ The Modern page (October 2026 design) ══════════════════════════════
  // Header (title, date, number) · customer card · items card (search, table,
  // add another) · right panel (details, charges & adjustments, totals) ·
  // bottom bar (status, Save Draft, Save & Print ▾, Create ▾).

  String _screenTitle(AppLocalizations l10n) {
    final type = _invoiceTypeLabel(invoiceType);
    if (_invoice != null && !isEditing) {
      return l10n.createInvoiceCreatedTitleShort(type);
    }
    if (widget.invoiceToEdit != null) return l10n.createInvoiceEditTitle(type);
    if (_convertFromId != null) {
      return l10n.createInvoiceConvertTitle;
    }
    if (_fromClone && widget.draftId == null) {
      return l10n.createInvoiceDuplicateAsTitle(type);
    }
    return l10n.createInvoiceAppBarTitle(type);
  }

  Future<void> _pickOrderDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedOrderDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      // Keep the invoice's existing time — the picker returns midnight.
      _selectedOrderDate = DateTime(picked.year, picked.month, picked.day,
          _selectedOrderDate.hour, _selectedOrderDate.minute, _selectedOrderDate.second);
      dateController.text = DateFormat(_datePattern).format(picked);
    });
    await _loadPreviousBalanceDue(selectedCustomer);
  }

  /// The date of the document: a chip that opens the date picker.
  Widget _dateChipModern() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        key: const ValueKey('modernHeaderDate'),
        customBorder:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: _pickOrderDate,
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today_outlined,
                  size: 17, color: scheme.onSurfaceVariant),
              const SizedBox(width: 9),
              Text(DateFormat('dd MMM yyyy').format(_selectedOrderDate),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down, size: 19, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }

  /// The "created" screen; in the Modern frame its title goes to the top bar.
  Widget _successBodyModern() {
    if (hasModernTopBar) {
      publishModernHeader((page) => ModernPageHeader(
            page: page,
            title: AppLocalizations.of(context)!
                .createInvoiceCreatedTitleShort(_invoiceTypeLabel(invoiceType)),
            onBack: widget.onGoToList == null
                ? null
                : () => widget.onGoToList!(invoiceType),
          ));
    }
    return buildInvoiceSuccessScreen();
  }

  /// Editing a saved invoice: start a new one (asks first if there are
  /// unsaved changes). Same as Ctrl+Q.
  Future<void> _startNewFromEdit() async {
    if (await _confirmLeaveIfDirty() && mounted) {
      widget.onCreateNewInvoice?.call();
      await resetValues('Invoice');
    }
  }

  /// Title, date and (when editing) "+ Create Invoice" in the Modern top bar.
  void _publishHeaderModern() {
    publishModernHeader((page) {
      final l10n = AppLocalizations.of(context)!;
      return ModernPageHeader(
        page: page,
        title: _screenTitle(l10n),
        subtitle: l10n.mInvSubtitle,
        actions: [_dateChipModern()],
        createButton: isEditing
            ? FilledButton.icon(
                key: const ValueKey('modernCreateDocument'),
                onPressed: _startNewFromEdit,
                icon: const Icon(Icons.add, size: 18),
                label: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(l10n.mInvCreateType(l10n.labelInvoice),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              )
            : null,
      );
    });
  }

  /// Title and date, drawn on the page when it is shown outside the Modern
  /// frame (inside it they are in the top bar).
  Widget _pageHeaderModern() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_screenTitle(l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(l10n.mInvSubtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
      const SizedBox(width: 16),
      _dateChipModern(),
    ]);
  }

  // ── Customer ─────────────────────────────────────────────────────────────

  // Open: name, phone, GSTIN / VAT and address. Closed: the name only.
  bool _customerStripOpen = true;

  Widget _customerLabelModern() {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).primaryColor;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.people_alt_outlined, size: 21, color: primary),
      ),
      const SizedBox(width: 10),
      Text(l10n.labelCustomer,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
    ]);
  }

  InputDecoration _customerFieldDecoration(String label, IconData icon,
      {Widget? suffixIcon}) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 14.5, color: scheme.onSurfaceVariant),
      prefixIcon: Icon(icon, size: 19, color: scheme.onSurfaceVariant),
      suffixIcon: suffixIcon,
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border(scheme.outlineVariant, 1),
      enabledBorder: border(scheme.outlineVariant, 1),
      focusedBorder: border(Theme.of(context).primaryColor, 1.6),
    );
  }

  /// Save (a new customer) or Update (a picked one that was changed),
  /// refresh, clear. A picked customer's boxes can be changed straight away.
  List<Widget> _customerStripActions() {
    final l10n = AppLocalizations.of(context)!;
    final saved =
        selectedCustomer != null && selectedCustomer!.id.trim().isNotEmpty;
    final hasName = nameController.text.trim().isNotEmpty;
    // Any change to a picked customer, the address included.
    final changed = selectedCustomer == null ||
        !_customerFormMatchesSelected ||
        addressController.text.trim() != selectedCustomer!.address.trim();
    return [
      if (hasName && changed)
        TextButton.icon(
          key: const ValueKey('modernSaveCustomer'),
          onPressed: _isSavingCustomer ? null : _saveCustomer,
          icon: _isSavingCustomer
              ? const SizedBox(
                  width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.person_add_alt_outlined, size: 16),
          // A picked customer: the changes update that customer.
          label: Text(_isSavingCustomer
              ? l10n.createInvoiceSavingEllipsisLabel
              : (saved ? l10n.mInvUpdateCustomer : l10n.createInvoiceSaveCustomerLabel)),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      if (saved)
        IconButton(
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: l10n.createInvoiceRefreshCustomerTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: _refreshCustomerFromRecord,
        ),
      if (hasName || saved)
        IconButton(
          key: const ValueKey('modernClearCustomer'),
          icon: const Icon(Icons.close, size: 18),
          tooltip: l10n.createInvoiceClearCustomerTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: _clearCustomerSelection,
        ),
    ];
  }

  Widget _customerToggleModern() => IconButton(
        key: const ValueKey('customerStripToggle'),
        icon: Icon(_customerStripOpen ? Icons.expand_less : Icons.expand_more,
            size: 22),
        tooltip: _customerStripOpen
            ? MaterialLocalizations.of(context).expandedIconTapHint
            : MaterialLocalizations.of(context).collapsedIconTapHint,
        onPressed: () {
          if (_customerListPortal.isShowing) _customerListPortal.hide();
          setState(() => _customerStripOpen = !_customerStripOpen);
        },
      );

  /// The customer box: name (search the saved customers or type a walk-in
  /// name), phone, GSTIN / VAT and address. The search box always shows; the
  /// details open when the box is clicked or a customer is picked, and close
  /// when the product search is used (the arrow opens / closes them by hand).
  Widget _customerSectionModern() {
    final l10n = AppLocalizations.of(context)!;
    return KeyedSubtree(
      key: const ValueKey('modernCustomerCard'),
      child: _flatCardV2(
        child: LayoutBuilder(builder: (context, c) {
          final phone = TextField(
            key: const ValueKey('modernCustomerPhone'),
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textAlignVertical: TextAlignVertical.center,
            onChanged: (_) => setState(() {}),
            decoration: _customerFieldDecoration(l10n.fieldPhoneLabel, Icons.phone_outlined),
          );
          final gstin = TextField(
            key: const ValueKey('modernCustomerGstin'),
            controller: gstinController,
            textAlignVertical: TextAlignVertical.center,
            onChanged: (_) => setState(() {}),
            decoration: _customerFieldDecoration(l10n.fieldGstinVatLabel, Icons.badge_outlined),
          );
          final address = TextField(
            key: const ValueKey('modernCustomerAddress'),
            controller: addressController,
            textAlignVertical: TextAlignVertical.center,
            onChanged: (_) => setState(() {}),
            decoration: _customerFieldDecoration(
                l10n.fieldAddressLabel, Icons.location_on_outlined,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.open_in_full, size: 16),
                  tooltip: l10n.tooltipEditInLargerView,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editLongTextDialogV2(
                    title: l10n.fieldAddressLabel,
                    controller: addressController,
                  ),
                )),
          );
          const gap = SizedBox(width: 12);

          final open = _customerStripOpen;
          // Wide: name and details on one line; otherwise details under it.
          final oneLine = c.maxWidth >= (_showGstFields ? 1300 : 1100);
          // GSTIN gets a bit more room than the phone: all 15 characters show.
          final details = c.maxWidth >= 640
              ? Row(children: [
                  Expanded(flex: 4, child: phone),
                  if (_showGstFields) ...[gap, Expanded(flex: 5, child: gstin)],
                  gap,
                  Expanded(flex: 7, child: address),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: phone),
                    if (_showGstFields) ...[gap, Expanded(child: gstin)],
                  ]),
                  const SizedBox(height: 12),
                  address,
                ]);
          return Column(
            key: ValueKey(open ? 'customerStrip' : 'customerStripClosed'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                if (c.maxWidth >= 520) ...[
                  _customerLabelModern(),
                  const SizedBox(width: 16),
                ],
                Expanded(flex: open && oneLine ? 3 : 1, child: _customerNameFieldModern()),
                if (open && oneLine) ...[
                  gap,
                  Expanded(flex: 2, child: phone),
                  if (_showGstFields) ...[gap, Expanded(flex: 2, child: gstin)],
                  gap,
                  Expanded(flex: 3, child: address),
                ],
                const SizedBox(width: 6),
                ..._customerStripActions(),
                _customerToggleModern(),
              ]),
              if (open && !oneLine) ...[
                const SizedBox(height: 12),
                details,
              ],
            ],
          );
        }),
      ),
    );
  }

  // ── Right panel ──────────────────────────────────────────────────────────

  String _taxLabelModern() {
    final l10n = AppLocalizations.of(context)!;
    if (_taxMode == TaxMode.global && taxRate > 0) {
      final pct = taxRate * 100;
      final txt = pct == pct.roundToDouble()
          ? pct.toInt().toString()
          : pct.toStringAsFixed(1);
      return '${l10n.fieldTaxLabel} (${_showGstFields ? 'GST' : 'VAT'} $txt%)';
    }
    return l10n.fieldTaxLabel;
  }

  Widget _advancedOptionsModern() {
    final l10n = AppLocalizations.of(context)!;
    final primary = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: const ValueKey('modernAdvancedOptions'),
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _advancedOpen = !_advancedOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(children: [
                Icon(Icons.tune, size: 18, color: primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l10n.mInvAdvancedOptions,
                      style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
                ),
                Icon(_advancedOpen ? Icons.expand_less : Icons.chevron_right,
                    color: primary),
              ]),
            ),
          ),
        ),
        if (_advancedOpen) ...[
          const SizedBox(height: 14),
          if (_customFieldsEnabled && _customFieldDefs.isNotEmpty) ...[
            _customFieldsSummaryCardV2(),
            const SizedBox(height: 14),
          ],
          _sectionLabelV2(l10n.createInvoiceNotesTitle),
          _notesFieldV2(),
          const SizedBox(height: 18),
          _sectionLabelV2(l10n.createInvoiceTaxSettingsLabel),
          _taxSettingsSectionV2(),
        ],
      ],
    );
  }

  Widget _chargesCardModern() {
    final l10n = AppLocalizations.of(context)!;
    final used =
        _additionalCostControllers.isNotEmpty || _invoiceDiscountValue > 0;
    final open = _chargesOpen ?? used;
    const green = Color(0xFF16A34A);
    return _flatCardV2(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('modernCharges'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _chargesOpen = !open),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add_box_outlined, size: 18, color: green),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l10n.mInvChargesAdjustments,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15, color: green)),
              ),
              Icon(open ? Icons.expand_less : Icons.expand_more, color: green),
            ]),
          ),
          if (open) ...[
            const SizedBox(height: 14),
            _buildAdditionalCostsSection(showHeader: false),
            const SizedBox(height: 12),
            _invoiceDiscountSectionV2(),
          ],
        ],
      ),
    );
  }

  Widget _totalsCardModern(double tax, double subtotal, double total,
          double grossSubtotal, double totalDiscount, double invoiceDiscountAmount) =>
      Container(
        key: const ValueKey('modernTotals'),
        decoration: _flatCardDecorationV2(context),
        clipBehavior: Clip.antiAlias,
        child: _totalsFooterV2(tax, subtotal, total, grossSubtotal,
            totalDiscount, invoiceDiscountAmount),
      );

  Widget _rightPanelModern(double tax, double subtotal, double total,
      double grossSubtotal, double totalDiscount, double invoiceDiscountAmount) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const ValueKey('modernRightPanelScroll'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _invoiceDetailsFormV2(),
                const SizedBox(height: 12),
                _chargesCardModern(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _totalsCardModern(tax, subtotal, total, grossSubtotal, totalDiscount,
            invoiceDiscountAmount),
        const SizedBox(height: 12),
        _actionButtonsModern(),
      ],
    );
  }

  Widget _buildDesktopLayoutModern(double tax, double subtotal, double total,
      double grossSubtotal, double totalDiscount, double invoiceDiscountAmount) {
    final openWidth = Platform.isAndroid ? 340.0 : _rightPanelWidth;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            // A very short window: the customer box and the items scroll
            // together instead of squeezing the items card.
            if (c.maxHeight < 480) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _customerSectionModern(),
                    const SizedBox(height: 12),
                    _itemsTableSectionV2(expand: false),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _customerSectionModern(),
                const SizedBox(height: 12),
                Expanded(child: _itemsTableSectionV2()),
              ],
            );
          }),
        ),
        const SizedBox(width: 16),
        // Slides between the full panel and a slim strip (the close button on
        // the details card folds it).
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _rightPanelOpen ? openWidth : _rightStripWidth),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          builder: (context, w, _) => SizedBox(
            key: const ValueKey('modernRightPanel'),
            width: w,
            child: ClipRect(
              child: w > _rightStripWidth + 140
                  // Laid out at full width while sliding, so nothing squeezes.
                  ? OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: openWidth,
                      maxWidth: openWidth,
                      child: _rightPanelModern(tax, subtotal, total,
                          grossSubtotal, totalDiscount, invoiceDiscountAmount),
                    )
                  : _rightPanelStripModern(total),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStackedLayoutModern(double tax, double subtotal, double total,
      double grossSubtotal, double totalDiscount, double invoiceDiscountAmount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _customerSectionModern(),
        const SizedBox(height: 12),
        _invoiceDetailsFormV2(showClose: false),
        const SizedBox(height: 12),
        _itemsTableSectionV2(expand: false),
        const SizedBox(height: 12),
        _chargesCardModern(),
        const SizedBox(height: 12),
        _totalsCardModern(tax, subtotal, total, grossSubtotal, totalDiscount,
            invoiceDiscountAmount),
      ],
    );
  }

  // ── Save Draft / Create ──────────────────────────────────────────────────

  /// Create ▾ choices: create and start a new one, save & print.
  List<(IconData, String, VoidCallback)> _createMenuModern() {
    final l10n = AppLocalizations.of(context)!;
    final editing = widget.invoiceToEdit != null;
    return [
      if (!editing)
        (Icons.add_circle_outline, l10n.mInvCreateAndNew,
            () => _saveAndMaybePrint(startNew: true)),
      if (editing || !_autoPrintOn)
        (Icons.print_outlined, editing ? l10n.mInvUpdatePrint : l10n.mInvSavePrint,
            () => _saveAndMaybePrint(forcePrint: true)),
    ];
  }

  String get _createTipModern => widget.invoiceToEdit != null
      ? AppLocalizations.of(context)!.createInvoiceUpdateShortcutsTip
      : AppLocalizations.of(context)!.createInvoiceCreateShortcutsTip;

  /// Save Draft and Create ▾: under the totals in the right panel (at the
  /// bottom of the page on a narrow window).
  Widget _actionButtonsModern() {
    final l10n = AppLocalizations.of(context)!;
    final editing = widget.invoiceToEdit != null;
    final canSave = invoiceItems.isNotEmpty && !isLoading;
    final type = _invoiceTypeLabel(invoiceType);
    final createLabel = isLoading
        ? l10n.createInvoiceProcessingLabel
        : (editing ? l10n.mInvUpdateType(type) : l10n.mInvCreateType(type));
    final draft = SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        key: const ValueKey('modernSaveDraft'),
        onPressed: _savingDraft || isLoading ? null : _saveDraft,
        icon: _savingDraft
            ? const SizedBox(
                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.description_outlined, size: 18),
        label: Text(l10n.mInvSaveDraft, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
    final create = Tooltip(
      message: _createTipModern,
      child: _splitButton(
        key: 'modernCreate',
        menuKey: 'modernCreateDropdown',
        filled: true,
        expand: true,
        icon: editing ? Icons.update : Icons.check,
        label: createLabel,
        onPressed: canSave ? () => _saveAndMaybePrint() : null,
        menu: _createMenuModern(),
      ),
    );
    return LayoutBuilder(builder: (context, box) {
      // Side by side when both labels fit. When they would be cut off (the
      // longer Tamil words in the right panel), Create goes full width with
      // Save Draft under it.
      final style = Theme.of(context)
          .textTheme
          .labelLarge!
          .merge(const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5));
      double textWidth(String s) => (TextPainter(
            text: TextSpan(text: s, style: style),
            maxLines: 1,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout())
              .width;
      final row = box.maxWidth - (editing ? 0 : 10);
      // Each button's share of the row, less its padding, icon and gap (and
      // Create's ▾ menu).
      final createRoom = row * (editing ? 1 : 3 / 5) - 24 - 19 - 10 - 41;
      final draftRoom = row * 2 / 5 - 24 - 18 - 8;
      final fits = !box.maxWidth.isFinite ||
          (textWidth(createLabel) <= createRoom &&
              (editing || textWidth(l10n.mInvSaveDraft) <= draftRoom));
      if (!fits) {
        return Column(
          key: const ValueKey('modernActions'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            create,
            if (!editing) ...[const SizedBox(height: 8), draft],
          ],
        );
      }
      return Row(
        key: const ValueKey('modernActions'),
        children: [
          if (!editing) ...[
            Expanded(flex: 2, child: draft),
            const SizedBox(width: 10),
          ],
          Expanded(flex: 3, child: create),
        ],
      );
    });
  }

  Widget _expandIf(bool expand, Widget child) =>
      expand ? Expanded(child: SizedBox(height: 48, child: child)) : child;

  /// A button with a ▾ menu of related choices on its right.
  Widget _splitButton({
    required String key,
    String? menuKey,
    required bool filled,
    bool expand = false,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required List<(IconData, String, VoidCallback)> menu,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final primary = Theme.of(context).primaryColor;
    final enabled = onPressed != null;
    final fg = filled
        ? Colors.white
        : (enabled ? primary : scheme.onSurfaceVariant);
    final bg = filled
        ? (enabled ? primary : primary.withValues(alpha: 0.4))
        : scheme.surfaceContainerHighest;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: filled
            ? BorderSide.none
            : BorderSide(
                color: enabled
                    ? primary.withValues(alpha: 0.5)
                    : scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _expandIf(
              expand,
              InkWell(
                key: ValueKey(key),
                onTap: onPressed,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: expand ? 12 : 18),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (filled && isLoading)
                          const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                        else
                          Icon(icon, size: 19, color: fg),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: fg, fontWeight: FontWeight.w700, fontSize: 14.5)),
                        ),
                      ]),
                ),
              ),
            ),
            if (menu.isNotEmpty) ...[
              Container(
                  width: 1,
                  height: 28,
                  color: filled
                      ? Colors.white.withValues(alpha: 0.35)
                      : scheme.outlineVariant),
              PopupMenuButton<int>(
                key: ValueKey(menuKey ?? '${key}Menu'),
                enabled: enabled,
                tooltip: '',
                onSelected: (i) => menu[i].$3(),
                itemBuilder: (_) => [
                  for (var i = 0; i < menu.length; i++)
                    PopupMenuItem<int>(
                      value: i,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(menu[i].$1, size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Flexible(
                            child: Text(menu[i].$2,
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                ],
                child: SizedBox(
                    width: 40,
                    height: 48,
                    child: Icon(Icons.keyboard_arrow_down, color: fg)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Create on the folded panel: the icon creates; the ▾ under it has the
  /// same choices as Create ▾ (start a new one, save & print).
  Widget _stripCreateModern(bool canSave, bool isEditMode) {
    final primary = Theme.of(context).primaryColor;
    final scheme = Theme.of(context).colorScheme;
    final menu = _createMenuModern();
    return Tooltip(
      message: _createTipModern,
      child: Material(
        color: canSave ? primary : primary.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 48,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              key: const ValueKey('modernStripCreate'),
              onTap: canSave ? _saveAndMaybePrint : null,
              child: SizedBox(
                height: 42,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Icon(isEditMode ? Icons.update : Icons.save_outlined,
                          color: Colors.white),
                ),
              ),
            ),
            Container(height: 1, width: 30, color: Colors.white.withValues(alpha: 0.35)),
            PopupMenuButton<int>(
              key: const ValueKey('modernStripCreateMenu'),
              enabled: canSave,
              tooltip: '',
              onSelected: (i) => menu[i].$3(),
              itemBuilder: (_) => [
                for (var i = 0; i < menu.length; i++)
                  PopupMenuItem<int>(
                    value: i,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(menu[i].$1, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Flexible(
                          child: Text(menu[i].$2,
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
              ],
              child: const SizedBox(
                  height: 24,
                  child: Center(
                      child: Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white))),
            ),
          ]),
        ),
      ),
    );
  }

  /// The folded panel: a button to open it again, the details shortcut, the
  /// total, Save Draft and Create ▾ — so an invoice can still be finished
  /// with the panel out of the way.
  Widget _rightPanelStripModern(double total) {
    final scheme = Theme.of(context).colorScheme;
    final isEditMode = widget.invoiceToEdit != null;
    final canSave = invoiceItems.isNotEmpty && !isLoading;
    return Container(
      key: const ValueKey('modernRightStrip'),
      decoration: _flatCardDecorationV2(context),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        children: [
          IconButton(
            tooltip: AppLocalizations.of(context)!
                .createInvoiceShowDetailsPanelTooltip,
            icon: const Icon(Icons.keyboard_double_arrow_left),
            onPressed: _toggleRightPanel,
          ),
          Divider(height: 12, color: scheme.outlineVariant),
          IconButton(
            tooltip: AppLocalizations.of(context)!
                .mInvDetailsTitle(_invoiceTypeLabel(invoiceType)),
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: _toggleRightPanel,
          ),
          const Spacer(),
          Text(AppLocalizations.of(context)!.fieldTotalLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(AppFormatters.formatAmount(total, _currencySymbol),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green)),
            ),
          ),
          const SizedBox(height: 10),
          if (!isEditMode) ...[
            Tooltip(
              message: AppLocalizations.of(context)!.mInvSaveDraft,
              child: SizedBox(
                width: 48,
                height: 42,
                child: OutlinedButton(
                  key: const ValueKey('modernStripDraft'),
                  onPressed: _savingDraft || isLoading ? null : _saveDraft,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _savingDraft
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.description_outlined, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _stripCreateModern(canSave, isEditMode),
        ],
      ),
    );
  }

}

/// Unit dropdown + "Custom…" text field. Whether the custom field is shown
/// is tracked as sticky local state (set the moment "Custom…" is picked) —
/// NOT re-derived from the current unit string each rebuild, since that
/// string is still empty right after picking "Custom…" and would otherwise
/// make the field disappear before the user can type anything into it.
class _UnitPicker extends StatefulWidget {
  final String initialUnit;
  final TextEditingController customController;
  final ValueChanged<String> onUnitChanged;

  const _UnitPicker({
    required this.initialUnit,
    required this.customController,
    required this.onUnitChanged,
  });

  @override
  State<_UnitPicker> createState() => _UnitPickerState();
}

class _UnitPickerState extends State<_UnitPicker> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _isCustom ? 'custom' : _presetValue,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.fieldUnitOverrideLabel,
            prefixIcon: const Icon(Icons.straighten),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          items: [
            DropdownMenuItem(value: '', child: Text(AppLocalizations.of(context)!.commonNoneLabel)),
            for (final u in ProductUnits.presets)
              DropdownMenuItem(value: u, child: Text(u.toUpperCase())),
            DropdownMenuItem(value: 'custom', child: Text(AppLocalizations.of(context)!.commonCustomEllipsisLabel)),
          ],
          onChanged: (val) {
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
          TextField(
            controller: widget.customController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.fieldCustomUnitLabel,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppBorderRadius.xsmall)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            onChanged: widget.onUnitChanged,
          ),
        ],
      ],
    );
  }
}

/// One column of the Modern items table. A null [width] takes the space left.
/// A text box in the items table and the value it last showed.
class _CellBinding {
  _CellBinding(this.controller, this.synced);
  final TextEditingController controller;
  double synced;
}

class _ItemCol {
  const _ItemCol(this.label, this.width, this.align, this.cell);
  final String label;
  final double? width;
  final Alignment align;
  final Widget Function(InvoiceItem item, int index) cell;
}
