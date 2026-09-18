import 'package:flutter/material.dart';

/// Central color tokens for Mamam Kasir.
///
/// Brand color matches the "Leci" reference app's sampled navy
/// (#0A2540, pulled directly from its primary button/header pixels),
/// applied everywhere brand color is used EXCEPT the dashboard hero
/// sales card, which keeps its existing dark gradient rather than
/// becoming solid navy (explicit user decision — the gradient stays as
/// an intentional accent).
class AppColors {
  AppColors._();

  // Neutrals
  static const Color background = Color(0xFFF8F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEEF0F4);
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Brand — sampled from Leci reference (primary button fill / header
  // title text): #0A2540.
  static const Color brand = Color(0xFF0A2540);
  static const Color brandDark = Color(0xFF071A2E);

  // Hero card gradient (the one intentional gradient in the app —
  // deliberately NOT replaced with solid brand navy, per explicit
  // decision when the Leci theme was adopted)
  static const List<Color> heroGradient = [Color(0xFF1F2230), Color(0xFF14161F)];

  // Status
  static const Color success = Color(0xFF2FA36B);
  static const Color danger = Color(0xFFE0554A);
  static const Color warning = Color(0xFFD9A441);
  static const Color info = Color(0xFF3B7DD9); // matches Leci's sampled chart/amount blue exactly

  // Menu-tile palette — vivid/solid tones matching the saturation level of
  // the Kasir/Riwayat quick-action colors, not a muted set. Each item
  // keeps its own hue for recognition.
  static const Color tileDompet = Color(0xFF7C5FC7); // purple
  static const Color tileMenu = Color(0xFF3B7DD9); // blue (matches info)
  static const Color tileCabang = Color(0xFF2FA36B); // green (matches success)
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
