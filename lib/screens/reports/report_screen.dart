import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../db/database_helper.dart';
import '../../providers/product_provider.dart';
import '../../providers/app_providers.dart';
import '../../utils/formatters.dart';
import '../../utils/export_helper.dart';

enum ReportPeriod { harian, mingguan, bulanan, tahunan }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _db = DatabaseHelper.instance;
  ReportPeriod _period = ReportPeriod.harian;
  Map<String, double> _summary = {};
  List<Map<String, dynamic>> _bestSelling = [];
  List<Map<String, dynamic>> _leastSelling = [];
  List<Map<String, dynamic>> _omzetPerCategory = [];
  double _stockValue = 0;
  bool _loading = true;

  DateTime get _from {
    final now = DateTime.now();
    switch (_period) {
      case ReportPeriod.harian:
        return DateTime(now.year, now.month, now.day);
      case ReportPeriod.mingguan:
        return now.subtract(Duration(days: now.weekday - 1));
      case ReportPeriod.bulanan:
        return DateTime(now.year, now.month, 1);
      case ReportPeriod.tahunan:
        return DateTime(now.year, 1, 1);
    }
  }

  DateTime get _to => DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _summary = await _db.getSummary(from: _from, to: _to);
    _bestSelling = await _db.getBestSellingProducts(limit: 10, from: _from, to: _to);
    _leastSelling = await _db.getLeastSellingProducts(limit: 10);
    _omzetPerCategory = await _db.getOmzetPerCategory();
    _stockValue = await _db.getTotalStockValue();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),
            onSelected: (v) async {
              final settings = context.read<SettingsProvider>();
              if (v == 'excel') {
                await ExportHelper.exportReportToExcel(
                  storeName: settings.storeName,
                  period: _period.name,
                  summary: _summary,
                  bestSelling: _bestSelling,
                );
              } else if (v == 'pdf') {
                await ExportHelper.exportReportToPdf(
                  storeName: settings.storeName,
                  period: _period.name,
                  summary: _summary,
                  bestSelling: _bestSelling,
                );
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'excel', child: Text('Export Excel')),
              const PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  SegmentedButton<ReportPeriod>(
                    segments: const [
                      ButtonSegment(value: ReportPeriod.harian, label: Text('Harian')),
                      ButtonSegment(value: ReportPeriod.mingguan, label: Text('Mingguan')),
                      ButtonSegment(value: ReportPeriod.bulanan, label: Text('Bulanan')),
                      ButtonSegment(value: ReportPeriod.tahunan, label: Text('Tahunan')),
                    ],
                    selected: {_period},
                    onSelectionChanged: (s) {
                      setState(() => _period = s.first);
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  _summaryTile('Omzet', formatCurrency(_summary['omzet'] ?? 0)),
                  _summaryTile('Keuntungan', formatCurrency(_summary['profit'] ?? 0)),
                  _summaryTile('Jumlah Transaksi', '${(_summary['trxCount'] ?? 0).toInt()}'),
                  _summaryTile('Barang Terjual', formatQty(_summary['qty'] ?? 0)),
                  _summaryTile('Nilai Stok Saat Ini', formatCurrency(_stockValue)),
                  const SizedBox(height: 16),
                  const Text('Barang Terlaris', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (_bestSelling.isEmpty)
                    const Padding(padding: EdgeInsets.all(8), child: Text('Belum ada data'))
                  else
                    SizedBox(
                      height: 220,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final i = value.toInt();
                                  if (i < 0 || i >= _bestSelling.length) return const SizedBox();
                                  final name = _bestSelling[i]['product_name'] as String;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(name.length > 6 ? '${name.substring(0, 6)}..' : name,
                                        style: const TextStyle(fontSize: 9)),
                                  );
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(_bestSelling.length, (i) {
                            final qty = (_bestSelling[i]['total_qty'] as num).toDouble();
                            return BarChartGroupData(x: i, barRods: [
                              BarChartRodData(toY: qty, color: Theme.of(context).colorScheme.primary, width: 14),
                            ]);
                          }),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text('Omzet per Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ..._omzetPerCategory.map((row) => ListTile(
                        dense: true,
                        title: Text(row['category_name'] as String? ?? 'Tanpa kategori'),
                        trailing: Text(formatCurrency((row['omzet'] as num?)?.toDouble() ?? 0)),
                      )),
                  const SizedBox(height: 16),
                  const Text('Barang Paling Sedikit Terjual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ..._leastSelling.map((row) => ListTile(
                        dense: true,
                        title: Text(row['product_name'] as String),
                        trailing: Text(formatQty((row['total_qty'] as num?)?.toDouble() ?? 0)),
                      )),
                ],
              ),
            ),
    );
  }

  Widget _summaryTile(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
