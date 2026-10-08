// The product list's kind filter (Products / Services pages) and the new
// list tabs: in_stock (in_stock + low + out = all), taxed / tax_free /
// no_hsn for services, the one-query tab counts, SKU search and deleting
// only one kind.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:invoiceo/database/database_helper.dart';
import 'package:invoiceo/database/product_service.dart';
import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/utils/formatters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  var dbCounter = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tmp = Directory.systemTemp.createTempSync('invoiceo_product_kinds');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tmp.path);
  });
  tearDownAll(() async {
    await DatabaseHelper().close();
    tmp.deleteSync(recursive: true);
  });

  Product p(String id, {String type = 'product', double stock = 0, bool unlimited = false,
          int tax = 0, String hsn = '1001'}) =>
      Product(id: id, name: 'Item $id', description: '', price: 10, stock: stock,
          hsncode: hsn, tax_rate: tax, type: type, unlimitedStock: unlimited);

  // Products: healthy 50, unlimited, low 5, out 0, and a tracked SERVICE at
  // stock 0 (services can be tracked) that must never count as a product.
  setUp(() async {
    await DatabaseHelper().switchToFile('product_kinds_${dbCounter++}.db');
    await ProductService.insertProduct(p('p1', stock: 50));
    await ProductService.insertProduct(p('p2', unlimited: true));
    await ProductService.insertProduct(p('p3', stock: 5));
    await ProductService.insertProduct(p('p4', stock: 0));
    await ProductService.insertProduct(p('s1', type: 'service', tax: 18, hsn: '9987'));
    await ProductService.insertProduct(p('s2', type: 'service', tax: 0, hsn: ''));
    await ProductService.insertProduct(p('s3', type: 'service', tax: 5, hsn: '  ', unlimited: true));
  });

  Future<List<String>> ids(String tab, {String? type, String query = ''}) async =>
      (await ProductService.getProductListPage(
              offset: 0, limit: 50, tab: tab, type: type, query: query))
          .map((e) => e.id)
          .toList()
        ..sort();

  test('type limits the list to products or services; null and both mean all', () async {
    expect(await ids('all', type: 'product'), ['p1', 'p2', 'p3', 'p4']);
    expect(await ids('all', type: 'service'), ['s1', 's2', 's3']);
    expect((await ids('all')).length, 7);
    expect((await ids('all', type: 'both')).length, 7);
    expect(await ProductService.getProductListCount(type: 'service'), 3);
  });

  test('products: in_stock + low + out = all, and services never leak in', () async {
    expect(await ids('in_stock', type: 'product'), ['p1', 'p2']);
    expect(await ids('low', type: 'product'), ['p3']);
    expect(await ids('out', type: 'product'), ['p4'], reason: 'not the tracked service s2');
    final c = await ProductService.getProductListTabCounts(
        ['all', 'in_stock', 'low', 'out', 'expired'], type: 'product');
    expect(c, {'all': 4, 'in_stock': 2, 'low': 1, 'out': 1, 'expired': 0});
    expect(c['in_stock']! + c['low']! + c['out']!, c['all']);
  });

  // Stock is a decimal: low = 0 < stock <= 10, out = stock <= 0.
  test('decimal stock: 0.5 and 10 are low, 10.5 is in stock, -0.25 is out', () async {
    await ProductService.insertProduct(p('d1', stock: 0.5));
    await ProductService.insertProduct(p('d2', stock: 10.5));
    await ProductService.insertProduct(p('d3', stock: -0.25));
    await ProductService.insertProduct(p('d4', stock: 10));
    expect((await ProductService.getProductById('d1'))!.stock, 0.5);
    expect(await ids('low', type: 'product'), ['d1', 'd4', 'p3']);
    expect(await ids('out', type: 'product'), ['d3', 'p4']);
    expect(await ids('in_stock', type: 'product'), ['d2', 'p1', 'p2']);
    final c = await ProductService.getProductListTabCounts(
        ['all', 'in_stock', 'low', 'out'], type: 'product');
    expect(c, {'all': 8, 'in_stock': 3, 'low': 3, 'out': 2});
    // Sort by stock (ties by id): -0.25, 0 (p2 unlimited, p4), 0.5, 5, 10, 10.5, 50.
    final byStock = (await ProductService.getProductListPage(
            offset: 0, limit: 50, orderBy: 'stock', type: 'product'))
        .map((e) => e.id)
        .toList();
    expect(byStock, ['d3', 'p2', 'p4', 'd1', 'p3', 'd4', 'd2', 'p1']);
  });

  test('stock reads and shows as people write it', () {
    expect(Product.stockFrom(5), 5.0, reason: 'an old INTEGER row');
    expect(Product.stockFrom(12.5), 12.5);
    expect(Product.stockFrom('12.5'), 12.5);
    expect(Product.stockFrom(null), 0);
    expect(Product.stockFrom('abc'), 0);
    expect(Product.roundStock(50 - 0.4 - 0.2), 49.4);
    expect(AppFormatters.formatStock(50.0), '50');
    expect(AppFormatters.formatStock(49.6), '49.6');
    expect(AppFormatters.formatStock(0.25), '0.25');
    expect(AppFormatters.formatStock(50 - 0.4 - 0.2), '49.4');
    expect(AppFormatters.formatStock(-0.5), '-0.5');
    expect(AppFormatters.formatStock(0), '0');
  });

  test('services: with tax, tax-free and without SAC', () async {
    expect(await ids('taxed', type: 'service'), ['s1', 's3']);
    expect(await ids('tax_free', type: 'service'), ['s2']);
    expect(await ids('no_hsn', type: 'service'), ['s2', 's3'], reason: 'blank or spaces');
    final c = await ProductService.getProductListTabCounts(
        ['all', 'taxed', 'tax_free', 'no_hsn'], type: 'service');
    expect(c, {'all': 3, 'taxed': 2, 'tax_free': 1, 'no_hsn': 2});
  });

  test('tab counts follow the search too', () async {
    final c = await ProductService.getProductListTabCounts(['all', 'low'],
        type: 'product', query: 'Item p3');
    expect(c, {'all': 1, 'low': 1});
  });

  test('search finds a SKU code', () async {
    await ProductService.upsertProductMetadata(
        ProductMetadata(productId: 'p3', skuCode: 'TRS-250'));
    expect(await ids('all', type: 'product', query: 'trs-25'), ['p3']);
    expect(await ids('all', type: 'service', query: 'trs-25'), isEmpty);
  });

  test('deleteProductsByType removes one kind and its details only', () async {
    await ProductService.upsertProductMetadata(ProductMetadata(productId: 's1', notes: 'x'));
    await ProductService.upsertProductMetadata(ProductMetadata(productId: 'p1', notes: 'y'));
    await ProductService.deleteProductsByType('service');
    expect(await ids('all'), ['p1', 'p2', 'p3', 'p4']);
    expect(await ProductService.getProductMetadata('s1'), isNull);
    expect((await ProductService.getProductMetadata('p1'))?.notes, 'y');
  });
}
