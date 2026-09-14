# Pola Pull-to-Refresh — Mamam Kasir

## Standar resmi: `RefreshIndicator` bawaan Flutter

Dipilih dibanding bikin animasi custom karena sudah ada 2 implementasi
berbeda di codebase sebelum audit ini (`RefreshIndicator` di Dompet vs
`InlineRefreshIndicator` custom di Dashboard) — `RefreshIndicator` yang
dijadikan standar karena lebih sederhana, sudah teruji dari Flutter
sendiri, dan sudah kepakai lebih dulu di Dompet.

Dipakai sekarang di: **Dompet**, **Kasir (POS)**, **Riwayat**, **Menu
Management**.

## Pengecualian yang disengaja: `InlineRefreshIndicator` (Dashboard)

Dashboard TETAP pakai `InlineRefreshIndicator` custom (lib/features/
dashboard/presentation/widgets/inline_refresh_indicator.dart), BUKAN
`RefreshIndicator` bawaan. Ini bukan inkonsistensi yang kelewat — ini
keputusan sengaja karena constraint layout: header dan tombol swipe-up
menu di Dashboard sengaja dibekukan di luar area scroll (lihat doc
comment `DashboardScreen`), sedangkan `RefreshIndicator` bawaan Flutter
butuh membungkus SATU scrollable utuh dan nampilin spinner-nya di
paling atas viewport situ — nggak cocok sama layout frozen-chrome ini
tanpa restrukturisasi besar.

Kalau Dashboard nanti direstruktur (misal header nggak perlu dibekukan
lagi), baru pertimbangkan pindah ke `RefreshIndicator` biar bener-bener
satu pola di semua tempat. Sampai saat itu, dua pola ini official-dua-duanya, masing-masing untuk kasus layoutnya sendiri.

## Cara pasang `RefreshIndicator` (checklist)

1. Pastikan controller punya method refresh yang genuinely re-fetch data
   (bukan cuma delay palsu) — biasanya udah ada, namanya `load()` atau
   `loadAll()` tergantung fitur.
2. Bungkus SATU scrollable (`ListView`/`GridView`) langsung dengan
   `RefreshIndicator(onRefresh: controller.load, child: ...)`.
3. WAJIB set `physics: const AlwaysScrollableScrollPhysics()` di
   scrollable itu — tanpa ini, `RefreshIndicator` nggak bisa deteksi
   gesture pull kalau kontennya lebih pendek dari layar (contoh: list
   cuma ada 1-2 item, atau lagi nampilin empty state).
4. Kalau ada kondisi "data kosong" yang biasanya cuma `Center(child:
   Text(...))`: JANGAN return widget itu langsung sebagai pengganti
   scrollable. Bungkus dengan `LayoutBuilder` + `ListView` +
   `SizedBox(height: constraints.maxHeight)` supaya (a) tetap ada
   scrollable buat `RefreshIndicator` deteksi pull, dan (b) `Center`
   di dalamnya tetap kebagian tinggi penuh buat centering yang benar.
   Lihat `_EmptyState` handling di `history_screen.dart`,
   `pos_screen.dart`, atau `menu_management_screen.dart` sebagai contoh
   pola yang sama persis dipakai di 3 tempat.

## Titik ekstensi buat nanti pas Supabase connect

`RefreshIndicator.onRefresh` cuma manggil `controller.load()` /
`loadAll()` yang sekarang isinya baca ulang dari SQLite lokal doang.
Begitu sync Supabase (docs/07 §19: Local DB → Outbox → Server Validation
→ Pull → Local DB) sudah jalan, yang perlu diubah CUMA isi method
`load()`/`loadAll()` di masing-masing controller — tambahin panggilan
`syncService.pull()` (atau apapun nama service sync-nya nanti) SEBELUM
baca ulang dari repository lokal. Widget UI (RefreshIndicator, animasi,
scrollable-nya) sama sekali TIDAK perlu disentuh lagi, karena dari awal
dia cuma `await` apapun yang dikembalikan `load()`/`loadAll()`.

Controller yang perlu ditambah sync call nanti:
- `DashboardController.load()` — lib/features/dashboard/application/dashboard_provider.dart
- `DompetController.load()` — cek nama file provider dompet
- `PosCatalogController.load()` — lib/features/pos/application/pos_catalog_provider.dart
- `HistoryController.load()` — lib/features/history/application/history_provider.dart
- `MenuManagementController.loadAll()` — lib/features/menu_management/application/menu_management_provider.dart

## Catatan penamaan
Method refresh di controller namanya BEDA-BEDA (`load()` di 4 tempat,
`loadAll()` di Menu Management) — bukan bug, cuma belum diseragamkan.
Nggak wajib diseragamkan sekarang, tapi kalau nanti nambah controller
baru yang butuh refresh, pakai nama `load()` biar konsisten sama
mayoritas yang udah ada.
