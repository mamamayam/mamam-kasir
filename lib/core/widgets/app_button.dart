import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum _AppButtonVariant { primary, secondary, danger }

/// Shared button — three fixed variants per the component standards
/// doc §5. Do not add ad hoc variants; extend this widget instead if a
/// new case is genuinely needed.
///
/// - [AppButton.primary]: main CTA (Bayar, Simpan, Konfirmasi) — filled
///   [AppColors.brand], white w800/15 text, [AppRadius.lg].
/// - [AppButton.secondary]: secondary action (Batal, etc.) — outlined
///   [AppColors.border], [AppColors.textPrimary] w700 text.
/// - [AppButton.danger]: destructive action (Hapus, etc.) — filled
///   [AppColors.danger].
///
/// All variants are full-width by default (set [fullWidth] to false to
/// opt out). Pass [isLoading] to show a small spinner in place of the
/// label and disable taps while an action is in flight.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final _AppButtonVariant _variant;
  final bool fullWidth;
  final bool isLoading;
  final IconData? icon;

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = true,
    this.isLoading = false,
    this.icon,
  }) : _variant = _AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = true,
    this.isLoading = false,
    this.icon,
  }) : _variant = _AppButtonVariant.secondary;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = true,
    this.isLoading = false,
    this.icon,
  }) : _variant = _AppButtonVariant.danger;

  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final button = switch (_variant) {
      _AppButtonVariant.primary => _buildFilled(backgroundColor: AppColors.brand, foregroundColor: Colors.white),
      _AppButtonVariant.danger => _buildFilled(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
      _AppButtonVariant.secondary => _buildOutlined(),
    };

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _buildFilled({required Color backgroundColor, required Color foregroundColor}) {
    return ElevatedButton(
      onPressed: _isDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        disabledBackgroundColor: backgroundColor.withValues(alpha: 0.4),
        foregroundColor: foregroundColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      child: _buildChild(foregroundColor),
    );
  }

  Widget _buildOutlined() {
    return OutlinedButton(
      onPressed: _isDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        disabledForegroundColor: AppColors.textMuted,
        side: BorderSide(color: onPressed == null ? AppColors.border : AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      child: _buildChild(AppColors.textPrimary),
    );
  }

  Widget _buildChild(Color foregroundColor) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.2, color: foregroundColor),
      );
    }

    final textStyle = TextStyle(
      fontSize: 15,
      fontWeight: _variant == _AppButtonVariant.secondary ? FontWeight.w700 : FontWeight.w800,
    );

    if (icon == null) {
      return Text(label, style: textStyle);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: textStyle),
      ],
    );
  }
}
