# Standar Komponen Visual — Mamam Kasir

Dokumen ini adalah rujukan resmi untuk **bentuk, ukuran, dan gaya setiap
jenis komponen UI** di app ini: input field, tombol, icon button, PIN
pad, card, thumbnail produk, badge, tab, sheet, empty state, loading
indicator, snackbar, dialog konfirmasi, radius, spacing, dan tipografi.
Ditulis berdasarkan audit langsung ke kode yang ada (bukan disusun dari
nol) — jadi tiap aturan di bawah menunjuk masalah nyata yang ditemukan
di file asli, bukan asumsi.

**Alasan dokumen ini dibuat:** app ini sudah punya token (`AppColors`,
`AppSpacing`, `AppRadius`), tapi token itu **tidak dipatuhi secara
konsisten**. Setiap fitur ditambahkan oleh sesi/agent yang berbeda-beda,
dan masing-masing membuat keputusan bentuk sendiri — akibatnya search
bar di satu layar berbentuk pil penuh, di layar lain berbentuk kotak
rounded; sheet satu punya sudut atas 24, sheet lain punya sudut atas 28
hardcoded; ukuran font judul kartu berbeda-beda 13/13.5/14/14.5 padahal
menampilkan informasi yang setara. Dokumen ini menutup celah itu.

**Kalau kamu adalah agent/AI yang menerima prompt untuk menambah atau
mengedit UI di repo ini: baca dokumen ini DULU sebelum menulis satu
widget pun.** Jangan menciptakan pola baru untuk hal yang sudah ada
aturannya di sini. Kalau butuh komponen yang belum diatur di sini,
ikuti prinsip di bagian 8 (Cara Menambah Aturan Baru), jangan menebak
sendiri.

---

## 1. Token dasar (sudah ada, WAJIB dipakai — jangan hardcode angka)

Lokasi: `lib/core/theme/app_colors.dart`, `app_spacing.dart`, `app_theme.dart`.

- Warna → selalu `AppColors.xxx`. Jangan pernah menulis `Color(0xFF...)`
  langsung di file fitur. Kalau warna yang dibutuhkan belum ada di
  `AppColors`, tambahkan token baru di file itu — jangan inline.
- Spacing → selalu `AppSpacing.xs/sm/md/lg/xl/xxl` (4/8/12/16/20/24).
  Jangan menulis `EdgeInsets.all(10)` atau angka spacing lain di luar
  skala ini. Kalau kebutuhan benar-benar di antara dua step (jarang),
  itu justru sinyal untuk pakai step terdekat, bukan angka baru.
- Radius → selalu `AppRadius.sm/md/lg/xl/pill` (12/16/20/24/999). Ini
  yang paling sering dilanggar di codebase saat ini — lihat Bagian 2.

### Skala tipografi (BARU — belum ada sebelumnya, ditambahkan oleh audit ini)
Sebelum ini font size ditulis bebas (ditemukan: 9, 9.5, 10.5, 11.5, 13,
13.5, 14, 14.5, 15, 16, 16.5, 17, 18 dipakai bergantian untuk peran yang
sama). Mulai sekarang pakai skala tetap ini untuk teks di dalam
card/list/form (di luar judul halaman/sheet yang sudah diatur
`IosPageHeader`/`AppSheetHeader` di 20):

| Peran | Size | Weight |
|---|---|---|
| Label kecil / caption / timestamp | 11 | w500 |
| Body sekunder (subtitle, deskripsi) | 13 | w500 |
| Body utama (nama item, isi field) | 14 | w600–w700 |
| Judul kartu / angka penting | 15 | w800 |
| Badge/tag (huruf kecil semua) | 10, letterSpacing 0.2–0.3 | w800 |

Kalau nambah/edit teks di kartu, list item, atau form, cocokkan ke tabel
ini — jangan pilih angka baru karena "kelihatan pas" di satu layar.

---

## 2. Radius — aturan bentuk per jenis komponen (WAJIB)

Ini akar dari masalah "ada yang bulat, ada yang kotak". Setiap JENIS
komponen di bawah ini radiusnya **sudah ditentukan, tidak boleh
dipilih ulang** per fitur:

| Komponen | Radius wajib | Kenapa |
|---|---|---|
| Search bar / filter pill / chip pilihan | `AppRadius.pill` (bulat penuh) | Konsisten dengan search bar Kasir (`pos_screen.dart`), yang jadi acuan awal |
| Input field di dalam form (nama, harga, catatan) | `AppRadius.md` (16) | Beda dengan search bar — field form bukan pil, biar gak disangka tombol aksi |
| Card (transaksi, menu item, kartu ringkasan apa pun) | `AppRadius.lg` (20) | Sudah konsisten di 90% kartu yang ada — dijadikan standar resmi |
| Tombol utama full-width (CTA: Bayar, Simpan, dst) | `AppRadius.lg` (20) | Samakan dengan card, biar tombol besar terasa satu keluarga visual dengan kartu di sekitarnya |
| Tombol kecil / icon button kotak (bukan lingkaran) | `AppRadius.sm` (12) | Untuk badge status, tombol aksi kecil dalam kartu |
| Icon button bulat (close, back di header) | Circle penuh (`CircleBorder()`, BUKAN `AppRadius.pill` pada Container persegi) | Sudah benar di `AppSheetHeader` — pertahankan pola ini |
| Sheet / bottom modal (sudut atas) | `AppRadius.xl` (24) | **PELANGGARAN DITEMUKAN — lebih luas dari perkiraan awal, lihat Bagian 2a** |
| Badge/tag kecil (status, label) | `AppRadius.sm` (12) | Sudah konsisten di kartu transaksi — pertahankan |

### Larangan eksplisit
- Jangan pernah menulis `BorderRadius.circular(<angka>)` dengan angka
  literal. Kalau ada kebutuhan radius yang benar-benar baru dan tidak
  cocok satu pun kategori di atas, tambahkan constant baru bernama di
  `AppRadius`, jangan tulis angka mentah di file fitur.
- `cardTheme` di `app_theme.dart` baris 35 saat ini masih
  `BorderRadius.circular(20)` literal — harus diganti
  `BorderRadius.circular(AppRadius.lg)` supaya token tetap jadi satu
  sumber kebenaran meskipun nilainya kebetulan sama.

---

## 2a. Sheet / slide-up menu — audit detail (WAJIB dibaca, ini yang paling acak di codebase)

**Temuan audit lengkap sudut atas sheet** (dicek satu-satu ke semua
pemanggil `AppNav.showModal`/`showModalBottomSheet` di repo):

| File | Sudut atas ditulis sebagai | Status |
|---|---|---|
| `category_filter_sheet.dart` | `AppRadius.xl` (24) | ✅ Benar, jadi acuan |
| `hpp_tab_content.dart` (form tambah bahan) | `AppRadius.xl` (24) | ✅ Benar |
| `dashboard_screen.dart` (detail chart point) | `24` hardcoded | ⚠️ Nilai benar, tapi angka mentah bukan token |
| `sort_sheet.dart` | `28` hardcoded | ❌ Salah |
| `receipt_modal.dart` | `28` hardcoded | ❌ Salah |
| `variant_selection_modal.dart` | `28` hardcoded | ❌ Salah |
| `customer_picker_sheet.dart` | `28` hardcoded | ❌ Salah |
| `menu_bottom_sheet.dart` (swipe-up menu dashboard) | `32` hardcoded | ❌ Salah, paling jauh dari standar |

Jadi bukan cuma satu file nyimpang — **5 dari 8 sheet di app pakai
radius sudut atas yang salah**, dan nilainya sendiri tidak konsisten
satu sama lain (28 vs 32). **Standar resmi: `AppRadius.xl` (24) untuk
SEMUA sheet, tanpa kecuali**, termasuk swipe-up menu dashboard.

**Temuan audit drag handle** (garis kecil abu-abu di atas tiap sheet,
tanda bisa di-drag/swipe):

| File | Ukuran (lebar × tinggi) | Radius |
|---|---|---|
| `category_filter_sheet.dart` | 36 × 4 | `2` hardcoded |
| `sort_sheet.dart` | 48 × 5 | `AppRadius.pill` ✅ |
| `receipt_modal.dart` | 48 × 5 | `AppRadius.pill` ✅ |
| `menu_bottom_sheet.dart` (swipe-up) | 56 × 5 | `AppRadius.pill` ✅ |
| `variant_selection_modal.dart` | 56 × 5 | `AppRadius.pill` ✅ |

Tiga ukuran berbeda (36×4, 48×5, 56×5) untuk elemen yang seharusnya
identik di semua sheet. **Standar resmi: 48 × 5, radius `AppRadius.pill`,
warna `AppColors.border`, margin bawah `AppSpacing.md` sebelum judul.**
Dipilih 48×5 karena itu yang paling banyak dipakai (3 dari 5 file) dan
ukurannya pas — tidak terlalu kecil untuk kena tap/swipe, tidak terlalu
besar sampai makan tempat judul.

### Dua jenis sheet — beda isi, radius & handle-nya WAJIB tetap sama
Jangan bingung antara "sheet berat" dan "sheet ringan" dari sisi
radius/handle — keduanya pakai kulit luar yang **sama persis**. Yang
beda cuma tinggi awal dan cara isinya di-scroll:

- **Slide-up menu / grid besar** (contoh: `menu_bottom_sheet.dart` —
  swipe-up 9-menu dari Dashboard): tinggi mengikuti konten sampai
  maksimum `0.85` tinggi layar (`MediaQuery.of(context).size.height * 0.85`),
  isi dibungkus `Flexible` + `SingleChildScrollView` karena kontennya
  bisa lebih panjang dari layar. Dipicu dari swipe gesture ATAU tap
  pada trigger pill (lihat `swipe_up_trigger.dart`).
- **Filter/pilihan pendek** (contoh: `category_filter_sheet.dart`,
  `sort_sheet.dart`): tinggi mengikuti konten apa adanya
  (`mainAxisSize: MainAxisSize.min`, TANPA batas `0.85` dan tanpa
  `SingleChildScrollView` kalau daftar pilihannya pendek). Dipicu dari
  tap ikon filter/sort di toolbar, bukan swipe gesture.

Baik yang grid besar maupun yang daftar pendek WAJIB pakai radius
`AppRadius.xl` dan drag handle 48×5 yang sama — perbedaan tinggi/scroll
di atas tidak mengubah kulit luarnya.

### Judul sheet
`category_filter_sheet.dart` (fontSize 16, w800) dijadikan acuan.
Beberapa sheet lain (`sort_sheet.dart`, `menu_bottom_sheet.dart`) tidak
selalu menulis judul dengan style yang sama persis — samakan semua
judul sheet ke **16 / w800 / `AppColors.textPrimary`**, sejalan dengan
skala tipografi "Judul kartu" di Bagian 1 tapi 1px lebih besar karena
ini judul level-sheet, bukan judul di dalam kartu.

### Checklist migrasi sheet
- [ ] `sort_sheet.dart` → radius `28` jadi `AppRadius.xl`, handle `48×5` sudah benar (pertahankan)
- [ ] `receipt_modal.dart` → radius `28` jadi `AppRadius.xl`, handle `48×5` sudah benar
- [ ] `variant_selection_modal.dart` → radius `28` jadi `AppRadius.xl`, handle `56×5` diperkecil ke `48×5`
- [ ] `customer_picker_sheet.dart` → radius `28` jadi `AppRadius.xl` (dua tempat, baris 54 & 61)
- [ ] `menu_bottom_sheet.dart` (swipe-up dashboard) → radius `32` jadi `AppRadius.xl`, handle `56×5` diperkecil ke `48×5`
- [ ] `category_filter_sheet.dart` → handle diperbesar dari `36×4` ke `48×5`, radius handle dari `2` hardcoded ke `AppRadius.pill`
- [ ] `dashboard_screen.dart` (detail chart point) → radius `24` hardcoded jadi token `AppRadius.xl`
- [ ] Setelah semua di atas beres, pertimbangkan ekstrak kulit luar sheet
      (radius + handle + padding) jadi satu widget
      `lib/core/widgets/app_sheet_shell.dart`, supaya sheet baru di masa
      depan otomatis benar tanpa perlu mengingat angka-angka ini lagi —
      sama seperti `AppSheetHeader` menyelesaikan masalah title/tombol
      nabrak.

---

## 3. Input field / form (WAJIB pakai widget bersama — belum ada, harus dibuat)

**Temuan audit:** tidak ada satu pun widget input bersama. 12 file
berbeda (`pos_screen.dart`, `menu_management_screen.dart`,
`add_menu_item_modal.dart`, `cart_drawer.dart`, `customer_picker_sheet.dart`,
`payment_modal.dart`, dll) masing-masing menulis `InputDecoration(...)`
sendiri dengan hint font size, padding, dan border yang berbeda-beda.

### Aturan baru: buat `lib/core/widgets/app_text_field.dart`
Sebelum menambah `TextField`/`TextFormField` baru di mana pun, WAJIB
pakai (atau perluas) widget bersama ini. Spesifikasi:

- **Search bar** (dipakai di toolbar atas layar list): tanpa border
  visible sendiri, dibungkus `Container` luar dengan
  `AppRadius.pill` + `AppColors.background` sebagai fill. Hint style:
  size 14, `AppColors.textMuted`, w500. Ini pola `pos_screen.dart` —
  jadikan acuan, port ke `menu_management_screen.dart` dan
  `history_screen.dart` yang saat ini masih pakai radius `lg` untuk
  search bar mereka (salah kategori, harusnya pill karena ini search bar
  bukan form field biasa).
- **Form field** (dalam modal tambah/edit — nama produk, harga, qty,
  catatan): border `AppRadius.md`, fill `AppColors.surface`, border
  color `AppColors.border` saat idle, `AppColors.brand` saat focus.
  Label di atas field (bukan floating label bawaan Material).
  Hint/placeholder size 14, w500, `AppColors.textMuted`.
- Kedua varian menerima parameter `prefixIcon`, `suffixIcon`,
  `prefixText` (untuk field seperti harga dengan prefix "Rp") dari satu
  widget yang sama — jangan bikin dua widget terpisah tanpa hubungan.

### Checklist migrasi
- [ ] `pos_screen.dart` search bar → jadi referensi varian "search"
- [ ] `menu_management_screen.dart` search bar → radius diperbaiki dari
      `lg` ke `pill`, pindah ke `AppTextField.search(...)`
- [ ] `history_screen.dart`, `transaction_detail_screen.dart` search/filter
      field → audit ulang, pastikan pill kalau memang search bar
- [ ] Semua field di dalam modal (`add_menu_item_modal.dart`,
      `add_ingredient_modal.dart`, `payment_modal.dart`,
      `cart_drawer.dart`, `customer_picker_sheet.dart`,
      `hpp_tab_content.dart`, `opname_tab_content.dart`,
      `courier_outstanding_card.dart`) → pindah ke `AppTextField.form(...)`

---

## 4. Tombol (WAJIB pakai widget bersama — belum ada, harus dibuat)

**Temuan audit:** tidak ada class `AppButton`. Setiap layar menulis
`ElevatedButton(...)` + `ElevatedButton.styleFrom(...)` inline sendiri.
Radiusnya kebetulan sering `AppRadius.lg` (baik), tapi padding vertikal,
font weight teks tombol, dan warna disabled state tidak dijamin sama
karena ditulis ulang tiap kali.

### Aturan baru: buat `lib/core/widgets/app_button.dart`
Tiga varian tetap, tidak boleh nambah varian ad hoc:

| Varian | Pemakaian | Style |
|---|---|---|
| `AppButton.primary` | CTA utama (Bayar, Simpan, Konfirmasi) | Fill `AppColors.brand`, teks putih w800 size 15, radius `AppRadius.lg`, padding vertikal 15, disabled fill `AppColors.border` |
| `AppButton.secondary` | Aksi kedua di sebelah primary (Batal, dst) | Outline `AppColors.border`, teks `AppColors.textPrimary` w700, radius sama dengan primary |
| `AppButton.danger` | Hapus / aksi destruktif | Fill `AppColors.danger`, sisanya sama seperti primary |

Semua full-width secara default (`SizedBox(width: double.infinity)`
dibungkus di dalam widget, bukan diulang di tiap pemanggil).

### Checklist migrasi
- [ ] Tombol "Bayar" di `cart_drawer.dart` (baris ~688) → jadi acuan
      `AppButton.primary`
- [ ] Tombol di `pin_login_screen.dart`, `variant_selection_modal.dart`,
      `hpp_opname_header.dart`, `menu_management_header.dart` → audit
      style masing-masing, samakan ke tiga varian di atas

---

## 4a. Icon button bulat (filter, tambah +, close, dst) — WAJIB satu ukuran

**Temuan audit:** ada **7 class terpisah** untuk hal yang sama secara
visual (`Material` + `shape: CircleBorder()` + `InkWell`):
`_ToolCircleButton` (pos_screen), `_CircleIconButton` (muncul 4 kali
sendiri-sendiri: `menu_management_header`, `hpp_opname_header`,
`app_sheet_header`, `ios_page_header`), `_StepperButton` (cart_drawer),
`_CircleStepperButton` (variant_selection_modal), plus satu inline di
`report_type_picker_sheet.dart` yang tidak diberi nama class sama
sekali. Kabar baiknya: 5 dari 7 kebetulan sudah sama-sama 44×44 tanpa
koordinasi. Kabar buruknya: 2 titik nyimpang, dan definisinya dobel
7 kali padahal harusnya 1 widget dipakai ulang.

| Kategori | Ukuran wajib | Icon size | Kondisi sekarang |
|---|---|---|---|
| Icon button standar (filter, close, back, tambah +, titik tiga) | **44 × 44** | 18–22 (sesuaikan visual, default 20) | ✅ Sudah benar di `pos_screen.dart` (`_ToolCircleButton`, tombol close search), `menu_management_header.dart`, `hpp_opname_header.dart`, `app_sheet_header.dart`, `ios_page_header.dart` — 5 file sudah cocok |
| — | — | — | ❌ `report_type_picker_sheet.dart` pakai **36×36** untuk tombol close — harus diperbesar ke 44×44 |
| Stepper qty (+/− di keranjang & pilih varian) | **36 × 36** (ukuran baru, di antara 24 dan 40 yang ada sekarang) | 16 | ❌ `cart_drawer.dart` pakai **24×24** (kekecilan, susah di-tap) dan `variant_selection_modal.dart` pakai **40×40** — dua-duanya diseragamkan ke 36×36 |

Stepper qty sengaja dibuat kategori terpisah dari icon button standar
(36 vs 44) karena stepper selalu tampil berpasangan rapat (− angka +)
dalam satu baris sempit, jadi butuh sedikit lebih kecil dari icon
button mandiri — tapi ukurannya sendiri harus tetap satu angka, bukan
dua kayak sekarang (24 dan 40 sama-sama terlalu jauh dari titik tengah
yang nyaman di-tap).

### Aturan baru: buat `lib/core/widgets/app_icon_button.dart`
Satu widget dengan dua constructor/varian:
- `AppIconButton.standard(icon, onTap, {filled = false})` → 44×44,
  fill `AppColors.surface` (atau `AppColors.brand` kalau `filled:true`
  untuk state aktif seperti tombol filter yang lagi aktif)
- `AppIconButton.stepper(icon, onTap, {filled = false})` → 36×36, fill
  `AppColors.background` atau `AppColors.textPrimary` kalau `filled:true`
  (state tombol "+" yang ditonjolkan)

Ganti SEMUA 7 class yang disebut di atas jadi pemanggil widget ini,
jangan tinggalkan salah satu class lama "karena kebetulan ukurannya
udah bener" — tetap harus satu sumber kebenaran.

### Checklist migrasi
- [ ] `report_type_picker_sheet.dart` → tombol close `36×36` jadi `44×44` lewat `AppIconButton.standard`
- [ ] `cart_drawer.dart` `_StepperButton` → `24×24` jadi `36×36` lewat `AppIconButton.stepper`
- [ ] `variant_selection_modal.dart` `_CircleStepperButton` → `40×40` jadi `36×36` lewat `AppIconButton.stepper`
- [ ] 5 file yang sudah benar (44×44) → tetap migrasi ke `AppIconButton.standard` biar gak ada 7 class duplikat, meski nilainya udah cocok

---

## 4b. PIN pad (login pemilik/manajer & PIN karyawan)

**Kondisi saat ini:** baru ada satu implementasi PIN pad di codebase
Flutter ini, yaitu `pin_login_screen.dart` (dipakai untuk login
awal). PIN karyawan (per-shift/per-transaksi) belum dibangun di sini —
sesuai PRD, ini kemungkinan akan jadi screen terpisah nanti. Karena
belum ada yang kedua untuk dibandingkan, `pin_login_screen.dart`
dijadikan **standar resmi yang wajib ditiru persis** begitu PIN
karyawan mulai dibangun — jangan biarkan agent lain mendesain ulang
dari nol.

### Spesifikasi resmi (dari `pin_login_screen.dart`, `_KeypadButton`)
| Elemen | Nilai |
|---|---|
| Tombol angka (0–9) | 72 × 72, `CircleBorder`, transparan (tanpa fill/border terlihat) |
| Teks angka | fontSize 24, w700, `AppColors.textPrimary` |
| Tombol backspace | Sama 72×72, isi `Icon(Icons.backspace_outlined, size: 22)` |
| Sel kosong (pojok kiri-bawah keypad) | `SizedBox` 72×72 tanpa isi — menjaga grid 3 kolom tetap rapi |
| Jarak antar baris | `EdgeInsets.symmetric(vertical: 6)` |
| Susunan | 3 kolom × 4 baris: 1-2-3 / 4-5-6 / 7-8-9 / (kosong)-0-backspace |
| Indikator PIN terisi (dot) | 16×16 lingkaran, border 2px, warna terisi vs kosong beda opacity/warna |

### WAJIB untuk PIN karyawan (saat dibangun nanti)
Gunakan `_Keypad`/`_KeypadButton` dari `pin_login_screen.dart` apa
adanya (ekstrak jadi `lib/core/widgets/app_pin_keypad.dart` supaya bisa
dipakai dua screen) — JANGAN desain ulang ukuran tombol, font, atau
susunan grid dari nol untuk PIN karyawan. Bedanya cukup di judul/label
atas keypad dan logic setelah PIN benar (login penuh vs verifikasi
aksi cepat), bukan di bentuk keypad-nya.

### Checklist migrasi
- [ ] Ekstrak `_Keypad` + `_KeypadButton` dari `pin_login_screen.dart` → `lib/core/widgets/app_pin_keypad.dart`
- [ ] `pin_login_screen.dart` pakai widget hasil ekstrak (bukan lagi private class di file sendiri)
- [ ] Begitu PIN karyawan dibangun, WAJIB pakai `AppPinKeypad` yang sama — ukuran 72×72 tidak boleh diubah tanpa update dokumen ini dulu

---

## 5. Card (WAJIB konsolidasi — sudah 90% konsisten, tinggal disatukan)

**Temuan audit:** ada 9+ class card terpisah
(`transaction_card.dart`, `menu_item_card.dart`,
`variant_group_card.dart`, `payment_breakdown_card.dart`,
`courier_outstanding_card.dart`, `hero_sales_card.dart`, dll). Bentuk
luarnya (radius `lg`, fill `surface`, border tipis `AppColors.border`)
sudah hampir seragam — ini bagus, pertahankan — tapi detail di
dalamnya (ukuran font judul: 13 vs 14.5 vs 13.5 untuk peran yang sama)
berbeda-beda karena tiap card dibuat dari nol.

### Aturan baru
Card-card di atas **tidak perlu dihapus jadi satu widget** (isinya
memang beda-beda: transaksi vs menu vs varian punya layout dalam yang
berbeda) — tapi kulit luarnya WAJIB seragam:

- Fill `AppColors.surface`, radius `AppRadius.lg`, `border: Border.all(color: AppColors.border)`
- Padding dalam default `AppSpacing.md`
- Bikin satu wrapper tipis `lib/core/widgets/app_card_shell.dart` yang
  cuma mengurus 3 hal di atas (fill/radius/border/padding), lalu semua
  card yang ada dibungkus `AppCardShell` alih-alih menulis
  `Container(decoration: BoxDecoration(...))` sendiri-sendiri.
- Konten di dalam card (judul, subtitle, angka) WAJIB ikuti skala
  tipografi di Bagian 1 — ini yang menyeragamkan ukuran font 13/14.5/13.5
  yang sekarang berbeda-beda.

---

## 5a. Thumbnail produk (pengganti foto) — inisial, bukan icon generik

**Temuan audit — dua pendekatan berbeda untuk masalah yang sama** (produk
tanpa foto, yang saat ini adalah SEMUA produk karena app belum punya
fitur upload foto):

| File | Pendekatan sekarang | Masalah |
|---|---|---|
| `pos_screen.dart` (`_PlaceholderThumb`) | 4 bentuk geometris abstrak (segitiga, hati, lingkaran, kotak) warna abu-abu | Tidak menunjukkan info apa pun tentang produknya — kasir tidak terbantu membedakan produk lewat sekilas lihat |
| `menu_item_card.dart` (`_ItemThumbnail`) | 1 icon Material generik (`Icons.inventory_2_rounded`, kotak kardus) | Semua produk — ayam, minuman, nasi — punya thumbnail yang identik persis, nol pembeda visual |

Dua pendekatan ini juga terlihat sebagai bagian aplikasi yang berbeda
kalau dilihat berdampingan (grid Kasir vs grid Menu Management),
padahal keduanya menampilkan entitas yang sama persis (`MenuItem`).

### Standar baru: inisial dari nama produk, dalam bentuk avatar bulat/rounded
Ganti KEDUA pendekatan di atas dengan satu widget yang mengambil 1–2
huruf pertama dari tiap kata di nama produk (maksimal 2 huruf) sebagai
inisial, mirip avatar inisial pada aplikasi chat/kontak:

- "Ayam Geprek Sambal Matah" → **AG**
- "Es Teh Manis" → **ET**
- "Kerupuk" (satu kata) → **KE** (2 huruf pertama kata itu sendiri)

| Elemen | Spesifikasi |
|---|---|
| Bentuk | Mengikuti radius thumbnail yang sudah ada per konteks — `AppRadius.md` untuk thumbnail kotak (grid Kasir/Menu), lingkaran penuh kalau suatu saat dipakai di list sempit (bukan kotak seperti sekarang) |
| Warna latar | Dari palet warna deterministik berdasarkan huruf pertama nama produk (misal hash sederhana ke salah satu dari 6–8 warna lembut), BUKAN warna acak yang berubah tiap render, dan BUKAN satu warna abu-abu untuk semua produk — supaya tiap produk punya identitas warna yang konsisten dan produk-produk jadi mudah dibedakan sekilas lihat di grid |
| Warna teks inisial | Kontras terhadap warna latar (putih atau `AppColors.textPrimary`, dipilih otomatis dari kecerahan warna latar) |
| Font inisial | Sesuai ukuran container: fontSize proporsional (kira-kira 40% dari tinggi container), w800 |
| Kapan dipakai | Setiap kali `MenuItem` tidak punya foto — yaitu selalu, untuk saat ini, sampai fitur upload foto ada |

### Aturan baru: buat `lib/core/widgets/app_item_thumbnail.dart`
Satu widget `AppItemThumbnail(name: item.name, size: ..., radius: ...)`
yang:
1. Kalau nanti ada field foto di `MenuItem` dan terisi → render foto.
2. Kalau tidak ada foto (kondisi semua produk sekarang) → render avatar
   inisial sesuai spesifikasi di atas.

Dengan begitu, ketika fitur upload foto ditambahkan nanti, tidak perlu
mengubah pemanggil di `pos_screen.dart` maupun `menu_item_card.dart` —
cukup ubah 1 widget ini, fallback ke inisial otomatis jalan di semua
tempat yang sudah pakai `AppItemThumbnail`.

### Checklist migrasi
- [ ] Hapus `_PlaceholderThumb` (`pos_screen.dart`) dan `_TrianglePainter`
      — sudah tidak dipakai setelah pindah ke `AppItemThumbnail`
- [ ] Hapus `_ItemThumbnail` (`menu_item_card.dart`)
- [ ] `pos_screen.dart` `_MenuGridCard` → pakai `AppItemThumbnail(name: item.name, ...)`
- [ ] `menu_item_card.dart` (list layout & grid layout) → pakai `AppItemThumbnail(name: item.name, ...)`
- [ ] Pastikan ukuran (`size`) yang dipassing ke `AppItemThumbnail` tetap
      mengikuti ukuran thumbnail yang sudah ada per konteks (compact vs
      normal di Kasir; grid2/grid3/list di Menu Management) — yang
      berubah cuma ISI-nya (inisial vs bentuk geometris/icon), bukan
      ukuran kotaknya

---

## 6. Badge / status tag

Sudah cukup konsisten (`AppRadius.sm`, padding horizontal 8 vertikal 4,
font size 10, w800, letterSpacing 0.2–0.3, warna dari
`AppColors.success/danger/warning` dengan opacity 0.08–0.1 sebagai
background). **Jadikan resmi seperti ini, dan buat widget kecil
`AppStatusBadge(label, color)`** supaya pola padding/radius/opacity di
atas tidak diketik ulang manual di tiap tempat (ditemukan di
`transaction_card.dart` ditulis manual 2x untuk 2 status berbeda dalam
satu file yang sama — seharusnya satu widget dipanggil dua kali).

---

## 7. Sheet header & page header (SUDAH BENAR — contoh yang harus ditiru)

`lib/core/widgets/app_sheet_header.dart` dan `ios_page_header.dart`
adalah **contoh baik** bagaimana seharusnya sebuah shared widget dibuat
di repo ini: parameterized, ada doc comment yang jelas menjelaskan
alasan desainnya, dan dipakai ulang. Pola dokumentasi di
`AppSheetHeader` (kenapa dibuat, apa yang salah dari pendekatan lama,
instruksi eksplisit "jangan reimplement manual") adalah pola yang harus
ditiru untuk `AppTextField`, `AppButton`, dan `AppCardShell` yang
diminta di Bagian 3–5.

Catatan: masih ada 5 screen yang belum pakai widget ini
(`dompet_screen.dart`, `history_screen.dart`, `laporan_screen.dart`,
`pengaturan_screen.dart`, dan layar-layar di bawah `pos/`) — audit ulang
satu per satu, ganti header custom mereka ke `IosPageHeader` kalau itu
full-page, atau `AppSheetHeader` kalau itu sheet.

---

## 7a. Tab & segmented control — dua varian resmi (bukan pelanggaran, tapi WAJIB tetap dalam 2 bentuk ini saja)

**Temuan audit:** ada 2 pola tab yang sudah dipakai dengan benar untuk
kebutuhan berbeda — ini BUKAN masalah, tapi harus didokumentasikan
resmi supaya agent lain tidak membuat pola ketiga untuk kasus yang
sebetulnya sudah tercakup salah satu dari dua ini.

| Varian | File acuan | Kapan dipakai | Ciri |
|---|---|---|---|
| `DateFilterTabs` (chip individual) | `history_screen` → `date_filter_tabs.dart` | Opsi banyak (4+), tidak harus muat semua di layar, boleh scroll horizontal | Tiap opsi chip terpisah, height 36, `AppRadius.pill`, fill `AppColors.textPrimary` saat aktif |
| `SlidingPillTabs` (kapsul meluncur) | `hpp_opname` → `sliding_pill_tabs.dart`, dipakai 3× di fitur yang sama | Opsi terbatas (2–3), semua harus muat sejajar, full-width | Satu kapsul solid `AnimatedPositioned` meluncur di antara opsi, opsi lebar sama rata |

**Aturan:** kalau butuh tab baru, pilih salah satu dari dua di atas
berdasarkan jumlah opsi — JANGAN bikin `_TabButton`/`_CategoryTab` versi
ketiga. `DateFilterTabs` masih private ke fitur History; kalau dipakai
di luar History, ekstrak ke `lib/core/widgets/app_filter_chips.dart`
dulu (sama seperti `SlidingPillTabs` yang sudah jadi shared widget).

Catatan terpisah: dropdown toggle di `menu_management_header.dart`
(klik judul → overlay pilihan tab muncul di bawahnya) adalah elemen
navigasi ketiga yang berbeda lagi (bukan tab horizontal) — ini valid
untuk kasus spesifik "ganti antara 2 sub-halaman dari header", tapi
jangan disamakan dengan dua varian tab di atas.

---

## 7b. Empty state ("belum ada data") — WAJIB pakai bentuk lengkap

**Temuan audit — 3 tingkat kelengkapan berbeda untuk hal yang sama:**

| File | Bentuk | Kualitas |
|---|---|---|
| `history_screen.dart` (`_EmptyState`) | Icon 48px abu-abu + judul bold 14 + subtitle 12 | ✅ Paling lengkap — jadi acuan resmi |
| `menu_management_screen.dart` (`_EmptyState`) | Teks polos 13, tanpa icon | ⚠️ Kurang lengkap |
| `dompet_screen.dart`, `laporan_screen.dart`, `opname_tab_content.dart` | `Text` inline langsung di tempat, tanpa class terpisah, font size beda-beda (12.5 vs 13) | ❌ Paling minim, tidak reusable |

### Aturan baru: buat `lib/core/widgets/app_empty_state.dart`
Satu widget `AppEmptyState({icon, title, subtitle})`, isi sesuai pola
`history_screen.dart`:
- Icon 48, `AppColors.border`
- Judul: 14 / w700 / `AppColors.textSecondary`
- Subtitle (opsional): 12 / w500 / `AppColors.textMuted`
- Dibungkus `Center` + `Column(mainAxisSize: MainAxisSize.min)`

Icon berbeda per konteks (boleh berbeda — ini bagian dari personalisasi
yang wajar, bukan pelanggaran): `Icons.receipt_long_rounded` untuk
riwayat transaksi kosong, dst — yang WAJIB seragam adalah ukuran icon,
struktur judul+subtitle, dan skala fontnya, bukan pilihan icon-nya.

### Checklist migrasi
- [ ] `menu_management_screen.dart` `_EmptyState` → tambah icon 48px, samakan ke `AppEmptyState`
- [ ] `dompet_screen.dart` → ganti `Text('Belum ada aktivitas.')` inline jadi `AppEmptyState`
- [ ] `laporan_screen.dart` → ganti `Text('Belum ada transaksi/pengeluaran bulan ini.')` jadi `AppEmptyState`
- [ ] `opname_tab_content.dart` → ganti `Text('Belum ada sesi opname.')` jadi `AppEmptyState`

---

## 7c. Loading indicator — WAJIB satu warna

**Temuan audit:** 7 dari 9 titik `CircularProgressIndicator` full-screen
sudah pakai `AppColors.brand` — sudah hampir seragam. Dua penyimpangan:

| File | Warna dipakai | Seharusnya |
|---|---|---|
| `hpp_opname_screen.dart` | `AppColors.tileHpp` | `AppColors.brand` |
| `laporan_screen.dart` | `accentColor` (variabel dinamis, ikut warna tab aktif) | `AppColors.brand` |

Loading indicator di dalam tombol (mis. tombol "Bayar" saat proses,
`payment_modal.dart`, `add_menu_item_modal.dart`) boleh tetap putih —
itu kategori berbeda (loading di atas tombol berwarna, bukan loading
full-screen), sudah benar sebagaimana adanya.

### Aturan
- Loading full-screen (Center di tengah layar, menggantikan seluruh
  konten): selalu `CircularProgressIndicator(color: AppColors.brand)`,
  tanpa kecuali, termasuk di layar dengan tema warna aksen berbeda
  seperti HPP atau Laporan.
- Loading di dalam tombol/komponen kecil: `Colors.white` (di atas fill
  berwarna) dengan `strokeWidth: 2` sampai `2.4`.

### Checklist migrasi
- [ ] `hpp_opname_screen.dart` → warna loading jadi `AppColors.brand`
- [ ] `laporan_screen.dart` → warna loading jadi `AppColors.brand` (lepas dari `accentColor`)

---

## 7d. Snackbar / pesan error & sukses

**Temuan audit:** 3 file (`history_screen.dart`, `menu_management_screen.dart`,
`dompet_screen.dart`) konsisten: `SnackBar` dengan
`backgroundColor: AppColors.danger` untuk pesan error. Ini bagus,
jadikan standar. Satu penyimpangan:

- `opname_tab_content.dart` menampilkan snackbar untuk DUA skenario
  (sukses simpan ATAU error) di satu `SnackBar` yang sama, **tanpa**
  `backgroundColor` sama sekali — jadi baik sukses maupun error
  tampil dengan warna default abu-abu Material, tidak ada pembeda
  visual antara "berhasil" dan "gagal".

### Aturan
| Skenario | `backgroundColor` |
|---|---|
| Error / gagal | `AppColors.danger` |
| Sukses / berhasil | `AppColors.success` |
| Informasi netral (jarang dipakai) | Default (tanpa `backgroundColor`) |

Selalu set `backgroundColor` eksplisit untuk sukses dan error — jangan
biarkan default abu-abu dipakai untuk pesan yang sebetulnya
menandakan hasil aksi (berhasil/gagal).

### Checklist migrasi
- [ ] `opname_tab_content.dart` → pisahkan jadi dua `SnackBar` sesuai hasil aksi: `AppColors.success` kalau `error == null`, `AppColors.danger` kalau ada `error`

---

## 7e. Switch, checkbox & radio-like selector (SUDAH BENAR — dokumentasikan sebagai standar resmi)

**Temuan audit:** tiga pola berikut sudah konsisten tanpa pelanggaran
berarti — dicatat di sini supaya tetap dipertahankan, bukan
"ditemukan ulang" beda cara oleh agent lain nanti:

- **Switch on/off** (Cetak Struk Otomatis, Open Bill, Split Payment):
  selalu `Switch` bawaan Flutter, `activeColor: AppColors.brand`. Jangan
  bikin custom toggle switch.
- **Checkbox multi-select** (pilih varian/tambahan di
  `add_menu_item_modal.dart`): `Checkbox` bawaan,
  `activeColor: AppColors.brand`,
  `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))`,
  `materialTapTargetSize: MaterialTapTargetSize.shrinkWrap`.
- **Pilihan tunggal ala-radio untuk metode pembayaran**
  (`payment_modal.dart`): BUKAN `Radio` bawaan Flutter, tapi baris
  tappable dengan `Icon(Icons.radio_button_checked_rounded)` saat
  terpilih vs `Icons.chevron_right_rounded` saat belum — ini pola yang
  disengaja untuk daftar pilihan yang juga bisa di-tap untuk membuka
  detail, bukan penyimpangan dari `Radio` bawaan. Pertahankan pola ini
  khusus untuk kasus "pilihan + kemungkinan buka detail"; untuk pilihan
  sederhana tanpa detail tambahan, `Radio` bawaan tetap jadi default.

---

## 7f. Dialog konfirmasi (AlertDialog) — isinya sudah rapi, kulit luarnya belum ditentukan

**Temuan audit:** 3 titik pemakaian `AlertDialog` (`pengaturan_screen.dart`
untuk konfirmasi logout, `transaction_detail_screen.dart` untuk batalkan
transaksi, `courier_outstanding_card.dart` untuk konfirmasi kasbon/setor)
sudah konsisten dari sisi struktur: `AlertDialog` bawaan Flutter,
`TextButton` untuk aksi, teks aksi destruktif diwarnai `AppColors.danger`.
Ini bagus — **jangan diubah strukturnya**.

Yang belum diatur: **tidak ada `dialogTheme` di `app_theme.dart`**, jadi
`AlertDialog` di seluruh app memakai radius default Material (biasanya
28, jauh lebih bulat dari radius card/sheet app ini yang 20/24) —
sehingga dialog terlihat seperti berasal dari komponen visual yang
berbeda dari card dan sheet di sekitarnya.

### Aturan baru
Tambahkan `dialogTheme` di `app_theme.dart`:
- `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg))` (20, samakan dengan card)
- `backgroundColor: AppColors.surface`
- Judul (`title`): 16 / w800 — konsisten dengan judul sheet di Bagian 2a
- Isi (`content`) teks: 13 / w500 / `AppColors.textSecondary` (saat ini
  ditulis 13 langsung di tiap pemanggil — sudah pas, tinggal jadikan
  default di `dialogTheme` supaya tidak perlu diulang tiap kali)

Karena ini diatur di level `ThemeData` (bukan widget terpisah), ketiga
titik pemakaian `AlertDialog` yang sudah ada otomatis ikut berubah
tanpa perlu diedit satu-satu — cukup tambahkan `dialogTheme` sekali di
`app_theme.dart`.

### Checklist migrasi
- [ ] Tambahkan `dialogTheme` di `app_theme.dart` sesuai spesifikasi di atas
- [ ] Verifikasi 3 dialog yang ada (`pengaturan_screen.dart`, `transaction_detail_screen.dart`, `courier_outstanding_card.dart` — 2 dialog di file ini) tampil dengan radius baru tanpa perlu diedit manual

---

## 7g. Divider (garis pemisah)

**Temuan audit:** 7 dari 12 titik `Divider()` polos tanpa `color:` —
otomatis memakai abu-abu default Material, bukan `AppColors.border`
yang dipakai 3 titik lain (`menu_bottom_sheet.dart`, `hpp_tab_content.dart`,
dan idealnya semua). `_DashedDivider` di `receipt_modal.dart` (4 titik)
adalah kategori terpisah yang sengaja (garis putus-putus meniru struk
kertas asli) — pertahankan, bukan pelanggaran.

Lebih baik lagi: atur `dividerTheme` di `app_theme.dart`
(`color: AppColors.border, thickness: 1, space: 1`) supaya
`const Divider()` polos di mana pun otomatis benar tanpa perlu
mengetik `color:` setiap kali — sama seperti solusi `dialogTheme` di 7f.

### Checklist migrasi
- [ ] Tambahkan `dividerTheme` di `app_theme.dart`
- [ ] Verifikasi `transaction_detail_screen.dart` (3×), `cart_drawer.dart`,
      `customer_picker_sheet.dart`, `variant_selection_modal.dart` ikut
      berubah otomatis jadi `AppColors.border`

---

## 8. Cara menambah aturan baru (kalau ada komponen yang belum diatur di sini)

1. Cek dulu apakah pola serupa sudah ada di kode (search dulu, jangan
   asumsi kosong).
2. Kalau ada 2+ implementasi berbeda untuk hal yang sama, pilih satu
   sebagai standar (biasanya yang paling banyak dipakai atau paling
   sesuai token yang ada), lalu tulis alasannya di sini — ikuti format
   "Temuan audit" di atas.
3. Kalau itu benar-benar komponen baru yang belum pernah ada, desain
   sesuai token di Bagian 1 (jangan pilih angka baru di luar skala
   spacing/radius/tipografi yang sudah ada), lalu tambahkan section
   baru di dokumen ini SEBELUM menulis kodenya.
4. Update checklist migrasi terkait kalau perubahan ini menggantikan
   pola lama.

---

## 9. Checklist sebelum menempel kode dari agent lain ke agent utama

Pakai daftar ini setiap kali ada potongan kode/prompt hasil dari sesi
lain yang mau digabung ke repo:

- [ ] Semua radius pakai `AppRadius.*`? Tidak ada `BorderRadius.circular(<angka>)` literal?
- [ ] Semua spacing/padding pakai `AppSpacing.*`? Tidak ada `EdgeInsets` dengan angka mentah?
- [ ] Semua warna pakai `AppColors.*`? Tidak ada `Color(0xFF...)` inline?
- [ ] Font size teks di dalam card/list/form cocok dengan skala di Bagian 1?
- [ ] Input field baru pakai `AppTextField` (search → pill, form → md), bukan `InputDecoration` inline baru?
- [ ] Tombol baru pakai `AppButton.primary/secondary/danger`, bukan `ElevatedButton` inline baru?
- [ ] Card baru dibungkus `AppCardShell` untuk kulit luarnya?
- [ ] Header sheet/page baru pakai `AppSheetHeader`/`IosPageHeader`, bukan `Stack`+`Center`+`Align` manual?
- [ ] Sheet/slide-up baru: sudut atas `AppRadius.xl`, drag handle 48×5 `AppRadius.pill`, judul 16/w800? (lihat Bagian 2a — jangan pilih angka sendiri)
- [ ] Icon button bulat baru pakai `AppIconButton.standard` (44×44) atau `.stepper` (36×36), bukan `Material`+`CircleBorder` inline baru? (lihat Bagian 4a)
- [ ] Kalau nambah PIN pad baru (mis. PIN karyawan): pakai `AppPinKeypad` yang sama persis dengan `pin_login_screen.dart` (72×72), bukan desain ulang? (lihat Bagian 4b)
- [ ] Thumbnail produk baru pakai `AppItemThumbnail` (inisial dari nama), bukan icon generik atau bentuk geometris baru? (lihat Bagian 5a)
- [ ] Tab/segmented control baru pakai `DateFilterTabs` (chip, opsi banyak) atau `SlidingPillTabs` (kapsul, opsi 2–3), bukan pola ketiga? (lihat Bagian 7a)
- [ ] Empty state baru pakai `AppEmptyState` (icon 48 + judul + subtitle), bukan `Text` polos? (lihat Bagian 7b)
- [ ] Loading full-screen baru pakai `AppColors.brand`, bukan warna aksen fitur? (lihat Bagian 7c)
- [ ] Snackbar sukses/error baru set `backgroundColor` eksplisit (`AppColors.success`/`AppColors.danger`), bukan dibiarkan default? (lihat Bagian 7d)
- [ ] Dialog konfirmasi baru pakai `AlertDialog` bawaan (bukan custom dialog widget baru) — radius otomatis ikut `dialogTheme`? (lihat Bagian 7f)
- [ ] Divider baru tidak perlu set `color:` manual kalau `dividerTheme` sudah ditambahkan — kalau belum, WAJIB `color: AppColors.border`? (lihat Bagian 7g)
- [ ] Kalau nemuin pola yang belum diatur di sini: sudah ikuti Bagian 8, bukan menebak sendiri?

Kalau salah satu kotak di atas tidak tercentang, JANGAN gabungkan kode
itu dulu — perbaiki supaya sesuai dokumen ini, baru tempel.
