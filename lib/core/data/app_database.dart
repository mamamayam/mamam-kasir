import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'password_hasher.dart';

/// App-wide encrypted local database.
///
/// Shared across features (not just Menu Management) — each feature's
/// repository opens its own queries against [database], but there is
/// only ever one open connection per app run.
///
/// NOTE on encryption key: per AGENTS.md security rules, the SQLCipher
/// passphrase must live in the OS keystore/keychain via
/// flutter_secure_storage, not hardcoded. This vertical slice uses a
/// placeholder fixed key so features can be built and tested end-to-end
/// now; swapping in the real secure-storage-backed key when the
/// Auth/security foundation phase (docs/06 phase 3) lands is a
/// single-line change in [_openDatabase] and does not affect any
/// repository or UI code above this layer.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'mamam_kasir.db';
  // v3: added transactions.canceled_at / cancel_reason for the "Batalkan
  // Transaksi" (cancel, not delete) flow — PRD explicitly rejects hard
  // delete for transactions (retention/permission is UNSPECIFIED there).
  // Still pre-release, straight recreate via onCreate rather than a real
  // migration — same rationale as the v1->v2 bump.
  // v4: added "Nasi Goreng Spesial" dummy menu item + "Topping Nasi
  // Goreng" variant group to _seedDemoData. NOTE: bumping this version
  // alone does NOT retroactively seed the new row on a device that
  // already has the app installed — onCreate only runs when no db file
  // exists yet, and _onUpgrade here is still a no-op. On a device with
  // an existing install, uninstall the app (or clear its storage) first
  // so onCreate runs fresh and the new item appears.
  // v6: removed placeholder/dummy rows that had no path to real editing —
  // the demo customer ("Budi Santoso"), demo voucher ("HEMAT10"), the two
  // demo courier cash_locations ("Budi"/"Andi"), and the store's demo
  // opening balance (Rp 200.000). Menu/category/variant seed data is kept
  // (it IS real, editable data via Menu Management — the point of the
  // cleanup was removing data with no real source, not emptying the menu
  // Agung actually sells). Added a handful of seeded `transactions` +
  // `transaction_items` rows (today + preceding days) so Dashboard/Riwayat
  // have real, editable/cancelable data to show instead of being empty —
  // these are ordinary transaction rows, not a separate demo mechanism.
  // v7: added ingredients, stock_opname_sessions, stock_opname_items
  // tables (HPP & Stok Opname feature, ported from the approved HTML
  // mockup) and seeded them with the same sample ingredient set used in
  // that mockup so the feature isn't empty on first run — same "real,
  // editable seed data" rationale as the v6 menu/transaction seeding.
  // v8: added dompet_closings (Tutup Dompet) and cash_expenses (Arus
  // Kas / Pengeluaran, and Pemasukan non-sales income) tables. No Shift
  // module exists yet, so a closing's period is simply "since the
  // previous closing" rather than tied to a shift_id — see the
  // DompetClosing model doc comment for the reconciliation note for
  // when Shift lands. Still pre-release, straight recreate.
  // v9: added the `branches` table (Manajemen Cabang, reached from the
  // swipe-up grid's Cabang tile — the slot Laba Rugi used to occupy
  // before it moved into Laporan as a report type). `branches` is an
  // already-specified logical entity in docs/handoff/04_DATABASE_
  // CONTRACT.md, not a new invention. Seeded with the one store the app
  // already implicitly assumes everywhere ("Mamam Ayam" is hardcoded in
  // PengaturanScreen today), so the screen shows real, editable data
  // rather than a mock row. Still pre-release, straight recreate.
  //
  // NOT added here on purpose: any branch_id FK on transactions /
  // cash_movements / menu prices. Branch-scoped data is specified in the
  // PRD but wiring it retroactively changes how every existing report
  // and balance is computed — that belongs in its own phase, not in a
  // change that adds a management screen.
  // v10: added users/roles/permissions/user_roles/user_branch_access —
  // Tahap A (auth/permission foundation), per docs/handoff/04_DATABASE_
  // CONTRACT.md's logical model. THIS IS THE FIRST REAL MIGRATION in
  // this codebase: every prior bump (v1 through v9) relied on
  // onCreate-only "straight recreate" because the app had no real users
  // yet. From v10 on, devices may already hold real transactions/menu/
  // dompet/HPP/branch data that must survive the upgrade — see
  // _onUpgrade's `if (oldVersion < 10)` block, which creates the new
  // tables and seeds them WITHOUT touching any existing table. Nothing
  // existing is dropped or recreated.
  //
  // Replaces the hardcoded_accounts.dart owner/owner123 + staff/staff123
  // pair with real seeded rows in `users` (password/PIN hashed, not
  // plaintext) plus a third seeded `manager/manager123` account. Owner/
  // Manager/Staff are permission-scoping labels only for now, not a
  // deeper "job role" concept (see [[mamam-kasir-flutter]] notes) —
  // `roles.name` and `AppRole`'s enum values both stay 'owner'/
  // 'manager'/'staff' (NOT renamed to PRD's "Cashier" term; that word is
  // never used as stored data or user-facing copy, only in comments
  // explaining the PRD-terminology mapping). `roles` is a real table
  // (not a hardcoded Dart enum) so custom roles are schema-ready, even
  // though there's no UI yet to create one. AppRole gained a third value
  // (`manager`) this pass — see AppRole's doc comment for why a
  // previously-saved `staff` session value still reads safely after
  // this upgrade (it required no migration at all, since `staff` remains
  // a valid enum name).
  static const _dbVersion = 10;

  // TODO(security-foundation): replace with a key generated once and
  // stored via flutter_secure_storage, per AGENTS.md.
  static const _placeholderPassphrase = 'mamam-kasir-dev-placeholder-key';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _openDatabase();
    return _db!;
  }

  Future<Database> _openDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);

    return openDatabase(
      path,
      password: _placeholderPassphrase,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE menu_items (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        hpp INTEGER,
        unit TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE variant_groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_required INTEGER NOT NULL DEFAULT 0,
        max_selection INTEGER NOT NULL DEFAULT 1,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE variant_options (
        id TEXT PRIMARY KEY,
        variant_group_id TEXT NOT NULL,
        name TEXT NOT NULL,
        extra_price INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (variant_group_id) REFERENCES variant_groups (id)
      )
    ''');

    // Join table: a menu item can be linked to multiple variant groups
    // ("Koneksi Varian" checkboxes in the add-form).
    await db.execute('''
      CREATE TABLE menu_item_variant_groups (
        menu_item_id TEXT NOT NULL,
        variant_group_id TEXT NOT NULL,
        PRIMARY KEY (menu_item_id, variant_group_id),
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id),
        FOREIGN KEY (variant_group_id) REFERENCES variant_groups (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Voucher functionality — kept despite AGENTS.md listing
    // "active points/vouchers" as forbidden scope; explicit user
    // decision to include vouchers while still excluding loyalty points
    // (see [[mamam-kasir-flutter]] notes for the override rationale).
    await db.execute('''
      CREATE TABLE vouchers (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        discount_type TEXT NOT NULL, -- 'percent' | 'fixed'
        discount_value INTEGER NOT NULL,
        min_purchase INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Completed/open transactions. Money and calculated amounts are
    // captured as a snapshot at checkout time (per PRD: "Historical data
    // survives master changes") — never recomputed later from current
    // menu prices or settings.
    await db.execute('''
      CREATE TABLE transactions (
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
      )
    ''');

    await db.execute('''
      CREATE TABLE transaction_items (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        menu_item_id TEXT NOT NULL,
        name TEXT NOT NULL,
        variant_name TEXT,
        variant_selected_json TEXT,
        price INTEGER NOT NULL,
        hpp INTEGER NOT NULL DEFAULT 0,
        qty INTEGER NOT NULL,
        note TEXT,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id)
      )
    ''');

    // --- Dompet ledger (see docs/dompet-prd for the full spec) ---
    //
    // Cash locations: Store Cash/Dompet plus one row per courier.
    // Couriers are manual/dummy entries for now (type='courier', no
    // staff_id link) since the Staff module doesn't exist yet — once it
    // does, staff_id gets backfilled and courier locations are sourced
    // from real staff records instead of being created ad hoc here.
    await db.execute('''
      CREATE TABLE cash_locations (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL, -- 'store' | 'courier'
        name TEXT NOT NULL, -- 'Dompet Toko' for store, courier's display name otherwise
        staff_id TEXT, -- NULL until the Staff module exists; reserved for backfill
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Every cash movement is an immutable ledger entry — a location's
    // balance is always SUM(amount) of movements where it's the
    // to_location, minus SUM(amount) where it's the from_location.
    // Never mutate a location's balance directly; never edit or delete
    // a movement row after it's written (corrections are new adjustment
    // movements with their own audit trail, per PRD §26).
    await db.execute('''
      CREATE TABLE cash_movements (
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
      )
    ''');

    // Staff debt created by "Jadikan Kasbon". Per PRD §9: never
    // auto-marked paid just by being referenced in payroll — status and
    // remaining_balance only change via explicit repayment records.
    // Payroll integration itself is out of scope until a Payroll module
    // exists; this table is shaped to support it later (source fields).
    await db.execute('''
      CREATE TABLE kasbon (
        id TEXT PRIMARY KEY,
        staff_id TEXT, -- NULL until Staff module exists; courier_location_id identifies who for now
        courier_location_id TEXT NOT NULL,
        staff_name TEXT NOT NULL, -- denormalized display name, since staff_id may be NULL
        amount INTEGER NOT NULL,
        remaining_balance INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'Unsettled Courier Cash',
        status TEXT NOT NULL DEFAULT 'outstanding', -- 'outstanding' | 'partially_paid' | 'paid'
        created_at TEXT NOT NULL,
        created_by TEXT,
        FOREIGN KEY (courier_location_id) REFERENCES cash_locations (id)
      )
    ''');

    // Repayment history for kasbon — kept separate from the kasbon row
    // itself so remaining_balance is always derivable/auditable rather
    // than a mutated field with no history, per PRD §9's repayment-
    // history requirement.
    await db.execute('''
      CREATE TABLE kasbon_repayments (
        id TEXT PRIMARY KEY,
        kasbon_id TEXT NOT NULL,
        amount INTEGER NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        FOREIGN KEY (kasbon_id) REFERENCES kasbon (id)
      )
    ''');

    // "Tutup Dompet" closings for Store Cash. One immutable row per
    // close — never edited after creation; a wrong close is corrected
    // with a new adjustment movement, same principle as cash_movements.
    // periodStart/periodEnd stand in for a shift_id until the Shift
    // module exists (see DompetClosing's doc comment).
    await db.execute('''
      CREATE TABLE dompet_closings (
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
      )
    ''');

    // Arus Kas (Pemasukan/Pengeluaran) entries. Cash-affecting rows
    // (sumber_dana = a real cash_location) get a matching cash_movement
    // so Dompet balances and Arus Kas totals stay berkesinambungan
    // (see [[mamam-kasir-flutter]] notes on the Arus Kas HTML preview);
    // 'non_cash' rows (transfer/QRIS/etc.) intentionally have no
    // cash_movement_id since they never touch a physical cash balance.
    await db.execute('''
      CREATE TABLE cash_expenses (
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
      )
    ''');

    // --- HPP & Stok Opname (port of the HTML mockup) ---
    // `ingredients` holds Agung's cost-basis (HPP) ingredient list, split
    // into the three categories used consistently across both HPP and
    // Stok Opname (per Agung's direction that Stok Opname's item list
    // "follows" HPP's) — 'baku' (raw), 'setengah_jadi' (semi-finished),
    // 'jadi' (finished/sellable). `last_price` is what HPP shows/edits
    // and what Stok Opname auto-fills (editable per-session, not
    // overwritten by that edit — see stock_opname_items.price_used).
    await db.execute('''
      CREATE TABLE ingredients (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        last_price INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // A session is one full "opname" pass that can span all three
    // categories in one sitting (per Agung's direction — one session,
    // free to switch categories, single submit) before being marked
    // 'selesai'. 'draft' sessions can be resumed/completed later.
    await db.execute('''
      CREATE TABLE stock_opname_sessions (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL DEFAULT 'draft',
        created_at TEXT NOT NULL,
        completed_at TEXT,
        created_by TEXT
      )
    ''');

    // price_used is captured per-item at submit time (defaults to the
    // ingredient's last_price, editable in the form) so a session's
    // historical value never silently changes if last_price is edited
    // later in HPP.
    await db.execute('''
      CREATE TABLE stock_opname_items (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        ingredient_id TEXT NOT NULL,
        qty REAL NOT NULL,
        price_used INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES stock_opname_sessions (id),
        FOREIGN KEY (ingredient_id) REFERENCES ingredients (id)
      )
    ''');

    // --- Cabang / Toko ---
    // One row per physical outlet. `is_active` is an operational
    // on/off for the outlet itself — it is NOT a soft-delete and NOT
    // "sold out"; an inactive branch keeps all its history, same
    // Nonaktif semantics the PRD uses for menu masters.
    await db.execute('''
      CREATE TABLE branches (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await _createAuthTables(db);

    await _seedDemoData(db);
    await _seedAuthData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // First real migration in this codebase — see _dbVersion's v10 doc
    // comment. Every block here must be additive only: CREATE TABLE for
    // new tables, never DROP/recreate an existing one, so a device
    // upgrading from v9 keeps every existing transaction/menu/dompet/
    // HPP/branch row untouched.
    if (oldVersion < 10) {
      await _createAuthTables(db);
      await _seedAuthData(db);
    }
    // Future migrations get added here as further `if (oldVersion < N)`
    // blocks, each additive-only like the one above.
  }

  /// Creates the users/roles/permissions/user_roles/user_branch_access
  /// tables. Called from both _onCreate (fresh install) and _onUpgrade
  /// (existing device crossing the v10 boundary) so there is exactly one
  /// definition of this schema, not two copies that could drift apart.
  Future<void> _createAuthTables(Database db) async {
    // `roles` is a real table, not a hardcoded Dart enum — this is what
    // "custom roles are schema-ready" means for this pass (see
    // [[mamam-kasir-flutter]] notes): the schema supports adding a role
    // row beyond the 3 seeded defaults, even though there is no UI yet
    // to create one, and app code should not assume exactly 3 rows will
    // always exist here. `is_default` marks the 3 seeded ones so future
    // UI can distinguish "built-in" from "custom" without a separate
    // flag table.
    await db.execute('''
      CREATE TABLE roles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // One row per (role, permission key, mode) — PRD's 3-mode model
    // (deny/direct/approval). Not built against yet (that's Tahap A4's
    // PermissionService); this table exists now so A1 doesn't have to
    // be revisited when A4 lands. permission_key is free-text rather
    // than an enum/FK on purpose — A4's PermissionKey values aren't
    // defined yet, and this table shouldn't hardcode them ahead of that
    // design work.
    await db.execute('''
      CREATE TABLE permissions (
        id TEXT PRIMARY KEY,
        role_id TEXT NOT NULL,
        permission_key TEXT NOT NULL,
        mode TEXT NOT NULL, -- 'deny' | 'direct' | 'approval'
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE (role_id, permission_key),
        FOREIGN KEY (role_id) REFERENCES roles (id)
      )
    ''');

    // Credentials + lockout state live directly on `users`, all
    // per-row (i.e. per-user) rather than anywhere device-scoped — this
    // is the A1 prerequisite for A2's per-user PIN work. password_hash/
    // pin_hash are salted-hash pairs (see PasswordHasher), never
    // plaintext. pin_hash/pin_salt are nullable because a freshly
    // seeded/created user has no PIN until they complete the
    // "set PIN after first login" flow. failed_pin_attempts/locked_at
    // implement AGENTS.md's "5 wrong attempts locks the account" as a
    // per-user, persistent counter (not the old in-memory
    // pinAuthControllerProvider.autoDispose state) — see A2.
    // last_pin_at backs AGENTS.md's "3 days with no PIN entry forces
    // User ID+password login" rule (A3).
    await db.execute('''
      CREATE TABLE users (
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
      )
    ''');

    // Many-to-many by schema (matches docs/handoff/04_DATABASE_
    // CONTRACT.md's logical model, which specifies user_roles as its
    // own join table) even though this pass's product decision is "one
    // role per user at a time" (see [[mamam-kasir-flutter]] notes) — the
    // app enforces the one-role rule at the application layer (only
    // ever inserting one row per user), not by constraining the schema
    // to a single role_id column on `users`. This keeps the door open
    // for real multi-role later without another migration.
    await db.execute('''
      CREATE TABLE user_roles (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        role_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (user_id, role_id),
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (role_id) REFERENCES roles (id)
      )
    ''');

    // Per docs/handoff/01_PRD.md's Access section: "Branch-scoped
    // operational data for Manager" — which branch(es) a non-Owner user
    // may operate against. Not enforced anywhere yet (no branch-scoped
    // query filters this pass — see [[mamam-kasir-flutter]] notes on
    // deferred scope), just the schema slot so it exists when that
    // enforcement is built, matching the same "table now, logic later"
    // treatment as `permissions` above.
    await db.execute('''
      CREATE TABLE user_branch_access (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        branch_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (user_id, branch_id),
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (branch_id) REFERENCES branches (id)
      )
    ''');
  }

  /// Seeds the 3 default roles and the 3 dummy accounts (owner/owner123,
  /// manager/manager123, staff/staff123 — see [[mamam-kasir-flutter]]
  /// notes) that replace hardcoded_accounts.dart's in-memory list.
  /// Called from both _onCreate and _onUpgrade for the same
  /// single-definition reason as _createAuthTables.
  ///
  /// "Hanya satu Owner" (PRD/AGENTS.md's single-Owner rule) is enforced
  /// ONLY by construction here — this is the one and only place an
  /// owner role assignment is ever inserted in this pass, since "Halaman
  /// kelola user" (any UI to create/promote users) is explicitly out of
  /// scope (see task brief section 5). There is no DB-level CHECK/
  /// trigger and no repository-level runtime guard preventing a second
  /// Owner — if a future user-management feature adds the ability to
  /// assign roles, THAT feature must add its own single-Owner check
  /// before this construction-only guarantee stops being sufficient.
  /// Flagged explicitly rather than implied, since sqflite's SQLite
  /// build here has no easy portable way to express "at most one row
  /// where X" as a schema-level constraint, and adding a full
  /// enforcement layer for a UI that doesn't exist yet was out of scope
  /// per the task's "keep this pass simple" guidance.
  Future<void> _seedAuthData(Database db) async {
    // Guard against double-seeding: _onUpgrade runs _createAuthTables +
    // _seedAuthData together, but if a future migration path ever calls
    // this again (or a developer re-runs onUpgrade logic in a test), a
    // second insert would violate the UNIQUE(username) constraint. This
    // check makes the seed idempotent rather than crash-prone.
    final existing = await db.query('roles', limit: 1);
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toIso8601String();
    const uuid = Uuid();

    final roleIds = <String, String>{
      'owner': uuid.v4(),
      'manager': uuid.v4(),
      'staff': uuid.v4(),
    };

    for (final entry in roleIds.entries) {
      await db.insert('roles', {
        'id': entry.value,
        'name': entry.key,
        'is_default': 1,
        'created_at': now,
        'updated_at': now,
      });
    }

    final accounts = [
      ('owner', 'owner123', 'Owner', roleIds['owner']!),
      ('manager', 'manager123', 'Manager', roleIds['manager']!),
      ('staff', 'staff123', 'Staff', roleIds['staff']!),
    ];

    for (final (username, password, displayName, roleId) in accounts) {
      final userId = uuid.v4();
      final passwordSalt = PasswordHasher.generateSalt();
      await db.insert('users', {
        'id': userId,
        'username': username,
        'display_name': displayName,
        'password_hash': PasswordHasher.hash(password, passwordSalt),
        'password_salt': passwordSalt,
        'pin_hash': null,
        'pin_salt': null,
        'failed_pin_attempts': 0,
        'locked_at': null,
        'last_pin_at': null,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await db.insert('user_roles', {
        'id': uuid.v4(),
        'user_id': userId,
        'role_id': roleId,
        'created_at': now,
      });
    }
  }

  /// Seeds initial rows on first run.
  ///
  /// Menu/category/variant data below is Agung's actual menu — real,
  /// editable rows via Menu Management, not placeholder content, so it
  /// stays. What got removed in the v6 cleanup was data with no real
  /// source to point to: a demo customer, a demo voucher, two demo
  /// courier cash_locations, and a demo opening cash balance — those
  /// were names/numbers invented for the shell phase with no path to
  /// becoming real (no Staff module for couriers, no actual customer
  /// named "Budi Santoso"). In their place, this seeds a handful of
  /// ordinary `transactions` rows (today + the preceding few days, using
  /// the real menu items) so Dashboard and Riwayat have something to
  /// show and compute from immediately — these are real rows editable/
  /// cancelable the same way any other transaction is, not a separate
  /// "demo mode".
  Future<void> _seedDemoData(Database db) async {
    final now = DateTime.now().toIso8601String();

    final categories = {
      'Saus & Bumbu': 'cat-saus-bumbu',
      'Makanan Utama': 'cat-makanan-utama',
      'Minuman': 'cat-minuman',
    };

    for (final entry in categories.entries) {
      await db.insert('categories', {
        'id': entry.value,
        'name': entry.key,
        'sort_order': categories.keys.toList().indexOf(entry.key),
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }

    final menuItems = [
      {'id': 'menu-1', 'category_id': 'cat-saus-bumbu', 'name': 'Brownbutter', 'price': 18000, 'unit': 'pcs'},
      {'id': 'menu-2', 'category_id': 'cat-saus-bumbu', 'name': 'Firesauce', 'price': 20000, 'unit': 'pcs'},
      {'id': 'menu-3', 'category_id': 'cat-makanan-utama', 'name': 'Ayam Crispy Original', 'price': 15000, 'unit': 'porsi'},
      {'id': 'menu-4', 'category_id': 'cat-makanan-utama', 'name': 'Ayam Bakar Madu', 'price': 17000, 'unit': 'porsi'},
      {'id': 'menu-5', 'category_id': 'cat-minuman', 'name': 'Es Teh Manis', 'price': 5000, 'unit': 'gelas'},
      {'id': 'menu-6', 'category_id': 'cat-minuman', 'name': 'Es Jeruk', 'price': 7000, 'unit': 'gelas'},
      {'id': 'menu-7', 'category_id': 'cat-makanan-utama', 'name': 'Nasi Goreng Spesial', 'price': 22000, 'unit': 'porsi'},
    ];

    for (final item in menuItems) {
      await db.insert('menu_items', {
        ...item,
        'hpp': null,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }

    final variantGroups = {
      'vg-1': {
        'name': 'Level Pedas',
        'isRequired': 1,
        'maxSelection': 1,
        'options': [
          {'name': 'Level 0', 'extraPrice': 0},
          {'name': 'Level 1', 'extraPrice': 0},
          {'name': 'Level 2', 'extraPrice': 0},
          {'name': 'Level 3', 'extraPrice': 0},
        ],
      },
      'vg-2': {
        'name': 'Pilihan Minuman',
        'isRequired': 0,
        'maxSelection': 1,
        'options': [
          {'name': 'Es Teh Manis', 'extraPrice': 0},
          {'name': 'Teh Tawar', 'extraPrice': 0},
          {'name': 'Mineral Water', 'extraPrice': 2000},
        ],
      },
      'vg-3': {
        'name': 'Ekstra Topping',
        'isRequired': 0,
        'maxSelection': 3,
        'options': [
          {'name': 'Keju', 'extraPrice': 5000},
          {'name': 'Saus Keju', 'extraPrice': 4000},
          {'name': 'Kremes', 'extraPrice': 3000},
        ],
      },
      'vg-4': {
        'name': 'Topping Nasi Goreng',
        'isRequired': 1,
        'maxSelection': 1,
        'options': [
          {'name': 'Telur Mata Sapi', 'extraPrice': 3000},
          {'name': 'Telur Dadar', 'extraPrice': 3000},
          {'name': 'Ayam Suwir', 'extraPrice': 5000},
          {'name': 'Tanpa Topping', 'extraPrice': 0},
        ],
      },
    };

    for (final entry in variantGroups.entries) {
      final data = entry.value;
      await db.insert('variant_groups', {
        'id': entry.key,
        'name': data['name'],
        'is_required': data['isRequired'],
        'max_selection': data['maxSelection'],
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      final options = data['options'] as List<Map<String, Object>>;
      for (var i = 0; i < options.length; i++) {
        await db.insert('variant_options', {
          'id': '${entry.key}-opt-$i',
          'variant_group_id': entry.key,
          'name': options[i]['name'],
          'extra_price': options[i]['extraPrice'],
          'sort_order': i,
        });
      }
    }

    // Link "Level Pedas" to the two chicken dishes, matching the
    // reference app's behavior of some menus having required variants.
    await db.insert('menu_item_variant_groups', {'menu_item_id': 'menu-3', 'variant_group_id': 'vg-1'});
    await db.insert('menu_item_variant_groups', {'menu_item_id': 'menu-4', 'variant_group_id': 'vg-1'});
    await db.insert('menu_item_variant_groups', {'menu_item_id': 'menu-4', 'variant_group_id': 'vg-3'});
    await db.insert('menu_item_variant_groups', {'menu_item_id': 'menu-7', 'variant_group_id': 'vg-4'});
    await db.insert('menu_item_variant_groups', {'menu_item_id': 'menu-7', 'variant_group_id': 'vg-3'});

    // --- Dompet ledger: only the structural Store Cash location. Every
    // location's balance is always derived from cash_movements (never a
    // stored/mutated field — see DompetRepository.getLocationBalance),
    // so omitting an opening-balance movement here just means Store Cash
    // legitimately starts at Rp 0 until real sales or a real "Saldo
    // Awal" entry create movements — not a placeholder value pretending
    // to be a real balance. ---
    await db.insert('cash_locations', {
      'id': 'loc-store',
      'type': 'store',
      'name': 'Dompet Toko',
      'staff_id': null,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // The one outlet that actually exists. Not placeholder content —
    // "Mamam Ayam" is already hardcoded into PengaturanScreen, this just
    // gives it a real row to live in so Manajemen Cabang reads data
    // instead of rendering a constant. Seeded active; deactivating is a
    // deliberate user action on the screen, not a default.
    await db.insert('branches', {
      'id': 'branch-cibarusah',
      'name': 'Mamam Ayam',
      'address': 'Cibarusah, Bekasi',
      'phone': '+6283805192127',
      'is_active': 1,
      'sort_order': 0,
      'created_at': now,
      'updated_at': now,
    });

    await _seedIngredients(db, now);
    await _seedSampleTransactions(db);
  }

  /// Seeds the same sample ingredient set shown in the approved HTML
  /// mockup — real, editable rows via the HPP screen (add/edit/delete),
  /// not placeholder content baked into the UI.
  Future<void> _seedIngredients(Database db, String now) async {
    final ingredients = [
      {'id': 'ing-1', 'category': 'baku', 'name': 'Ayam Potong', 'unit': 'kg', 'lastPrice': 38000},
      {'id': 'ing-2', 'category': 'baku', 'name': 'Beras', 'unit': 'kg', 'lastPrice': 14000},
      {'id': 'ing-3', 'category': 'baku', 'name': 'Minyak Goreng', 'unit': 'liter', 'lastPrice': 21000},
      {'id': 'ing-4', 'category': 'baku', 'name': 'Bawang Putih', 'unit': 'kg', 'lastPrice': 42000},
      {'id': 'ing-5', 'category': 'setengah_jadi', 'name': 'Bumbu Marinasi', 'unit': 'liter', 'lastPrice': 35000},
      {'id': 'ing-6', 'category': 'setengah_jadi', 'name': 'Adonan Tepung', 'unit': 'kg', 'lastPrice': 18000},
      {'id': 'ing-7', 'category': 'jadi', 'name': 'Firesauce (botol)', 'unit': 'pcs', 'lastPrice': 12000},
      {'id': 'ing-8', 'category': 'jadi', 'name': 'Brownbutter (botol)', 'unit': 'pcs', 'lastPrice': 11000},
    ];

    for (final ing in ingredients) {
      await db.insert('ingredients', {
        'id': ing['id'],
        'category': ing['category'],
        'name': ing['name'],
        'unit': ing['unit'],
        'last_price': ing['lastPrice'],
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  /// Seeds a handful of ordinary paid transactions (today + the
  /// preceding several days) using the real menu rows above, so
  /// Dashboard metrics/trend and Riwayat have real data to compute from
  /// and display on first run — same tables, same shape, same
  /// cancel/view flow as any transaction created through checkout. Not a
  /// separate "sample data" system; these rows are editable/cancelable
  /// exactly like any other transaction.
  Future<void> _seedSampleTransactions(Database db) async {
    const uuid = Uuid();
    final today = DateTime.now();

    // (day offset from today, [(menu_id, name, price, qty)], payment method)
    final days = [
      (0, [('menu-3', 'Ayam Crispy Original', 15000, 2), ('menu-6', 'Es Jeruk', 7000, 2)], 'Tunai'),
      (0, [('menu-2', 'Firesauce', 20000, 1), ('menu-7', 'Nasi Goreng Spesial', 22000, 1)], 'QRIS'),
      (1, [('menu-4', 'Ayam Bakar Madu', 17000, 3), ('menu-5', 'Es Teh Manis', 5000, 3)], 'Tunai'),
      (2, [('menu-1', 'Brownbutter', 18000, 1), ('menu-3', 'Ayam Crispy Original', 15000, 1)], 'QRIS'),
      (2, [('menu-7', 'Nasi Goreng Spesial', 22000, 2)], 'Transfer'),
      (4, [('menu-3', 'Ayam Crispy Original', 15000, 1), ('menu-6', 'Es Jeruk', 7000, 1)], 'Tunai'),
      (6, [('menu-4', 'Ayam Bakar Madu', 17000, 2), ('menu-2', 'Firesauce', 20000, 1)], 'QRIS'),
    ];

    for (final (dayOffset, items, paymentMethod) in days) {
      final createdAt = today.subtract(Duration(days: dayOffset, hours: today.hour - 12));
      final id = uuid.v4();
      final displayNumber = 'ORD-${id.substring(0, 6).toUpperCase()}';
      final subtotal = items.fold<int>(0, (sum, i) => sum + (i.$3 * i.$4));
      final tax = (subtotal * 0.11).round();
      final total = subtotal + tax;

      await db.insert('transactions', {
        'id': id,
        'display_number': displayNumber,
        'status': 'paid',
        'order_type': 'Takeaway',
        'customer_id': null,
        'customer_name': null,
        'ojol_platform': null,
        'ojol_order_number': null,
        'subtotal': subtotal,
        'voucher_id': null,
        'voucher_code': null,
        'voucher_discount': 0,
        'manual_discount_type': null,
        'manual_discount_value': null,
        'manual_discount_amount': 0,
        'tax_amount': tax,
        'service_amount': 0,
        'delivery_fee': 0,
        'rounding_adjustment': 0,
        'total': total,
        'payment_method': paymentMethod,
        'amount_paid': total,
        'change_amount': 0,
        'split_payments_json': null,
        'created_at': createdAt.toIso8601String(),
        'paid_at': createdAt.toIso8601String(),
      });

      for (final (menuId, name, price, qty) in items) {
        await db.insert('transaction_items', {
          'id': uuid.v4(),
          'transaction_id': id,
          'menu_item_id': menuId,
          'name': name,
          'variant_name': null,
          'variant_selected_json': null,
          'price': price,
          'hpp': 0,
          'qty': qty,
          'note': null,
        });
      }

      // Cash-method sales route through the Dompet ledger like a real
      // checkout would (see PosRepository.saveTransaction) — QRIS/
      // Transfer have no physical cash to track, so no movement.
      if (paymentMethod == 'Tunai') {
        await db.insert('cash_movements', {
          'id': uuid.v4(),
          'type': 'cash_sale',
          'from_location_id': null,
          'to_location_id': 'loc-store',
          'amount': total,
          'reference_transaction_id': id,
          'reference_kasbon_id': null,
          'reason': null,
          'created_at': createdAt.toIso8601String(),
          'created_by': null,
        });
      }
    }
  }
}
