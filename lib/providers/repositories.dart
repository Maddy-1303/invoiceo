import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoiceo/repositories/auth_repository.dart';
import 'package:invoiceo/repositories/company_info_repository.dart';
import 'package:invoiceo/repositories/customer_repository.dart';
import 'package:invoiceo/repositories/invoice_item_repository.dart';
import 'package:invoiceo/repositories/invoice_repository.dart';
import 'package:invoiceo/repositories/invoice_draft_repository.dart';
import 'package:invoiceo/repositories/payment_repository.dart';
import 'package:invoiceo/repositories/product_repository.dart';
import 'package:invoiceo/repositories/report_repository.dart';
import 'package:invoiceo/repositories/settings_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  throw UnimplementedError(
    'customerRepositoryProvider must be overridden.',
  );
});

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  throw UnimplementedError(
    'invoiceRepositoryProvider must be overridden.',
  );
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  throw UnimplementedError(
    'productRepositoryProvider must be overridden.',
  );
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  throw UnimplementedError(
    'paymentRepositoryProvider must be overridden.',
  );
});

final companyInfoRepositoryProvider = Provider<CompanyInfoRepository>((ref) {
  throw UnimplementedError(
    'companyInfoRepositoryProvider must be overridden.',
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  throw UnimplementedError(
    'settingsRepositoryProvider must be overridden.',
  );
});

final invoiceDraftRepositoryProvider = Provider<InvoiceDraftRepository>((ref) {
  throw UnimplementedError(
    'invoiceDraftRepositoryProvider must be overridden.',
  );
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  throw UnimplementedError(
    'reportRepositoryProvider must be overridden.',
  );
});

final invoiceItemRepositoryProvider = Provider<InvoiceItemRepository>((ref) {
  throw UnimplementedError(
    'invoiceItemRepositoryProvider must be overridden.',
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError(
    'invoiceItemRepositoryProvider must be overridden.',
  );
});


// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:invoiceo/repositories/company_info_repository.dart';
// import 'package:invoiceo/repositories/customer_repository.dart';
// import 'package:invoiceo/repositories/invoice_repository.dart';
// import 'package:invoiceo/repositories/payment_repository.dart';
// import 'package:invoiceo/repositories/product_repository.dart';
// import 'package:invoiceo/repositories/report_repository.dart';
// import 'package:invoiceo/repositories/settings_repository.dart';
// import 'package:invoiceo/repositories/sqlite/sqlite_company_info_repository.dart';
// import 'package:invoiceo/repositories/sqlite/sqlite_customer_repository.dart';
// import 'package:invoiceo/repositories/sqlite/sqlite_invoice_repository.dart';
// import 'package:invoiceo/repositories/sqlite/sqlite_payment_repository.dart';
// import 'package:invoiceo/repositories/sqlite/sqlite_product_repository.dart';
// import 'package:invoiceo/repositories/sqlite/sqlite_report_repository.dart';
// import 'package:invoiceo/repositories/sqlite/sqlite_settings_repository.dart';
//
// final customerRepositoryProvider = Provider<CustomerRepository>((ref) => SqliteCustomerRepository());
// final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) => SqliteInvoiceRepository());
// final productRepositoryProvider = Provider<ProductRepository>((ref) => SqliteProductRepository());
// final paymentRepositoryProvider = Provider<PaymentRepository>((ref) => SqlitePaymentRepository());
// final companyInfoRepositoryProvider = Provider<CompanyInfoRepository>((ref) => SqliteCompanyInfoRepository());
// final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SqliteSettingsRepository());
// final reportRepositoryProvider = Provider<ReportRepository>((ref) => SqliteReportRepository());
