import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shared PIN keypad per the component standards doc §7. Use this for
/// EVERY PIN screen (owner/manager login, staff PIN, quick-action
/// verification) — do not redesign from scratch.
///
/// - Number (0–9) and backspace buttons: 72×72, [CircleBorder],
///   transparent.
/// - Digit text: 24/w700/[AppColors.textPrimary].
/// - Layout: 3 columns × 4 rows — 1-2-3 / 4-5-6 / 7-8-9 / (empty)-0-backspace.
///   The (empty) cell can optionally host [bottomLeft].
/// - Row spacing: `EdgeInsets.symmetric(vertical: 6)`.
class AppPinKeypad extends StatelessWidget {
  final bool disabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Optional widget for the bottom-left cell, which is empty by default
  /// (`(kosong)-0-backspace`). Purely additive: existing PIN screens omit
  /// it and are unchanged. Used by the staff PIN screen for its "back to
  /// name list" key. The widget is responsible for its own tap handling
  /// and is centered in the same 72×72 cell as the digit buttons.
  final Widget? bottomLeft;

  const AppPinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.disabled = false,
    this.bottomLeft,
  });

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'back'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key.isEmpty) {
                return SizedBox(width: 72, height: 72, child: bottomLeft == null ? null : Center(child: bottomLeft));
              }
              if (key == 'back') {
                return _KeypadButton(
                  disabled: disabled,
                  onTap: onBackspace,
                  child: const Icon(Icons.backspace_outlined, size: 22, color: AppColors.textSecondary),
                );
              }
              return _KeypadButton(
                disabled: disabled,
                onTap: () => onDigit(key),
                child: Text(key, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

/// Shared PIN-filled indicator dots per the component standards doc §7:
/// 16×16, 2px border. Use alongside [AppPinKeypad] on every PIN screen.
class AppPinDots extends StatelessWidget {
  final int length;
  final int filledCount;
  final bool isError;

  const AppPinDots({super.key, required this.length, required this.filledCount, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final filled = i < filledCount;
        final color = isError
            ? AppColors.danger
            : filled
                ? AppColors.brand
                : AppColors.border;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: filled || isError ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final bool disabled;
  final VoidCallback onTap;
  final Widget child;

  const _KeypadButton({required this.disabled, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: disabled ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(width: 72, height: 72, child: Center(child: child)),
        ),
      ),
    );
  }
}
