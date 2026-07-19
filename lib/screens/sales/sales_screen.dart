import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../utils/formatters.dart';
import '../../widgets/barcode_scanner_screen.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _searchController = TextEditingController();
  List<Product> _searchResults = [];

  Future<void> _search(String query) async {
    final provider = context.read<ProductProvider>();
    final results = await provider.search(query: query);
    setState(() => _searchResults = results);
  }

  Future<void> _scanAndAdd() async {
    final code = await Navigator.push<String>(
        context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
    if (code == null || !mounted) return;
    final product = await context.read<ProductProvider>().findByBarcode(code);
    if (product == null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Barang dengan barcode "$code" tidak ditemukan')));
      }
      return;
    }
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok barang habis')));
      return;
    }
    context.read<CartProvider>().addProduct(product);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penjualan (Kasir)'),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _scanAndAdd),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari barang untuk ditambahkan...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: _search,
            ),
          ),
          if (_searchResults.isNotEmpty)
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, i) {
                  final p = _searchResults[i];
                  return ListTile(
                    dense: true,
                    title: Text(p.name),
                    subtitle: Text('${formatCurrency(p.sellPrice)} • stok ${formatQty(p.stock)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: p.stock <= 0
                          ? null
                          : () {
                              cart.addProduct(p);
                              _searchController.clear();
                              setState(() => _searchResults = []);
                            },
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('Keranjang masih kosong.\nCari barang atau scan barcode.', textAlign: TextAlign.center))
                : ListView.builder(
                    itemCount: cart.lines.length,
                    itemBuilder: (context, i) {
                      final line = cart.lines[i];
                      return Dismissible(
                        key: ValueKey(line.product.id),
                        direction: DismissDirection.endToStart,
                        background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                        onDismissed: (_) => cart.removeProduct(line.product.id!),
                        child: ListTile(
                          title: Text(line.product.name),
                          subtitle: Text('${formatCurrency(line.product.sellPrice)} x ${formatQty(line.qty)}'
                              '${line.discount > 0 ? ' (diskon ${formatCurrency(line.discount)})' : ''}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => cart.setQty(line.product.id!, line.qty - 1),
                              ),
                              Text(formatQty(line.qty)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => cart.setQty(line.product.id!, line.qty + 1),
                              ),
                            ],
                          ),
                          onLongPress: () => _editLineDiscount(context, line),
                        ),
                      );
                    },
                  ),
          ),
          _buildCheckoutBar(context, cart),
        ],
      ),
    );
  }

  Future<void> _editLineDiscount(BuildContext context, CartLine line) async {
    final controller = TextEditingController(text: line.discount.toStringAsFixed(0));
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Diskon untuk ${line.product.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Diskon (nominal Rp)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Simpan')),
        ],
      ),
    );
    if (value != null) {
      context.read<CartProvider>().setLineDiscount(line.product.id!, double.tryParse(value) ?? 0);
    }
  }

  Widget _buildCheckoutBar(BuildContext context, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Diskon Transaksi:'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Rp 0', isDense: true),
                    onChanged: (v) => cart.setHeaderDiscount(double.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(formatCurrency(cart.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.point_of_sale),
                label: const Text('Simpan Transaksi'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: cart.isEmpty ? null : () => _checkout(context, cart),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkout(BuildContext context, CartProvider cart) async {
    try {
      final trxNo = await cart.checkout();
      if (!mounted) return;
      await context.read<ProductProvider>().loadAll();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Transaksi Berhasil'),
          content: Text('Nomor transaksi: $trxNo'),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }
}
