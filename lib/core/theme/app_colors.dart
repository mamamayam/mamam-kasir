import 'package:flutter/material.dart';

/// Central color tokens for Mamam Kasir.
///
/// Design direction (per UI/UX reference pack): clean, modern, operational,
/// slightly premium — avoid excessive gradients / card-heavy decoration.
/// The hero "Total Penjualan Hari Ini" card keeps a dark gradient as an
/// accent focal point; the swipe-up menu's 3x3 icon grid and the quick
/// action cards (Kasir/Riwayat) both use solid, vivid per-item colors
/// (not muted) — see tile palette below.
class AppColors {
  AppColors._();

  // Neutrals
  static const Color background = Color(0xFFF8F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEEF0F4);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Brand
  static const Color brand = Color(0xFFFF6B2C);
  static const Color brandDark = Color(0xFFE85A1F);

  // Hero card gradient (the one intentional gradient in the app)
  static const List<Color> heroGradient = [Color(0xFF1F2230), Color(0xFF14161F)];

  // Status
  static const Color success = Color(0xFF2FA36B);
  static const Color danger = Color(0xFFE0554A);
  static const Color warning = Color(0xFFD9A441);
  static const Color info = Color(0xFF3B7DD9);

  // Menu-tile palette — vivid/solid tones matching the saturation level of
  // the Kasir/Riwayat quick-action colors (brand orange, info blue), not
  // the earlier muted set. Each item keeps its own hue for recognition.
  static const Color tileDompet = Color(0xFF7C5FC7); // purple
  static const Color tileMenu = Color(0xFF3B7DD9); // blue (matches info)
  static const Color tileLabaRugi = Color(0xFF2FA36B); // green (matches success)
  static const Color tileKas = Color(0xFFE0554A); // red (matches danger)
  static const Color tilePelanggan = Color(0xFFD6478E); // pink
  static const Color tileLaporan = Color(0xFF5B5FE0); // indigo
  static const Color tileStaff = Color(0xFFD9A441); // amber (matches warning)
  static const Color tileHpp = Color(0xFF1FA3AE); // cyan
  static const Color tilePengaturan = Color(0xFF5C6478); // slate

  // Top-row action cards (Notifikasi / Approval) — dark rounded icon chip,
  // matching the reference screenshot's style.
  static const Color actionIconBg = Color(0xFF1F2230);
}
