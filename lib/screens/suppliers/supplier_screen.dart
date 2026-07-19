import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_providers.dart';
import '../../models/supplier.dart';
import '../../widgets/pin_dialog.dart';
import '../purchases/purchase_history_screen.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SupplierProvider>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplierProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier')),
      body: provider.suppliers.isEmpty
          ? const Center(child: Text('Belum ada supplier'))
          : ListView.builder(
              itemCount: provider.suppliers.length,
              itemBuilder: (context, i) {
                final s = provider.suppliers[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.local_shipping)),
                  title: Text(s.name),
                  subtitle: Text(s.phone ?? '-'),
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => PurchaseHistoryScreen(supplier: s))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(context, supplier: s)),
                      IconButton(icon: const Icon(Icons.delete), onPressed: () => _delete(context, s)),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Supplier s) async {
    final pinOk = await confirmWithPin(context, title: 'PIN untuk hapus supplier');
    if (!pinOk || !context.mounted) return;
    await context.read<SupplierProvider>().delete(s.id!);
  }

  Future<void> _showForm(BuildContext context, {Supplier? supplier}) async {
    final name = TextEditingController(text: supplier?.name ?? '');
    final phone = TextEditingController(text: supplier?.phone ?? '');
    final address = TextEditingController(text: supplier?.address ?? '');
    final notes = TextEditingController(text: supplier?.notes ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(supplier == null ? 'Tambah Supplier' : 'Edit Supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama *')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telepon')),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Alamat')),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Catatan')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final newSupplier = Supplier(
                id: supplier?.id,
                name: name.text.trim(),
                phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                address: address.text.trim().isEmpty ? null : address.text.trim(),
                notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
              );
              final provider = ctx.read<SupplierProvider>();
              if (supplier == null) {
                await provider.add(newSupplier);
              } else {
                await provider.update(newSupplier);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
