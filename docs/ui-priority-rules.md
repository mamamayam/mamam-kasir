# Aturan Prioritas Tampilan & Stack Navigation — Mamam Kasir

Dokumen ini adalah rujukan resmi untuk kapan pakai dialog kecil, bottom
sheet, atau full page, dan bagaimana navigasi antar-layar/sheet harus
berperilaku secara konsisten di seluruh app. Ditulis berdasarkan audit
langsung ke kode yang ada (bukan disusun dari nol), jadi contoh-contoh di
bawah menunjuk ke file asli di repo.

Kalau ragu nempatin komponen baru di skala mana, baca dulu dokumen ini —
jangan bikin pola baru sendiri.

## 1. Skala prioritas tampilan

Dari paling ringan ke paling berat:

### Level 1 — Dialog kecil (`showDialog`)
Untuk konfirmasi singkat / alert / pilihan 2-3 opsi tanpa form. Muncul di
tengah layar, ukurannya kecil, tidak untuk konten yang butuh scroll.

Contoh yang sudah benar: `lib/features/pengaturan/presentation/
pengaturan_screen.dart` → `_confirmLogout` (dialog "Keluar Akun?").

Catatan: dialog TIDAK melalui `AppNav` — `AppNav` cuma menangani bottom
sheet (`AppNav.showModal`) dan full page (`AppNav.push`). `showDialog`
langsung dari Flutter tetap dipakai apa adanya untuk kasus Level 1.

### Level 2 — Bottom sheet slide-up parsial
Untuk pilihan dari list pendek, filter, sort, picker. Tinggi mengikuti
konten (`isScrollControlled: false`), bukan hampir-full-screen.

Contoh yang sudah benar: `category_filter_sheet.dart`, `sort_sheet.dart`,
`month_picker_sheet.dart`, `report_type_picker_sheet.dart`,
`customer_picker_sheet.dart` (pakai `DraggableScrollableSheet` ukuran
sedang), dashboard `_showTrendDetail`.

### Level 3 — Bottom sheet slide-up full/near-full
Untuk FORM tambah/edit yang banyak field atau butuh scroll. Pakai
`DraggableScrollableSheet` dengan `initialChildSize` tinggi (0.75–1.0),
`isScrollControlled: true`.

Contoh yang sudah benar: `payment_modal.dart` (Pembayaran), `cart_drawer.
dart` (Checkout), `variant_selection_modal.dart`, `receipt_modal.dart`,
`add_menu_item_modal.dart`, `add_ingredient_modal.dart`.

### Level 4 — Full page (`AppNav.push`)
Untuk layar yang punya identitas navigasi sendiri, biasa dibuka dari tap
item di list, dan orang mungkin mau pindah-pindah antar halaman terkait.
Transisi masuk dari kanan (lihat bagian Stack Navigation di bawah).

Contoh yang sudah benar: `TransactionDetailScreen`, `PosScreen`,
`HistoryScreen`, `MenuManagementScreen`, semua tujuan tile menu di
`menu_grid_items.dart`, semua item di `pengaturan_screen.dart`.

### Transisi antar-tab sejenis (bukan salah satu dari 4 level di atas)
Perpindahan ANTAR TAB sejenis dalam satu context yang sama (misal antar
kategori menu, antar tab laporan) pakai transisi geser kanan<->kiri
(swipe horizontal antar tab), bukan push/pop vertikal dan bukan salah
satu dari 4 level di atas. Ini pola terpisah untuk tab-switching, bukan
untuk membuka layar/form baru.

## 2. Cara memanggil tiap level (WAJIB, jangan reimplement manual)

- **Level 1**: `showDialog(context: context, builder: ...)` langsung.
- **Level 2 & 3**: WAJIB lewat `AppNav.showModal(context, builder: ...,
  isScrollControlled: ...)` — lib/core/navigation/app_nav.dart. JANGAN
  panggil `showModalBottomSheet` langsung di mana pun. Semua sheet di
  codebase per audit ini sudah dikonversi ke `AppNav.showModal`; kalau
  nambah sheet baru, ikuti pola ini dari awal.
  - Level 2 → pass `isScrollControlled: false` (default sheet tinggi
    sesuai konten).
  - Level 3 → biarkan default (`isScrollControlled: true`), bungkus
    contentnya dengan `DraggableScrollableSheet`.
- **Level 4**: WAJIB lewat `AppNav.push(context, builder)` —
  lib/core/navigation/app_nav.dart. JANGAN panggil `Navigator.push` /
  `Navigator.of(context).push` langsung.

Header setiap Level 2/3 sheet yang punya tombol close WAJIB pakai
`AppSheetHeader` (lib/core/widgets/app_sheet_header.dart) — lihat doc
comment di file itu untuk alasannya (mencegah title/tombol nabrak).
Header setiap Level 4 full page WAJIB pakai `IosPageHeader`
(lib/core/widgets/ios_page_header.dart). Jangan bikin header custom baru
dengan `Stack` + `Center` + `Align` manual di kedua kasus ini.

## 3. Stack navigation — sheet tetap hidup di belakang layar yang di-push

Aturan inti: **sheet/modal yang lagi terbuka adalah route asli di
Navigator stack, bukan sekadar overlay.** Kalau dari dalam sheet ada aksi
"buka sesuatu yang lain" (form lain, layar detail, dll), pakai
`AppNav.push` dari dalam sheet TANPA menutup sheet itu dulu. Begitu layar
baru itu di-pop (tombol back/close), sheet sebelumnya otomatis muncul
lagi persis seperti kondisi sebelum ditinggal — karena dia memang belum
pernah hilang dari stack, cuma ketutup visual sementara.

Referensi/contoh acuan yang sudah benar dari awal:
`lib/features/menu_shell/presentation/menu_grid_items.dart` — baca doc
comment `pushDestination`. Tiap tile menu manggil `AppNav.push` tanpa
nutup menu sheet-nya dulu; itu sebabnya swipe-up menu "balik lagi" ke
kondisi semula setelah user pencet back dari salah satu tile.

### Bug yang ditemukan & diperbaiki dalam audit ini
`CartDrawer` → tombol "Bayar" tadinya `Navigator.of(context).pop()`
(nutup CartDrawer) baru `showModalBottomSheet` untuk `PaymentModal` —
akibatnya kalau user pencet close di PaymentModal, dia balik ke Kasir
grid kosong, bukan ke CartDrawer dengan isi keranjang yang masih ada.
Sudah diperbaiki: sekarang `AppNav.showModal(context, builder: (_) =>
const PaymentModal())` dipanggil TANPA pop CartDrawer dulu (lihat
`cart_drawer.dart`, method `onCheckout`).

### Pengecualian yang disengaja (boleh pop dulu baru show)
`PaymentModal` → setelah transaksi SUKSES, kode sengaja
`Navigator.of(context).pop()` (nutup Payment) baru `AppNav.showModal`
untuk `ReceiptModal`. Ini BUKAN bug — setelah transaksi selesai, cart
sudah di-reset dan tidak ada state yang perlu di-"balikin". Struk adalah
akhir alur, bukan langkah bersarang di tengah alur. Kalau ada kasus serupa
di masa depan (sheet yang mewakili "aksi sudah selesai/final"), boleh
pakai pola pop-dulu ini, TAPI wajib ditulis sebagai comment di kode kenapa
itu pengecualian — supaya nggak disalahartikan sebagai bug oleh developer
berikutnya.

### CATATAN WAJIB untuk fitur baru
Setiap kali nambah fitur baru yang melibatkan sheet/modal yang bisa
membuka layar lain di dalamnya (form dengan tombol "pilih dari daftar"
yang bukanya full page, menu yang tiap tile-nya buka screen baru, dst),
WAJIB pakai `AppNav.push` dari dalam sheet tersebut, JANGAN pop sheet
dulu baru navigate — kecuali sheet itu memang mewakili aksi yang sudah
final/selesai (lihat pengecualian di atas), dan itu pun harus
didokumentasikan sebagai comment di kode. Kalau ragu, contoh acuannya ada
di `lib/features/menu_shell/presentation/menu_grid_items.dart`.

## 4. Ringkasan checklist sebelum bikin sheet/dialog/page baru

- [ ] Sudah tentuin ini Level 1/2/3/4 sesuai kriteria di atas?
- [ ] Level 1 → `showDialog` langsung.
- [ ] Level 2/3 → `AppNav.showModal`, bukan `showModalBottomSheet` manual.
- [ ] Level 4 → `AppNav.push`, bukan `Navigator.push` manual.
- [ ] Header sheet pakai `AppSheetHeader`? Header full page pakai
      `IosPageHeader`?
- [ ] Kalau dari dalam sheet ini bisa buka layar/sheet lain: apakah sheet
      ini harus tetap kebuka di belakang (kasus umum, pakai `AppNav.push`
      tanpa pop dulu), atau ini memang kasus "aksi final" yang boleh pop
      dulu (tulis comment kenapa)?
