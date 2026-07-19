# Aplikasi Kasir & Manajemen Toko (Flutter)

Aplikasi kasir offline-first dengan database SQLite lokal. Semua data (barang, transaksi,
stok, supplier, pembelian) tersimpan di HP, tidak butuh internet untuk operasional harian.

## Cara Menjalankan

1. Pastikan Flutter SDK sudah terpasang (`flutter --version`).
2. Salin folder proyek ini, lalu jalankan di terminal:
   ```
   cd kasir_app
   flutter pub get
   flutter run
   ```

## Permission yang Perlu Ditambahkan (Android)

Tambahkan ke `android/app/src/main/AndroidManifest.xml` (di dalam tag `<manifest>`, sebelum `<application>`):

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Untuk iOS, tambahkan ke `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Digunakan untuk scan barcode dan foto barang</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Digunakan untuk memilih foto barang</string>
```

## Fitur yang Sudah Berfungsi Penuh

- **Dashboard**: omzet, keuntungan, transaksi, barang terjual hari ini, total stok,
  stok menipis, kedaluwarsa, grafik penjualan harian/mingguan/bulanan.
- **Master Barang**: scan barcode, tambah/edit/hapus, foto barang, kategori, satuan,
  harga beli/jual, stok, minimal stok, lokasi rak, kedaluwarsa, catatan.
- **Penjualan (Kasir/POS)**: scan barcode, cari barang, keranjang, ubah qty, diskon
  per item & transaksi, nomor transaksi otomatis, stok otomatis berkurang.
- **Manajemen Stok**: tambah/kurangi/opname, riwayat perubahan stok, filter stok
  menipis & kedaluwarsa.
- **Supplier**: CRUD + riwayat pembelian per supplier.
- **Pembelian Barang**: input barang masuk, update harga beli terbaru, nomor faktur,
  riwayat pembelian, stok otomatis bertambah.
- **Riwayat Transaksi**: semua transaksi, detail, cari per tanggal/barang, retur
  (mengembalikan stok), hapus transaksi (dengan konfirmasi PIN).
- **Laporan**: harian/mingguan/bulanan/tahunan, omzet, keuntungan, nilai stok, barang
  terlaris/paling sedikit terjual, omzet per kategori, grafik, export Excel & PDF.
- **Pencarian global**: nama barang, barcode, kategori, supplier.
- **Backup/Restore**: backup manual (pilih lokasi penyimpanan/folder Drive lokal),
  share backup (lewat share sheet, termasuk opsi "Simpan ke Drive"), restore dari
  file, export/import Excel data barang.
- **Pengaturan**: nama & logo toko, tema terang/gelap, PIN untuk aksi sensitif.
- **Notifikasi**: stok menipis, kedaluwarsa, pengingat backup (notifikasi lokal).
- **Keamanan**: tanpa login, PIN opsional untuk hapus barang/transaksi, restore
  database, dan pengaturan penting.

## Catatan Penting: Integrasi Google Drive Langsung (Upload/Download API)

Backup/restore saat ini menggunakan **pendekatan file lokal**:
- "Backup Manual" membuka file picker sistem untuk menyimpan file `.db` ke lokasi
  pilihan pengguna (termasuk folder yang disinkronkan Google Drive/OneDrive di HP).
- "Bagikan Backup" membuka share sheet Android/iOS, yang biasanya menyertakan opsi
  "Simpan ke Drive" jika aplikasi Google Drive terpasang.

Ini **belum** integrasi API Google Drive langsung (upload/download otomatis tanpa
campur tangan user), karena itu membutuhkan:
1. Project di Google Cloud Console + OAuth Client ID milik Anda sendiri.
2. Package `google_sign_in` + `googleapis` (Drive API v3).
3. Consent screen & verifikasi aplikasi oleh Google (untuk scope Drive).

Jika Anda ingin fitur ini, beri tahu saya nanti — saya bisa tambahkan modul
`GoogleDriveBackupService` begitu Anda punya kredensial OAuth-nya sendiri, karena
kredensial tersebut tidak bisa saya buatkan (harus didaftarkan atas nama Anda/toko Anda).

## Struktur Folder

```
lib/
  models/       -> semua model data (Product, Supplier, Transaction, dll)
  db/           -> database_helper.dart (skema SQLite + semua query)
  providers/    -> state management (Provider)
  screens/      -> semua halaman UI, dikelompokkan per modul
  widgets/      -> komponen reusable (scanner, dialog PIN)
  utils/        -> formatter, export Excel/PDF, backup, notifikasi
```

## Rekomendasi Pengembangan Lanjutan

- Tambahkan enkripsi untuk file backup (misalnya dengan `encrypt` package) jika data
  toko sensitif.
- Tambahkan halaman "Statistik" terpisah jika ingin visual lebih detail per barang
  (saat ini datanya sudah tersedia di modul Laporan).
- Untuk toko dengan banyak kasir/perangkat, pertimbangkan migrasi ke database
  server (mis. Supabase/Firebase) agar data tersinkron antar perangkat.
