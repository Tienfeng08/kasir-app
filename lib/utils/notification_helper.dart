import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/product.dart';

class NotificationHelper {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> _show(int id, String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'kasir_channel',
      'Notifikasi Kasir App',
      channelDescription: 'Notifikasi stok menipis, kedaluwarsa, dan pengingat backup',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
    await _plugin.show(id, title, body, details);
  }

  /// Panggil ini secara berkala (misalnya saat dashboard dimuat) untuk
  /// memunculkan notifikasi jika ada barang stok menipis / kedaluwarsa.
  static Future<void> checkAndNotify(List<Product> products) async {
    await init();
    final lowStock = products.where((p) => p.isLowStock).toList();
    final expiring = products.where((p) => p.isExpired || p.isExpiringSoon).toList();

    if (lowStock.isNotEmpty) {
      await _show(
        1001,
        'Stok Menipis',
        '${lowStock.length} barang perlu segera diisi ulang stoknya.',
      );
    }
    if (expiring.isNotEmpty) {
      await _show(
        1002,
        'Barang Kedaluwarsa',
        '${expiring.length} barang sudah/akan kedaluwarsa dalam 30 hari.',
      );
    }
  }

  static Future<void> remindBackup() async {
    await init();
    await _show(1003, 'Pengingat Backup', 'Jangan lupa backup data toko Anda secara rutin.');
  }
}
