import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shared text field — two variants per the component standards doc §4.
/// Do not write a new inline `InputDecoration` for search bars or form
/// fields; extend this widget if a new case is needed.
///
/// - [AppTextField.search]: no visible border, wrapped in a pill
///   ([AppRadius.pill]) container filled [AppColors.background]. Hint
///   14/w500/[AppColors.textMuted].
/// - [AppTextField.form]: bordered [AppRadius.md], filled
///   [AppColors.surface], border [AppColors.border] idle →
///   [AppColors.brand] focused. Label sits above the field (not a
///   floating label) via [label]. Hint 14/w500/[AppColors.textMuted].
///
/// Both variants take [prefixIcon]/[suffixIcon]/[prefixText] directly —
/// use those instead of wrapping in a second widget.
class AppTextField extends StatelessWidget {
  final bool _isSearch;
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int maxLines;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  const AppTextField.search({
    super.key,
    this.controller,
    this.hintText = 'Cari...',
    this.prefixIcon = Icons.search_rounded,
    this.suffixIcon,
    this.onChanged,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  })  : _isSearch = true,
        label = null,
        prefixText = null,
        keyboardType = null,
        minLines = 1,
        maxLines = 1;

  const AppTextField.form({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.keyboardType,
    this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  }) : _isSearch = false;

  @override
  Widget build(BuildContext context) {
    if (_isSearch) return _buildSearch();

    if (label == null) return _buildField();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        _buildField(),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: TextField(
        controller: controller,
        enabled: enabled,
        autofocus: autofocus,
        focusNode: focusNode,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMuted),
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20, color: AppColors.textMuted),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.pill), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildField() {
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      keyboardType: keyboardType,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMuted),
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20, color: AppColors.textMuted),
        prefixText: prefixText,
        prefixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.brand, width: 1.5)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: const BorderSide(color: AppColors.border)),
      ),
    );
  }
}
