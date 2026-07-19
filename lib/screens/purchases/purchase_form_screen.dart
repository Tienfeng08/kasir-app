import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../models/stock_purchase.dart';
import '../../utils/formatters.dart';

class PurchaseFormScreen extends StatefulWidget {
  const PurchaseFormScreen({super.key});

  @override
  State<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends State<PurchaseFormScreen> {
  int? _supplierId;
  final _invoiceController = TextEditingController();
  final List<PurchaseItem> _items = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SupplierProvider>().loadAll());
  }

  double get _total => _items.fold(0.0, (s, i) => s + i.subtotal);

  @override
  Widget build(BuildContext context) {
    final suppliers = context.watch<SupplierProvider>().suppliers;

    return Scaffold(
      appBar: AppBar(title: const Text('Input Barang Masuk')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                DropdownButtonFormField<int?>(
                  value: _supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('- Tanpa supplier -')),
                    ...suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _invoiceController,
                  decoration: const InputDecoration(labelText: 'Nomor Faktur (opsional)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('Belum ada barang ditambahkan'))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      return ListTile(
                        title: Text(item.productName),
                        subtitle: Text('${formatQty(item.qty)} x ${formatCurrency(item.buyPrice)} = ${formatCurrency(item.subtotal)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(() => _items.removeAt(i)),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(formatCurrency(_total), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Tambah Barang'),
                        onPressed: _addItemDialog,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Simpan'),
                        onPressed: _items.isEmpty ? null : _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addItemDialog() async {
    final products = context.read<ProductProvider>().products;
    Product? selected;
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Tambah Barang'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                decoration: const InputDecoration(labelText: 'Barang'),
                items: products
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.name, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (p) {
                  setState(() {
                    selected = p;
                    priceController.text = p?.buyPrice.toStringAsFixed(0) ?? '';
                  });
                },
              ),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah'),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Harga Beli Terbaru'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () {
                if (selected == null) return;
                final qty = double.tryParse(qtyController.text) ?? 0;
                final price = double.tryParse(priceController.text) ?? 0;
                if (qty <= 0) return;
                this.setState(() {
                  _items.add(PurchaseItem(
                    productId: selected!.id!,
                    productName: selected!.name,
                    qty: qty,
                    buyPrice: price,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final purchase = Purchase(
      supplierId: _supplierId,
      invoiceNo: _invoiceController.text.trim().isEmpty ? null : _invoiceController.text.trim(),
      items: _items,
    );
    await context.read<PurchaseProvider>().save(purchase);
    await context.read<ProductProvider>().loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barang masuk berhasil disimpan, stok diperbarui')));
      Navigator.pop(context);
    }
  }
}
