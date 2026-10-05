#!/usr/bin/env python3
"""Verifies the Tahap B / B2 migration (DB v13 -> v14) against REAL SQLite.

Jalankan dari ROOT repo yang sudah berisi perubahan B2 (butuh git + python3, tanpa dependency lain):

    python3 verify_b2_migration.py --v13-rev <git rev yang masih v13, mis. origin/main sebelum B2>

What it does
  1. Rebuilds the frozen v13 snapshot from the v13 revision's own
     app_database.dart (so the fixture can't drift from reality) and fills
     it with representative rows.
  2. Runs the SAME migration steps that lib/core/data/branch_scope_migration.dart
     defines (table list, legacy branch id, ALTER definitions and index
     statements are parsed out of that Dart file; the control flow is mirrored).
  3. Asserts: data intact, backfill, idempotency, partially-migrated DB,
     abort + rollback, empty-DB no-op, fresh-install DDL parity.
  4. Optionally emits test/app_database_branch_scope_test.dart from the
     same fixture, so the on-device Dart test and this script use identical data.

LIMITS: this proves the SQL and the control flow on SQLite. It does NOT
compile or run the Dart; the Dart test must still be run on a device.
"""
import argparse, json, re, sqlite3, subprocess, sys

MIGRATION = 'lib/core/data/branch_scope_migration.dart'
APPDB = 'lib/core/data/app_database.dart'
SNAPSHOT_TABLES = ['users', 'branches', 'transactions', 'cash_locations',
                   'cash_movements', 'dompet_closings', 'cash_expenses',
                   'stock_opname_sessions']

TS = '2026-09-20T10:00:00.000'
FIXTURE = [
    "INSERT INTO branches (id, name, address, phone, is_active, sort_order, created_at, updated_at) VALUES ('branch-cibarusah', 'Mamam Ayam', NULL, NULL, 1, 0, '2026-09-01T00:00:00.000', '2026-09-01T00:00:00.000')",
    "INSERT INTO transactions (id, display_number, status, order_type, customer_name, subtotal, total, payment_method, amount_paid, change_amount, created_at, paid_at) VALUES ('t1', '#001', 'paid', 'Takeaway', 'Pelanggan Umum', 50000, 50000, 'Tunai', 50000, 0, '2026-09-20T10:00:00.000', '2026-09-20T10:00:00.000')",
    "INSERT INTO transactions (id, display_number, status, order_type, subtotal, total, created_at, paid_at, canceled_at, cancel_reason) VALUES ('t2', '#002', 'canceled', 'Delivery', 30000, 30000, '2026-09-21T11:00:00.000', '2026-09-21T11:05:00.000', '2026-09-21T12:00:00.000', 'Salah input')",
    "INSERT INTO transactions (id, display_number, status, order_type, subtotal, total, created_at) VALUES ('t3', '#003', 'open', 'Dine-in', 20000, 20000, '2026-09-22T12:00:00.000')",
    "INSERT INTO cash_locations (id, type, name, is_active, created_at, updated_at) VALUES ('loc-store', 'store', 'Dompet Toko', 1, '2026-09-01T00:00:00.000', '2026-09-01T00:00:00.000')",
    "INSERT INTO cash_locations (id, type, name, is_active, created_at, updated_at) VALUES ('loc-budi', 'courier', 'Budi', 1, '2026-09-01T00:00:00.000', '2026-09-01T00:00:00.000')",
    "INSERT INTO cash_movements (id, type, from_location_id, to_location_id, amount, reference_transaction_id, created_at) VALUES ('m1', 'cash_sale', NULL, 'loc-store', 50000, 't1', '2026-09-20T10:00:01.000')",
    "INSERT INTO cash_movements (id, type, from_location_id, to_location_id, amount, reason, created_at, created_by) VALUES ('m2', 'expense', 'loc-store', NULL, 10000, 'Belanja', '2026-09-20T15:00:00.000', 'legacy-user')",
    "INSERT INTO cash_expenses (id, direction, category, amount, transaction_date, source_location_id, funding_source, store_or_supplier_name, detail, cash_movement_id, created_at) VALUES ('e1', 'pengeluaran', 'Belanja', 10000, '2026-09-20', 'loc-store', 'cash_location', 'Pasar', 'Ayam', 'm2', '2026-09-20T15:00:00.000')",
    "INSERT INTO cash_expenses (id, direction, category, amount, transaction_date, funding_source, created_at, created_by) VALUES ('e2', 'pemasukan', 'Lainnya', 5000, '2026-09-21', 'non_cash', '2026-09-21T09:00:00.000', 'legacy-user')",
    "INSERT INTO dompet_closings (id, period_start, period_end, opening_balance, cash_sales_total, courier_deposits_total, cash_expenses_total, expected_cash, counted_cash, discrepancy, status, created_at) VALUES ('c1', '2026-09-20T00:00:00.000', '2026-09-20T23:59:59.000', 100000, 50000, 0, 10000, 140000, 139000, -1000, 'closed', '2026-09-20T23:59:59.000')",
    "INSERT INTO stock_opname_sessions (id, status, created_at, completed_at) VALUES ('o1', 'completed', '2026-09-01T08:00:00.000', '2026-09-01T09:00:00.000')",
]
SUMS = {  # table -> money column; compared before/after
    'transactions': 'total', 'cash_expenses': 'amount', 'cash_movements': 'amount',
    'dompet_closings': 'counted_cash'}

FAILS = []
def check(cond, msg):
    print(('  PASS  ' if cond else '  FAIL  ') + msg)
    if not cond: FAILS.append(msg)

def sh(*a): return subprocess.run(a, capture_output=True, text=True, check=True).stdout

# ---------------------------------------------------------------- inputs
def v13_ddl(rev):
    src = sh('git', 'show', f'{rev}:{APPDB}')
    out = {}
    for t in SNAPSHOT_TABLES:
        m = re.search(rf"(CREATE TABLE {t} \(\n.*?\n      \))", src, re.S)
        assert m, f'{t} missing in {rev}'
        out[t] = '\n'.join(l[6:] if l.startswith('      ') else l for l in m.group(1).split('\n'))
    return out

def parse_migration():
    src = open(MIGRATION, encoding='utf-8').read()
    tables = re.findall(r"'(\w+)',", re.search(r"branchScopedTables = <String>\[(.*?)\];", src, re.S).group(1))
    legacy = re.search(r"legacyBranchId = '([^']+)'", src).group(1)
    alters = re.findall(r"_addColumnIfMissing\(db, ('?[\w]+'?), '(\w+)', '([^']+)'\)", src)
    # `table` loop variable in the first call -> every branch-scoped table
    steps = []
    for tbl, col, definition in alters:
        steps += [(t, col, definition) for t in tables] if tbl == 'table' else [(tbl.strip("'"), col, definition)]
    indexes = re.findall(r"db\.execute\('(CREATE INDEX IF NOT EXISTS [^']+)'\)", src)
    return tables, legacy, steps, indexes

# ---------------------------------------------------------------- mirror
def cols(db, t): return [r[1] for r in db.execute(f'PRAGMA table_info({t})')]

def migrate(db, tables, legacy, steps, indexes):
    for t, c, d in steps:
        if c not in cols(db, t):
            db.execute(f'ALTER TABLE {t} ADD COLUMN {c} {d}')
    backfill(db, tables, legacy)
    for sql in indexes: db.execute(sql)

def backfill(db, tables, legacy):
    pending = sum(db.execute(f'SELECT COUNT(*) FROM {t} WHERE branch_id IS NULL').fetchone()[0] for t in tables)
    if pending == 0: return
    if not db.execute('SELECT 1 FROM branches WHERE id = ? LIMIT 1', (legacy,)).fetchone():
        raise RuntimeError('StateError: legacy branch missing')
    for t in tables:
        db.execute(f'UPDATE {t} SET branch_id = ? WHERE branch_id IS NULL', (legacy,))

def new_snapshot(ddl, with_fixture=True):
    db = sqlite3.connect(':memory:', isolation_level=None)   # FK enforcement OFF, like the app
    for t in SNAPSHOT_TABLES: db.execute(ddl[t])
    if with_fixture:
        for s in FIXTURE: db.execute(s)
    return db

def capture(db, orig_cols):
    return {t: db.execute(f'SELECT {", ".join(c)} FROM {t} ORDER BY id').fetchall() for t, c in orig_cols.items()}

# ---------------------------------------------------------------- dart test
def emit_dart_test(path, ddl, orig_cols, tables, legacy):
    raw = lambda s: "r'''" + s + "'''"
    ddl_dart = ',\n'.join('  ' + raw(ddl[t]) for t in SNAPSHOT_TABLES)
    fx_dart = ',\n'.join('  ' + raw(s) for s in FIXTURE)
    cols_dart = ',\n'.join(f"  '{t}': [{', '.join(repr(c) for c in cs)}]" for t, cs in orig_cols.items())
    sums_dart = ',\n'.join(f"  '{t}': '{c}'" for t, c in SUMS.items())
    tables_dart = ', '.join(f"'{t}'" for t in tables)
    open(path, 'w', encoding='utf-8').write(DART_TEMPLATE
        .replace('@@DDL@@', ddl_dart).replace('@@FIXTURE@@', fx_dart)
        .replace('@@COLS@@', cols_dart).replace('@@SUMS@@', sums_dart)
        .replace('@@TABLES@@', tables_dart))
    print(f'wrote {path}')

DART_TEMPLATE = open(__file__.replace('verify_b2_migration.py', 'dart_template.txt'), encoding='utf-8').read() \
    if __import__('os').path.exists(__file__.replace('verify_b2_migration.py', 'dart_template.txt')) else ''

# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--v13-rev', default='origin/main')
    ap.add_argument('--emit-dart-test')
    a = ap.parse_args()

    ddl = v13_ddl(a.v13_rev)
    tables, legacy, steps, indexes = parse_migration()
    print(f'parsed from Dart: tables={tables}\n  legacy={legacy}\n  {len(steps)} ADD COLUMN steps, {len(indexes)} indexes')

    base = new_snapshot(ddl)
    orig_cols = {t: cols(base, t) for t in tables}
    base.close()

    if a.emit_dart_test:
        emit_dart_test(a.emit_dart_test, ddl, orig_cols, tables, legacy)

    # --- 1. normal upgrade
    print('\n[1] upgrade of a v13 snapshot')
    db = new_snapshot(ddl)
    before = capture(db, orig_cols)
    sums_before = {t: db.execute(f'SELECT SUM({c}), COUNT(*) FROM {t}').fetchone() for t, c in SUMS.items()}
    db.execute('BEGIN'); migrate(db, tables, legacy, steps, indexes); db.execute('COMMIT')
    for t in tables:
        check('branch_id' in cols(db, t), f'{t}.branch_id exists')
        fk = [(r[2], r[4]) for r in db.execute(f'PRAGMA foreign_key_list({t})')]
        check(('branches', 'id') in fk, f'{t}.branch_id has FK -> branches(id)')
    check('created_by' in cols(db, 'transactions'), 'transactions.created_by added')
    check(('users', 'id') in [(r[2], r[4]) for r in db.execute('PRAGMA foreign_key_list(transactions)')], 'transactions.created_by has FK -> users(id)')
    after = capture(db, orig_cols)
    check(after == before, 'EVERY pre-existing column value is byte-identical after migration (all 6 tables)')
    check({t: db.execute(f'SELECT SUM({c}), COUNT(*) FROM {t}').fetchone() for t, c in SUMS.items()} == sums_before, 'row counts and money sums identical')
    for t in tables:
        n_null = db.execute(f'SELECT COUNT(*) FROM {t} WHERE branch_id IS NULL').fetchone()[0]
        n_other = db.execute(f'SELECT COUNT(*) FROM {t} WHERE branch_id <> ?', (legacy,)).fetchone()[0]
        check(n_null == 0 and n_other == 0, f'{t}: every row attributed to {legacy}')
    check(db.execute('SELECT COUNT(*) FROM transactions WHERE created_by IS NOT NULL').fetchone()[0] == 0, 'transactions.created_by stays NULL on legacy rows')
    check(db.execute("SELECT created_by FROM cash_expenses WHERE id='e2'").fetchone()[0] == 'legacy-user'
          and db.execute("SELECT created_by FROM cash_movements WHERE id='m2'").fetchone()[0] == 'legacy-user',
          'pre-existing non-null created_by values are NOT overwritten')
    check(db.execute("SELECT COUNT(*) FROM cash_movements WHERE created_by IS NULL").fetchone()[0] == 1, 'NULL created_by not invented')
    orphans = sum(db.execute(f'SELECT COUNT(*) FROM {t} WHERE branch_id IS NOT NULL AND branch_id NOT IN (SELECT id FROM branches)').fetchone()[0] for t in tables)
    check(orphans == 0, 'no orphan branch_id')
    idx = {r[1] for r in db.execute("SELECT * FROM sqlite_master WHERE type='index'")}
    check(all(re.search(r'idx_\w+', s).group(0) in idx for s in indexes), f'all {len(indexes)} indexes created')
    plan = ' '.join(r[3] for r in db.execute("EXPLAIN QUERY PLAN SELECT SUM(total) FROM transactions WHERE branch_id=? AND status='paid' AND paid_at >= ?", (legacy, TS)))
    check('idx_transactions_branch_paid_at' in plan, f'report query uses the branch index ({plan.strip()[:70]})')

    # --- 2. idempotent
    print('\n[2] idempotency: run the whole migration again')
    try:
        db.execute('BEGIN'); migrate(db, tables, legacy, steps, indexes); db.execute('COMMIT'); ok = True
    except Exception as e:
        db.execute('ROLLBACK'); ok = False; print('   ', e)
    check(ok, 'second run does not raise (no "duplicate column")')
    check(capture(db, orig_cols) == before, 'data still identical after second run')
    db.close()

    # --- 3. partially migrated (old v14 shape: branch_id on 2 tables, plain TEXT, one row on another branch)
    print('\n[3] partially migrated DB (earlier v14: plain branch_id on transactions + cash_expenses)')
    db = new_snapshot(ddl)
    db.execute("INSERT INTO branches (id,name,is_active,sort_order,created_at,updated_at) VALUES ('branch-other','Lain',1,1,'x','x')")
    for t in ('transactions', 'cash_expenses'):
        db.execute(f'ALTER TABLE {t} ADD COLUMN branch_id TEXT')
    db.execute("UPDATE transactions SET branch_id='branch-other' WHERE id='t2'")
    db.execute("UPDATE transactions SET branch_id=? WHERE id='t1'", (legacy,))
    try:
        db.execute('BEGIN'); migrate(db, tables, legacy, steps, indexes); db.execute('COMMIT'); ok = True
    except Exception as e:
        db.execute('ROLLBACK'); ok = False; print('   ', e)
    check(ok, 'migration completes on a partly migrated DB')
    got = dict(db.execute('SELECT id, branch_id FROM transactions'))
    check(got == {'t1': legacy, 't2': 'branch-other', 't3': legacy}, 'rows already attributed are kept; only NULL rows backfilled')
    check(all(db.execute(f'SELECT COUNT(*) FROM {t} WHERE branch_id IS NULL').fetchone()[0] == 0 for t in tables), 'no NULL branch_id left')
    db.close()

    # --- 4. abort + rollback
    print('\n[4] legacy branch row missing while rows need attribution')
    db = new_snapshot(ddl)
    db.execute("DELETE FROM branches WHERE id=?", (legacy,))
    raised = False
    try:
        db.execute('BEGIN'); migrate(db, tables, legacy, steps, indexes); db.execute('COMMIT')
    except Exception:
        raised = True; db.execute('ROLLBACK')
    check(raised, 'migration aborts with an error')
    check(all('branch_id' not in cols(db, t) for t in tables) and 'created_by' not in cols(db, 'transactions'),
          'ROLLBACK removed the ADD COLUMNs too (DDL is transactional): DB is exactly v13 again')
    check(capture(db, orig_cols) == before, 'data untouched after the aborted attempt')
    db.close()

    # --- 5. empty DB without the legacy branch: nothing to attribute -> no abort
    print('\n[5] empty tables + no legacy branch row')
    db = new_snapshot(ddl, with_fixture=False)
    try:
        db.execute('BEGIN'); migrate(db, tables, legacy, steps, indexes); db.execute('COMMIT'); ok = True
    except Exception as e:
        db.execute('ROLLBACK'); ok = False; print('   ', e)
    check(ok, 'no rows to attribute -> migration succeeds')
    db.close()

    # --- 6. fresh-install DDL (as now written in app_database.dart) vs upgraded schema
    print('\n[6] fresh-install DDL parity')
    src = open(APPDB, encoding='utf-8').read()
    fresh = sqlite3.connect(':memory:', isolation_level=None)
    for t in SNAPSHOT_TABLES:
        m = re.search(rf"CREATE TABLE {t} \(\n.*?\n      \)", src, re.S)
        fresh.execute(m.group(0))
    up = new_snapshot(ddl)
    up.execute('BEGIN'); migrate(up, tables, legacy, steps, indexes); up.execute('COMMIT')
    for t in tables:
        fc, uc = cols(fresh, t), cols(up, t)
        check(set(fc) == set(uc), f'{t}: fresh and upgraded have the same columns')
        ffk = {(r[2], r[3], r[4]) for r in fresh.execute(f'PRAGMA foreign_key_list({t})')}
        ufk = {(r[2], r[3], r[4]) for r in up.execute(f'PRAGMA foreign_key_list({t})')}
        check(ffk == ufk, f'{t}: fresh and upgraded have the same foreign keys')
    check(not fresh.execute('PRAGMA foreign_key_check').fetchall(), 'fresh DDL parses and passes foreign_key_check')

    print(f'\n{"ALL CHECKS PASSED" if not FAILS else str(len(FAILS)) + " CHECK(S) FAILED"}')
    sys.exit(1 if FAILS else 0)

if __name__ == '__main__':
    main()
