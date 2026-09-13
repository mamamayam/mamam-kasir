import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/dompet_models.dart';

/// One cash-movement row, described in plain cashier-facing language
/// per PRD §20 ("Gunakan istilah yang mudah dipahami kasir") rather
/// than raw ledger jargon.
class CashMovementTile extends StatelessWidget {
  final CashMovement movement;
  final Map<String, String> locationNames; // id -> display name, for from/to labels

  const CashMovementTile({super.key, required this.movement, required this.locationNames});

  String get _title {
    switch (movement.type) {
      case CashMovementType.opening:
        return 'Saldo Awal';
      case CashMovementType.cashSale:
        final to = locationNames[movement.toLocationId] ?? 'Dompet';
        return movement.toLocationId == 'loc-store' ? 'Penjualan Cash' : 'Penjualan Cash · $to';
      case CashMovementType.courierDeposit:
        final from = locationNames[movement.fromLocationId] ?? 'Kurir';
        return 'Setoran dari $from';
      case CashMovementType.convertToKasbon:
        final from = locationNames[movement.fromLocationId] ?? 'Kurir';
        return 'Konversi Kasbon · $from';
      case CashMovementType.expense:
        return 'Pengeluaran';
      case CashMovementType.adjustment:
        return 'Penyesuaian';
    }
  }

  IconData get _icon {
    switch (movement.type) {
      case CashMovementType.opening:
        return Icons.wallet_rounded;
      case CashMovementType.cashSale:
        return Icons.point_of_sale_rounded;
      case CashMovementType.courierDeposit:
        return Icons.arrow_downward_rounded;
      case CashMovementType.convertToKasbon:
        return Icons.receipt_long_rounded;
      case CashMovementType.expense:
        return Icons.arrow_upward_rounded;
      case CashMovementType.adjustment:
        return Icons.tune_rounded;
    }
  }

  bool get _isOutflowFromStore => movement.fromLocationId == 'loc-store';

  @override
  Widget build(BuildContext context) {
    final isPositiveForStore = movement.toLocationId == 'loc-store' || (movement.toLocationId == null && movement.fromLocationId != 'loc-store');
    final color = _isOutflowFromStore ? AppColors.danger : (isPositiveForStore ? AppColors.success : AppColors.textSecondary);
    final sign = _isOutflowFromStore ? '-' : (isPositiveForStore ? '+' : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Icon(_icon, size: 16, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(
                  DateFormat('d MMM, HH:mm', 'id_ID').format(movement.createdAt),
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Text('$sign${formatRupiah(movement.amount)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
