class Product {
  final int? id;
  final String name;
  final String? barcode;
  final int? categoryId;
  final String? categoryName; // hasil join, tidak disimpan
  final String unit; // pcs, dus, kg, pack, dll
  final double buyPrice;
  final double sellPrice;
  final double stock;
  final double minStock;
  final String? shelfLocation;
  final DateTime? expiryDate;
  final String? notes;
  final String? photoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    this.barcode,
    this.categoryId,
    this.categoryName,
    required this.unit,
    required this.buyPrice,
    required this.sellPrice,
    required this.stock,
    required this.minStock,
    this.shelfLocation,
    this.expiryDate,
    this.notes,
    this.photoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isLowStock => stock <= minStock;
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());
  bool get isExpiringSoon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.difference(DateTime.now()).inDays <= 30;

  double get stockValue => stock * buyPrice;
  double get marginPerUnit => sellPrice - buyPrice;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'category_id': categoryId,
      'unit': unit,
      'buy_price': buyPrice,
      'sell_price': sellPrice,
      'stock': stock,
      'min_stock': minStock,
      'shelf_location': shelfLocation,
      'expiry_date': expiryDate?.toIso8601String(),
      'notes': notes,
      'photo_path': photoPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      barcode: map['barcode'] as String?,
      categoryId: map['category_id'] as int?,
      categoryName: map['category_name'] as String?,
      unit: map['unit'] as String,
      buyPrice: (map['buy_price'] as num).toDouble(),
      sellPrice: (map['sell_price'] as num).toDouble(),
      stock: (map['stock'] as num).toDouble(),
      minStock: (map['min_stock'] as num).toDouble(),
      shelfLocation: map['shelf_location'] as String?,
      expiryDate: map['expiry_date'] != null
          ? DateTime.parse(map['expiry_date'] as String)
          : null,
      notes: map['notes'] as String?,
      photoPath: map['photo_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    int? categoryId,
    String? categoryName,
    String? unit,
    double? buyPrice,
    double? sellPrice,
    double? stock,
    double? minStock,
    String? shelfLocation,
    DateTime? expiryDate,
    String? notes,
    String? photoPath,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      unit: unit ?? this.unit,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      shelfLocation: shelfLocation ?? this.shelfLocation,
      expiryDate: expiryDate ?? this.expiryDate,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class Category {
  final int? id;
  final String name;
  Category({this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
  factory Category.fromMap(Map<String, dynamic> map) =>
      Category(id: map['id'] as int?, name: map['name'] as String);
}
