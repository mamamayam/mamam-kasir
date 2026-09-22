import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_item_thumbnail.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import 'hrd_staff_pin_screen.dart';

/// Staff Screen 1 — Pilih Nama. Every new staff session starts here (new
/// pick, or logout) — there is deliberately no way to switch to another
/// employee once a PIN succeeds (see hrd_staff_session_provider.dart).
class HrdStaffEntryScreen extends ConsumerStatefulWidget {
  const HrdStaffEntryScreen({super.key});

  @override
  ConsumerState<HrdStaffEntryScreen> createState() => _HrdStaffEntryScreenState();
}

class _HrdStaffEntryScreenState extends ConsumerState<HrdStaffEntryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hrdControllerProvider);
    final list = state.workingEmployees.where((e) => e.name.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Karyawan')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  const Text('Siapa kamu?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField.search(hintText: 'Cari nama...', onChanged: (v) => setState(() => _query = v)),
                  const SizedBox(height: AppSpacing.md),
                  for (final e in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: InkWell(
                          onTap: () => AppNav.push(context, (_) => HrdStaffPinScreen(employeeId: e.id)),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
                            child: Row(
                              children: [
                                AppItemThumbnail(name: e.name, size: 44, radius: AppRadius.pill),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                      Text(e.role, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
