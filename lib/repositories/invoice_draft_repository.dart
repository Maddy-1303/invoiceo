import 'package:invoiceo/models/invoice_draft.dart';

/// Drafts saved from the create form ("Save Draft").
abstract class InvoiceDraftRepository {
  Future<String> saveDraft(InvoiceDraft draft);
  String newId();
  Future<List<InvoiceDraft>> getDrafts(String type);
  Future<InvoiceDraft?> getDraft(String id);
  Future<int> countDrafts(String type);
  Future<void> deleteDraft(String id);
}
