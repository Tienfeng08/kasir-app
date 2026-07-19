enum StockMovementType { masuk, keluar, opname, penjualan, retur }

extension StockMovementTypeX on StockMovementType {
  String get label {
    switch (this) {
      case StockMovementType.masuk:
        return 'Stok Masuk';
      case StockMovementType.keluar:
        return 'Stok Keluar';
      case StockMovementType.opname:
        return 'Penyesuaian (Opname)';
      case StockMovementType.penjualan:
        return 'Penjualan';
      case StockMovementType.retur:
        return 'Retur';
    }
  }

  static StockMovementType fromString(String s) =>
      StockMovementType.values.firstWhere((e) => e.name == s,
          orElse: () => StockMovementType.opname);
}

class StockMovement {
  final int? id;
  final int productId;
  final String productName;
  final StockMovementType type;
  final double qty; // positif = tambah, negatif = kurang
  final double stockBefore;
  final double stockAfter;
  final DateTime date;
  final String? note;
  final String? reference; // no. transaksi / no. faktur

  StockMovement({
    this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.qty,
    required this.stockBefore,
    required this.stockAfter,
    DateTime? date,
    this.note,
    this.reference,
  }) : date = date ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'product_name': productName,
        'type': type.name,
        'qty': qty,
        'stock_before': stockBefore,
        'stock_after': stockAfter,
        'date': date.toIso8601String(),
        'note': note,
        'reference': reference,
      };

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        productName: map['product_name'] as String,
        type: StockMovementTypeX.fromString(map['type'] as String),
        qty: (map['qty'] as num).toDouble(),
        stockBefore: (map['stock_before'] as num).toDouble(),
        stockAfter: (map['stock_after'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        note: map['note'] as String?,
        reference: map['reference'] as String?,
      );
}

class PurchaseItem {
  final int? id;
  final int? purchaseId;
  final int productId;
  final String productName;
  final double qty;
  final double buyPrice;

  PurchaseItem({
    this.id,
    this.purchaseId,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.buyPrice,
  });

  double get subtotal => qty * buyPrice;

  Map<String, dynamic> toMap() => {
        'id': id,
        'purchase_id': purchaseId,
        'product_id': productId,
        'product_name': productName,
        'qty': qty,
        'buy_price': buyPrice,
      };

  factory PurchaseItem.fromMap(Map<String, dynamic> map) => PurchaseItem(
        id: map['id'] as int?,
        purchaseId: map['purchase_id'] as int?,
        productId: map['product_id'] as int,
        productName: map['product_name'] as String,
        qty: (map['qty'] as num).toDouble(),
        buyPrice: (map['buy_price'] as num).toDouble(),
      );
}

class Purchase {
  final int? id;
  final int? supplierId;
  final String? supplierName;
  final String? invoiceNo;
  final DateTime date;
  final List<PurchaseItem> items;

  Purchase({
    this.id,
    this.supplierId,
    this.supplierName,
    this.invoiceNo,
    DateTime? date,
    this.items = const [],
  }) : date = date ?? DateTime.now();

  double get total => items.fold(0.0, (sum, i) => sum + i.subtotal);

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplier_id': supplierId,
        'invoice_no': invoiceNo,
        'date': date.toIso8601String(),
      };

  factory Purchase.fromMap(Map<String, dynamic> map,
      {List<PurchaseItem> items = const [], String? supplierName}) {
    return Purchase(
      id: map['id'] as int?,
      supplierId: map['supplier_id'] as int?,
      supplierName: supplierName,
      invoiceNo: map['invoice_no'] as String?,
      date: DateTime.parse(map['date'] as String),
      items: items,
    );
  }
}
