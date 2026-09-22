import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/pelanggan_logic.dart';
import '../../domain/pelanggan_models.dart';

/// List card for one customer. Mockup `.cust-card`: white, radius 20,
/// padding 16, 10px gap between rows; top row = rank | name+phone | omzet;
/// then a 1px divider; then the one-line "last purchase" row indented 40.
class PelangganListCard extends StatelessWidget {
  final Pelanggan customer;

  /// 1-based position in the CURRENT list (not the global loyalty rank).
  final int rank;

  /// Only the Loyal tab highlights its top 3 (and only if omzet > 0).
  final bool highlightTop;
  final VoidCallback onTap;

  const PelangganListCard({
    super.key,
    required this.customer,
    required this.rank,
    required this.highlightTop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTop = highlightTop && rank <= 3 && customer.omzet > 0;
    final phoneText = customer.phones.isNotEmpty ? customer.phones.first : '— (tidak ada nomor)';
    final last = customer.lastPurchase;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$rank',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isTop ? AppColors.pelangganTextPrimary : AppColors.pelangganTextMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.pelangganTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          phoneText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        PelangganLogic.formatRp(customer.omzet),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.pelangganTextPrimary,
                        ),
                      ),
                      const Text(
                        'omzet all-time',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pelangganTextMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.pelangganBorder),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Row(
                  children: [
                    Icon(
                      last != null ? Icons.receipt_long_outlined : Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.pelangganTextMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        last != null ? last.text : 'Belum ada riwayat pembelian',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (last != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        last.time,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.pelangganTextMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White rounded container that stacks [PelangganRecordRow]s separated by
/// hairlines. Mockup `.record-card`: radius 20, margin 0/16/16/16, the
/// last row has no bottom border.
class PelangganRecordCard extends StatelessWidget {
  final List<PelangganRecordRow> rows;
  const PelangganRecordCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          color: AppColors.surface,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: i == rows.length - 1
                        ? null
                        : const Border(bottom: BorderSide(color: AppColors.pelangganBorder)),
                  ),
                  child: rows[i],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One record row: 20px muted icon, small muted label (12/w500) above a
/// bold value (15/w700). Mockup `.record-row`: gap 14, padding 15/18.
class PelangganRecordRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const PelangganRecordRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // margin-top:1px on the icon in the mockup.
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20, color: AppColors.pelangganTextMuted),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.pelangganTextMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.pelangganTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Peringkat #N Pelanggan Paling Loyal" card. Mockup `.rank-badge-row`.
class PelangganRankCard extends StatelessWidget {
  final String title;
  final String subtitle;
  const PelangganRankCard({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: AppColors.pelangganBackground, shape: BoxShape.circle),
              child: const Icon(Icons.emoji_events_outlined, size: 24, color: AppColors.pelangganTextPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.pelangganTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.pelangganTextMuted,
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

/// Section heading ("Ringkasan Omzet", "Riwayat Pembelian"). Mockup
/// `.section-title`: 15/w800, padding 0/16, margin-bottom 8.
class PelangganSectionTitle extends StatelessWidget {
  final String text;
  const PelangganSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.pelangganTextPrimary,
        ),
      ),
    );
  }
}

/// One purchase-history entry. Mockup `.riwayat-item`: white, radius 20,
/// padding 16, margin 0/16/8/16; date (12/w600 muted) + total (15/w800)
/// on top, items (13/w500), then small pill tags (10.5/w700).
class PelangganRiwayatCard extends StatelessWidget {
  final PelangganRiwayat entry;
  const PelangganRiwayatCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.date,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.pelangganTextMuted,
                  ),
                ),
                Text(
                  PelangganLogic.formatRp(entry.total),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.pelangganTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.items,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < entry.tags.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.pelangganBackground,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      entry.tags[i],
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty box shown inside the detail page when a customer has no history.
/// Mockup `.riwayat-empty`.
class PelangganRiwayatEmpty extends StatelessWidget {
  const PelangganRiwayatEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.pelangganTextMuted),
            SizedBox(height: 8),
            Text(
              'Belum ada riwayat pembelian',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.pelangganTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
