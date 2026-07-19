class TransactionItem {
  final int? id;
  final int? transactionId;
  final int productId;
  final String productName;
  final double qty;
  final double price; // harga jual saat transaksi
  final double costPrice; // harga beli saat transaksi (untuk hitung profit)
  final double discount; // diskon per item (nominal)

  TransactionItem({
    this.id,
    this.transactionId,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.price,
    required this.costPrice,
    this.discount = 0,
  });

  double get subtotal => (qty * price) - discount;
  double get profit => subtotal - (qty * costPrice);

  Map<String, dynamic> toMap() => {
        'id': id,
        'transaction_id': transactionId,
        'product_id': productId,
        'product_name': productName,
        'qty': qty,
        'price': price,
        'cost_price': costPrice,
        'discount': discount,
      };

  factory TransactionItem.fromMap(Map<String, dynamic> map) => TransactionItem(
        id: map['id'] as int?,
        transactionId: map['transaction_id'] as int?,
        productId: map['product_id'] as int,
        productName: map['product_name'] as String,
        qty: (map['qty'] as num).toDouble(),
        price: (map['price'] as num).toDouble(),
        costPrice: (map['cost_price'] as num).toDouble(),
        discount: (map['discount'] as num?)?.toDouble() ?? 0,
      );
}

class SaleTransaction {
  final int? id;
  final String trxNo;
  final DateTime date;
  final double discount; // diskon total nominal
  final String paymentMethod;
  final bool isReturned;
  final List<TransactionItem> items;

  SaleTransaction({
    this.id,
    required this.trxNo,
    DateTime? date,
    this.discount = 0,
    this.paymentMethod = 'Tunai',
    this.isReturned = false,
    this.items = const [],
  }) : date = date ?? DateTime.now();

  double get subtotalItems => items.fold(0.0, (sum, i) => sum + (i.qty * i.price));
  double get total => subtotalItems - discount;
  double get profit =>
      items.fold(0.0, (sum, i) => sum + i.profit) - discount;
  double get totalQty => items.fold(0.0, (sum, i) => sum + i.qty);

  Map<String, dynamic> toMap() => {
        'id': id,
        'trx_no': trxNo,
        'date': date.toIso8601String(),
        'discount': discount,
        'payment_method': paymentMethod,
        'is_returned': isReturned ? 1 : 0,
      };

  factory SaleTransaction.fromMap(Map<String, dynamic> map,
      {List<TransactionItem> items = const []}) {
    return SaleTransaction(
      id: map['id'] as int?,
      trxNo: map['trx_no'] as String,
      date: DateTime.parse(map['date'] as String),
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['payment_method'] as String? ?? 'Tunai',
      isReturned: (map['is_returned'] as int? ?? 0) == 1,
      items: items,
    );
  }
}
