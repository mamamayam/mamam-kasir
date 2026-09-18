import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Soft, deterministic background palette for initials avatars — picked
/// to be distinguishable but not garish; the same first letter always
/// maps to the same color (see [_colorForInitials]).
const List<Color> _avatarPalette = [
  Color(0xFFEFD9C7), // warm peach
  Color(0xFFD8E7D3), // soft sage
  Color(0xFFD6E4F0), // soft blue
  Color(0xFFEAD9EE), // soft lavender
  Color(0xFFF3E0D2), // soft terracotta
  Color(0xFFD9EEE8), // soft teal
  Color(0xFFF0E0D9), // soft clay
  Color(0xFFE0E0EF), // soft periwinkle
];

/// Shared product thumbnail per the component standards doc §9. Renders
/// the item's photo if it has one; otherwise falls back to a deterministic
/// initials avatar — never a generic icon/gray box.
///
/// The initials are the first letter of up to the first 2 words of the
/// name ("Ayam Geprek" -> "AG", "Kerupuk" -> "KE" using the first two
/// letters of a single-word name). Background color is derived
/// deterministically from the first letter (hashed into a fixed soft
/// palette) — not random, not uniform gray, and stable across rebuilds.
class AppItemThumbnail extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;
  final double radius;

  const AppItemThumbnail({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 56,
    this.radius = AppRadius.md,
  });

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return word.length >= 2 ? word.substring(0, 2).toUpperCase() : word.toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  Color get _backgroundColor {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return _avatarPalette.first;
    final firstLetter = trimmed[0].toUpperCase();
    final index = firstLetter.codeUnitAt(0) % _avatarPalette.length;
    return _avatarPalette[index];
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildInitials(borderRadius),
        ),
      );
    }

    return _buildInitials(borderRadius);
  }

  Widget _buildInitials(BorderRadius borderRadius) {
    final bg = _backgroundColor;
    // Dark, low-saturation text reads reliably against every color in
    // the soft palette above (all are light), so a single fixed
    // foreground keeps this simple and always-contrasting.
    const foreground = Color(0xFF3A3A3A);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: borderRadius),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}
