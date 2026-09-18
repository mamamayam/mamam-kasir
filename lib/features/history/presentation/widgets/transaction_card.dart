import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/app_status_badge.dart';
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
                  _StatusBadgeForTransaction(transaction: transaction),
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

/// Explicit 3-way branch on [Transaction.status] — previously this was
/// an if/else-if that treated "not canceled" as "has a payment method,
/// show it green", which silently mis-rendered an `open` (Diproses)
/// transaction (no payment method yet) as if it were paid the moment
/// any payment method string happened to be present. Each status now
/// gets its own explicit badge rather than being inferred from what
/// other fields happen to be set.
class _StatusBadgeForTransaction extends StatelessWidget {
  final Transaction transaction;
  const _StatusBadgeForTransaction({required this.transaction});

  @override
  Widget build(BuildContext context) {
    if (transaction.isCanceled) {
      return const AppStatusBadge('Dibatalkan', AppColors.danger);
    }
    if (transaction.isOpen) {
      return const AppStatusBadge('Diproses', AppColors.warning);
    }
    // isPaid — payment method may still be null in edge cases (e.g. a
    // legacy row), so fall back to a generic paid label rather than
    // rendering an empty badge.
    return AppStatusBadge(transaction.paymentMethodLabel ?? 'Selesai', AppColors.success);
  }
}
