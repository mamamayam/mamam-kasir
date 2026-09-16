import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/arus_kas_models.dart';

class ArusKasEntryTile extends StatelessWidget {
  final ArusKasEntry entry;
  final VoidCallback onDelete;

  const ArusKasEntryTile({super.key, required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isPemasukan = entry.direction == ArusKasDirection.pemasukan;
    final color = isPemasukan ? AppColors.success : AppColors.danger;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        color: AppColors.danger,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(isPemasukan ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 16, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.category, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(
                    [
                      DateFormat('d MMM yyyy', 'id_ID').format(entry.transactionDate),
                      entry.sourceLabel,
                      if (entry.storeOrSupplierName != null && entry.storeOrSupplierName!.isNotEmpty) entry.storeOrSupplierName!,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              '${isPemasukan ? '+' : '-'}${formatRupiah(entry.amount)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
