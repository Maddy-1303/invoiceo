import 'package:invoiceo/models/company_info.dart';

abstract class CompanyInfoRepository {
  Future<CompanyInfo?> getCompanyInfo();
  Future<int> insertCompanyInfo(CompanyInfo info);
  Future<int> updateCompanyInfo(CompanyInfo info);
}
