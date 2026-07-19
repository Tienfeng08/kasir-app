import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../utils/notification_helper.dart';
import '../providers/product_provider.dart';
import 'dashboard_screen.dart';
import 'products/product_list_screen.dart';
import 'sales/sales_screen.dart';
import 'stock/stock_screen.dart';
import 'suppliers/supplier_screen.dart';
import 'purchases/purchase_history_screen.dart';
import 'history/history_screen.dart';
import 'reports/report_screen.dart';
import 'settings/settings_screen.dart';
import 'search_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    DashboardScreen(),
    SalesScreen(),
    ProductListScreen(),
    StockScreen(),
  ];

  final _titles = const ['Dashboard', 'Penjualan', 'Master Barang', 'Manajemen Stok'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final productProvider = context.read<ProductProvider>();
      await productProvider.loadAll();
      if (mounted) {
        await NotificationHelper.checkAndNotify(productProvider.products);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(settings.storeName),
              accountEmail: null,
              currentAccountPicture: CircleAvatar(
                backgroundImage: settings.logoPath != null ? FileImage(File(settings.logoPath!)) : null,
                child: settings.logoPath == null ? const Icon(Icons.store, size: 32) : null,
              ),
            ),
            _drawerItem(Icons.dashboard, 'Dashboard', () => _goto(0)),
            _drawerItem(Icons.point_of_sale, 'Penjualan', () => _goto(1)),
            _drawerItem(Icons.inventory_2, 'Master Barang', () => _goto(2)),
            _drawerItem(Icons.warehouse, 'Manajemen Stok', () => _goto(3)),
            const Divider(),
            _drawerItem(Icons.local_shipping, 'Supplier', () => _push(const SupplierScreen())),
            _drawerItem(Icons.shopping_cart, 'Pembelian Barang', () => _push(const PurchaseHistoryScreen())),
            _drawerItem(Icons.receipt_long, 'Riwayat Transaksi', () => _push(const HistoryScreen())),
            _drawerItem(Icons.bar_chart, 'Laporan & Statistik', () => _push(const ReportScreen())),
            const Divider(),
            _drawerItem(Icons.settings, 'Pengaturan', () => _push(const SettingsScreen())),
          ],
        ),
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Jual'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Barang'),
          NavigationDestination(icon: Icon(Icons.warehouse), label: 'Stok'),
        ],
      ),
    );
  }

  void _goto(int i) {
    Navigator.pop(context);
    setState(() => _index = i);
  }

  void _push(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }
}
