import 'package:flutter/material.dart';

/// Central color tokens for Mamam Kasir.
///
/// Design direction (per UI/UX reference pack): clean, modern, operational,
/// slightly premium — avoid excessive gradients / overly saturated colors /
/// card-heavy decoration. The one deliberate exception is the dashboard's
/// "Total Penjualan Hari Ini" hero card, which keeps a dark gradient as an
/// accent focal point; everything else (including the swipe-up menu's 3x3
/// icon grid) uses calmer, muted tones instead of the fully-saturated
/// palette from the original mockup.
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

  // Muted menu-tile palette — toned down from the mockup's saturated set.
  // Same hue identity per item (so recognition carries over), lower
  // saturation/lightness so the 3x3 grid reads calmer as a whole.
  static const Color tileDompet = Color(0xFF8B7CC7); // muted purple
  static const Color tileMenu = Color(0xFF5B8DBF); // muted blue
  static const Color tileLabaRugi = Color(0xFF4FA383); // muted green
  static const Color tileKas = Color(0xFFC96B63); // muted red
  static const Color tilePelanggan = Color(0xFFC777A0); // muted pink
  static const Color tileLaporan = Color(0xFF7A7FCB); // muted indigo
  static const Color tileStaff = Color(0xFFCC9A4A); // muted amber
  static const Color tileHpp = Color(0xFF4FA3AE); // muted cyan
  static const Color tilePengaturan = Color(0xFF6B7385); // slate

  // Top-row action cards (Notifikasi / Approval) — dark rounded icon chip,
  // matching the reference screenshot's style.
  static const Color actionIconBg = Color(0xFF1F2230);
}
