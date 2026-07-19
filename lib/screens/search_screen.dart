import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/app_providers.dart';
import '../utils/formatters.dart';
import 'products/product_form_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SupplierProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products.where((p) {
      if (_query.isEmpty) return false;
      final q = _query.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
          (p.barcode ?? '').contains(q) ||
          (p.categoryName ?? '').toLowerCase().contains(q);
    }).toList();

    final suppliers = context.watch<SupplierProvider>().suppliers.where((s) {
      if (_query.isEmpty) return false;
      return s.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Cari barang, kategori, atau supplier...',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: _query.isEmpty
          ? const Center(child: Text('Ketik untuk mencari'))
          : ListView(
              children: [
                if (products.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.all(12), child: Text('Barang', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...products.map((p) => ListTile(
                        title: Text(p.name),
                        subtitle: Text('${p.categoryName ?? '-'} • ${formatCurrency(p.sellPrice)} • Stok ${formatQty(p.stock)}'),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: p))),
                      )),
                ],
                if (suppliers.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.all(12), child: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...suppliers.map((s) => ListTile(
                        leading: const Icon(Icons.local_shipping),
                        title: Text(s.name),
                        subtitle: Text(s.phone ?? '-'),
                      )),
                ],
                if (products.isEmpty && suppliers.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Tidak ditemukan'))),
              ],
            ),
    );
  }
}
