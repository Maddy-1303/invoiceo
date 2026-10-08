import 'package:invoiceo/models/product.dart';
import 'package:invoiceo/models/product_list_stats.dart';

abstract class ProductRepository {
  Future<void> insertProduct(Product product);
  Future<List<Product>> getAllProducts();
  Future<int> getTotalProductCount();
  Future<Product?> getProductById(String id);
  Future<void> updateProduct(Product product);
  Future<List<Product>> searchProducts(String query, {String? type});
  Future<List<Product>> getProductsPaginated({
    required int offset,
    required int limit,
    String query = '',
    String orderBy = 'name',
    bool orderASC = true,
    String? type,
  });
  Future<int> getProductCount([String query = '', String? type]);
  /// Product management list (Issues.md #42). [tab]: 'all' | 'product' |
  /// 'service' | 'low' | 'out' | 'expired' | 'in_stock' | 'taxed' |
  /// 'tax_free' | 'no_hsn'. [type] 'product' | 'service' limits it to that
  /// kind (null: both). Search: name, alias, HSN / SAC, SKU.
  Future<List<Product>> getProductListPage({
    required int offset,
    required int limit,
    String query = '',
    String tab = 'all',
    String orderBy = 'name',
    bool ascending = true,
    String? type,
  });
  Future<int> getProductListCount({String query = '', String tab = 'all', String? type});
  /// The count of each of [tabs] (same keys as [getProductListPage]).
  Future<Map<String, int>> getProductListTabCounts(List<String> tabs,
      {String query = '', String? type});
  /// Deletes every product or every service, with their details.
  Future<void> deleteProductsByType(String type);
  Future<ProductListStats> getProductListStats();
  Future<void> deleteProduct(String id);
  Future<void> updateProductStock(String id, int newStock);
  Future<bool> hasSufficientStock(String productId, int quantity);
  Future<Product?> findDuplicateByName(String name);
  Future<void> deleteAllProducts();
  Future<void> insertBatch(List<Product> products, {int batchSize = 50});
  Future<List<Product>> getOutOfStockProducts();
  Future<ProductMetadata?> getProductMetadata(String productId);
  Future<Map<String, ProductMetadata>> getAllProductMetadata();
  Future<Map<String, ProductMetadata>> getProductMetadataForIds(List<String> productIds);
  Future<void> upsertProductMetadata(ProductMetadata metadata);
}
