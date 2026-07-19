import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../db/database_helper.dart';
import '../providers/product_provider.dart';
import '../utils/formatters.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum ChartRange { harian, mingguan, bulanan }

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseHelper.instance;
  Map<String, double> _today = {'omzet': 0, 'profit': 0, 'qty': 0, 'trxCount': 0};
  ChartRange _range = ChartRange.harian;
  List<FlSpot> _spots = [];
  List<String> _labels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final endToday = startToday.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    _today = await _db.getSummary(from: startToday, to: endToday);
    await _loadChart();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadChart() async {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    final labels = <String>[];

    if (_range == ChartRange.harian) {
      // 7 hari terakhir
      for (int i = 6; i >= 0; i--) {
        final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final end = day.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
        final s = await _db.getSummary(from: day, to: end);
        spots.add(FlSpot((6 - i).toDouble(), s['omzet'] ?? 0));
        labels.add('${day.day}/${day.month}');
      }
    } else if (_range == ChartRange.mingguan) {
      // 6 minggu terakhir
      for (int i = 5; i >= 0; i--) {
        final weekStart = now.subtract(Duration(days: now.weekday - 1 + i * 7));
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        final end = start.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
        final s = await _db.getSummary(from: start, to: end);
        spots.add(FlSpot((5 - i).toDouble(), s['omzet'] ?? 0));
        labels.add('${start.day}/${start.month}');
      }
    } else {
      // 6 bulan terakhir
      for (int i = 5; i >= 0; i--) {
        final month = DateTime(now.year, now.month - i, 1);
        final nextMonth = DateTime(month.year, month.month + 1, 1);
        final end = nextMonth.subtract(const Duration(milliseconds: 1));
        final s = await _db.getSummary(from: month, to: end);
        spots.add(FlSpot((5 - i).toDouble(), s['omzet'] ?? 0));
        labels.add('${month.month}/${month.year}');
      }
    }
    _spots = spots;
    _labels = labels;
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();

    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        await productProvider.loadAll();
      },
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _statCard('Omzet Hari Ini', formatCurrency(_today['omzet'] ?? 0), Icons.attach_money, Colors.green),
                    _statCard('Keuntungan Hari Ini', formatCurrency(_today['profit'] ?? 0), Icons.trending_up, Colors.blue),
                    _statCard('Transaksi Hari Ini', '${(_today['trxCount'] ?? 0).toInt()}', Icons.receipt_long, Colors.orange),
                    _statCard('Barang Terjual', formatQty(_today['qty'] ?? 0), Icons.shopping_bag, Colors.purple),
                    _statCard('Total Stok', '${productProvider.products.fold(0.0, (s, p) => s + p.stock).toInt()}', Icons.inventory_2, Colors.teal),
                    _statCard('Stok Menipis', '${productProvider.lowStockProducts.length}', Icons.warning_amber, Colors.red),
                  ],
                ),
                const SizedBox(height: 8),
                if (productProvider.expiringProducts.isNotEmpty)
                  Card(
                    color: Colors.amber.shade50,
                    child: ListTile(
                      leading: const Icon(Icons.event_busy, color: Colors.red),
                      title: Text('${productProvider.expiringProducts.length} barang kedaluwarsa / akan kedaluwarsa'),
                      subtitle: const Text('Lihat di Manajemen Stok'),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grafik Penjualan (Omzet)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    DropdownButton<ChartRange>(
                      value: _range,
                      items: const [
                        DropdownMenuItem(value: ChartRange.harian, child: Text('Harian')),
                        DropdownMenuItem(value: ChartRange.mingguan, child: Text('Mingguan')),
                        DropdownMenuItem(value: ChartRange.bulanan, child: Text('Bulanan')),
                      ],
                      onChanged: (v) async {
                        setState(() => _range = v!);
                        await _loadChart();
                        setState(() {});
                      },
                    ),
                  ],
                ),
                SizedBox(
                  height: 220,
                  child: _spots.isEmpty
                      ? const Center(child: Text('Belum ada data'))
                      : Padding(
                          padding: const EdgeInsets.only(top: 12, right: 12),
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: true),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i < 0 || i >= _labels.length) return const SizedBox();
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(_labels[i], style: const TextStyle(fontSize: 10)),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _spots,
                                  isCurved: true,
                                  color: Theme.of(context).colorScheme.primary,
                                  barWidth: 3,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
