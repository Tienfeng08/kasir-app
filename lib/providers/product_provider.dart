import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/product.dart';
import '../models/stock_purchase.dart';

class ProductProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Product> _products = [];
  List<ProductCategory> _categories = [];
  bool isLoading = false;

  List<Product> get products => _products;
  List<ProductCategory> get categories => _categories;

  List<Product> get lowStockProducts => _products.where((p) => p.isLowStock).toList();
  List<Product> get expiringProducts =>
      _products.where((p) => p.isExpired || p.isExpiringSoon).toList();

  Future<void> loadAll() async {
    isLoading = true;
    notifyListeners();
    _products = await _db.getProducts();
    _categories = await _db.getCategories();
    isLoading = false;
    notifyListeners();
  }

  Future<List<Product>> search({String? query, int? categoryId}) {
    return _db.getProducts(query: query, categoryId: categoryId);
  }

  Future<Product?> findByBarcode(String barcode) => _db.getProductByBarcode(barcode);

  Future<void> addProduct(Product p) async {
    await _db.insertProduct(p);
    await loadAll();
  }

  Future<void> updateProduct(Product p) async {
    await _db.updateProduct(p);
    await loadAll();
  }

  Future<void> deleteProduct(int id) async {
    await _db.deleteProduct(id);
    await loadAll();
  }

  Future<void> addCategory(String name) async {
    await _db.insertCategory(ProductCategory(name: name));
    await loadAll();
  }

  Future<void> adjustStock({
    required Product product,
    required double deltaQty,
    required StockMovementType type,
    String? note,
    String? reference,
  }) async {
    await _db.adjustStock(product: product, deltaQty: deltaQty, type: type, note: note, reference: reference);
    await loadAll();
  }
}
