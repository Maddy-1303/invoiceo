import 'package:sqflite/sqflite.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/models/invoice_draft.dart';
import 'package:uuid/uuid.dart';

/// Saved drafts ("Save Draft" on the create form). See [InvoiceDraft].
class InvoiceDraftService {
  static final _dbHelper = DatabaseHelper();

  /// Saves [draft], replacing the one with the same id. Returns its id.
  static Future<String> saveDraft(InvoiceDraft draft) async {
    final db = await _dbHelper.database;
    await db.insert('invoice_drafts', draft.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return draft.id;
  }

  static String newId() => const Uuid().v4();

  /// Drafts of [type] ('Invoice' | 'Quotation' | 'Receipt'), newest first.
  static Future<List<InvoiceDraft>> getDrafts(String type) async {
    final db = await _dbHelper.database;
    final rows = await db.query('invoice_drafts',
        where: 'type = ?', whereArgs: [type], orderBy: 'updated_at DESC');
    final out = <InvoiceDraft>[];
    for (final r in rows) {
      try {
        out.add(InvoiceDraft.fromRow(r));
      } catch (_) {
        // A draft that cannot be read is skipped rather than breaking the list.
      }
    }
    return out;
  }

  static Future<InvoiceDraft?> getDraft(String id) async {
    final db = await _dbHelper.database;
    final rows =
        await db.query('invoice_drafts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return InvoiceDraft.fromRow(rows.first);
  }

  static Future<int> countDrafts(String type) async {
    final db = await _dbHelper.database;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM invoice_drafts WHERE type = ?', [type]);
    return (r.first['n'] as int?) ?? 0;
  }

  static Future<void> deleteDraft(String id) async {
    final db = await _dbHelper.database;
    await db.delete('invoice_drafts', where: 'id = ?', whereArgs: [id]);
  }
}
