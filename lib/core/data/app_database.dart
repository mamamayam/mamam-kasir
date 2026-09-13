import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

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
  // v5: added the Dompet ledger core — cash_locations (Store
  // Cash/Dompet + per-courier, courier rows are manual/dummy since the
  // Staff module doesn't exist yet), cash_movements (immutable
  // ledger entries with audit-trail fields per the Dompet PRD — never a
  // simple balance mutation; every location's balance is always SUM of
  // its movements, computed on read), and kasbon (staff debt records
  // created by "Jadikan Kasbon"). Closing/shift-block logic is
  // explicitly NOT part of this pass — see [[dompet-prd]] notes.
  static const _dbVersion = 5;

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

    await _seedDemoData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // NOTE: no real migrations yet — pre-release, straight recreate is
    // handled by bumping _dbVersion and relying on onCreate for now.
    // Future migrations get added here as `if (oldVersion < N) { ... }`
    // blocks once the DB is in the hands of real users with existing
    // data that must be preserved across upgrades.
  }

  /// Seeds demo rows so screens show familiar data on first run instead
  /// of an empty state. Safe to remove once real data entry is routine.
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

    // New dummy item — required topping choice plus the shared Ekstra
    // Topping group (multi-select), so it exercises a menu item with
    // two variant groups at once.
    await db.insert('menu_item_variant_groups', {'menu_item_id': 'menu-7', 'variant_group_id': 'vg-4'});
    await db.insert('menu_item_variant_groups', {'menu_item_id': 'menu-7', 'variant_group_id': 'vg-3'});

    await db.insert('customers', {
      'id': 'cust-1',
      'name': 'Budi Santoso',
      'phone': '081234567890',
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('vouchers', {
      'id': 'vch-1',
      'code': 'HEMAT10',
      'discount_type': 'percent',
      'discount_value': 10,
      'min_purchase': 20000,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // --- Dompet ledger seed ---
    // Store Cash location plus two dummy courier locations (manual
    // stand-ins until the Staff module provides real courier/staff
    // records — see docs/dompet-prd).
    await db.insert('cash_locations', {
      'id': 'loc-store',
      'type': 'store',
      'name': 'Dompet Toko',
      'staff_id': null,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('cash_locations', {
      'id': 'loc-courier-budi',
      'type': 'courier',
      'name': 'Budi',
      'staff_id': null,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('cash_locations', {
      'id': 'loc-courier-andi',
      'type': 'courier',
      'name': 'Andi',
      'staff_id': null,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // Opening balance for Store Cash so the Dompet page isn't empty on
    // first run — a movement with no from_location (cash entering the
    // ledger), same shape a real "opening shift" entry would use later.
    await db.insert('cash_movements', {
      'id': 'cm-opening-store',
      'type': 'opening',
      'from_location_id': null,
      'to_location_id': 'loc-store',
      'amount': 200000,
      'reference_transaction_id': null,
      'reference_kasbon_id': null,
      'reason': 'Saldo awal (demo)',
      'created_at': now,
      'created_by': null,
    });
  }
}
