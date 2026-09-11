import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../../pos/domain/cart_item.dart';
import '../../pos/domain/order_models.dart';
import '../../pos/domain/transaction.dart' as txn;

/// Reads transaction history and handles "Batalkan Transaksi" (cancel).
/// Per PRD, transactions are never hard-deleted — retention/deletion
/// permission is explicitly UNSPECIFIED there, so no delete method
/// exists here at all, not even a disabled one.
class HistoryRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<List<txn.Transaction>> getTransactions() async {
    final db = await _db;
    final rows = await db.query('transactions', orderBy: 'created_at DESC');

    final transactions = <txn.Transaction>[];
    for (final row in rows) {
      final itemRows = await db.query('transaction_items', where: 'transaction_id = ?', whereArgs: [row['id']]);
      transactions.add(_transactionFromRow(row, itemRows));
    }
    return transactions;
  }

  txn.Transaction _transactionFromRow(Map<String, Object?> row, List<Map<String, Object?>> itemRows) {
    final items = itemRows.map((r) {
      final variantJson = r['variant_selected_json'] as String?;
      return CartItem(
        cartItemId: r['id'] as String,
        menuItemId: r['menu_item_id'] as String,
        name: r['name'] as String,
        variantName: r['variant_name'] as String?,
        variantSelectedOptions: variantJson == null
            ? const {}
            : (jsonDecode(variantJson) as Map<String, dynamic>).map((k, v) => MapEntry(k, List<String>.from(v as List))),
        price: r['price'] as int,
        hpp: r['hpp'] as int,
        qty: r['qty'] as int,
        note: (r['note'] as String?) ?? '',
      );
    }).toList();

    final splitJson = row['split_payments_json'] as String?;
    final splitPayments = splitJson == null
        ? <SplitPaymentEntry>[]
        : (jsonDecode(splitJson) as List)
            .map((e) => SplitPaymentEntry(
                  method: PaymentMethod.values.firstWhere((m) => m.label == e['method'], orElse: () => PaymentMethod.tunai),
                  amount: e['amount'] as int,
                ))
            .toList();

    final manualDiscountType = row['manual_discount_type'] as String?;

    return txn.Transaction(
      id: row['id'] as String,
      displayNumber: row['display_number'] as String,
      status: txn.TransactionStatus.values.firstWhere((s) => s.name == row['status'], orElse: () => txn.TransactionStatus.paid),
      orderType: OrderType.values.firstWhere((t) => t.label == row['order_type'], orElse: () => OrderType.takeaway),
      customerId: row['customer_id'] as String?,
      customerName: row['customer_name'] as String?,
      ojolPlatform: row['ojol_platform'] == null
          ? null
          : OjolPlatform.values.firstWhere((p) => p.label == row['ojol_platform'], orElse: () => OjolPlatform.gofood),
      ojolOrderNumber: row['ojol_order_number'] as String?,
      items: items,
      subtotal: row['subtotal'] as int,
      voucherId: row['voucher_id'] as String?,
      voucherCode: row['voucher_code'] as String?,
      voucherDiscount: row['voucher_discount'] as int,
      manualDiscount: manualDiscountType == null
          ? null
          : ManualDiscount(
              type: manualDiscountType == 'percent' ? ManualDiscountType.percent : ManualDiscountType.fixed,
              value: row['manual_discount_value'] as int? ?? 0,
            ),
      manualDiscountAmount: row['manual_discount_amount'] as int,
      taxAmount: row['tax_amount'] as int,
      serviceAmount: row['service_amount'] as int,
      deliveryFee: row['delivery_fee'] as int,
      roundingAdjustment: row['rounding_adjustment'] as int,
      total: row['total'] as int,
      paymentMethodLabel: row['payment_method'] as String?,
      amountPaid: row['amount_paid'] as int?,
      changeAmount: row['change_amount'] as int?,
      splitPayments: splitPayments,
      createdAt: DateTime.parse(row['created_at'] as String),
      paidAt: row['paid_at'] == null ? null : DateTime.parse(row['paid_at'] as String),
      canceledAt: row['canceled_at'] == null ? null : DateTime.parse(row['canceled_at'] as String),
      cancelReason: row['cancel_reason'] as String?,
    );
  }

  /// "Batalkan Transaksi" per PRD: canceled transactions remain in
  /// history (shown red by the UI), are excluded from omzet
  /// calculations, and cannot be canceled or edited again once
  /// canceled. No refund transaction is created — this only flips
  /// status/canceled_at/cancel_reason on the existing row.
  Future<void> cancelTransaction(String transactionId, {String? reason}) async {
    final db = await _db;
    await db.update(
      'transactions',
      {
        'status': txn.TransactionStatus.canceled.name,
        'canceled_at': DateTime.now().toIso8601String(),
        'cancel_reason': reason,
      },
      where: 'id = ? AND status != ?',
      whereArgs: [transactionId, txn.TransactionStatus.canceled.name],
    );
  }
}
