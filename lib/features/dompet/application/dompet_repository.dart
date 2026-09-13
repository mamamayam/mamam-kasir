import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/app_database.dart';
import '../domain/dompet_models.dart';

class DompetRepository {
  final _uuid = const Uuid();

  Future<Database> get _db => AppDatabase.instance.database;

  // --- Cash locations ---

  Future<List<CashLocation>> getCashLocations({CashLocationType? type}) async {
    final db = await _db;
    final rows = await db.query(
      'cash_locations',
      where: type == null ? 'is_active = 1' : 'is_active = 1 AND type = ?',
      whereArgs: type == null ? null : [type.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(_locationFromRow).toList();
  }

  Future<CashLocation?> getCashLocation(String id) async {
    final db = await _db;
    final rows = await db.query('cash_locations', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _locationFromRow(rows.first);
  }

  CashLocation _locationFromRow(Map<String, Object?> row) {
    return CashLocation(
      id: row['id'] as String,
      type: (row['type'] as String) == 'store' ? CashLocationType.store : CashLocationType.courier,
      name: row['name'] as String,
      staffId: row['staff_id'] as String?,
      isActive: (row['is_active'] as int) == 1,
    );
  }

  /// Balance is always computed as SUM(amount) where this location is
  /// the destination, minus SUM(amount) where it's the source — never a
  /// stored/mutated field. This is the ledger principle the Dompet PRD
  /// requires (§26: "Jangan membuat modul Dompet sebagai sistem saldo
  /// sederhana... balance += cash").
  Future<int> getLocationBalance(String locationId) async {
    final db = await _db;

    final inResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM cash_movements WHERE to_location_id = ?',
      [locationId],
    );
    final outResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM cash_movements WHERE from_location_id = ?',
      [locationId],
    );

    final inTotal = inResult.first['total'] as int;
    final outTotal = outResult.first['total'] as int;
    return inTotal - outTotal;
  }

  Future<List<CashLocationBalance>> getCourierBalancesWithOutstanding() async {
    final couriers = await getCashLocations(type: CashLocationType.courier);
    final balances = <CashLocationBalance>[];
    for (final courier in couriers) {
      final balance = await getLocationBalance(courier.id);
      if (balance > 0) {
        balances.add(CashLocationBalance(location: courier, balance: balance));
      }
    }
    return balances;
  }

  Future<DompetSummary> getSummary() async {
    final storeBalance = await getLocationBalance('loc-store');
    final courierBalances = await getCourierBalancesWithOutstanding();
    final totalCourierOutstanding = courierBalances.fold<int>(0, (sum, b) => sum + b.balance);
    final totalKasbon = await getTotalOutstandingKasbon();

    return DompetSummary(
      storeCashBalance: storeBalance,
      totalCourierOutstanding: totalCourierOutstanding,
      totalKasbonOutstanding: totalKasbon,
      courierBalances: courierBalances,
    );
  }

  // --- Cash movements ---

  Future<List<CashMovement>> getMovements({String? locationId, int limit = 100}) async {
    final db = await _db;
    final rows = await db.query(
      'cash_movements',
      where: locationId == null ? null : 'from_location_id = ? OR to_location_id = ?',
      whereArgs: locationId == null ? null : [locationId, locationId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(_movementFromRow).toList();
  }

  CashMovement _movementFromRow(Map<String, Object?> row) {
    return CashMovement(
      id: row['id'] as String,
      type: CashMovementType.values.firstWhere((t) => t.name == row['type'], orElse: () => CashMovementType.adjustment),
      fromLocationId: row['from_location_id'] as String?,
      toLocationId: row['to_location_id'] as String?,
      amount: row['amount'] as int,
      referenceTransactionId: row['reference_transaction_id'] as String?,
      referenceKasbonId: row['reference_kasbon_id'] as String?,
      reason: row['reason'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      createdBy: row['created_by'] as String?,
    );
  }

  /// Records a cash sale entering a location's ledger (Store Cash for
  /// non-delivery/non-cash payments and dine-in/takeaway cash, or a
  /// courier location when the cashier records that a courier is
  /// holding the cash for a delivery/Ojol cash payment). Called from
  /// checkout — see PosRepository.saveTransaction, which calls this
  /// after the transaction itself is saved.
  Future<void> recordCashSale({
    required String toLocationId,
    required int amount,
    required String transactionId,
  }) async {
    final db = await _db;
    await db.insert('cash_movements', {
      'id': _uuid.v4(),
      'type': CashMovementType.cashSale.name,
      'from_location_id': null,
      'to_location_id': toLocationId,
      'amount': amount,
      'reference_transaction_id': transactionId,
      'reference_kasbon_id': null,
      'reason': null,
      'created_at': DateTime.now().toIso8601String(),
      'created_by': null,
    });
  }

  /// "Sudah Disetor" — courier hands cash to the store. Per PRD §5,
  /// this is a cash movement only, never a new sales transaction.
  /// Supports partial settlement (PRD §10): amount may be less than the
  /// courier's full outstanding balance.
  Future<void> recordCourierDeposit({
    required String courierLocationId,
    required int amount,
  }) async {
    final db = await _db;
    await db.insert('cash_movements', {
      'id': _uuid.v4(),
      'type': CashMovementType.courierDeposit.name,
      'from_location_id': courierLocationId,
      'to_location_id': 'loc-store',
      'amount': amount,
      'reference_transaction_id': null,
      'reference_kasbon_id': null,
      'reason': 'Setoran kurir',
      'created_at': DateTime.now().toIso8601String(),
      'created_by': null,
    });
  }

  // --- Kasbon ---

  Future<List<Kasbon>> getKasbonList({KasbonStatus? status}) async {
    final db = await _db;
    final rows = await db.query(
      'kasbon',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status.name],
      orderBy: 'created_at DESC',
    );

    final list = <Kasbon>[];
    for (final row in rows) {
      final repaymentRows = await db.query('kasbon_repayments', where: 'kasbon_id = ?', whereArgs: [row['id']], orderBy: 'created_at ASC');
      list.add(_kasbonFromRow(row, repaymentRows));
    }
    return list;
  }

  Kasbon _kasbonFromRow(Map<String, Object?> row, List<Map<String, Object?>> repaymentRows) {
    return Kasbon(
      id: row['id'] as String,
      staffId: row['staff_id'] as String?,
      courierLocationId: row['courier_location_id'] as String,
      staffName: row['staff_name'] as String,
      amount: row['amount'] as int,
      remainingBalance: row['remaining_balance'] as int,
      source: row['source'] as String,
      status: KasbonStatus.values.firstWhere((s) => s.name == row['status'], orElse: () => KasbonStatus.outstanding),
      createdAt: DateTime.parse(row['created_at'] as String),
      createdBy: row['created_by'] as String?,
      repayments: repaymentRows
          .map((r) => KasbonRepayment(
                id: r['id'] as String,
                kasbonId: r['kasbon_id'] as String,
                amount: r['amount'] as int,
                note: r['note'] as String?,
                createdAt: DateTime.parse(r['created_at'] as String),
                createdBy: r['created_by'] as String?,
              ))
          .toList(),
    );
  }

  Future<int> getTotalOutstandingKasbon() async {
    final db = await _db;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(remaining_balance), 0) as total FROM kasbon WHERE status != 'paid'",
    );
    return result.first['total'] as int;
  }

  /// "Jadikan Kasbon" — converts a courier's outstanding cash into a
  /// Staff Debt record. Per PRD §7/§13, this creates a cash_movement
  /// (courier -> nowhere, cash leaves the courier's ledger balance) AND
  /// a kasbon record, but never touches the original sales
  /// transaction(s) that produced the outstanding cash.
  Future<Kasbon> convertToKasbon({
    required String courierLocationId,
    required String courierName,
    required int amount,
  }) async {
    final db = await _db;
    final kasbonId = _uuid.v4();
    final now = DateTime.now().toIso8601String();

    await db.insert('kasbon', {
      'id': kasbonId,
      'staff_id': null,
      'courier_location_id': courierLocationId,
      'staff_name': courierName,
      'amount': amount,
      'remaining_balance': amount,
      'source': 'Unsettled Courier Cash',
      'status': KasbonStatus.outstanding.name,
      'created_at': now,
      'created_by': null,
    });

    await db.insert('cash_movements', {
      'id': _uuid.v4(),
      'type': CashMovementType.convertToKasbon.name,
      'from_location_id': courierLocationId,
      'to_location_id': null,
      'amount': amount,
      'reference_transaction_id': null,
      'reference_kasbon_id': kasbonId,
      'reason': 'Konversi outstanding kurir menjadi kasbon',
      'created_at': now,
      'created_by': null,
    });

    return (await getKasbonList()).firstWhere((k) => k.id == kasbonId);
  }

  /// Records a repayment against a kasbon (e.g. a payroll deduction,
  /// once a Payroll module exists, or a manual repayment now). Updates
  /// remaining_balance/status derived from the repayment history, per
  /// PRD §9 — never silently marks paid.
  Future<void> recordKasbonRepayment({
    required String kasbonId,
    required int amount,
    String? note,
  }) async {
    final db = await _db;
    final kasbonRows = await db.query('kasbon', where: 'id = ?', whereArgs: [kasbonId], limit: 1);
    if (kasbonRows.isEmpty) return;

    final currentRemaining = kasbonRows.first['remaining_balance'] as int;
    final newRemaining = (currentRemaining - amount).clamp(0, currentRemaining);
    final newStatus = newRemaining == 0
        ? KasbonStatus.paid.name
        : (newRemaining < (kasbonRows.first['amount'] as int) ? KasbonStatus.partiallyPaid.name : KasbonStatus.outstanding.name);

    await db.insert('kasbon_repayments', {
      'id': _uuid.v4(),
      'kasbon_id': kasbonId,
      'amount': amount,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
      'created_by': null,
    });

    await db.update(
      'kasbon',
      {'remaining_balance': newRemaining, 'status': newStatus},
      where: 'id = ?',
      whereArgs: [kasbonId],
    );
  }
}
