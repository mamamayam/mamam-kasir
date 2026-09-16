import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../application/dompet_provider.dart';
import '../domain/dompet_models.dart';
import 'dompet_closing_screen.dart';
import 'widgets/cash_movement_tile.dart';
import 'widgets/courier_outstanding_card.dart';

/// Dompet (cash ledger) page — reached via the swipe-up menu's "Dompet"
/// tile. Shows saldo, the PRD-mandated three-category summary (Uang di
/// Dompet / Uang di Kurir / Kasbon Staff, deliberately never summed
/// together — PRD §23), outstanding courier cash needing resolution,
/// recent cash activity, and a "Tutup Dompet" entry point (header
/// trailing icon) into [DompetClosingScreen].
class DompetScreen extends ConsumerWidget {
  const DompetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dompetProvider);
    final controller = ref.read(dompetProvider.notifier);

    ref.listen(dompetProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.danger));
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: IosPageHeader(
        title: const Text('Dompet'),
        trailingIcon: Icons.lock_clock_rounded,
        onTrailingTap: () async {
          await AppNav.push(context, (_) => const DompetClosingScreen());
          controller.load();
        },
      ),
      body: SafeArea(
        top: false,
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
            : RefreshIndicator(
                color: AppColors.brand,
                onRefresh: controller.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                  children: [
                    _SaldoCard(summary: state.summary),
                    const SizedBox(height: AppSpacing.lg),
                    _RingkasanRow(summary: state.summary),
                    if (state.lastClosing != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _LastClosingNote(closing: state.lastClosing!),
                    ],
                    if (state.summary != null && state.summary!.courierBalances.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionLabel(text: 'UANG DI KURIR'),
                      const SizedBox(height: AppSpacing.sm),
                      ...state.summary!.courierBalances.map((balance) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: CourierOutstandingCard(
                              balance: balance,
                              onDeposit: (amount) => controller.recordCourierDeposit(
                                courierLocationId: balance.location.id,
                                amount: amount,
                              ),
                              onConvertToKasbon: () => controller.convertToKasbon(
                                courierLocationId: balance.location.id,
                                courierName: balance.location.name,
                                amount: balance.balance,
                              ),
                            ),
                          )),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionLabel(text: 'AKTIVITAS CASH'),
                    const SizedBox(height: AppSpacing.sm),
                    if (state.recentMovements.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Center(
                          child: Text('Belum ada aktivitas.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
                        child: Column(
                          children: state.recentMovements
                              .map((m) => CashMovementTile(movement: m, locationNames: _locationNameLookup(state.summary)))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  Map<String, String> _locationNameLookup(DompetSummary? summary) {
    if (summary == null) return {'loc-store': 'Dompet Toko'};
    final map = <String, String>{'loc-store': 'Dompet Toko'};
    for (final b in summary.courierBalances) {
      map[b.location.id] = b.location.name;
    }
    return map;
  }
}

class _SaldoCard extends StatelessWidget {
  final DompetSummary? summary;
  const _SaldoCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.heroGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SALDO DOMPET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white.withValues(alpha: 0.55))),
          const SizedBox(height: 6),
          Text(formatRupiah(summary?.storeCashBalance ?? 0), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}

class _RingkasanRow extends StatelessWidget {
  final DompetSummary? summary;
  const _RingkasanRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RingkasanChip(
            icon: Icons.storefront_rounded,
            label: 'Di Dompet',
            value: summary?.storeCashBalance ?? 0,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _RingkasanChip(
            icon: Icons.moped_rounded,
            label: 'Di Kurir',
            value: summary?.totalCourierOutstanding ?? 0,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _RingkasanChip(
            icon: Icons.receipt_long_rounded,
            label: 'Kasbon',
            value: summary?.totalKasbonOutstanding ?? 0,
            color: AppColors.danger,
          ),
        ),
      ],
    );
  }
}

class _RingkasanChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _RingkasanChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(
            formatRupiah(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5));
  }
}

class _LastClosingNote extends StatelessWidget {
  final DompetClosing closing;
  const _LastClosingNote({required this.closing});

  @override
  Widget build(BuildContext context) {
    final isOverdue = closing.status == DompetClosingStatus.overdueClosing;
    final label = isOverdue ? 'Tutup Dompet terakhir (overdue)' : 'Tutup Dompet terakhir';
    return Row(
      children: [
        Icon(Icons.history_rounded, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$label · ${_formatDate(closing.periodEnd)}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isOverdue ? AppColors.warning : AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${months[dt.month - 1]}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
