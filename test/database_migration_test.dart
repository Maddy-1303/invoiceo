// Regression test for the full historical upgrade chain.
//
// v4 (commit 4fd7ee2, 2025-10-14) is the oldest schema any real installed
// user could still be on — every version before it (v1-v3) predates the
// `path_provider`-based db location and lacked company_info/settings
// tables entirely, so no live install could realistically be stuck there.
// v4's schema is reproduced here verbatim from git history (see
// `git show 4fd7ee2:lib/database/database_helper.dart`) since that code no
// longer exists in the current file.
//
// This exercises the real `_upgradeDB` chain (via the @visibleForTesting
// upgradeDbForTest hook) end to end: v4 -> current dbVersion, on a live
// in-memory sqflite_common_ffi connection — the same way sqflite's real
// onUpgrade callback operates on an already-open Database, just invoked
// directly instead of via a version-triggered reopen (in-memory DBs don't
// survive close/reopen, so that path doesn't apply here anyway). Catches: a
// migration step assuming a column/table that didn't exist yet in v4, a
// step ordering bug, or old data getting clobbered/lost during the chain.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/models/product.dart';

const _v4Schema = [
  '''
    CREATE TABLE customers (
      id TEXT PRIMARY KEY,
      name TEXT,
      email TEXT,
      phone TEXT,
      address TEXT,
      gstin TEXT
    )
  ''',
  '''
    CREATE TABLE products (
      id TEXT PRIMARY KEY,
      name TEXT,
      description TEXT,
      price REAL,
      stock INTEGER,
      hsncode TEXT,
      tax_rate INTEGER
    )
  ''',
  '''
    CREATE TABLE invoices (
      id TEXT PRIMARY KEY,
      customer_id TEXT,
      customer_name TEXT,
      customer_email TEXT,
      customer_phone TEXT,
      customer_address TEXT,
      customer_gstin TEXT,
      date TEXT,
      notes TEXT,
      tax_rate REAL,
      type TEXT
    )
  ''',
  '''
    CREATE TABLE invoice_items (
      invoice_id TEXT,
      product_id TEXT,
      product_name TEXT,
      product_description TEXT,
      product_price REAL,
      product_tax_rate INTEGER,
      product_hsn_code TEXT,
      quantity INTEGER,
      discount REAL,
      PRIMARY KEY (invoice_id, product_id),
      FOREIGN KEY (invoice_id) REFERENCES invoices(id)
    )
  ''',
  '''
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      username TEXT UNIQUE,
      password TEXT,
      user_type TEXT
    )
  ''',
  '''
    CREATE TABLE company_info (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      address TEXT,
      phone TEXT,
      email TEXT,
      website TEXT,
      gstin TEXT
    )
  ''',
  '''
    CREATE TABLE settings (
      key TEXT PRIMARY KEY,
      value TEXT
    )
  ''',
];

// products as a fresh v50 install made it: stock still INTEGER.
const _v50Products = '''
  CREATE TABLE products (
    id TEXT PRIMARY KEY,
    name TEXT,
    description TEXT,
    price REAL,
    stock INTEGER,
    hsncode TEXT,
    tax_rate INTEGER,
    type TEXT DEFAULT 'product',
    default_discount REAL DEFAULT 0,
    purchase_price REAL DEFAULT 0.0,
    alias_name TEXT,
    unit TEXT DEFAULT '',
    unlimited_stock INTEGER DEFAULT 0,
    price_includes_tax INTEGER DEFAULT 0
  )
''';

/// A v50 database with products only (all that v51 touches) and sample rows:
/// whole, big, zero, negative and NULL stock.
Future<Database> _openV50Products({List<String> extra = const []}) async {
  final db = await openDatabase(
    inMemoryDatabasePath,
    version: 50,
    onCreate: (db, v) async {
      await db.execute(_v50Products);
      await db.execute('CREATE INDEX idx_products_name ON products(name)');
      await db.execute(
          'CREATE INDEX idx_products_name_nc ON products(name COLLATE NOCASE)');
      for (final sql in extra) {
        await db.execute(sql);
      }
    },
  );
  await db.insert('products', {
    'id': 'p1',
    'name': 'Rice',
    'description': 'Ponni',
    'price': 60.0,
    'stock': 50,
    'hsncode': '1006',
    'tax_rate': 5,
    'unit': 'kg',
    'purchase_price': 45.0,
  });
  await db.insert('products', {'id': 'p2', 'name': 'Big', 'price': 1.0, 'stock': 123456789});
  await db.insert('products',
      {'id': 'p3', 'name': 'Cut', 'price': 1.0, 'stock': 0, 'unlimited_stock': 1});
  await db.insert('products', {'id': 'p4', 'name': 'Short', 'price': 1.0, 'stock': -3});
  await db.insert('products', {'id': 'p5', 'name': 'Legacy', 'price': 1.0});
  return db;
}

Future<Map<String, Map<String, Object?>>> _stockRows(Database db) async => {
      for (final r in await db.rawQuery(
          'SELECT *, typeof(stock) AS stock_type FROM products'))
        r['id'] as String: r
    };

Future<String> _stockColumnType(Database db) async =>
    (await db.rawQuery('PRAGMA table_info(products)'))
        .firstWhere((c) => c['name'] == 'stock')['type'] as String;

Future<Database> _openV4WithSampleData() async {
  final db = await openDatabase(
    inMemoryDatabasePath,
    version: 4,
    onCreate: (db, v) async {
      for (final stmt in _v4Schema) {
        await db.execute(stmt);
      }
    },
  );

  await db.insert('customers', {
    'id': 'c1',
    'name': 'Old Customer',
    'email': 'old@example.com',
    'phone': '9999999999',
    'address': 'Old Address',
    'gstin': '',
  });
  await db.insert('products', {
    'id': 'p1',
    'name': 'Old Product',
    'description': '',
    'price': 100.0,
    'stock': 5,
    'hsncode': '1234',
    'tax_rate': 18,
  });
  await db.insert('invoices', {
    'id': 'i1',
    'customer_id': 'c1',
    'customer_name': 'Old Customer',
    'customer_email': 'old@example.com',
    'customer_phone': '9999999999',
    'customer_address': 'Old Address',
    'customer_gstin': '',
    'date': '2025-10-14',
    'notes': 'Pre-migration invoice',
    'tax_rate': 18.0,
    'type': 'Invoice',
  });
  await db.insert('invoice_items', {
    'invoice_id': 'i1',
    'product_id': 'p1',
    'product_name': 'Old Product',
    'product_description': '',
    'product_price': 100.0,
    'product_tax_rate': 18,
    'product_hsn_code': '1234',
    'quantity': 2,
    'discount': 0.0,
  });
  await db.insert('users', {
    'id': 'user-001',
    'username': 'admin',
    'password': 'admin',
    'user_type': 'admin',
  });
  await db.insert('company_info', {
    'name': 'Your Company Name',
    'address': '123 Street \nCity, State 12345',
    'phone': '9876543210',
    'email': 'info@yourcompany.com',
    'website': 'www.yourcompany.com',
    'gstin': '',
  });

  return db;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('upgrading from v4 to current preserves old data and adds new columns',
      () async {
    final db = await _openV4WithSampleData();
    final currentVersion = DatabaseHelper().dbVersion;

    await DatabaseHelper().upgradeDbForTest(db, 4, currentVersion);

    // Old data survived the full chain.
    final invoice =
        (await db.query('invoices', where: 'id = ?', whereArgs: ['i1']))
            .first;
    expect(invoice['notes'], 'Pre-migration invoice');
    expect(invoice['customer_name'], 'Old Customer');

    final item = (await db.query('invoice_items',
            where: 'invoice_id = ?', whereArgs: ['i1']))
        .first;
    expect(item['product_name'], 'Old Product');
    expect(item['quantity'], 2);

    // New columns exist with sane defaults, didn't crash the chain.
    expect(invoice['currency_code'], 'INR');
    expect(invoice['tax_mode'], 'global');
    expect(invoice['customer_business_name'], '');

    final user = (await db.query('users',
            where: 'username = ?', whereArgs: ['admin']))
        .first;
    expect(user['salt'], isNull); // no salt was ever set for this legacy row
    expect(user['password_changed'], 0); // forced reset for admin, per v8 step

    // v41 added the per-line description. Pre-v41 rows stay NULL, and nothing
    // falls back to product_description, so reprinting an old invoice renders
    // exactly what it rendered before.
    expect(item.containsKey('description'), isTrue);
    expect(item['description'], isNull);

    // v49 added quotation status + quote<->invoice links. Legacy rows stay
    // NULL (read as 'draft', no link).
    expect(invoice.containsKey('status'), isTrue);
    expect(invoice['status'], isNull);
    expect(invoice['converted_to_invoice_id'], isNull);
    expect(invoice['converted_from_invoice_id'], isNull);

    final companyInfo = (await db.query('company_info')).first;
    expect(companyInfo['country'], 'India');
    expect(companyInfo['pan_number'], '');
    expect(companyInfo['fssai_code'], '');

    // v51 made stock REAL; the old whole number is kept exactly.
    expect(await _stockColumnType(db), 'REAL');
    final product = (await _stockRows(db))['p1']!;
    expect(product['stock'], 5.0);
    expect(product['stock_type'], 'real');
    expect(product['name'], 'Old Product');
    expect(product['type'], 'product');

    await db.close();
  });

  test('v50 -> v51: stock becomes REAL, whole stock kept exactly, decimals accepted',
      () async {
    final db = await _openV50Products(extra: [
      // A column some older build added on its own: it must survive.
      'ALTER TABLE products ADD COLUMN extra_note TEXT',
    ]);
    await db.update('products', {'extra_note': 'keep me'},
        where: 'id = ?', whereArgs: ['p1']);

    await DatabaseHelper().upgradeDbForTest(db, 50, 51);

    expect(await _stockColumnType(db), 'REAL');
    final rows = await _stockRows(db);
    expect(rows.keys.toSet(), {'p1', 'p2', 'p3', 'p4', 'p5'});
    expect(rows['p1']!['stock'], 50.0);
    expect(rows['p1']!['stock_type'], 'real');
    expect(rows['p2']!['stock'], 123456789.0);
    expect(rows['p3']!['stock'], 0.0);
    expect(rows['p4']!['stock'], -3.0);
    expect(rows['p5']!['stock'], isNull);
    // Every other value is untouched.
    expect(rows['p1']!['description'], 'Ponni');
    expect(rows['p1']!['price'], 60.0);
    expect(rows['p1']!['hsncode'], '1006');
    expect(rows['p1']!['tax_rate'], 5);
    expect(rows['p1']!['unit'], 'kg');
    expect(rows['p1']!['purchase_price'], 45.0);
    expect(rows['p1']!['extra_note'], 'keep me');
    expect(rows['p3']!['unlimited_stock'], 1);
    // The app reads them as doubles; NULL is 0.
    expect(Product.fromMap(rows['p1']!).stock, 50.0);
    expect(Product.fromMap(rows['p5']!).stock, 0.0);

    // Decimals go in and come back exactly.
    await db.update('products', {'stock': 49.6}, where: 'id = ?', whereArgs: ['p1']);
    expect((await _stockRows(db))['p1']!['stock'], 49.6);

    // Column defaults, the primary key and the indexes are kept.
    await db.insert('products', {'id': 'p6', 'name': 'New', 'price': 1.0, 'stock': 12.5});
    final p6 = (await _stockRows(db))['p6']!;
    expect(p6['stock'], 12.5);
    expect(p6['type'], 'product');
    expect(p6['unit'], '');
    expect(p6['unlimited_stock'], 0);
    expect(p6['price_includes_tax'], 0);
    expect(p6['default_discount'], 0);
    await expectLater(db.insert('products', {'id': 'p1', 'name': 'Twin'}),
        throwsA(isA<DatabaseException>()));
    final schema = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE tbl_name LIKE 'products%'"))
        .map((r) => r['name'])
        .toSet();
    expect(schema, containsAll(['products', 'idx_products_name', 'idx_products_name_nc']));
    expect(schema, isNot(contains('products_new')));

    // Running the step again changes nothing.
    await DatabaseHelper().upgradeDbForTest(db, 50, 51);
    expect((await _stockRows(db))['p1']!['stock'], 49.6);
    expect((await _stockRows(db)).length, 6);

    await db.close();
  });

  test('v51 keeps the INTEGER column when a view would block the rebuild; '
      'decimals still work', () async {
    final db = await _openV50Products(
        extra: ['CREATE VIEW cheap AS SELECT id FROM products WHERE price < 10']);

    await DatabaseHelper().upgradeDbForTest(db, 50, 51);

    expect(await _stockColumnType(db), 'INTEGER');
    expect((await _stockRows(db))['p1']!['stock'], 50);
    // INTEGER affinity still keeps 49.6 as a decimal.
    await db.update('products', {'stock': 49.6}, where: 'id = ?', whereArgs: ['p1']);
    final p1 = (await _stockRows(db))['p1']!;
    expect(p1['stock'], 49.6);
    expect(Product.fromMap(p1).stock, 49.6);

    await db.close();
  });
}
