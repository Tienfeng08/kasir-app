import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_providers.dart';
import '../../models/supplier.dart';
import '../../utils/formatters.dart';
import 'purchase_form_screen.dart';

class PurchaseHistoryScreen extends StatefulWidget {
  final Supplier? supplier;
  const PurchaseHistoryScreen({super.key, this.supplier});

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<PurchaseProvider>().loadAll(supplierId: widget.supplier?.id));
  }

  @override
  Widget build(BuildContext context) {
    final purchases = context.watch<PurchaseProvider>().purchases;
    return Scaffold(
      appBar: AppBar(title: Text(widget.supplier != null ? 'Pembelian: ${widget.supplier!.name}' : 'Riwayat Pembelian')),
      body: purchases.isEmpty
          ? const Center(child: Text('Belum ada riwayat pembelian'))
          : ListView.builder(
              itemCount: purchases.length,
              itemBuilder: (context, i) {
                final p = purchases[i];
                return ExpansionTile(
                  title: Text('${p.supplierName ?? 'Tanpa supplier'} • ${formatDate(p.date)}'),
                  subtitle: Text('Faktur: ${p.invoiceNo ?? '-'} • Total: ${formatCurrency(p.total)}'),
                  children: p.items
                      .map((item) => ListTile(
                            dense: true,
                            title: Text(item.productName),
                            subtitle: Text('${formatQty(item.qty)} x ${formatCurrency(item.buyPrice)}'),
                            trailing: Text(formatCurrency(item.subtotal)),
                          ))
                      .toList(),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Barang Masuk'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseFormScreen())),
      ),
    );
  }
}
