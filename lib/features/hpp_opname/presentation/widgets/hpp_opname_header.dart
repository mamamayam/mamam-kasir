import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

enum HppOpnamePage { hpp, opname }

/// Header for the combined HPP & Stok Opname screen: circular back
/// button, a tappable dropdown title to switch between HPP and Stok
/// Opname (ported 1:1 from the HTML mockup's header dropdown, using the
/// same [OverlayEntry] approach as [MenuManagementHeader] — the mockup's
/// original nested-DOM dropdown had a real click-bubbling bug; an
/// Overlay is a fully independent layer, so that class of bug can't
/// happen here), and an optional "+" button on the right shown only on
/// the HPP page (Stok Opname has no "add ingredient" action of its own).
class HppOpnameHeader extends StatefulWidget {
  final HppOpnamePage currentPage;
  final ValueChanged<HppOpnamePage> onPageSelected;
  final VoidCallback onBack;
  final VoidCallback? onAdd;

  const HppOpnameHeader({
    super.key,
    required this.currentPage,
    required this.onPageSelected,
    required this.onBack,
    this.onAdd,
  });

  @override
  State<HppOpnameHeader> createState() => _HppOpnameHeaderState();
}

class _HppOpnameHeaderState extends State<HppOpnameHeader> {
  final _dropdownKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() => _isOpen ? _closeDropdown() : _openDropdown();

  void _openDropdown() {
    final renderBox = _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeDropdown,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: position.dy + size.height + 6,
            left: position.dx + size.width / 2 - 85,
            width: 170,
            child: _DropdownMenu(
              currentPage: widget.currentPage,
              onSelect: (page) {
                widget.onPageSelected(page);
                _closeDropdown();
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: GestureDetector(
                key: _dropdownKey,
                onTap: _toggleDropdown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.currentPage == HppOpnamePage.hpp ? 'HPP' : 'Stok Opname',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _CircleIconButton(icon: Icons.chevron_left_rounded, onTap: widget.onBack),
            ),
            if (widget.currentPage == HppOpnamePage.hpp)
              Align(
                alignment: Alignment.centerRight,
                child: _CircleIconButton(icon: Icons.add_rounded, onTap: widget.onAdd),
              ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CircleIconButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, size: 24, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _DropdownMenu extends StatelessWidget {
  final HppOpnamePage currentPage;
  final ValueChanged<HppOpnamePage> onSelect;

  const _DropdownMenu({required this.currentPage, required this.onSelect});

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
          children: [
            _DropdownOption(
              label: 'HPP',
              selected: currentPage == HppOpnamePage.hpp,
              onTap: () => onSelect(HppOpnamePage.hpp),
            ),
            _DropdownOption(
              label: 'Stok Opname',
              selected: currentPage == HppOpnamePage.opname,
              onTap: () => onSelect(HppOpnamePage.opname),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DropdownOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
        color: selected ? AppColors.brand.withValues(alpha: 0.06) : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.brand : AppColors.textPrimary,
              ),
            ),
            if (selected) const Icon(Icons.check_rounded, size: 16, color: AppColors.brand),
          ],
        ),
      ),
    );
  }
}
