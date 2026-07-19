import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';

/// Menampilkan dialog PIN jika PIN aktif. Mengembalikan `true` jika:
/// - PIN tidak aktif (langsung lanjut), atau
/// - PIN dimasukkan dengan benar.
/// Mengembalikan `false` jika dibatalkan atau PIN salah.
Future<bool> confirmWithPin(BuildContext context, {String title = 'Konfirmasi PIN'}) async {
  final settings = context.read<SettingsProvider>();
  if (!settings.isPinEnabled) return true;

  final controller = TextEditingController();
  String? errorText;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Masukkan PIN',
            errorText: errorText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text == settings.pin) {
                Navigator.pop(ctx, true);
              } else {
                setState(() => errorText = 'PIN salah');
              }
            },
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
