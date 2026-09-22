import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../domain/hrd_date_utils.dart';
import '../../domain/hrd_models.dart';

Color _statusColor(HrdApprovalStatus s) => switch (s) {
      HrdApprovalStatus.menunggu => AppColors.warning,
      HrdApprovalStatus.disetujui => AppColors.success,
      HrdApprovalStatus.ditolak => AppColors.danger,
    };

/// Staff Screen 8 — Status Pengajuan: this employee's own income
/// submission history with status badges (Menunggu/Disetujui/Ditolak).
class HrdStaffIncomeStatusScreen extends ConsumerWidget {
  final String employeeId;
  const HrdStaffIncomeStatusScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hrdControllerProvider);
    final rows = state.approvals.where((r) => r.type == HrdApprovalType.income && r.employeeId == employeeId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Status Pengajuan')),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: AppEmptyState(icon: Icons.receipt_long_rounded, title: 'Belum ada pengajuan'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                      children: [
                        for (final r in rows) ...[
                          AppCardShell(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(r.label ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                                    AppStatusBadge(r.status.label, _statusColor(r.status)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(formatDateLong(r.date), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                const SizedBox(height: 6),
                                Text(formatRupiah(r.amount ?? 0), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
