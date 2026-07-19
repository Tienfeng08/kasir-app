import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_providers.dart';
import '../../models/transaction.dart';
import '../../utils/formatters.dart';
import '../../widgets/pin_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime? _from;
  DateTime? _to;
  final _productQueryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<TransactionProvider>().loadAll());
  }

  Future<void> _applyFilter() async {
    await context.read<TransactionProvider>().loadAll(
          from: _from,
          to: _to,
          productQuery: _productQueryController.text.trim().isEmpty ? null : _productQueryController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<TransactionProvider>().transactions;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                TextField(
                  controller: _productQueryController,
                  decoration: InputDecoration(
                    hintText: 'Cari berdasarkan nama barang...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (_) => _applyFilter(),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(_from == null ? 'Dari tanggal' : formatDate(_from!)),
                        onPressed: () async {
                          final d = await showDatePicker(
                              context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (d != null) {
                            setState(() => _from = d);
                            _applyFilter();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(_to == null ? 'Sampai tanggal' : formatDate(_to!)),
                        onPressed: () async {
                          final d = await showDatePicker(
                              context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (d != null) {
                            setState(() => _to = d);
                            _applyFilter();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('Belum ada transaksi'))
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, i) {
                      final trx = transactions[i];
                      return ListTile(
                        title: Text(trx.trxNo),
                        subtitle: Text('${formatDateTime(trx.date)} • ${formatQty(trx.totalQty)} item'
                            '${trx.isReturned ? ' • (ada retur)' : ''}'),
                        trailing: Text(formatCurrency(trx.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionDetailScreen(trx: trx))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TransactionDetailScreen extends StatelessWidget {
  final SaleTransaction trx;
  const TransactionDetailScreen({super.key, required this.trx});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(trx.trxNo),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Hapus transaksi',
            onPressed: () => _deleteTransaction(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('Tanggal: ${formatDateTime(trx.date)}'),
          Text('Metode Bayar: ${trx.paymentMethod}'),
          const Divider(),
          ...trx.items.map((item) => ListTile(
                title: Text(item.productName),
                subtitle: Text('${formatQty(item.qty)} x ${formatCurrency(item.price)}'
                    '${item.discount > 0 ? ' (diskon ${formatCurrency(item.discount)})' : ''}'),
                trailing: Text(formatCurrency(item.subtotal)),
                onLongPress: () => _returnItemDialog(context, item),
              )),
          const Divider(),
          ListTile(title: const Text('Diskon Transaksi'), trailing: Text(formatCurrency(trx.discount))),
          ListTile(
            title: const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text(formatCurrency(trx.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(height: 8),
          const Text('Tekan lama item untuk melakukan retur', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _returnItemDialog(BuildContext context, TransactionItem item) async {
    final controller = TextEditingController(text: item.qty.toStringAsFixed(0));
    final qty = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retur: ${item.productName}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Jumlah retur (maks ${formatQty(item.qty)})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Proses Retur')),
        ],
      ),
    );
    if (qty == null || !context.mounted) return;
    final qtyVal = double.tryParse(qty) ?? 0;
    if (qtyVal <= 0 || qtyVal > item.qty) return;

    final pinOk = await confirmWithPin(context, title: 'PIN untuk retur penjualan');
    if (!pinOk || !context.mounted) return;

    await context.read<TransactionProvider>().returnItem(item, qtyVal);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retur berhasil, stok dikembalikan')));
    }
  }

  Future<void> _deleteTransaction(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Yakin ingin menghapus transaksi ini? Stok barang akan dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final pinOk = await confirmWithPin(context, title: 'PIN untuk hapus transaksi');
    if (!pinOk || !context.mounted) return;

    await context.read<TransactionProvider>().deleteTransaction(trx.id!, restoreStock: true);
    if (context.mounted) Navigator.pop(context);
  }
}
