import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db/database_helper.dart';
import '../models/product.dart';

class BackupHelper {
  /// Backup manual: menyalin file database ke folder yang dipilih user
  /// (bisa folder Google Drive lokal jika sudah disinkronkan sebagai folder,
  /// atau dibagikan lewat share sheet yang mencakup opsi "Simpan ke Drive").
  static Future<String?> backupManual() async {
    final dbFile = await DatabaseHelper.instance.getDbFile();
    if (!await dbFile.exists()) return null;

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan Backup Database',
      fileName: 'kasir_backup_${DateTime.now().millisecondsSinceEpoch}.db',
      bytes: await dbFile.readAsBytes(),
    );
    return result;
  }

  /// Alternatif: share file backup (user bisa memilih "Simpan ke Google Drive"
  /// dari share sheet bawaan sistem).
  static Future<void> shareBackup() async {
    final dbFile = await DatabaseHelper.instance.getDbFile();
    if (!await dbFile.exists()) return;
    final dir = await getApplicationDocumentsDirectory();
    final copy = await dbFile.copy('${dir.path}/kasir_backup_${DateTime.now().millisecondsSinceEpoch}.db');
    await Share.shareXFiles([XFile(copy.path)], text: 'Backup database Kasir App');
  }

  /// Restore: pilih file .db hasil backup lalu timpa database aktif.
  static Future<bool> restoreFromPicker() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return false;
    final file = File(result.files.single.path!);
    await DatabaseHelper.instance.restoreFromFile(file);
    return true;
  }

  /// Export seluruh data barang ke file Excel.
  static Future<void> exportProductsToExcel(List<Product> products) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel['Barang'];
    sheet.appendRow([
      xls.TextCellValue('Nama'),
      xls.TextCellValue('Barcode'),
      xls.TextCellValue('Kategori'),
      xls.TextCellValue('Satuan'),
      xls.TextCellValue('Harga Beli'),
      xls.TextCellValue('Harga Jual'),
      xls.TextCellValue('Stok'),
      xls.TextCellValue('Minimal Stok'),
      xls.TextCellValue('Lokasi Rak'),
      xls.TextCellValue('Tanggal Kedaluwarsa'),
    ]);
    for (final p in products) {
      sheet.appendRow([
        xls.TextCellValue(p.name),
        xls.TextCellValue(p.barcode ?? ''),
        xls.TextCellValue(p.categoryName ?? ''),
        xls.TextCellValue(p.unit),
        xls.DoubleCellValue(p.buyPrice),
        xls.DoubleCellValue(p.sellPrice),
        xls.DoubleCellValue(p.stock),
        xls.DoubleCellValue(p.minStock),
        xls.TextCellValue(p.shelfLocation ?? ''),
        xls.TextCellValue(p.expiryDate?.toIso8601String() ?? ''),
      ]);
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/data_barang_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Export Data Barang');
    }
  }

  /// Import data barang dari file Excel (format kolom sama seperti hasil export).
  /// Mengembalikan jumlah barang yang berhasil diimpor.
  static Future<int> importProductsFromExcel({
    required Future<void> Function(Product) onEachProduct,
    required Map<String, int?> categoryNameToId,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null || result.files.single.path == null) return 0;

    final bytes = await File(result.files.single.path!).readAsBytes();
    final excel = xls.Excel.decodeBytes(bytes);
    int count = 0;

    for (final table in excel.tables.keys) {
      final rows = excel.tables[table]!.rows;
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row[0]?.value == null) continue;
        try {
          final name = row[0]!.value.toString();
          final barcode = row.length > 1 ? row[1]?.value?.toString() : null;
          final categoryName = row.length > 2 ? row[2]?.value?.toString() : null;
          final unit = row.length > 3 ? (row[3]?.value?.toString() ?? 'pcs') : 'pcs';
          final buyPrice = row.length > 4 ? double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0 : 0.0;
          final sellPrice = row.length > 5 ? double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0 : 0.0;
          final stock = row.length > 6 ? double.tryParse(row[6]?.value?.toString() ?? '0') ?? 0 : 0.0;
          final minStock = row.length > 7 ? double.tryParse(row[7]?.value?.toString() ?? '0') ?? 0 : 0.0;
          final shelfLocation = row.length > 8 ? row[8]?.value?.toString() : null;
          final expiryStr = row.length > 9 ? row[9]?.value?.toString() : null;

          final product = Product(
            name: name,
            barcode: (barcode == null || barcode.isEmpty) ? null : barcode,
            categoryId: categoryName != null ? categoryNameToId[categoryName] : null,
            unit: unit,
            buyPrice: buyPrice,
            sellPrice: sellPrice,
            stock: stock,
            minStock: minStock,
            shelfLocation: (shelfLocation == null || shelfLocation.isEmpty) ? null : shelfLocation,
            expiryDate: (expiryStr != null && expiryStr.isNotEmpty) ? DateTime.tryParse(expiryStr) : null,
          );
          await onEachProduct(product);
          count++;
        } catch (_) {
          // lewati baris yang gagal diparse
        }
      }
    }
    return count;
  }
}
