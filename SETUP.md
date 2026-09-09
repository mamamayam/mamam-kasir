# Setup — baca ini dulu sebelum build

File-file di `lib/` dan `pubspec.yaml` ini ditulis manual (tanpa Flutter SDK
tersedia di sandbox tempat saya kerja), jadi **belum di-compile-check**.
Sebelum jadi app yang bisa jalan, ada beberapa langkah wajib di sisi kamu:

## 1. Generate platform folders

Project ini baru berisi `lib/` + `pubspec.yaml` — belum ada folder
`android/`, `ios/`, dll. Di root project, jalankan:

```
flutter create --org com.mamamayam --project-name mamam_kasir .
```

Ini akan generate platform folders TANPA menimpa `lib/` dan `pubspec.yaml`
yang sudah ada (flutter create aman dijalankan di folder yang sudah punya
`lib/`, hanya akan skip file yang sudah ada — tapi **backup dulu** kalau
ragu).

## 2. Install dependencies

```
flutter pub get
```

## 3. Analyze & fix

```
flutter analyze
```

Karena saya nggak bisa compile-check di sandbox, kemungkinan ada
typo/import kecil yang baru ketahuan di sini. Semua import relatif sudah
saya verifikasi manual resolve ke file yang benar, dan brace/paren sudah
saya cek seimbang — tapi verifikasi Dart-level (tipe, null-safety, dll)
belum jalan.

## 4. Cek versi Flutter SDK kamu

Saya pakai `Color.withValues(alpha: ...)` (API modern, gantiin
`withOpacity` yang deprecated) — ini butuh **Flutter 3.27+**. Kalau
versi kamu lebih lama, ganti semua `withValues(alpha: x)` jadi
`withOpacity(x)` (ada 7 pemakaian, semua di file dashboard/theme).

## 5. Yang sengaja belum saya isi

- `Supabase.initialize(...)` dan encrypted-DB bootstrap di `main.dart`
  (dikomentari, nunggu fase backend/local-db)
- PIN verification di `PinAuthController._verify()` masih hardcoded
  `'0000'` sebagai demo — bukan verifikasi asli
- Semua tap target di 3x3 menu grid & quick actions cuma `Navigator.pop()`
  atau kosong — belum di-route ke screen fitur (sesuai instruksi: shell
  dulu, fitur nanti)

## Struktur folder

```
lib/
  app/                     — root MaterialApp
  core/
    theme/                 — design tokens (colors, spacing, ThemeData)
    utils/                 — currency formatter, dst.
    widgets/                — (kosong, siap diisi shared widgets)
  features/
    auth/                  — splash, PIN login
    dashboard/             — dashboard screen + widgets + provider
    menu_shell/             — swipe-up bottom sheet, 3x3 grid, trigger
```

Struktur ini ngikutin layer di `docs/02_ARCHITECTURE.md`
(Presentation → Application → Domain), per-fitur, biar gampang nambah
modul baru (menu, customer, shift, dst.) tanpa bongkar struktur yang ada.
