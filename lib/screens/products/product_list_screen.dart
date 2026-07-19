import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../utils/formatters.dart';
import '../../widgets/barcode_scanner_screen.dart';
import '../../widgets/pin_dialog.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  int? _categoryId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final filtered = provider.products.where((p) {
      final matchQuery = _query.isEmpty ||
          p.name.toLowerCase().contains(_query.toLowerCase()) ||
          (p.barcode ?? '').contains(_query);
      final matchCat = _categoryId == null || p.categoryId == _categoryId;
      return matchQuery && matchCat;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Barang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan barcode',
            onPressed: () async {
              final code = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
              );
              if (code != null) {
                final product = await provider.findByBarcode(code);
                if (!mounted) return;
                if (product != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)));
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProductFormScreen(initialBarcode: code)),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari nama barang / barcode...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: _categoryId == null,
                        onSelected: (_) => setState(() => _categoryId = null),
                      ),
                      const SizedBox(width: 6),
                      ...provider.categories.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(c.name),
                              selected: _categoryId == c.id,
                              onSelected: (_) => setState(() => _categoryId = c.id),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Belum ada barang'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: p.photoPath != null ? FileImage(File(p.photoPath!)) : null,
                          child: p.photoPath == null ? const Icon(Icons.inventory_2) : null,
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                            '${p.barcode ?? '-'} • Stok: ${formatQty(p.stock)} ${p.unit} • ${formatCurrency(p.sellPrice)}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p.isLowStock)
                              const Icon(Icons.warning_amber, color: Colors.red, size: 18),
                            if (p.isExpired)
                              const Icon(Icons.event_busy, color: Colors.red, size: 18)
                            else if (p.isExpiringSoon)
                              const Icon(Icons.event_busy, color: Colors.orange, size: 18),
                          ],
                        ),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: p))),
                        onLongPress: () => _confirmDelete(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Barang'),
        content: Text('Yakin ingin menghapus "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final pinOk = await confirmWithPin(context, title: 'PIN untuk hapus barang');
    if (!pinOk || !context.mounted) return;

    await context.read<ProductProvider>().deleteProduct(p.id!);
  }
}
