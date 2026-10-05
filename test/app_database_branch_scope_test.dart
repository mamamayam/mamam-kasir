// Tests for AppDatabase's v13->v14 migration (Tahap B / B2): `branch_id`
// on the operational tables and `created_by` on transactions.
//
// IMPORTANT — like test/app_database_auth_test.dart, these need a real
// device or emulator: sqflite_sqlcipher has no host-side (FFI) test mode,
// so plain `flutter test` cannot load the native library. Run them on a
// connected device/emulator. The migration SQL and control flow were
// separately checked against real SQLite with tool/verify_b2_migration.py,
// which uses the very same fixture; THIS FILE has not been run.
//
// The snapshot below is the exact v13 DDL (taken from the v13 revision of
// app_database.dart), frozen here on purpose: the test must keep
// describing v13 even after the app's own schema moves on.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/data/app_database.dart';
import 'package:mamam_kasir/core/data/branch_scope_migration.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

const _v13Ddl = <String>[
  r'''CREATE TABLE users (
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  pin_hash TEXT,
  pin_salt TEXT,
  failed_pin_attempts INTEGER NOT NULL DEFAULT 0,
  locked_at TEXT,
  last_pin_at TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''',
  r'''CREATE TABLE branches (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''',
  r'''CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  display_number TEXT NOT NULL,
  status TEXT NOT NULL, -- 'open' | 'paid' | 'canceled'
  order_type TEXT NOT NULL, -- 'Takeaway' | 'Dine-in' | 'Delivery' | 'Ojol'
  customer_id TEXT,
  customer_name TEXT,
  ojol_platform TEXT,
  ojol_order_number TEXT,
  subtotal INTEGER NOT NULL,
  voucher_id TEXT,
  voucher_code TEXT,
  voucher_discount INTEGER NOT NULL DEFAULT 0,
  manual_discount_type TEXT, -- 'percent' | 'fixed'
  manual_discount_value INTEGER,
  manual_discount_amount INTEGER NOT NULL DEFAULT 0,
  tax_amount INTEGER NOT NULL DEFAULT 0,
  service_amount INTEGER NOT NULL DEFAULT 0,
  delivery_fee INTEGER NOT NULL DEFAULT 0,
  rounding_adjustment INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL,
  payment_method TEXT, -- 'Tunai' | 'QRIS' | 'Transfer' | 'Ojol' | 'Split Payment'
  amount_paid INTEGER,
  change_amount INTEGER,
  split_payments_json TEXT, -- JSON array, only when payment_method = 'Split Payment'
  created_at TEXT NOT NULL,
  paid_at TEXT,
  canceled_at TEXT,
  cancel_reason TEXT
)''',
  r'''CREATE TABLE cash_locations (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL, -- 'store' | 'courier'
  name TEXT NOT NULL, -- 'Dompet Toko' for store, courier's display name otherwise
  staff_id TEXT, -- NULL until the Staff module exists; reserved for backfill
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''',
  r'''CREATE TABLE cash_movements (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL, -- 'cash_sale' | 'courier_deposit' | 'convert_to_kasbon' | 'expense' | 'adjustment' | 'opening'
  from_location_id TEXT, -- NULL for movements that originate cash (e.g. a cash sale entering Store Cash or a courier location)
  to_location_id TEXT, -- NULL for movements that remove cash (e.g. convert_to_kasbon leaves the cash ledger for Staff Debt)
  amount INTEGER NOT NULL,
  reference_transaction_id TEXT, -- links to transactions.id when the movement originates from a sale
  reference_kasbon_id TEXT, -- links to kasbon.id when the movement is a kasbon conversion
  reason TEXT,
  created_at TEXT NOT NULL,
  created_by TEXT, -- NULL until Auth exists; reserved for the acting user's id/name
  FOREIGN KEY (from_location_id) REFERENCES cash_locations (id),
  FOREIGN KEY (to_location_id) REFERENCES cash_locations (id),
  FOREIGN KEY (reference_transaction_id) REFERENCES transactions (id)
)''',
  r'''CREATE TABLE dompet_closings (
  id TEXT PRIMARY KEY,
  period_start TEXT NOT NULL,
  period_end TEXT NOT NULL,
  opening_balance INTEGER NOT NULL,
  cash_sales_total INTEGER NOT NULL,
  courier_deposits_total INTEGER NOT NULL,
  cash_expenses_total INTEGER NOT NULL,
  expected_cash INTEGER NOT NULL,
  counted_cash INTEGER NOT NULL,
  discrepancy INTEGER NOT NULL,
  status TEXT NOT NULL, -- 'closed' | 'overdue_closing'
  note TEXT,
  created_at TEXT NOT NULL,
  created_by TEXT
)''',
  r'''CREATE TABLE cash_expenses (
  id TEXT PRIMARY KEY,
  direction TEXT NOT NULL, -- 'pemasukan' | 'pengeluaran'
  category TEXT NOT NULL,
  amount INTEGER NOT NULL,
  transaction_date TEXT NOT NULL,
  source_location_id TEXT, -- NULL when funding_source = 'non_cash'
  funding_source TEXT NOT NULL, -- 'cash_location' | 'non_cash'
  store_or_supplier_name TEXT, -- Pengeluaran only
  detail TEXT,
  cash_movement_id TEXT, -- NULL for non_cash rows
  created_at TEXT NOT NULL,
  created_by TEXT,
  FOREIGN KEY (source_location_id) REFERENCES cash_locations (id),
  FOREIGN KEY (cash_movement_id) REFERENCES cash_movements (id)
)''',
  r'''CREATE TABLE stock_opname_sessions (
  id TEXT PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'draft',
  created_at TEXT NOT NULL,
  completed_at TEXT,
  created_by TEXT
)''',
];

const _fixture = <String>[
  r'''INSERT INTO branches (id, name, address, phone, is_active, sort_order, created_at, updated_at) VALUES ('branch-cibarusah', 'Mamam Ayam', NULL, NULL, 1, 0, '2026-09-01T00:00:00.000', '2026-09-01T00:00:00.000')''',
  r'''INSERT INTO transactions (id, display_number, status, order_type, customer_name, subtotal, total, payment_method, amount_paid, change_amount, created_at, paid_at) VALUES ('t1', '#001', 'paid', 'Takeaway', 'Pelanggan Umum', 50000, 50000, 'Tunai', 50000, 0, '2026-09-20T10:00:00.000', '2026-09-20T10:00:00.000')''',
  r'''INSERT INTO transactions (id, display_number, status, order_type, subtotal, total, created_at, paid_at, canceled_at, cancel_reason) VALUES ('t2', '#002', 'canceled', 'Delivery', 30000, 30000, '2026-09-21T11:00:00.000', '2026-09-21T11:05:00.000', '2026-09-21T12:00:00.000', 'Salah input')''',
  r'''INSERT INTO transactions (id, display_number, status, order_type, subtotal, total, created_at) VALUES ('t3', '#003', 'open', 'Dine-in', 20000, 20000, '2026-09-22T12:00:00.000')''',
  r'''INSERT INTO cash_locations (id, type, name, is_active, created_at, updated_at) VALUES ('loc-store', 'store', 'Dompet Toko', 1, '2026-09-01T00:00:00.000', '2026-09-01T00:00:00.000')''',
  r'''INSERT INTO cash_locations (id, type, name, is_active, created_at, updated_at) VALUES ('loc-budi', 'courier', 'Budi', 1, '2026-09-01T00:00:00.000', '2026-09-01T00:00:00.000')''',
  r'''INSERT INTO cash_movements (id, type, from_location_id, to_location_id, amount, reference_transaction_id, created_at) VALUES ('m1', 'cash_sale', NULL, 'loc-store', 50000, 't1', '2026-09-20T10:00:01.000')''',
  r'''INSERT INTO cash_movements (id, type, from_location_id, to_location_id, amount, reason, created_at, created_by) VALUES ('m2', 'expense', 'loc-store', NULL, 10000, 'Belanja', '2026-09-20T15:00:00.000', 'legacy-user')''',
  r'''INSERT INTO cash_expenses (id, direction, category, amount, transaction_date, source_location_id, funding_source, store_or_supplier_name, detail, cash_movement_id, created_at) VALUES ('e1', 'pengeluaran', 'Belanja', 10000, '2026-09-20', 'loc-store', 'cash_location', 'Pasar', 'Ayam', 'm2', '2026-09-20T15:00:00.000')''',
  r'''INSERT INTO cash_expenses (id, direction, category, amount, transaction_date, funding_source, created_at, created_by) VALUES ('e2', 'pemasukan', 'Lainnya', 5000, '2026-09-21', 'non_cash', '2026-09-21T09:00:00.000', 'legacy-user')''',
  r'''INSERT INTO dompet_closings (id, period_start, period_end, opening_balance, cash_sales_total, courier_deposits_total, cash_expenses_total, expected_cash, counted_cash, discrepancy, status, created_at) VALUES ('c1', '2026-09-20T00:00:00.000', '2026-09-20T23:59:59.000', 100000, 50000, 0, 10000, 140000, 139000, -1000, 'closed', '2026-09-20T23:59:59.000')''',
  r'''INSERT INTO stock_opname_sessions (id, status, created_at, completed_at) VALUES ('o1', 'completed', '2026-09-01T08:00:00.000', '2026-09-01T09:00:00.000')''',
];

/// Columns that existed at v13, per migrated table. Compared before and
/// after to prove the migration did not alter a single existing value.
const _originalColumns = <String, List<String>>{
  'transactions': ['id', 'display_number', 'status', 'order_type', 'customer_id', 'customer_name', 'ojol_platform', 'ojol_order_number', 'subtotal', 'voucher_id', 'voucher_code', 'voucher_discount', 'manual_discount_type', 'manual_discount_value', 'manual_discount_amount', 'tax_amount', 'service_amount', 'delivery_fee', 'rounding_adjustment', 'total', 'payment_method', 'amount_paid', 'change_amount', 'split_payments_json', 'created_at', 'paid_at', 'canceled_at', 'cancel_reason'],
  'cash_expenses': ['id', 'direction', 'category', 'amount', 'transaction_date', 'source_location_id', 'funding_source', 'store_or_supplier_name', 'detail', 'cash_movement_id', 'created_at', 'created_by'],
  'cash_movements': ['id', 'type', 'from_location_id', 'to_location_id', 'amount', 'reference_transaction_id', 'reference_kasbon_id', 'reason', 'created_at', 'created_by'],
  'dompet_closings': ['id', 'period_start', 'period_end', 'opening_balance', 'cash_sales_total', 'courier_deposits_total', 'cash_expenses_total', 'expected_cash', 'counted_cash', 'discrepancy', 'status', 'note', 'created_at', 'created_by'],
  'cash_locations': ['id', 'type', 'name', 'staff_id', 'is_active', 'created_at', 'updated_at'],
  'stock_opname_sessions': ['id', 'status', 'created_at', 'completed_at', 'created_by'],
};

/// Money column per table, compared before and after.
const _moneyColumns = <String, String>{
  'transactions': 'total',
  'cash_expenses': 'amount',
  'cash_movements': 'amount',
  'dompet_closings': 'counted_cash',
};

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String tempDirPath;
  _FakePathProvider.withPath(this.tempDirPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDirPath;
}

Future<Database> _openSnapshot({bool withFixture = true}) {
  return openDatabase(
    inMemoryDatabasePath,
    version: 13,
    singleInstance: false,
    onCreate: (db, version) async {
      for (final ddl in _v13Ddl) {
        await db.execute(ddl);
      }
      if (withFixture) {
        for (final sql in _fixture) {
          await db.execute(sql);
        }
      }
    },
  );
}

Future<List<String>> _columnNames(DatabaseExecutor db, String table) async {
  final info = await db.rawQuery('PRAGMA table_info($table)');
  return info.map((row) => row['name'] as String).toList();
}

Future<Map<String, List<Map<String, Object?>>>> _captureOriginal(DatabaseExecutor db) async {
  final out = <String, List<Map<String, Object?>>>{};
  for (final entry in _originalColumns.entries) {
    out[entry.key] = await db.rawQuery('SELECT ${entry.value.join(', ')} FROM ${entry.key} ORDER BY id');
  }
  return out;
}

Future<Map<String, List<Object?>>> _moneyTotals(DatabaseExecutor db) async {
  final out = <String, List<Object?>>{};
  for (final entry in _moneyColumns.entries) {
    final rows = await db.rawQuery('SELECT SUM(${entry.value}) AS s, COUNT(*) AS c FROM ${entry.key}');
    out[entry.key] = [rows.first['s'], rows.first['c']];
  }
  return out;
}

Future<int> _count(DatabaseExecutor db, String sql, [List<Object?>? args]) async {
  return Sqflite.firstIntValue(await db.rawQuery(sql, args)) ?? 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const legacy = BranchScopeMigration.legacyBranchId;
  const tables = BranchScopeMigration.branchScopedTables;

  group('v13 -> v14 migration on a frozen v13 snapshot', () {
    late Database db;

    setUp(() async {
      db = await _openSnapshot();
    });

    tearDown(() async {
      await db.close();
    });

    test('adds branch_id (FK -> branches) to all six operational tables and created_by to transactions', () async {
      await db.transaction((txn) => BranchScopeMigration.migrate(txn));

      for (final table in tables) {
        expect(await _columnNames(db, table), contains('branch_id'), reason: table);
        final fks = await db.rawQuery('PRAGMA foreign_key_list($table)');
        expect(
          fks.any((fk) => fk['table'] == 'branches' && fk['from'] == 'branch_id' && fk['to'] == 'id'),
          isTrue,
          reason: '$table.branch_id must reference branches(id)',
        );
      }
      expect(await _columnNames(db, 'transactions'), contains('created_by'));
      final txFks = await db.rawQuery('PRAGMA foreign_key_list(transactions)');
      expect(txFks.any((fk) => fk['table'] == 'users' && fk['from'] == 'created_by'), isTrue);
    });

    test('keeps every pre-existing value byte-identical and money totals unchanged', () async {
      final before = await _captureOriginal(db);
      final totalsBefore = await _moneyTotals(db);

      await db.transaction((txn) => BranchScopeMigration.migrate(txn));

      expect(await _captureOriginal(db), equals(before));
      expect(await _moneyTotals(db), equals(totalsBefore));
    });

    test('attributes every legacy row to the legacy branch and does not touch created_by', () async {
      await db.transaction((txn) => BranchScopeMigration.migrate(txn));

      for (final table in tables) {
        expect(await _count(db, 'SELECT COUNT(*) FROM $table WHERE branch_id IS NULL'), 0, reason: table);
        expect(await _count(db, 'SELECT COUNT(*) FROM $table WHERE branch_id <> ?', [legacy]), 0, reason: table);
        expect(
          await _count(db, 'SELECT COUNT(*) FROM $table WHERE branch_id IS NOT NULL AND branch_id NOT IN (SELECT id FROM branches)'),
          0,
          reason: '$table has an orphan branch_id',
        );
      }
      // Legacy creator is unknown: stays NULL (never invented) ...
      expect(await _count(db, 'SELECT COUNT(*) FROM transactions WHERE created_by IS NOT NULL'), 0);
      expect(await _count(db, 'SELECT COUNT(*) FROM cash_movements WHERE created_by IS NULL'), 1);
      // ... and a value that was already there is never overwritten.
      expect(await _count(db, "SELECT COUNT(*) FROM cash_expenses WHERE id = 'e2' AND created_by = 'legacy-user'"), 1);
      expect(await _count(db, "SELECT COUNT(*) FROM cash_movements WHERE id = 'm2' AND created_by = 'legacy-user'"), 1);
    });

    test('is idempotent: running the migration twice changes nothing and does not throw', () async {
      await db.transaction((txn) => BranchScopeMigration.migrate(txn));
      final afterFirst = await _captureOriginal(db);

      await db.transaction((txn) => BranchScopeMigration.migrate(txn));

      expect(await _captureOriginal(db), equals(afterFirst));
      for (final table in tables) {
        final names = await _columnNames(db, table);
        expect(names.where((n) => n == 'branch_id').length, 1, reason: '$table.branch_id must exist exactly once');
      }
    });

    test('completes on a partly migrated database without overwriting rows that already have a branch', () async {
      await db.execute("INSERT INTO branches (id, name, is_active, sort_order, created_at, updated_at) VALUES ('branch-other', 'Lain', 1, 1, 'x', 'x')");
      await db.execute('ALTER TABLE transactions ADD COLUMN branch_id TEXT');
      await db.execute('ALTER TABLE cash_expenses ADD COLUMN branch_id TEXT');
      await db.execute("UPDATE transactions SET branch_id = 'branch-other' WHERE id = 't2'");
      await db.execute("UPDATE transactions SET branch_id = '$legacy' WHERE id = 't1'");

      await db.transaction((txn) => BranchScopeMigration.migrate(txn));

      final rows = await db.rawQuery('SELECT id, branch_id FROM transactions ORDER BY id');
      expect({for (final r in rows) r['id']: r['branch_id']}, {'t1': legacy, 't2': 'branch-other', 't3': legacy});
      for (final table in tables) {
        expect(await _count(db, 'SELECT COUNT(*) FROM $table WHERE branch_id IS NULL'), 0, reason: table);
      }
    });

    test('aborts and rolls back (columns included) when the legacy branch is missing but rows need it', () async {
      await db.delete('branches', where: 'id = ?', whereArgs: [legacy]);
      final before = await _captureOriginal(db);

      await expectLater(
        db.transaction((txn) => BranchScopeMigration.migrate(txn)),
        throwsA(isA<StateError>()),
      );

      for (final table in tables) {
        expect(await _columnNames(db, table), isNot(contains('branch_id')), reason: '$table must be back at v13');
      }
      expect(await _columnNames(db, 'transactions'), isNot(contains('created_by')));
      expect(await _captureOriginal(db), equals(before));
    });

    test('creates the per-branch indexes', () async {
      await db.transaction((txn) => BranchScopeMigration.migrate(txn));

      final rows = await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'index'");
      final names = rows.map((r) => r['name']).toSet();
      expect(names, containsAll(<String>[
        'idx_transactions_branch_paid_at',
        'idx_cash_expenses_branch_date',
        'idx_cash_movements_branch_created_at',
        'idx_dompet_closings_branch_period_end',
        'idx_cash_locations_branch',
        'idx_stock_opname_sessions_branch_created_at',
      ]));
    });
  });

  test('does not abort when there is nothing to attribute (empty tables, no legacy branch row)', () async {
    final db = await _openSnapshot(withFixture: false);
    addTearDown(db.close);

    await db.transaction((txn) => BranchScopeMigration.migrate(txn));

    for (final table in tables) {
      expect(await _columnNames(db, table), contains('branch_id'), reason: table);
    }
  });

  group('fresh install (onCreate) at v14', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mamam_kasir_test_');
      PathProviderPlatform.instance = _FakePathProvider.withPath(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates the v14 schema and leaves no seeded row without a branch', () async {
      final db = await AppDatabase.instance.database;

      expect(await _count(db, 'PRAGMA user_version'), 14);
      for (final table in tables) {
        expect(await _columnNames(db, table), contains('branch_id'), reason: table);
        expect(await _count(db, 'SELECT COUNT(*) FROM $table WHERE branch_id IS NULL'), 0, reason: '$table has seeded rows without a branch');
      }
      expect(await _columnNames(db, 'transactions'), contains('created_by'));
    });
  });
}
