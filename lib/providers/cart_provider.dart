import 'package:flutter/foundation.dart';
import '../db/database_helper.dart';
import '../models/product.dart';
import '../models/transaction.dart';

class CartLine {
  final Product product;
  double qty;
  double discount; // diskon nominal per baris
  CartLine({required this.product, this.qty = 1, this.discount = 0});

  double get subtotal => (qty * product.sellPrice) - discount;
}

class CartProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final Map<int, CartLine> _lines = {}; // key: productId

  List<CartLine> get lines => _lines.values.toList();
  bool get isEmpty => _lines.isEmpty;

  double totalDiscountHeader = 0; // diskon tambahan di level transaksi

  double get subtotal => _lines.values.fold(0.0, (s, l) => s + l.subtotal);
  double get total => subtotal - totalDiscountHeader;
  double get totalQty => _lines.values.fold(0.0, (s, l) => s + l.qty);

  void addProduct(Product product, {double qty = 1}) {
    if (_lines.containsKey(product.id)) {
      _lines[product.id]!.qty += qty;
    } else {
      _lines[product.id!] = CartLine(product: product, qty: qty);
    }
    notifyListeners();
  }

  void setQty(int productId, double qty) {
    if (qty <= 0) {
      _lines.remove(productId);
    } else if (_lines.containsKey(productId)) {
      _lines[productId]!.qty = qty;
    }
    notifyListeners();
  }

  void setLineDiscount(int productId, double discount) {
    if (_lines.containsKey(productId)) {
      _lines[productId]!.discount = discount;
      notifyListeners();
    }
  }

  void removeProduct(int productId) {
    _lines.remove(productId);
    notifyListeners();
  }

  void setHeaderDiscount(double value) {
    totalDiscountHeader = value;
    notifyListeners();
  }

  void clear() {
    _lines.clear();
    totalDiscountHeader = 0;
    notifyListeners();
  }

  /// Menyimpan transaksi ke database, mengurangi stok otomatis, dan
  /// mengembalikan nomor transaksi yang dihasilkan.
  Future<String> checkout({String paymentMethod = 'Tunai'}) async {
    if (_lines.isEmpty) {
      throw Exception('Keranjang kosong');
    }
    final trxNo = await _db.generateTrxNo();
    final items = _lines.values
        .map((l) => TransactionItem(
              productId: l.product.id!,
              productName: l.product.name,
              qty: l.qty,
              price: l.product.sellPrice,
              costPrice: l.product.buyPrice,
              discount: l.discount,
            ))
        .toList();

    final trx = SaleTransaction(
      trxNo: trxNo,
      discount: totalDiscountHeader,
      paymentMethod: paymentMethod,
      items: items,
    );
    await _db.saveSaleTransaction(trx);
    clear();
    return trxNo;
  }
}
