import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/app_database.dart';
import '../../dompet/application/dompet_repository.dart';
import '../../pos/domain/cart_item.dart';
import '../../pos/domain/order_models.dart';
import '../../pos/domain/transaction.dart' as txn;

/// Reads transaction history and handles "Batalkan Transaksi" (cancel).
/// Per PRD, transactions are never hard-deleted — retention/deletion
/// permission is explicitly UNSPECIFIED there, so no delete method
/// exists here at all, not even a disabled one.
class HistoryRepository {
  final DompetRepository _dompetRepository = DompetRepository();

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

  /// "Edit Pesanan" — overwrites an `open` (Diproses) transaction's
  /// items and recomputed totals in place. This updates the SAME row
  /// (matching the business rule that editing a Diproses order never
  /// creates a second transaction) — line items are replaced wholesale
  /// (delete + re-insert) rather than diffed, since the cart draft that
  /// produces [items] already represents the full new state, not a
  /// delta. Only `open` transactions can be edited (per PRD: paid/
  /// canceled transactions are immutable) — the `where` clause enforces
  /// this the same way [cancelTransaction] guards its own status
  /// transition.
  Future<void> updateOpenTransaction({
    required String transactionId,
    required List<CartItem> items,
    required OrderType orderType,
    String? customerId,
    String? customerName,
    required int subtotal,
    String? voucherId,
    String? voucherCode,
    required int voucherDiscount,
    required int manualDiscountAmount,
    required int taxAmount,
    required int serviceAmount,
    required int deliveryFee,
    required int roundingAdjustment,
    required int total,
  }) async {
    final db = await _db;
    final uuid = const Uuid();

    final updated = await db.update(
      'transactions',
      {
        'order_type': orderType.label,
        'customer_id': customerId,
        'customer_name': customerName,
        'subtotal': subtotal,
        'voucher_id': voucherId,
        'voucher_code': voucherCode,
        'voucher_discount': voucherDiscount,
        'manual_discount_amount': manualDiscountAmount,
        'tax_amount': taxAmount,
        'service_amount': serviceAmount,
        'delivery_fee': deliveryFee,
        'rounding_adjustment': roundingAdjustment,
        'total': total,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [transactionId, txn.TransactionStatus.open.name],
    );

    if (updated == 0) return; // not open (anymore) — nothing to edit

    await db.delete('transaction_items', where: 'transaction_id = ?', whereArgs: [transactionId]);
    for (final item in items) {
      await db.insert('transaction_items', {
        'id': uuid.v4(),
        'transaction_id': transactionId,
        'menu_item_id': item.menuItemId,
        'name': item.name,
        'variant_name': item.variantName,
        'variant_selected_json': item.variantSelectedOptions.isEmpty ? null : jsonEncode(item.variantSelectedOptions),
        'price': item.price,
        'hpp': item.hpp,
        'qty': item.qty,
        'note': item.note.isEmpty ? null : item.note,
      });
    }
  }

  /// "Selesaikan Pesanan" — moves an `open` (Diproses) transaction to
  /// `paid`. This is the one place besides checkout itself where a
  /// `cash_movements` row can be created (see [PosRepository.
  /// saveTransaction]'s gating comment) — an `open` transaction never
  /// created one when it was first saved (no payment was recorded yet),
  /// so completing it here is the actual moment the sale counts toward
  /// Dompet/Dashboard/Laporan, matching the business rule that Diproses
  /// orders are excluded from all three until marked done.
  Future<void> completeTransaction(
    String transactionId, {
    required String paymentMethodLabel,
    required int amountPaid,
    String? cashLocationId,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    final updated = await db.update(
      'transactions',
      {
        'status': txn.TransactionStatus.paid.name,
        'paid_at': now,
        'payment_method': paymentMethodLabel,
        'amount_paid': amountPaid,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [transactionId, txn.TransactionStatus.open.name],
    );

    // Guards the same way saveTransaction does: only a real cash
    // location + a positive amount creates a ledger entry. `updated ==
    // 0` means the row wasn't actually `open` (already completed/
    // canceled by something else) — skip the cash movement rather than
    // recording money for a status change that didn't happen.
    if (updated > 0 && cashLocationId != null && amountPaid > 0) {
      await _dompetRepository.recordCashSale(
        toLocationId: cashLocationId,
        amount: amountPaid,
        transactionId: transactionId,
      );
    }
  }
}
