import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../domain/hrd_models.dart';
import '../../domain/payroll_engine.dart';
import '../widgets/hrd_shared_widgets.dart';
import 'hrd_owner_employee_detail_screen.dart';
import 'hrd_owner_employee_form_screen.dart';

/// Owner Screen 2 — Kelola Karyawan: search, status/role filter chips,
/// sort (Level-2 sheet), list. "+" in the header opens Tambah Karyawan.
class HrdOwnerEmployeeListScreen extends ConsumerWidget {
  const HrdOwnerEmployeeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hrdControllerProvider);
    final filter = ref.watch(hrdEmployeeListFilterProvider);
    final filterController = ref.read(hrdEmployeeListFilterProvider.notifier);
    final today = state.today;

    final roles = state.employees.map((e) => e.role).toSet().toList();
    final list = filter.apply(state.employees);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(
              title: const Text('Kelola Karyawan'),
              trailingIcon: Icons.add_rounded,
              onTrailingTap: () => AppNav.push(context, (_) => const HrdOwnerEmployeeFormScreen()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: AppTextField.search(
                hintText: 'Cari nama karyawan...',
                onChanged: filterController.setSearch,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _FilterChip(label: 'Semua Status', selected: filter.status == null, onTap: () => filterController.setStatus(null)),
                      for (final s in EmployeeStatus.values)
                        _FilterChip(label: s.label, selected: filter.status == s, onTap: () => filterController.setStatus(s)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _FilterChip(label: 'Semua Role', selected: filter.role == null, onTap: () => filterController.setRole(null)),
                      for (final r in roles) _FilterChip(label: r, selected: filter.role == r, onTap: () => filterController.setRole(r)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${list.length} karyawan', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      InkWell(
                        onTap: () => _openSortSheet(context, filter.sort, filterController.setSort),
                        child: const Row(
                          children: [
                            Icon(Icons.sort_rounded, size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 5),
                            Text('Urutkan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: AppEmptyState(icon: Icons.groups_rounded, title: 'Tidak ada karyawan yang cocok'),
                    ),
                  for (final e in list)
                    HrdEmployeeListCard(
                      employee: e,
                      onShift: isOnShiftNow(state.todayLogsFor(e.id)),
                      onTap: () => AppNav.push(context, (_) => HrdOwnerEmployeeDetailScreen(employeeId: e.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSortSheet(BuildContext context, EmployeeSort current, ValueChanged<EmployeeSort> onSelect) {
    AppNav.showModal(
      context,
      isScrollControlled: false,
      builder: (context) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const SizedBox(width: AppSpacing.lg),
                  const Expanded(child: Text('Urutkan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: AppIconButton.standard(icon: Icons.close_rounded, iconSize: 18, onTap: () => Navigator.of(context).pop()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final option in EmployeeSort.values)
                ListTile(
                  title: Text(option.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: option == current ? AppColors.brand : AppColors.textPrimary)),
                  trailing: option == current ? const Icon(Icons.check_circle_rounded, color: AppColors.brand) : null,
                  onTap: () {
                    onSelect(option);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}
