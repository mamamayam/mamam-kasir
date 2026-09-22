import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card_shell.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../domain/hrd_date_utils.dart';
import '../../domain/hrd_models.dart';
import '../../domain/payroll_engine.dart';
import 'hrd_owner_approval_screen.dart';

/// Owner Screen 6 — Koreksi Absen. Owner can directly EDIT today's Jam
/// Masuk / Jam Pulang (updates the existing row, never duplicates), plus
/// a separate "tambah catatan lain" section for Masuk Lagi / Jam Bolong /
/// Libur. Jam Pulang is locked while the employee is stuck mid-bolong —
/// that must be resolved through Approval first (see
/// payroll_engine.dart's stuck-bolong rules).
class HrdOwnerCorrectAttendanceScreen extends ConsumerStatefulWidget {
  final String employeeId;
  const HrdOwnerCorrectAttendanceScreen({super.key, required this.employeeId});

  @override
  ConsumerState<HrdOwnerCorrectAttendanceScreen> createState() => _HrdOwnerCorrectAttendanceScreenState();
}

class _HrdOwnerCorrectAttendanceScreenState extends ConsumerState<HrdOwnerCorrectAttendanceScreen> {
  final _masukController = TextEditingController();
  final _pulangController = TextEditingController();
  final _correctionTimeController = TextEditingController();
  AttendanceLogType _correctionType = AttendanceLogType.masukLagi;
  bool _initialized = false;

  @override
  void dispose() {
    _masukController.dispose();
    _pulangController.dispose();
    _correctionTimeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.danger));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
  }

  void _saveMasukPulang() {
    final result = ref.read(hrdControllerProvider.notifier).saveMasukPulang(widget.employeeId, _masukController.text, _pulangController.text);
    if (!result.ok) {
      _showError(result.message);
      return;
    }
    _showSuccess(result.message);
  }

  void _submitCorrection() {
    final result = ref.read(hrdControllerProvider.notifier).addCorrection(widget.employeeId, _correctionType, _correctionTimeController.text);
    if (!result.ok) {
      _showError(result.message);
      return;
    }
    _correctionTimeController.clear();
    _showSuccess(result.message);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hrdControllerProvider);
    final e = state.employeeById(widget.employeeId);
    if (e == null) {
      return Scaffold(body: SafeArea(child: Column(children: [const IosPageHeader(title: Text('Koreksi Absen')), Expanded(child: Center(child: Text('Karyawan tidak ditemukan')))])));
    }

    final todayLogs = state.todayLogsFor(e.id);
    if (!_initialized) {
      _initialized = true;
      final masuk = todayLogs.where((l) => l.type == AttendanceLogType.masuk).cast<AttendanceLog?>().firstWhere((_) => true, orElse: () => null);
      final pulang = todayLogs.where((l) => l.type == AttendanceLogType.pulang).cast<AttendanceLog?>().firstWhere((_) => true, orElse: () => null);
      _masukController.text = masuk?.time ?? '';
      _pulangController.text = pulang?.time ?? '';
    }

    final otherLogs = todayLogs.where((l) => l.type != AttendanceLogType.masuk && l.type != AttendanceLogType.pulang).toList();
    final stuck = todayLogs.any((l) => l.type == AttendanceLogType.masuk) ? findStuckBolong(todayLogs) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Koreksi Absen')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  Text('${e.name} · ${formatDateLong(state.today)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Text(
                    'Kalau karyawan lupa absen padahal sudah bekerja, isi jam sebenarnya di sini — datanya akan diperbarui langsung.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (stuck != null) ...[
                    AppCardShell(
                      backgroundColor: AppColors.warning.withValues(alpha: 0.05),
                      borderColor: AppColors.warning.withValues(alpha: 0.35),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.warning),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Masih bolong sejak ${stuck.time}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Belum ada catatan masuk lagi, jadi Jam Pulang belum bisa diisi di sini. Selesaikan lewat layar Approval.',
                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppButton.secondary(
                            label: 'Buka Approval',
                            fullWidth: true,
                            onPressed: () => AppNav.push(context, (_) => const HrdOwnerApprovalScreen()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  const _SectionLabel('JAM MASUK & PULANG'),
                  AppCardShell(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        AppTextField.form(label: 'Jam Masuk', controller: _masukController, hintText: 'Belum absen — contoh: 09:00'),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField.form(
                          label: 'Jam Pulang',
                          controller: _pulangController,
                          hintText: stuck != null ? 'Terkunci — selesaikan bolong dulu' : 'Belum absen — contoh: 19:00',
                          enabled: stuck == null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton.primary(label: 'Simpan Jam Masuk & Pulang', fullWidth: true, onPressed: _saveMasukPulang),
                  if (otherLogs.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionLabel('CATATAN LAIN HARI INI'),
                    for (final l in otherLogs)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCardShell(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l.type.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                              Text(l.time ?? '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  const _SectionLabel('TAMBAH CATATAN LAIN'),
                  const Text('Jenis', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border), color: AppColors.surface),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AttendanceLogType>(
                        value: _correctionType,
                        isExpanded: true,
                        items: const [AttendanceLogType.masukLagi, AttendanceLogType.bolong, AttendanceLogType.libur]
                            .map((t) => DropdownMenuItem(value: t, child: Text(t.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))))
                            .toList(),
                        onChanged: (v) => setState(() => _correctionType = v ?? _correctionType),
                      ),
                    ),
                  ),
                  if (_correctionType != AttendanceLogType.libur) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppTextField.form(label: 'Jam', controller: _correctionTimeController, hintText: 'Contoh: 13:00'),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppButton.secondary(label: 'Simpan Catatan', fullWidth: true, onPressed: _submitCorrection),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
    );
  }
}
