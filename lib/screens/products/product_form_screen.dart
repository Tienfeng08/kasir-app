import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../models/product.dart';
import '../../widgets/barcode_scanner_screen.dart';

const List<String> kUnits = ['pcs', 'dus', 'kg', 'gram', 'pack', 'box', 'liter', 'lusin'];

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final String? initialBarcode;
  const ProductFormScreen({super.key, this.product, this.initialBarcode});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _barcode;
  late TextEditingController _buyPrice;
  late TextEditingController _sellPrice;
  late TextEditingController _stock;
  late TextEditingController _minStock;
  late TextEditingController _shelfLocation;
  late TextEditingController _notes;
  String _unit = 'pcs';
  int? _categoryId;
  DateTime? _expiryDate;
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _buyPrice = TextEditingController(text: p?.buyPrice.toStringAsFixed(0) ?? '');
    _sellPrice = TextEditingController(text: p?.sellPrice.toStringAsFixed(0) ?? '');
    _stock = TextEditingController(text: p?.stock.toStringAsFixed(0) ?? '0');
    _minStock = TextEditingController(text: p?.minStock.toStringAsFixed(0) ?? '0');
    _shelfLocation = TextEditingController(text: p?.shelfLocation ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _unit = p?.unit ?? 'pcs';
    _categoryId = p?.categoryId;
    _expiryDate = p?.expiryDate;
    _photoPath = p?.photoPath;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final isEdit = widget.product != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Barang' : 'Tambah Barang')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: CircleAvatar(
                  radius: 45,
                  backgroundImage: _photoPath != null ? FileImage(File(_photoPath!)) : null,
                  child: _photoPath == null ? const Icon(Icons.add_a_photo, size: 30) : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nama Barang *', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              decoration: InputDecoration(
                labelText: 'Barcode',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final code = await Navigator.push<String>(
                        context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
                    if (code != null) _barcode.text = code;
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('- Tanpa kategori -')),
                ...provider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah kategori baru'),
              onPressed: _addCategoryDialog,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _unit,
              decoration: const InputDecoration(labelText: 'Satuan', border: OutlineInputBorder()),
              items: kUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (v) => setState(() => _unit = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _buyPrice,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Harga Beli', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellPrice,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Harga Jual *', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Jumlah Stok', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minStock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minimal Stok', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _shelfLocation,
              decoration: const InputDecoration(labelText: 'Lokasi Rak (opsional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_expiryDate == null
                  ? 'Tanggal Kedaluwarsa (opsional)'
                  : 'Kedaluwarsa: ${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _expiryDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (date != null) setState(() => _expiryDate = date);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Catatan', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Simpan Perubahan' : 'Tambah Barang'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xfile == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final saved = await File(xfile.path).copy('${dir.path}/$fileName');
    setState(() => _photoPath = saved.path);
  }

  Future<void> _addCategoryDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategori Baru'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Nama kategori')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Tambah')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && mounted) {
      await context.read<ProductProvider>().addCategory(name);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<ProductProvider>();

    final product = Product(
      id: widget.product?.id,
      name: _name.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      categoryId: _categoryId,
      unit: _unit,
      buyPrice: double.tryParse(_buyPrice.text) ?? 0,
      sellPrice: double.tryParse(_sellPrice.text) ?? 0,
      stock: double.tryParse(_stock.text) ?? 0,
      minStock: double.tryParse(_minStock.text) ?? 0,
      shelfLocation: _shelfLocation.text.trim().isEmpty ? null : _shelfLocation.text.trim(),
      expiryDate: _expiryDate,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      photoPath: _photoPath,
    );

    if (widget.product == null) {
      await provider.addProduct(product);
    } else {
      await provider.updateProduct(product);
    }

    if (mounted) Navigator.pop(context);
  }
}
