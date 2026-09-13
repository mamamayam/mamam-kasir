import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/app_database.dart';
import '../../dompet/application/dompet_repository.dart';
import '../../menu_management/application/menu_management_repository.dart';
import '../../menu_management/domain/menu_management_models.dart';
import '../domain/cart_item.dart';
import '../domain/customer.dart';
import '../domain/order_models.dart';
import '../domain/transaction.dart' as txn;
import '../domain/voucher.dart';

class PosRepository {
  final _uuid = const Uuid();
  final MenuManagementRepository _menuRepository = MenuManagementRepository();
  final DompetRepository _dompetRepository = DompetRepository();

  Future<Database> get _db => AppDatabase.instance.database;

  // --- Menu / catalog (delegates to Menu Management's repository so
  // there is one source of truth for menu/category/variant data) ---

  Future<List<MenuItem>> getActiveMenuItems() async {
    final items = await _menuRepository.getMenuItems();
    return items.where((i) => i.isActive).toList();
  }

  Future<List<VariantGroup>> getVariantGroups() => _menuRepository.getVariantGroups();

  // --- Customers ---

  Future<List<Customer>> getActiveCustomers() async {
    final db = await _db;
    final rows = await db.query('customers', where: 'is_active = 1', orderBy: 'name ASC');
    return rows
        .map((r) => Customer(
              id: r['id'] as String,
              name: r['name'] as String,
              phone: r['phone'] as String?,
              isActive: true,
            ))
        .toList();
  }

  Future<Customer> createCustomer({required String name, String? phone}) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();
    await db.insert('customers', {
      'id': id,
      'name': name,
      'phone': phone,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    return Customer(id: id, name: name, phone: phone, isActive: true);
  }

  // --- Vouchers ---

  Future<Voucher?> findVoucherByCode(String code) async {
    final db = await _db;
    final rows = await db.query(
      'vouchers',
      where: 'code = ? AND is_active = 1',
      whereArgs: [code],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Voucher(
      id: r['id'] as String,
      code: r['code'] as String,
      discountType: (r['discount_type'] as String) == 'percent' ? VoucherDiscountType.percent : VoucherDiscountType.fixed,
      discountValue: r['discount_value'] as int,
      minPurchase: r['min_purchase'] as int,
      isActive: true,
    );
  }

  // --- Transactions ---

  /// Persists a completed transaction and its line items. `id` and
  /// `displayNumber` are generated here so the caller (checkout flow)
  /// doesn't need its own ID scheme.
  ///
  /// `cashLocationId`: when the payment is cash (fully or in part —
  /// callers pass this only for the cash portion), this records where
  /// that cash physically ended up (Store Cash, or a specific courier
  /// for Delivery/Ojol) as a Dompet ledger movement — see
  /// [[dompet-prd]]. Left null for non-cash payments, where there is no
  /// physical cash to track.
  Future<txn.Transaction> saveTransaction({
    required txn.TransactionStatus status,
    required OrderType orderType,
    String? customerId,
    String? customerName,
    OjolPlatform? ojolPlatform,
    String? ojolOrderNumber,
    required List<CartItem> items,
    required int subtotal,
    String? voucherId,
    String? voucherCode,
    required int voucherDiscount,
    ManualDiscount? manualDiscount,
    required int manualDiscountAmount,
    required int taxAmount,
    required int serviceAmount,
    required int deliveryFee,
    required int roundingAdjustment,
    required int total,
    String? paymentMethodLabel,
    int? amountPaid,
    int? changeAmount,
    List<SplitPaymentEntry> splitPayments = const [],
    String? cashLocationId,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    final id = _uuid.v4();
    // Short, human-readable presentation ID — not a durable identifier
    // (the UUID is), matching the architecture doc's "Human-readable SB
    // numbers are presentation IDs" note.
    final displayNumber = 'ORD-${id.substring(0, 6).toUpperCase()}';

    await db.insert('transactions', {
      'id': id,
      'display_number': displayNumber,
      'status': status.name,
      'order_type': orderType.label,
      'customer_id': customerId,
      'customer_name': customerName,
      'ojol_platform': ojolPlatform?.label,
      'ojol_order_number': ojolOrderNumber,
      'subtotal': subtotal,
      'voucher_id': voucherId,
      'voucher_code': voucherCode,
      'voucher_discount': voucherDiscount,
      'manual_discount_type': manualDiscount?.type.name,
      'manual_discount_value': manualDiscount?.value,
      'manual_discount_amount': manualDiscountAmount,
      'tax_amount': taxAmount,
      'service_amount': serviceAmount,
      'delivery_fee': deliveryFee,
      'rounding_adjustment': roundingAdjustment,
      'total': total,
      'payment_method': paymentMethodLabel,
      'amount_paid': amountPaid,
      'change_amount': changeAmount,
      'split_payments_json': splitPayments.isEmpty
          ? null
          : jsonEncode(splitPayments.map((p) => {'method': p.method.label, 'amount': p.amount}).toList()),
      'created_at': now.toIso8601String(),
      'paid_at': status == txn.TransactionStatus.paid ? now.toIso8601String() : null,
    });

    for (final item in items) {
      await db.insert('transaction_items', {
        'id': _uuid.v4(),
        'transaction_id': id,
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

    // Dompet ledger entry — per [[dompet-prd]], a Paid status does not
    // by itself mean the cash is in Store Cash; the cash amount goes to
    // wherever the cashier recorded it (Store Cash or a courier). Only
    // recorded for paid, cash-involving checkouts where a location was
    // actually chosen — non-cash payments have no physical cash to
    // track, and this repository has no opinion on where cash "should"
    // go by default.
    if (cashLocationId != null && status == txn.TransactionStatus.paid && amountPaid != null && amountPaid > 0) {
      await _dompetRepository.recordCashSale(
        toLocationId: cashLocationId,
        amount: amountPaid,
        transactionId: id,
      );
    }

    return txn.Transaction(
      id: id,
      displayNumber: displayNumber,
      status: status,
      orderType: orderType,
      customerId: customerId,
      customerName: customerName,
      ojolPlatform: ojolPlatform,
      ojolOrderNumber: ojolOrderNumber,
      items: items,
      subtotal: subtotal,
      voucherId: voucherId,
      voucherCode: voucherCode,
      voucherDiscount: voucherDiscount,
      manualDiscount: manualDiscount,
      manualDiscountAmount: manualDiscountAmount,
      taxAmount: taxAmount,
      serviceAmount: serviceAmount,
      deliveryFee: deliveryFee,
      roundingAdjustment: roundingAdjustment,
      total: total,
      paymentMethodLabel: paymentMethodLabel,
      amountPaid: amountPaid,
      changeAmount: changeAmount,
      splitPayments: splitPayments,
      createdAt: now,
      paidAt: status == txn.TransactionStatus.paid ? now : null,
    );
  }
}
