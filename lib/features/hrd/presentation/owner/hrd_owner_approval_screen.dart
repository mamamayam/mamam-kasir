import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_item_thumbnail.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../domain/hrd_date_utils.dart';
import '../../domain/hrd_models.dart';

/// Owner Screen 12 — Approval. Generic list: staff income requests
/// (Tolak/Setujui) and attendance clarifications (Option A fill
/// masuk_lagi / Option B treat bolong as pulang). Named `Hrd…` in the
/// model layer so it can later be absorbed into a shared Approval
/// feature (see hrd_models.dart's doc comment) — this screen is what
/// menu_bottom_sheet.dart's "Approval" card should eventually open.
class HrdOwnerApprovalScreen extends ConsumerWidget {
  const HrdOwnerApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hrdControllerProvider);
    final pending = state.pendingApprovals;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Approval')),
            Expanded(
              child: pending.isEmpty
                  ? const Center(child: AppEmptyState(icon: Icons.check_circle_rounded, title: 'Tidak ada pengajuan menunggu'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                      children: [
                        for (final r in pending) ...[
                          if (r.type == HrdApprovalType.attendanceClarification)
                            _AttendanceClarificationCard(request: r, employeeName: state.employeeById(r.employeeId)?.name ?? '-')
                          else
                            _IncomeRequestCard(request: r, employeeName: state.employeeById(r.employeeId)?.name ?? '-'),
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

class _IncomeRequestCard extends ConsumerWidget {
  final HrdApprovalRequest request;
  final String employeeName;

  const _IncomeRequestCard({required this.request, required this.employeeName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void decide(bool approve) {
      final result = ref.read(hrdControllerProvider.notifier).decideIncomeRequest(request.id, approve: approve);
      if (!result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: AppColors.danger));
      }
    }

    return AppCardShell(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppItemThumbnail(name: employeeName, size: 38, radius: AppRadius.pill),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employeeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(request.label ?? '-', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text(formatRupiah(request.amount ?? 0), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.border),
          Text(formatDateLong(request.date), style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          if ((request.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(request.note!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: AppButton.secondary(label: 'Tolak', fullWidth: true, onPressed: () => decide(false))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: AppButton.primary(label: 'Setujui', fullWidth: true, onPressed: () => decide(true))),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceClarificationCard extends ConsumerStatefulWidget {
  final HrdApprovalRequest request;
  final String employeeName;

  const _AttendanceClarificationCard({required this.request, required this.employeeName});

  @override
  ConsumerState<_AttendanceClarificationCard> createState() => _AttendanceClarificationCardState();
}

class _AttendanceClarificationCardState extends ConsumerState<_AttendanceClarificationCard> {
  final _masukLagiController = TextEditingController();

  @override
  void dispose() {
    _masukLagiController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.danger));
  }

  void _optionA() {
    final result = ref.read(hrdControllerProvider.notifier).clarifyWithMasukLagi(widget.request.id, _masukLagiController.text);
    if (!result.ok) _showError(result.message);
  }

  void _optionB() {
    final result = ref.read(hrdControllerProvider.notifier).clarifyAsPulang(widget.request.id);
    if (!result.ok) _showError(result.message);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return AppCardShell(
      backgroundColor: AppColors.warning.withValues(alpha: 0.04),
      borderColor: AppColors.warning.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppItemThumbnail(name: widget.employeeName, size: 38, radius: AppRadius.pill),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.employeeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const Text('Belum absen masuk lagi setelah bolong', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg, color: AppColors.border),
          Text('${formatDateLong(r.date)} · Bolong sejak ${r.bolongTime}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          AppTextField.form(label: 'Opsi A — Isi jam masuk lagi sebenarnya', controller: _masukLagiController, hintText: 'Contoh: 14:00'),
          const SizedBox(height: AppSpacing.sm),
          AppButton.secondary(label: 'Simpan Masuk Lagi', fullWidth: true, onPressed: _optionA),
          const SizedBox(height: AppSpacing.md),
          const Center(child: Text('atau', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted))),
          const SizedBox(height: AppSpacing.md),
          const Text('Opsi B — Anggap bolong sebagai jam pulang', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          AppButton.primary(label: 'Tetapkan Jam ${r.bolongTime} sebagai Pulang', fullWidth: true, onPressed: _optionB),
        ],
      ),
    );
  }
}
