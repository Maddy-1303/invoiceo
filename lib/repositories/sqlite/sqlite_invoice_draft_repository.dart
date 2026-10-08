import 'package:invoiceo/database/invoice_draft_service.dart';
import 'package:invoiceo/models/invoice_draft.dart';
import 'package:invoiceo/repositories/invoice_draft_repository.dart';

class SqliteInvoiceDraftRepository implements InvoiceDraftRepository {
  @override
  Future<String> saveDraft(InvoiceDraft draft) => InvoiceDraftService.saveDraft(draft);
  @override
  String newId() => InvoiceDraftService.newId();
  @override
  Future<List<InvoiceDraft>> getDrafts(String type) => InvoiceDraftService.getDrafts(type);
  @override
  Future<InvoiceDraft?> getDraft(String id) => InvoiceDraftService.getDraft(id);
  @override
  Future<int> countDrafts(String type) => InvoiceDraftService.countDrafts(type);
  @override
  Future<void> deleteDraft(String id) => InvoiceDraftService.deleteDraft(id);
}
