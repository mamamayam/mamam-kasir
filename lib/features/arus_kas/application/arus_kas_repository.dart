import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/app_database.dart';
import '../../dompet/application/dompet_repository.dart';
import '../domain/arus_kas_models.dart';

class ArusKasRepository {
  final _uuid = const Uuid();
  final DompetRepository _dompetRepository;

  ArusKasRepository(this._dompetRepository);

  Future<Database> get _db => AppDatabase.instance.database;

  /// Distinct categories used so far, per direction — feeds the
  /// editable Kategori combobox (pick existing or type new).
  Future<List<String>> getCategories(ArusKasDirection direction) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT DISTINCT category FROM cash_expenses WHERE direction = ? ORDER BY category ASC',
      [direction.dbValue],
    );
    return rows.map((r) => r['category'] as String).toList();
  }

  Future<List<ArusKasEntry>> getEntries({
    required ArusKasDirection direction,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;
    final where = StringBuffer('direction = ?');
    final args = <Object?>[direction.dbValue];

    if (from != null) {
      where.write(' AND transaction_date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.write(' AND transaction_date <= ?');
      args.add(to.toIso8601String());
    }

    final rows = await db.query('cash_expenses', where: where.toString(), whereArgs: args, orderBy: 'transaction_date DESC, created_at DESC');

    // Join cash_locations for display names in one pass rather than
    // per-row, since the location set is small.
    final locationRows = await db.query('cash_locations');
    final locationNames = {for (final l in locationRows) l['id'] as String: l['name'] as String};

    return rows.map((row) => _entryFromRow(row, locationNames)).toList();
  }

  ArusKasEntry _entryFromRow(Map<String, Object?> row, Map<String, String> locationNames) {
    final sourceLocationId = row['source_location_id'] as String?;
    return ArusKasEntry(
      id: row['id'] as String,
      direction: ArusKasDirectionDb.fromDbValue(row['direction'] as String),
      category: row['category'] as String,
      amount: row['amount'] as int,
      transactionDate: DateTime.parse(row['transaction_date'] as String),
      sourceLocationId: sourceLocationId,
      sourceLocationName: sourceLocationId == null ? null : locationNames[sourceLocationId],
      fundingSource: ArusKasFundingSourceDb.fromDbValue(row['funding_source'] as String),
      storeOrSupplierName: row['store_or_supplier_name'] as String?,
      detail: row['detail'] as String?,
      cashMovementId: row['cash_movement_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      createdBy: row['created_by'] as String?,
    );
  }

  /// Creates an Arus Kas entry. When [fundingSource] is
  /// [ArusKasFundingSource.cashLocation], also writes a matching
  /// cash_movement (income for Pemasukan, expense for Pengeluaran) via
  /// [DompetRepository] so Dompet balances and Arus Kas totals stay
  /// berkesinambungan — 'Non-Tunai' entries skip this since they never
  /// touch a physical cash balance.
  Future<void> addEntry({
    required ArusKasDirection direction,
    required String category,
    required int amount,
    required DateTime transactionDate,
    required ArusKasFundingSource fundingSource,
    String? sourceLocationId,
    String? storeOrSupplierName,
    String? detail,
  }) async {
    if (fundingSource == ArusKasFundingSource.cashLocation && sourceLocationId == null) {
      throw ArgumentError('sourceLocationId is required when fundingSource is cashLocation');
    }

    final db = await _db;
    String? cashMovementId;

    if (fundingSource == ArusKasFundingSource.cashLocation) {
      cashMovementId = direction == ArusKasDirection.pengeluaran
          ? await _dompetRepository.recordCashExpense(
              fromLocationId: sourceLocationId!,
              amount: amount,
              reason: category,
            )
          : await _dompetRepository.recordCashIncome(
              toLocationId: sourceLocationId!,
              amount: amount,
              reason: category,
            );
    }

    await db.insert('cash_expenses', {
      'id': _uuid.v4(),
      'direction': direction.dbValue,
      'category': category,
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String(),
      'source_location_id': fundingSource == ArusKasFundingSource.cashLocation ? sourceLocationId : null,
      'funding_source': fundingSource.dbValue,
      'store_or_supplier_name': direction == ArusKasDirection.pengeluaran ? storeOrSupplierName : null,
      'detail': detail,
      'cash_movement_id': cashMovementId,
      'created_at': DateTime.now().toIso8601String(),
      'created_by': null,
    });
  }

  /// Deletes an entry, and its matching cash_movement if it had one —
  /// keeping Dompet balances and Arus Kas in sync after an undo. This
  /// is a user-facing "remove this entry" action, distinct from the
  /// ledger's general immutability (see DompetRepository.deleteCashMovement).
  Future<void> deleteEntry(String id) async {
    final db = await _db;
    final rows = await db.query('cash_expenses', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return;

    final cashMovementId = rows.first['cash_movement_id'] as String?;
    if (cashMovementId != null) {
      await _dompetRepository.deleteCashMovement(cashMovementId);
    }
    await db.delete('cash_expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getTotal({required ArusKasDirection direction, DateTime? from, DateTime? to}) async {
    final db = await _db;
    final where = StringBuffer('direction = ?');
    final args = <Object?>[direction.dbValue];
    if (from != null) {
      where.write(' AND transaction_date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.write(' AND transaction_date <= ?');
      args.add(to.toIso8601String());
    }
    final result = await db.rawQuery('SELECT COALESCE(SUM(amount), 0) as total FROM cash_expenses WHERE $where', args);
    return result.first['total'] as int;
  }
}
