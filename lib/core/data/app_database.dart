import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

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
  static const _dbVersion = 7;

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

    await _seedDemoData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // NOTE: no real migrations yet — pre-release, straight recreate is
    // handled by bumping _dbVersion and relying on onCreate for now.
    // Future migrations get added here as `if (oldVersion < N) { ... }`
    // blocks once the DB is in the hands of real users with existing
    // data that must be preserved across upgrades.
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
