import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/product.dart';
import '../models/supplier.dart';
import '../models/transaction.dart';
import '../models/stock_purchase.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<String> get dbPath async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'kasir_app.db');
  }

  Future<Database> _initDb() async {
    final path = await dbPath;
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT,
        category_id INTEGER,
        unit TEXT NOT NULL DEFAULT 'pcs',
        buy_price REAL NOT NULL DEFAULT 0,
        sell_price REAL NOT NULL DEFAULT 0,
        stock REAL NOT NULL DEFAULT 0,
        min_stock REAL NOT NULL DEFAULT 0,
        shelf_location TEXT,
        expiry_date TEXT,
        notes TEXT,
        photo_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trx_no TEXT NOT NULL UNIQUE,
        date TEXT NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        payment_method TEXT NOT NULL DEFAULT 'Tunai',
        is_returned INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        qty REAL NOT NULL,
        price REAL NOT NULL,
        cost_price REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        type TEXT NOT NULL,
        qty REAL NOT NULL,
        stock_before REAL NOT NULL,
        stock_after REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        reference TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_id INTEGER,
        invoice_no TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        qty REAL NOT NULL,
        buy_price REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db.execute('CREATE INDEX idx_trx_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_stockmove_product ON stock_movements(product_id)');
  }

  // ---------------- CATEGORY ----------------
  Future<int> insertCategory(Category c) async {
    final db = await database;
    return db.insert('categories', c.toMap()..remove('id'));
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'name');
    return rows.map((e) => Category.fromMap(e)).toList();
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- PRODUCT ----------------
  Future<int> insertProduct(Product p) async {
    final db = await database;
    final map = p.toMap()..remove('id');
    return db.insert('products', map);
  }

  Future<int> updateProduct(Product p) async {
    final db = await database;
    return db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE p.id = ?
    ''', [id]);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      WHERE p.barcode = ? LIMIT 1
    ''', [barcode]);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    bool onlyLowStock = false,
    bool onlyExpiring = false,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];

    if (query != null && query.isNotEmpty) {
      where.add('(p.name LIKE ? OR p.barcode LIKE ?)');
      args.add('%$query%');
      args.add('%$query%');
    }
    if (categoryId != null) {
      where.add('p.category_id = ?');
      args.add(categoryId);
    }
    if (onlyLowStock) {
      where.add('p.stock <= p.min_stock');
    }
    if (onlyExpiring) {
      where.add("p.expiry_date IS NOT NULL AND p.expiry_date <= ?");
      args.add(DateTime.now().add(const Duration(days: 30)).toIso8601String());
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT p.*, c.name as category_name FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      $whereClause
      ORDER BY p.name
    ''', args);
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  Future<double> getTotalStockValue() async {
    final db = await database;
    final res = await db.rawQuery('SELECT SUM(stock * buy_price) as total FROM products');
    return (res.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<int> getTotalStockUnits() async {
    final db = await database;
    final res = await db.rawQuery('SELECT SUM(stock) as total FROM products');
    return ((res.first['total'] as num?) ?? 0).toInt();
  }

  // ---------------- STOCK MOVEMENT ----------------
  Future<void> adjustStock({
    required Product product,
    required double deltaQty, // positif=tambah, negatif=kurang
    required StockMovementType type,
    String? note,
    String? reference,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final before = product.stock;
      final after = before + deltaQty;
      await txn.update(
        'products',
        {'stock': after, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [product.id],
      );
      await txn.insert('stock_movements', {
        'product_id': product.id,
        'product_name': product.name,
        'type': type.name,
        'qty': deltaQty,
        'stock_before': before,
        'stock_after': after,
        'date': DateTime.now().toIso8601String(),
        'note': note,
        'reference': reference,
      });
    });
  }

  Future<List<StockMovement>> getStockMovements({int? productId, int limit = 200}) async {
    final db = await database;
    final where = productId != null ? 'WHERE product_id = ?' : '';
    final args = productId != null ? [productId] : [];
    final rows = await db.rawQuery('''
      SELECT * FROM stock_movements $where ORDER BY date DESC LIMIT ?
    ''', [...args, limit]);
    return rows.map((e) => StockMovement.fromMap(e)).toList();
  }

  // ---------------- SUPPLIER ----------------
  Future<int> insertSupplier(Supplier s) async {
    final db = await database;
    return db.insert('suppliers', s.toMap()..remove('id'));
  }

  Future<int> updateSupplier(Supplier s) async {
    final db = await database;
    return db.update('suppliers', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  }

  Future<int> deleteSupplier(int id) async {
    final db = await database;
    return db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Supplier>> getSuppliers({String? query}) async {
    final db = await database;
    final rows = await db.query(
      'suppliers',
      where: query != null && query.isNotEmpty ? 'name LIKE ?' : null,
      whereArgs: query != null && query.isNotEmpty ? ['%$query%'] : null,
      orderBy: 'name',
    );
    return rows.map((e) => Supplier.fromMap(e)).toList();
  }

  // ---------------- TRANSACTIONS (PENJUALAN) ----------------
  Future<String> generateTrxNo() async {
    final now = DateTime.now();
    final prefix = 'TRX${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final db = await database;
    final res = await db.rawQuery(
        "SELECT COUNT(*) as c FROM transactions WHERE trx_no LIKE ?", ['$prefix%']);
    final count = (res.first['c'] as int) + 1;
    return '$prefix-${count.toString().padLeft(4, '0')}';
  }

  /// Menyimpan transaksi penjualan + item, dan otomatis mengurangi stok.
  Future<int> saveSaleTransaction(SaleTransaction trx) async {
    final db = await database;
    late int trxId;
    await db.transaction((txn) async {
      trxId = await txn.insert('transactions', trx.toMap()..remove('id'));
      for (final item in trx.items) {
        await txn.insert('transaction_items', {
          ...item.toMap()..remove('id'),
          'transaction_id': trxId,
        });
        // kurangi stok
        final prodRows = await txn.query('products', where: 'id = ?', whereArgs: [item.productId]);
        if (prodRows.isNotEmpty) {
          final before = (prodRows.first['stock'] as num).toDouble();
          final after = before - item.qty;
          await txn.update('products', {'stock': after, 'updated_at': DateTime.now().toIso8601String()},
              where: 'id = ?', whereArgs: [item.productId]);
          await txn.insert('stock_movements', {
            'product_id': item.productId,
            'product_name': item.productName,
            'type': StockMovementType.penjualan.name,
            'qty': -item.qty,
            'stock_before': before,
            'stock_after': after,
            'date': DateTime.now().toIso8601String(),
            'note': 'Penjualan',
            'reference': trx.trxNo,
          });
        }
      }
    });
    return trxId;
  }

  Future<int> deleteSaleTransaction(int id, {bool restoreStock = false}) async {
    final db = await database;
    if (restoreStock) {
      final items = await getTransactionItems(id);
      for (final item in items) {
        final prod = await getProductById(item.productId);
        if (prod != null) {
          await adjustStock(
            product: prod,
            deltaQty: item.qty,
            type: StockMovementType.retur,
            note: 'Transaksi dihapus, stok dikembalikan',
            reference: 'DEL-$id',
          );
        }
      }
    }
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Retur penjualan: mengembalikan sebagian/seluruh qty item ke stok.
  Future<void> returnTransactionItem({
    required TransactionItem item,
    required double returnQty,
  }) async {
    final prod = await getProductById(item.productId);
    if (prod == null) return;
    await adjustStock(
      product: prod,
      deltaQty: returnQty,
      type: StockMovementType.retur,
      note: 'Retur penjualan',
      reference: 'RETUR-${item.transactionId}',
    );
    final db = await database;
    await db.update('transactions', {'is_returned': 1}, where: 'id = ?', whereArgs: [item.transactionId]);
  }

  Future<List<TransactionItem>> getTransactionItems(int trxId) async {
    final db = await database;
    final rows = await db.query('transaction_items', where: 'transaction_id = ?', whereArgs: [trxId]);
    return rows.map((e) => TransactionItem.fromMap(e)).toList();
  }

  Future<List<SaleTransaction>> getTransactions({
    DateTime? from,
    DateTime? to,
    String? productQuery,
    int limit = 500,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (from != null) {
      where.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(to.toIso8601String());
    }
    if (productQuery != null && productQuery.isNotEmpty) {
      where.add('id IN (SELECT transaction_id FROM transaction_items WHERE product_name LIKE ?)');
      args.add('%$productQuery%');
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery(
        'SELECT * FROM transactions $whereClause ORDER BY date DESC LIMIT ?', [...args, limit]);

    final result = <SaleTransaction>[];
    for (final r in rows) {
      final items = await getTransactionItems(r['id'] as int);
      result.add(SaleTransaction.fromMap(r, items: items));
    }
    return result;
  }

  // Ringkasan untuk dashboard & laporan
  Future<Map<String, double>> getSummary({required DateTime from, required DateTime to}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT ti.qty, ti.price, ti.cost_price, ti.discount, t.discount as trx_discount
      FROM transaction_items ti
      JOIN transactions t ON t.id = ti.transaction_id
      WHERE t.date >= ? AND t.date <= ?
    ''', [from.toIso8601String(), to.toIso8601String()]);

    double omzet = 0, profit = 0, qtyTotal = 0;
    for (final r in rows) {
      final qty = (r['qty'] as num).toDouble();
      final price = (r['price'] as num).toDouble();
      final cost = (r['cost_price'] as num).toDouble();
      final disc = (r['discount'] as num?)?.toDouble() ?? 0;
      omzet += (qty * price) - disc;
      profit += (qty * (price - cost)) - disc;
      qtyTotal += qty;
    }
    final trxCountRes = await db.rawQuery(
        'SELECT COUNT(*) as c FROM transactions WHERE date >= ? AND date <= ?',
        [from.toIso8601String(), to.toIso8601String()]);
    final trxCount = (trxCountRes.first['c'] as int).toDouble();

    return {
      'omzet': omzet,
      'profit': profit,
      'qty': qtyTotal,
      'trxCount': trxCount,
    };
  }

  Future<List<Map<String, dynamic>>> getBestSellingProducts({int limit = 10, DateTime? from, DateTime? to}) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (from != null) {
      where.add('t.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('t.date <= ?');
      args.add(to.toIso8601String());
    }
    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT ti.product_name, SUM(ti.qty) as total_qty,
        SUM((ti.qty * (ti.price - ti.cost_price)) - ti.discount) as total_profit
      FROM transaction_items ti
      JOIN transactions t ON t.id = ti.transaction_id
      $whereClause
      GROUP BY ti.product_id
      ORDER BY total_qty DESC
      LIMIT ?
    ''', [...args, limit]);
    return rows;
  }

  Future<List<Map<String, dynamic>>> getLeastSellingProducts({int limit = 10}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.name as product_name, COALESCE(SUM(ti.qty), 0) as total_qty
      FROM products p
      LEFT JOIN transaction_items ti ON ti.product_id = p.id
      GROUP BY p.id
      ORDER BY total_qty ASC
      LIMIT ?
    ''', [limit]);
    return rows;
  }

  Future<List<Map<String, dynamic>>> getOmzetPerCategory() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT c.name as category_name, SUM(ti.qty * ti.price) as omzet
      FROM transaction_items ti
      JOIN products p ON p.id = ti.product_id
      LEFT JOIN categories c ON c.id = p.category_id
      GROUP BY c.id
      ORDER BY omzet DESC
    ''');
    return rows;
  }

  // ---------------- PURCHASES (PEMBELIAN) ----------------
  Future<int> savePurchase(Purchase purchase) async {
    final db = await database;
    late int purchaseId;
    await db.transaction((txn) async {
      purchaseId = await txn.insert('purchases', purchase.toMap()..remove('id'));
      for (final item in purchase.items) {
        await txn.insert('purchase_items', {
          ...item.toMap()..remove('id'),
          'purchase_id': purchaseId,
        });
        final prodRows = await txn.query('products', where: 'id = ?', whereArgs: [item.productId]);
        if (prodRows.isNotEmpty) {
          final before = (prodRows.first['stock'] as num).toDouble();
          final after = before + item.qty;
          await txn.update(
            'products',
            {
              'stock': after,
              'buy_price': item.buyPrice, // update harga beli terbaru
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [item.productId],
          );
          await txn.insert('stock_movements', {
            'product_id': item.productId,
            'product_name': item.productName,
            'type': StockMovementType.masuk.name,
            'qty': item.qty,
            'stock_before': before,
            'stock_after': after,
            'date': DateTime.now().toIso8601String(),
            'note': 'Pembelian ${purchase.invoiceNo ?? ''}',
            'reference': purchase.invoiceNo,
          });
        }
      }
    });
    return purchaseId;
  }

  Future<List<Purchase>> getPurchases({int? supplierId}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT p.*, s.name as supplier_name FROM purchases p
      LEFT JOIN suppliers s ON s.id = p.supplier_id
      ${supplierId != null ? 'WHERE p.supplier_id = ?' : ''}
      ORDER BY p.date DESC
    ''', supplierId != null ? [supplierId] : []);

    final result = <Purchase>[];
    for (final r in rows) {
      final items = await db.query('purchase_items', where: 'purchase_id = ?', whereArgs: [r['id']]);
      result.add(Purchase.fromMap(r,
          items: items.map((e) => PurchaseItem.fromMap(e)).toList(),
          supplierName: r['supplier_name'] as String?));
    }
    return result;
  }

  Future<void> closeDb() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  /// Untuk fitur backup: salin file database ke lokasi tujuan.
  Future<File> getDbFile() async {
    final path = await dbPath;
    return File(path);
  }

  /// Untuk fitur restore: ganti file database dengan file backup.
  Future<void> restoreFromFile(File backupFile) async {
    await closeDb();
    final path = await dbPath;
    await backupFile.copy(path);
    _db = await _initDb();
  }
}
