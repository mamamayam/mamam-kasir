import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/app_database.dart';
import '../domain/hpp_opname_models.dart';

/// CRUD access for HPP (ingredients/cost basis) and Stok Opname (monthly
/// physical stock count sessions), ported from the approved HTML
/// mockup. Same "one repository, one set of tables" pattern as
/// [MenuManagementRepository] — the UI/controller never touch
/// [AppDatabase] directly.
class HppOpnameRepository {
  final _uuid = const Uuid();

  Future<Database> get _db => AppDatabase.instance.database;

  // --- HPP: ingredients ---

  Future<List<Ingredient>> getIngredients({IngredientCategory? category}) async {
    final db = await _db;
    final rows = await db.query(
      'ingredients',
      where: category != null ? 'category = ?' : null,
      whereArgs: category != null ? [category.dbValue] : null,
      orderBy: 'created_at ASC',
    );
    return rows.map(Ingredient.fromMap).toList();
  }

  Future<Ingredient> createIngredient({
    required IngredientCategory category,
    required String name,
    required String unit,
    required int lastPrice,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();

    await db.insert('ingredients', {
      'id': id,
      'category': category.dbValue,
      'name': name,
      'unit': unit,
      'last_price': lastPrice,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    return Ingredient(id: id, category: category, name: name, unit: unit, lastPrice: lastPrice, isActive: true);
  }

  /// Updates an ingredient's cost basis. Per the mockup's info banner,
  /// this is the single source every Menu & Variant HPP calculation is
  /// meant to read from — no other table stores a duplicate price.
  Future<void> updateIngredientPrice(String id, int newPrice) async {
    final db = await _db;
    await db.update(
      'ingredients',
      {'last_price': newPrice, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deactivateIngredient(String id) async {
    final db = await _db;
    await db.update(
      'ingredients',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Stok Opname: sessions ---

  Future<List<StockOpnameSession>> getSessions() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT
        s.id, s.status, s.created_at, s.completed_at,
        COUNT(i.id) as item_count,
        COALESCE(SUM(i.qty * i.price_used), 0) as total_value
      FROM stock_opname_sessions s
      LEFT JOIN stock_opname_items i ON i.session_id = s.id
      GROUP BY s.id
      ORDER BY s.created_at DESC
    ''');

    return rows.map((row) {
      return StockOpnameSession(
        id: row['id'] as String,
        status: StockOpnameStatus.fromDb(row['status'] as String),
        createdAt: DateTime.parse(row['created_at'] as String),
        completedAt: row['completed_at'] != null ? DateTime.parse(row['completed_at'] as String) : null,
        itemCount: row['item_count'] as int,
        totalValue: (row['total_value'] as num).round(),
      );
    }).toList();
  }

  /// Saves a full session in one pass: all items entered across
  /// whichever categories were visited (per Agung's direction — one
  /// session, free to switch categories, single submit), not saved
  /// incrementally per category.
  Future<void> submitSession({
    required List<StockOpnameItem> items,
    required bool asDraft,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final sessionId = _uuid.v4();

    await db.insert('stock_opname_sessions', {
      'id': sessionId,
      'status': asDraft ? StockOpnameStatus.draft.dbValue : StockOpnameStatus.selesai.dbValue,
      'created_at': now,
      'completed_at': asDraft ? null : now,
      'created_by': null, // no Staff/Auth module yet — see docs/06 phase 3
    });

    for (final item in items) {
      await db.insert('stock_opname_items', {
        'id': _uuid.v4(),
        'session_id': sessionId,
        'ingredient_id': item.ingredientId,
        'qty': item.qty,
        'price_used': item.priceUsed,
      });
    }
  }
}
