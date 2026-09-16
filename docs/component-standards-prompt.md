# Standar Komponen Visual — Mamam Kasir (Acuan untuk Agent/AI)

Ini adalah standar RESMI dan FINAL untuk bentuk, ukuran, dan gaya
komponen UI di app Mamam Kasir (Flutter). Ikuti persis seperti yang
tertulis — ini bukan usulan atau opsi, ini keputusan yang sudah dikunci.

**Sebelum menulis widget UI apa pun, cocokkan dulu ke dokumen ini.**
Kalau kebutuhanmu belum tercakup di sini, ikuti prinsip di Bagian 9,
jangan menciptakan pola baru sendiri.

---

## 1. Token dasar

Lokasi: `lib/core/theme/app_colors.dart`, `app_spacing.dart`, `app_theme.dart`.

- Warna → selalu `AppColors.xxx`. Jangan tulis `Color(0xFF...)` inline.
  Kalau warna belum ada di `AppColors`, tambahkan token baru di sana.
- Spacing → selalu `AppSpacing.xs/sm/md/lg/xl/xxl` (4/8/12/16/20/24).
  Jangan pakai `EdgeInsets` dengan angka di luar skala ini.
- Radius → selalu `AppRadius.sm/md/lg/xl/pill` (12/16/20/24/999). Jangan
  pernah menulis `BorderRadius.circular(<angka>)` literal.

### Skala tipografi
Untuk teks di dalam card/list/form (di luar judul halaman/sheet, lihat
Bagian 6):

| Peran | Size | Weight |
|---|---|---|
| Label kecil / caption / timestamp | 11 | w500 |
| Body sekunder (subtitle, deskripsi) | 13 | w500 |
| Body utama (nama item, isi field) | 14 | w600–w700 |
| Judul kartu / angka penting | 15 | w800 |
| Badge/tag (huruf kecil semua) | 10, letterSpacing 0.2–0.3 | w800 |

---

## 2. Radius per jenis komponen

| Komponen | Radius wajib |
|---|---|
| Search bar / filter pill / chip pilihan | `AppRadius.pill` |
| Input field form (nama, harga, catatan) | `AppRadius.md` (16) |
| Card apa pun | `AppRadius.lg` (20) |
| Tombol utama full-width (CTA) | `AppRadius.lg` (20) |
| Badge/tag kecil | `AppRadius.sm` (12) |
| Icon button bulat (close, back, filter) | `CircleBorder()` penuh |
| Sheet / bottom modal (sudut atas) | `AppRadius.xl` (24) |
| Dialog konfirmasi (AlertDialog) | `AppRadius.lg` (20) via `dialogTheme` |

---

## 3. Sheet / slide-up menu

- Sudut atas: **selalu `AppRadius.xl` (24)** — sheet berat (slide-up
  menu, tinggi sampai 0.85 layar + scroll) maupun sheet ringan
  (filter/pilihan pendek, tinggi mengikuti konten) pakai radius yang
  sama. Yang beda cuma tinggi & scroll behavior, bukan kulit luarnya.
- Drag handle: **selalu 48 × 5**, `AppRadius.pill`, warna
  `AppColors.border`, margin bawah `AppSpacing.md` sebelum judul.
- Judul sheet: **16 / w800 / `AppColors.textPrimary`**.

---

## 4. Input field / form

Gunakan (atau perluas) `lib/core/widgets/app_text_field.dart` — jangan
tulis `InputDecoration` inline baru.

- **Search bar**: tanpa border visible, dibungkus `Container` dengan
  `AppRadius.pill` + fill `AppColors.background`. Hint: 14/w500/`AppColors.textMuted`.
- **Form field**: border `AppRadius.md`, fill `AppColors.surface`,
  border `AppColors.border` (idle) → `AppColors.brand` (focus). Label
  di atas field (bukan floating label). Hint 14/w500/`AppColors.textMuted`.
- Satu widget dengan parameter `prefixIcon`/`suffixIcon`/`prefixText`,
  bukan dua widget terpisah.

---

## 5. Tombol

Gunakan `lib/core/widgets/app_button.dart` — tiga varian tetap, jangan
tambah varian ad hoc:

| Varian | Pemakaian | Style |
|---|---|---|
| `AppButton.primary` | CTA utama (Bayar, Simpan, Konfirmasi) | Fill `AppColors.brand`, teks putih w800/15, radius `AppRadius.lg`, padding vertikal 15 |
| `AppButton.secondary` | Aksi kedua (Batal, dst) | Outline `AppColors.border`, teks `AppColors.textPrimary` w700 |
| `AppButton.danger` | Hapus / aksi destruktif | Fill `AppColors.danger` |

Semua full-width secara default.

---

## 6. Icon button bulat

Gunakan `lib/core/widgets/app_icon_button.dart`:

| Varian | Ukuran | Icon size | Pemakaian |
|---|---|---|---|
| `AppIconButton.standard` | 44 × 44 | 18–22 (default 20) | Filter, close, back, tambah +, titik tiga |
| `AppIconButton.stepper` | 36 × 36 | 16 | Qty +/− di keranjang, pilih varian |

---

## 7. PIN pad

Gunakan `lib/core/widgets/app_pin_keypad.dart` untuk SEMUA layar PIN
(login pemilik/manajer, PIN karyawan, verifikasi aksi cepat) — jangan
desain ulang dari nol:

- Tombol angka (0–9) & backspace: **72 × 72**, `CircleBorder`, transparan.
- Teks angka: 24/w700/`AppColors.textPrimary`.
- Susunan 3 kolom × 4 baris: 1-2-3 / 4-5-6 / 7-8-9 / (kosong)-0-backspace.
- Jarak antar baris: `EdgeInsets.symmetric(vertical: 6)`.
- Indikator PIN terisi: dot 16×16, border 2px.

---

## 8. Card

- Kulit luar SELALU: fill `AppColors.surface`, radius `AppRadius.lg`,
  `border: Border.all(color: AppColors.border)`, padding dalam `AppSpacing.md`.
- Bungkus dengan `lib/core/widgets/app_card_shell.dart` — jangan tulis
  `Container(decoration: BoxDecoration(...))` sendiri.
- Isi konten (judul, subtitle, angka) ikuti skala tipografi Bagian 1.

---

## 9. Thumbnail produk (pengganti foto)

Gunakan `lib/core/widgets/app_item_thumbnail.dart`:

- Kalau `MenuItem` punya foto → render foto.
- Kalau tidak ada foto (kondisi default) → render **avatar inisial**:
  ambil 1 huruf pertama dari maksimal 2 kata pertama nama produk
  ("Ayam Geprek" → **AG**, "Es Teh Manis" → **ET**, "Kerupuk" → **KE**).
- Warna latar: deterministik dari huruf pertama nama (hash ke salah
  satu dari 6–8 warna lembut) — BUKAN abu-abu seragam, BUKAN acak
  berubah tiap render.
- Teks inisial: kontras terhadap latar, w800, ~40% tinggi container.
- Radius mengikuti radius thumbnail yang berlaku di konteksnya
  (`AppRadius.md` untuk grid Kasir/Menu).

---

## 10. Badge / status tag

Gunakan `AppStatusBadge(label, color)`:
- `AppRadius.sm`, padding horizontal 8 / vertikal 4
- Font 10/w800, letterSpacing 0.2–0.3
- Warna dari `AppColors.success/danger/warning` dengan opacity 0.08–0.1 sebagai background

---

## 11. Header (sheet & halaman)

Gunakan `AppSheetHeader` (untuk sheet) atau `IosPageHeader` (untuk
halaman penuh) dari `lib/core/widgets/` — JANGAN reimplement manual
dengan `Stack`+`Center`+`Align`.

---

## 12. Tab & segmented control

Dua varian resmi, pilih salah satu berdasarkan kebutuhan — jangan buat
pola ketiga:

| Varian | Kapan dipakai | Ciri |
|---|---|---|
| `DateFilterTabs` (chip individual) | Opsi banyak (4+), boleh scroll horizontal | Chip terpisah, height 36, `AppRadius.pill`, fill `AppColors.textPrimary` saat aktif |
| `SlidingPillTabs` (kapsul meluncur) | Opsi terbatas (2–3), harus muat sejajar, full-width | Kapsul solid meluncur (`AnimatedPositioned`), lebar opsi sama rata |

---

## 13. Empty state ("belum ada data")

Gunakan `lib/core/widgets/app_empty_state.dart` — `AppEmptyState({icon, title, subtitle})`:
- Icon 48, `AppColors.border`
- Judul: 14/w700/`AppColors.textSecondary`
- Subtitle (opsional): 12/w500/`AppColors.textMuted`
- Icon boleh beda per konteks; struktur & skala font harus sama.

---

## 14. Loading indicator

- Loading full-screen (menggantikan seluruh konten layar): selalu
  `CircularProgressIndicator(color: AppColors.brand)` — termasuk di
  layar dengan tema warna aksen berbeda.
- Loading di dalam tombol/komponen kecil: `Colors.white`, `strokeWidth: 2`–`2.4`.

---

## 15. Snackbar

Selalu set `backgroundColor` eksplisit sesuai hasil aksi:

| Skenario | `backgroundColor` |
|---|---|
| Error / gagal | `AppColors.danger` |
| Sukses / berhasil | `AppColors.success` |
| Informasi netral (jarang) | Default (tanpa `backgroundColor`) |

---

## 16. Dialog konfirmasi

`AlertDialog` bawaan Flutter tetap dipakai (jangan bikin custom dialog
widget baru). Struktur: `TextButton` untuk aksi, teks aksi destruktif
`AppColors.danger`. Radius (20), warna latar, dan style judul/isi
diatur via `dialogTheme` di `app_theme.dart` — bukan diulang manual
tiap pemanggilan.

---

## 17. Divider

`const Divider()` polos, warna diatur via `dividerTheme` di
`app_theme.dart` (`AppColors.border`) — jangan set `color:` manual
tiap kali kecuali `dividerTheme` belum ada.

Pengecualian: garis putus-putus di struk (`_DashedDivider`) adalah
kategori terpisah yang sengaja meniru struk kertas — pertahankan.

---

## 18. Switch, checkbox & radio-like selector

- **Switch on/off**: `Switch` bawaan Flutter, `activeColor: AppColors.brand`. Jangan bikin custom toggle.
- **Checkbox multi-select**: `Checkbox` bawaan, `activeColor: AppColors.brand`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))`.
- **Pilihan tunggal + detail** (mis. metode pembayaran): baris tappable dengan `Icon(Icons.radio_button_checked_rounded)` saat terpilih vs `Icons.chevron_right_rounded` saat belum — dipakai khusus kalau pilihan itu juga bisa dibuka detailnya. Untuk pilihan sederhana tanpa detail, `Radio` bawaan tetap default.

---

## 19. Cara menambah aturan baru

1. Cek dulu apakah ada widget/pola serupa di `lib/core/widgets/` sebelum bikin baru.
2. Kalau komponen benar-benar baru, desain sesuai token di Bagian 1
   (jangan pilih angka baru di luar skala spacing/radius/tipografi
   yang sudah ada).
3. Kalau ragu kategori mana yang berlaku, tanyakan ke pemilik project
   dulu sebelum menulis kode — jangan menebak.

---

## Checklist wajib sebelum submit kode UI

- [ ] Semua radius pakai `AppRadius.*`? Tidak ada `BorderRadius.circular(<angka>)` literal?
- [ ] Semua spacing/padding pakai `AppSpacing.*`?
- [ ] Semua warna pakai `AppColors.*`? Tidak ada `Color(0xFF...)` inline?
- [ ] Font size teks di card/list/form cocok skala Bagian 1?
- [ ] Input field baru pakai `AppTextField` (search → pill, form → md)?
- [ ] Tombol baru pakai `AppButton.primary/secondary/danger`?
- [ ] Icon button bulat baru pakai `AppIconButton.standard` (44×44) atau `.stepper` (36×36)?
- [ ] PIN pad baru (kalau ada) pakai `AppPinKeypad`, ukuran 72×72, tidak didesain ulang?
- [ ] Card baru dibungkus `AppCardShell`?
- [ ] Thumbnail produk baru pakai `AppItemThumbnail` (inisial), bukan icon/bentuk generik?
- [ ] Header sheet/halaman baru pakai `AppSheetHeader`/`IosPageHeader`?
- [ ] Sheet/slide-up baru: radius `AppRadius.xl`, handle 48×5, judul 16/w800?
- [ ] Tab baru pakai `DateFilterTabs` atau `SlidingPillTabs`, bukan pola ketiga?
- [ ] Empty state baru pakai `AppEmptyState`?
- [ ] Loading full-screen pakai `AppColors.brand`?
- [ ] Snackbar set `backgroundColor` eksplisit sesuai hasil aksi?
- [ ] Dialog konfirmasi pakai `AlertDialog` bawaan (ikut `dialogTheme`)?
- [ ] Divider tidak set `color:` manual (ikut `dividerTheme`)?

**Kalau salah satu kotak tidak tercentang, perbaiki dulu sebelum kode digabungkan ke repo utama.**
