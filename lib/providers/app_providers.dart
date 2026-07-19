import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/supplier.dart';
import '../models/stock_purchase.dart';
import '../models/transaction.dart';

class SupplierProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  List<Supplier> suppliers = [];

  Future<void> loadAll() async {
    suppliers = await _db.getSuppliers();
    notifyListeners();
  }

  Future<void> add(Supplier s) async {
    await _db.insertSupplier(s);
    await loadAll();
  }

  Future<void> update(Supplier s) async {
    await _db.updateSupplier(s);
    await loadAll();
  }

  Future<void> delete(int id) async {
    await _db.deleteSupplier(id);
    await loadAll();
  }
}

class PurchaseProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  List<Purchase> purchases = [];

  Future<void> loadAll({int? supplierId}) async {
    purchases = await _db.getPurchases(supplierId: supplierId);
    notifyListeners();
  }

  Future<void> save(Purchase p) async {
    await _db.savePurchase(p);
    await loadAll();
  }
}

class TransactionProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  List<SaleTransaction> transactions = [];

  Future<void> loadAll({DateTime? from, DateTime? to, String? productQuery}) async {
    transactions = await _db.getTransactions(from: from, to: to, productQuery: productQuery);
    notifyListeners();
  }

  Future<void> deleteTransaction(int id, {bool restoreStock = true}) async {
    await _db.deleteSaleTransaction(id, restoreStock: restoreStock);
    await loadAll();
  }

  Future<void> returnItem(TransactionItem item, double qty) async {
    await _db.returnTransactionItem(item: item, returnQty: qty);
    await loadAll();
  }
}

/// Pengaturan aplikasi: nama toko, logo, tema, PIN, backup.
class SettingsProvider extends ChangeNotifier {
  String storeName = 'Toko Saya';
  String? logoPath;
  bool isDarkMode = false;
  String? pin; // null = PIN tidak aktif
  bool autoBackupEnabled = false;
  DateTime? lastBackupDate;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    storeName = prefs.getString('store_name') ?? 'Toko Saya';
    logoPath = prefs.getString('logo_path');
    isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    pin = prefs.getString('pin');
    autoBackupEnabled = prefs.getBool('auto_backup') ?? false;
    final lastBackup = prefs.getString('last_backup');
    lastBackupDate = lastBackup != null ? DateTime.tryParse(lastBackup) : null;
    notifyListeners();
  }

  Future<void> saveStoreProfile({String? name, String? logo}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      storeName = name;
      await prefs.setString('store_name', name);
    }
    if (logo != null) {
      logoPath = logo;
      await prefs.setString('logo_path', logo);
    }
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    notifyListeners();
  }

  Future<void> setPin(String? newPin) async {
    pin = newPin;
    final prefs = await SharedPreferences.getInstance();
    if (newPin == null) {
      await prefs.remove('pin');
    } else {
      await prefs.setString('pin', newPin);
    }
    notifyListeners();
  }

  bool get isPinEnabled => pin != null && pin!.isNotEmpty;

  Future<void> setAutoBackup(bool value) async {
    autoBackupEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup', value);
    notifyListeners();
  }

  Future<void> markBackupDone() async {
    lastBackupDate = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_backup', lastBackupDate!.toIso8601String());
    notifyListeners();
  }
}
