import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/product_provider.dart';
import '../../utils/backup_helper.dart';
import '../../utils/formatters.dart';
import '../../widgets/pin_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const _SectionHeader('Profil Toko'),
          ListTile(
            leading: CircleAvatar(
              backgroundImage: settings.logoPath != null ? FileImage(File(settings.logoPath!)) : null,
              child: settings.logoPath == null ? const Icon(Icons.store) : null,
            ),
            title: Text(settings.storeName),
            subtitle: const Text('Ketuk untuk ubah nama toko'),
            trailing: IconButton(icon: const Icon(Icons.photo_camera), onPressed: _pickLogo),
            onTap: _editStoreName,
          ),
          const Divider(),
          const _SectionHeader('Tampilan'),
          SwitchListTile(
            title: const Text('Tema Gelap'),
            value: settings.isDarkMode,
            onChanged: (v) => settings.setDarkMode(v),
          ),
          const Divider(),
          const _SectionHeader('Keamanan (PIN)'),
          SwitchListTile(
            title: const Text('Aktifkan PIN untuk aksi penting'),
            subtitle: const Text('Hapus barang, hapus transaksi, restore database, pengaturan penting'),
            value: settings.isPinEnabled,
            onChanged: (v) async {
              if (v) {
                await _setPinDialog(context);
              } else {
                final ok = await confirmWithPin(context, title: 'Masukkan PIN untuk menonaktifkan');
                if (ok) await settings.setPin(null);
              }
            },
          ),
          if (settings.isPinEnabled)
            ListTile(
              title: const Text('Ubah PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final ok = await confirmWithPin(context, title: 'Masukkan PIN saat ini');
                if (ok) await _setPinDialog(context);
              },
            ),
          const Divider(),
          const _SectionHeader('Backup & Restore'),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup Manual (pilih lokasi/Drive)'),
            subtitle: settings.lastBackupDate != null
                ? Text('Terakhir: ${formatDateTime(settings.lastBackupDate!)}')
                : const Text('Belum pernah backup'),
            onTap: _busy ? null : () => _doBackup(context),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Bagikan Backup (via share sheet)'),
            subtitle: const Text('Pilih "Simpan ke Drive" atau aplikasi lain dari menu bagikan'),
            onTap: _busy ? null : () => BackupHelper.shareBackup(),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Database'),
            subtitle: const Text('Menimpa data saat ini dengan file backup'),
            onTap: _busy ? null : () => _doRestore(context),
          ),
          SwitchListTile(
            title: const Text('Backup Otomatis'),
            subtitle: const Text('Pengingat backup rutin (notifikasi)'),
            value: settings.autoBackupEnabled,
            onChanged: (v) => settings.setAutoBackup(v),
          ),
          const Divider(),
          const _SectionHeader('Data Barang'),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Export Excel (Data Barang)'),
            onTap: () async {
              final products = context.read<ProductProvider>().products;
              await BackupHelper.exportProductsToExcel(products);
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Import Excel (Data Barang)'),
            onTap: () => _importExcel(context),
          ),
          const Divider(),
          const _SectionHeader('Tentang'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Aplikasi Kasir & Manajemen Toko'),
            subtitle: Text('Versi 1.0.0'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _editStoreName() async {
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(text: settings.storeName);
    final pinOk = await confirmWithPin(context, title: 'PIN untuk ubah pengaturan penting');
    if (!pinOk || !mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nama Toko'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Simpan')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await settings.saveStoreProfile(name: name.trim());
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xfile == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final saved = await File(xfile.path).copy('${dir.path}/store_logo.jpg');
    if (mounted) await context.read<SettingsProvider>().saveStoreProfile(logo: saved.path);
  }

  Future<void> _setPinDialog(BuildContext context) async {
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atur PIN Baru'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: const InputDecoration(labelText: 'PIN (4-6 digit)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Simpan')),
        ],
      ),
    );
    if (pin != null && pin.length >= 4 && context.mounted) {
      await context.read<SettingsProvider>().setPin(pin);
    }
  }

  Future<void> _doBackup(BuildContext context) async {
    setState(() => _busy = true);
    try {
      final path = await BackupHelper.backupManual();
      if (path != null && context.mounted) {
        await context.read<SettingsProvider>().markBackupDone();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup disimpan: $path')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doRestore(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Database'),
        content: const Text('Semua data saat ini akan diganti dengan data dari file backup. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final pinOk = await confirmWithPin(context, title: 'PIN untuk restore database');
    if (!pinOk || !context.mounted) return;

    setState(() => _busy = true);
    try {
      final success = await BackupHelper.restoreFromPicker();
      if (success && context.mounted) {
        await context.read<ProductProvider>().loadAll();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database berhasil di-restore')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importExcel(BuildContext context) async {
    final productProvider = context.read<ProductProvider>();
    final categoryMap = {for (final c in productProvider.categories) c.name: c.id};
    final count = await BackupHelper.importProductsFromExcel(
      onEachProduct: (p) => productProvider.addProduct(p),
      categoryNameToId: categoryMap,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count barang berhasil diimpor')));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
