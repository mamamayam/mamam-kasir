import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../pos/domain/order_models.dart';
import '../../../pos/domain/transaction.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;

  const TransactionCard({super.key, required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCanceled = transaction.isCanceled;

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: isCanceled ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.displayNumber,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isCanceled ? AppColors.danger : AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(transaction.createdAt),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (isCanceled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: const Text('DIBATALKAN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.danger, letterSpacing: 0.3)),
                    )
                  else if (transaction.paymentMethodLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(AppRadius.sm)),
                      child: Text(
                        transaction.paymentMethodLabel!,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: AppColors.success, letterSpacing: 0.2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${transaction.customerName ?? 'Pelanggan Umum'} · ${transaction.totalQty} item · ${transaction.orderType.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatRupiah(transaction.total),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isCanceled ? AppColors.textMuted : AppColors.textPrimary,
                  decoration: isCanceled ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
