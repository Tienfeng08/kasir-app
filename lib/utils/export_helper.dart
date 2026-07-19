import 'dart:io';
import 'package:excel/excel.dart' as xls;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'formatters.dart';

class ExportHelper {
  static Future<void> exportReportToExcel({
    required String storeName,
    required String period,
    required Map<String, double> summary,
    required List<Map<String, dynamic>> bestSelling,
  }) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel['Laporan'];
    sheet.appendRow([xls.TextCellValue('Laporan Penjualan - $storeName')]);
    sheet.appendRow([xls.TextCellValue('Periode: $period')]);
    sheet.appendRow([]);
    sheet.appendRow([xls.TextCellValue('Omzet'), xls.TextCellValue(formatCurrency(summary['omzet'] ?? 0))]);
    sheet.appendRow([xls.TextCellValue('Keuntungan'), xls.TextCellValue(formatCurrency(summary['profit'] ?? 0))]);
    sheet.appendRow([xls.TextCellValue('Jumlah Transaksi'), xls.TextCellValue('${(summary['trxCount'] ?? 0).toInt()}')]);
    sheet.appendRow([xls.TextCellValue('Barang Terjual'), xls.TextCellValue(formatQty(summary['qty'] ?? 0))]);
    sheet.appendRow([]);
    sheet.appendRow([xls.TextCellValue('Barang Terlaris'), xls.TextCellValue('Qty Terjual'), xls.TextCellValue('Keuntungan')]);
    for (final row in bestSelling) {
      sheet.appendRow([
        xls.TextCellValue(row['product_name'] as String),
        xls.TextCellValue(formatQty((row['total_qty'] as num?)?.toDouble() ?? 0)),
        xls.TextCellValue(formatCurrency((row['total_profit'] as num?)?.toDouble() ?? 0)),
      ]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/laporan_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Penjualan $storeName');
    }
  }

  static Future<void> exportReportToPdf({
    required String storeName,
    required String period,
    required Map<String, double> summary,
    required List<Map<String, dynamic>> bestSelling,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Laporan Penjualan - $storeName', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Periode: $period'),
            pw.SizedBox(height: 12),
            pw.Text('Omzet: ${formatCurrency(summary['omzet'] ?? 0)}'),
            pw.Text('Keuntungan: ${formatCurrency(summary['profit'] ?? 0)}'),
            pw.Text('Jumlah Transaksi: ${(summary['trxCount'] ?? 0).toInt()}'),
            pw.Text('Barang Terjual: ${formatQty(summary['qty'] ?? 0)}'),
            pw.SizedBox(height: 16),
            pw.Text('Barang Terlaris', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Table.fromTextArray(
              headers: ['Nama Barang', 'Qty Terjual', 'Keuntungan'],
              data: bestSelling
                  .map((row) => [
                        row['product_name'] as String,
                        formatQty((row['total_qty'] as num?)?.toDouble() ?? 0),
                        formatCurrency((row['total_profit'] as num?)?.toDouble() ?? 0),
                      ])
                  .toList(),
            ),
          ],
        ),
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'laporan_penjualan.pdf');
  }
}
