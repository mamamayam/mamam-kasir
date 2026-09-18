import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Tappable title with a dropdown chevron, meant to be passed as
/// [IosPageHeader]'s `title:` — see that widget's doc comment, which
/// specifically calls out this case ("callers needing a tappable title
/// with a dropdown chevron... can still center it the same way").
///
/// Renders [currentLabel] + an animated chevron; tapping opens an
/// [Overlay] menu positioned under the title with one row per
/// [options], via [labelBuilder]. Use this instead of reimplementing a
/// whole header with `Stack` + `Center` + `Align` — that combination is
/// exactly what [AppSheetHeader]'s doc comment warns against, and the
/// same reasoning applies to full-page headers.
///
/// Originally extracted from Menu Management's Menu/Varian switch and
/// Arus Kas's Pemasukan/Pengeluaran switch — both now use this instead
/// of their own copy.
class AppDropdownTitle<T> extends StatefulWidget {
  final T selected;
  final List<T> options;
  final String Function(T option) labelBuilder;
  final ValueChanged<T> onSelected;

  const AppDropdownTitle({
    super.key,
    required this.selected,
    required this.options,
    required this.labelBuilder,
    required this.onSelected,
  });

  @override
  State<AppDropdownTitle<T>> createState() => _AppDropdownTitleState<T>();
}

class _AppDropdownTitleState<T> extends State<AppDropdownTitle<T>> {
  final _key = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    const menuWidth = 160.0;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: position.dy + size.height + 6,
            left: position.dx + size.width / 2 - menuWidth / 2,
            width: menuWidth,
            child: _DropdownMenu<T>(
              selected: widget.selected,
              options: widget.options,
              labelBuilder: widget.labelBuilder,
              onSelect: (option) {
                widget.onSelected(option);
                _close();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: _key,
      onTap: _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.labelBuilder(widget.selected),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedRotation(
            turns: _isOpen ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _DropdownMenu<T> extends StatelessWidget {
  final T selected;
  final List<T> options;
  final String Function(T option) labelBuilder;
  final ValueChanged<T> onSelect;

  const _DropdownMenu({required this.selected, required this.options, required this.labelBuilder, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) {
            final isSelected = option == selected;
            return InkWell(
              onTap: () => onSelect(option),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
                color: isSelected ? AppColors.brand.withValues(alpha: 0.06) : Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      labelBuilder(option),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? AppColors.brand : AppColors.textPrimary),
                    ),
                    if (isSelected) const Icon(Icons.check_rounded, size: 16, color: AppColors.brand),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
