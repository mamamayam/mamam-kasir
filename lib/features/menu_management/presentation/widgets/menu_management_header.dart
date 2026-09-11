import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/menu_management_models.dart';

class MenuManagementHeader extends StatefulWidget {
  final MenuManagementTab currentTab;
  final ValueChanged<MenuManagementTab> onTabSelected;
  final VoidCallback onBack;
  final VoidCallback onAdd;

  const MenuManagementHeader({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    required this.onBack,
    required this.onAdd,
  });

  @override
  State<MenuManagementHeader> createState() => _MenuManagementHeaderState();
}

class _MenuManagementHeaderState extends State<MenuManagementHeader> {
  final _dropdownKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

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
            left: position.dx + size.width / 2 - 80,
            width: 160,
            child: _DropdownMenu(
              currentTab: widget.currentTab,
              onSelect: (tab) {
                widget.onTabSelected(tab);
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
                      widget.currentTab == MenuManagementTab.menu ? 'Menu' : 'Varian',
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
  final MenuManagementTab currentTab;
  final ValueChanged<MenuManagementTab> onSelect;

  const _DropdownMenu({required this.currentTab, required this.onSelect});

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
              label: 'Menu',
              selected: currentTab == MenuManagementTab.menu,
              onTap: () => onSelect(MenuManagementTab.menu),
            ),
            _DropdownOption(
              label: 'Varian',
              selected: currentTab == MenuManagementTab.varian,
              onTap: () => onSelect(MenuManagementTab.varian),
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
