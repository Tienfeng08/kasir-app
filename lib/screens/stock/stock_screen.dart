import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../models/stock_purchase.dart';
import '../../utils/formatters.dart';
import '../../db/database_helper.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Stok'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Semua Barang'),
            Tab(text: 'Stok Menipis'),
            Tab(text: 'Kedaluwarsa'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _productList(provider.products, provider),
          _productList(provider.lowStockProducts, provider),
          _productList(provider.expiringProducts, provider),
        ],
      ),
    );
  }

  Widget _productList(List<Product> products, ProductProvider provider) {
    if (products.isEmpty) return const Center(child: Text('Tidak ada data'));
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, i) {
        final p = products[i];
        return ListTile(
          title: Text(p.name),
          subtitle: Text('Stok: ${formatQty(p.stock)} ${p.unit} • Min: ${formatQty(p.minStock)}'
              '${p.expiryDate != null ? ' • Kadaluwarsa: ${formatDate(p.expiryDate!)}' : ''}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'Riwayat perubahan',
                onPressed: () => _showHistory(context, p),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Sesuaikan stok',
                onPressed: () => _showAdjustDialog(context, p, provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAdjustDialog(BuildContext context, Product p, ProductProvider provider) async {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    StockMovementType type = StockMovementType.masuk;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Sesuaikan Stok: ${p.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stok saat ini: ${formatQty(p.stock)} ${p.unit}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<StockMovementType>(
                value: type,
                decoration: const InputDecoration(labelText: 'Jenis'),
                items: const [
                  DropdownMenuItem(value: StockMovementType.masuk, child: Text('Tambah Stok')),
                  DropdownMenuItem(value: StockMovementType.keluar, child: Text('Kurangi Stok')),
                  DropdownMenuItem(value: StockMovementType.opname, child: Text('Penyesuaian (Set ke jumlah tertentu)')),
                ],
                onChanged: (v) => setState(() => type = v!),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: type == StockMovementType.opname ? 'Jumlah stok baru' : 'Jumlah'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final inputQty = double.tryParse(qtyController.text) ?? 0;
                double delta;
                if (type == StockMovementType.opname) {
                  delta = inputQty - p.stock;
                } else if (type == StockMovementType.keluar) {
                  delta = -inputQty;
                } else {
                  delta = inputQty;
                }
                await provider.adjustStock(
                  product: p,
                  deltaQty: delta,
                  type: type,
                  note: noteController.text.isEmpty ? null : noteController.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHistory(BuildContext context, Product p) async {
    final movements = await DatabaseHelper.instance.getStockMovements(productId: p.id);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Riwayat Stok: ${p.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Expanded(
              child: movements.isEmpty
                  ? const Center(child: Text('Belum ada riwayat'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: movements.length,
                      itemBuilder: (context, i) {
                        final m = movements[i];
                        final isPositive = m.qty >= 0;
                        return ListTile(
                          leading: Icon(
                            isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                            color: isPositive ? Colors.green : Colors.red,
                          ),
                          title: Text('${m.type.label} • ${isPositive ? '+' : ''}${formatQty(m.qty)}'),
                          subtitle: Text(
                              '${formatDateTime(m.date)}\nStok: ${formatQty(m.stockBefore)} → ${formatQty(m.stockAfter)}'
                              '${m.note != null ? '\nCatatan: ${m.note}' : ''}'),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
