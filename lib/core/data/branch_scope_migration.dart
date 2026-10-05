import 'package:sqflite_sqlcipher/sqflite.dart';

/// DB v14 (Tahap B / B2): every operational table learns *which branch*
/// a row belongs to, and `transactions` learns *who* created it.
///
/// Kept in its own file, taking a plain [DatabaseExecutor] (a Database *or* a Transaction), so the migration can
/// be exercised directly against a frozen v13 snapshot (see
/// test/app_database_branch_scope_test.dart) instead of only through the
/// app's singleton database.
///
/// Guarantees, in the order they matter:
/// * **Additive only** — nullable `ADD COLUMN`s plus one `UPDATE` of the
///   new column. Nothing is dropped, recreated or rewritten, so every
///   pre-existing value (including every Rupiah amount) is untouched.
/// * **Idempotent** — a column is only added when `PRAGMA table_info`
///   says it is missing, and the backfill only touches rows whose
///   `branch_id IS NULL`. Safe on a database that is already partly
///   migrated, and safe to run twice.
/// * **Atomic** — sqflite runs `onUpgrade` inside one transaction, so a
///   thrown error rolls the whole step back and the DB stays at v13.
/// * **No invented history** — legacy rows are attributed to the one
///   branch that has ever existed ([legacyBranchId]); legacy
///   `created_by` stays NULL (the real creator is unknown).
class BranchScopeMigration {
  BranchScopeMigration._();

  /// The only branch that existed before Tahap B ("Mamam Ayam", seeded in
  /// `_seedDemoData`; Manajemen Cabang can toggle branches but never
  /// create or delete one). Every pre-v14 operational row belongs to it.
  static const legacyBranchId = 'branch-cibarusah';

  /// Tables that get `branch_id` (all of them operational: sales, money
  /// movements, closings, cash locations, opname). Child tables
  /// (`transaction_items`, `stock_opname_items`) inherit via their
  /// parent; masters (menu, customers, ingredients, ...) stay global.
  static const branchScopedTables = <String>[
    'transactions',
    'cash_expenses',
    'cash_movements',
    'dompet_closings',
    'cash_locations',
    'stock_opname_sessions',
  ];

  /// The v13 -> v14 upgrade step.
  static Future<void> migrate(DatabaseExecutor db) async {
    for (final table in branchScopedTables) {
      await _addColumnIfMissing(db, table, 'branch_id', 'TEXT REFERENCES branches (id)');
    }
    // The other five tables already have `created_by` (always NULL until
    // Tahap B3 starts filling it); `transactions` never had one.
    await _addColumnIfMissing(db, 'transactions', 'created_by', 'TEXT REFERENCES users (id)');

    await backfillLegacyBranch(db);
    await createIndexes(db);
  }

  /// Attributes every row that has no branch yet to [legacyBranchId].
  ///
  /// Also called at the end of a fresh install's `_onCreate`, so seeded
  /// demo rows are attributed the same way.
  ///
  /// Throws (aborting and rolling back the surrounding upgrade) if there
  /// is something to attribute but the legacy branch row is missing:
  /// writing a `branch_id` that points at nothing would silently orphan
  /// financial data, which is worse than a loud, retryable failure.
  static Future<void> backfillLegacyBranch(DatabaseExecutor db) async {
    var pending = 0;
    for (final table in branchScopedTables) {
      final rows = await db.rawQuery('SELECT COUNT(*) FROM $table WHERE branch_id IS NULL');
      pending += Sqflite.firstIntValue(rows) ?? 0;
    }
    if (pending == 0) return;

    final legacy = await db.query(
      'branches',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [legacyBranchId],
      limit: 1,
    );
    if (legacy.isEmpty) {
      throw StateError(
        'Migrasi cabang dibatalkan: $pending baris data operasional perlu '
        'dimasukkan ke cabang "$legacyBranchId", tetapi cabang itu tidak '
        'ditemukan di tabel branches. Tidak ada data yang diubah.',
      );
    }

    for (final table in branchScopedTables) {
      await db.rawUpdate('UPDATE $table SET branch_id = ? WHERE branch_id IS NULL', [legacyBranchId]);
    }
  }

  /// Indexes for the per-branch + per-date reads. `IF NOT EXISTS`, so
  /// safe from both `_onCreate` and the upgrade.
  static Future<void> createIndexes(DatabaseExecutor db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_branch_paid_at ON transactions (branch_id, paid_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cash_expenses_branch_date ON cash_expenses (branch_id, transaction_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cash_movements_branch_created_at ON cash_movements (branch_id, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_dompet_closings_branch_period_end ON dompet_closings (branch_id, period_end)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cash_locations_branch ON cash_locations (branch_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_opname_sessions_branch_created_at ON stock_opname_sessions (branch_id, created_at)');
  }

  /// `ALTER TABLE ... ADD COLUMN`, but only when [column] is not already
  /// there. SQLite allows a `REFERENCES` clause on an added column as
  /// long as its default is NULL (it is), which is why the FK is
  /// declared here rather than needing a table rebuild.
  static Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }
}
