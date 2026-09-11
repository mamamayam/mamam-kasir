import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/app_database.dart';
import '../domain/menu_management_models.dart';

/// CRUD access for Menu Management (menu items, categories, variant
/// groups) against the local encrypted database.
///
/// This is the only place in the app that runs SQL for these tables —
/// [MenuManagementController] and the UI never touch [AppDatabase]
/// directly, so swapping in real sync (docs/06 phase 5) later only
/// means changing what happens inside these methods, not any call site.
class MenuManagementRepository {
  final _uuid = const Uuid();

  Future<Database> get _db => AppDatabase.instance.database;

  // --- Categories ---

  Future<List<MenuCategory>> getCategories() async {
    final db = await _db;
    final rows = await db.query('categories', orderBy: 'sort_order ASC');
    return rows.map(_categoryFromRow).toList();
  }

  Future<MenuCategory> getOrCreateCategory(String name) async {
    final db = await _db;
    final existing = await db.query('categories', where: 'name = ?', whereArgs: [name], limit: 1);
    if (existing.isNotEmpty) return _categoryFromRow(existing.first);

    final countResult = await db.rawQuery('SELECT COUNT(*) as c FROM categories');
    final sortOrder = Sqflite.firstIntValue(countResult) ?? 0;

    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();
    await db.insert('categories', {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
    return MenuCategory(id: id, name: name, sortOrder: sortOrder, isActive: true);
  }

  MenuCategory _categoryFromRow(Map<String, Object?> row) {
    return MenuCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      sortOrder: row['sort_order'] as int,
      isActive: (row['is_active'] as int) == 1,
    );
  }

  // --- Menu items ---

  Future<List<MenuItem>> getMenuItems() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT menu_items.*, categories.name as category_name
      FROM menu_items
      JOIN categories ON categories.id = menu_items.category_id
      ORDER BY menu_items.created_at ASC
    ''');

    final items = <MenuItem>[];
    for (final row in rows) {
      final variantGroupIds = await _getVariantGroupIdsForMenuItem(row['id'] as String);
      items.add(_menuItemFromRow(row, variantGroupIds));
    }
    return items;
  }

  Future<List<String>> _getVariantGroupIdsForMenuItem(String menuItemId) async {
    final db = await _db;
    final rows = await db.query(
      'menu_item_variant_groups',
      columns: ['variant_group_id'],
      where: 'menu_item_id = ?',
      whereArgs: [menuItemId],
    );
    return rows.map((r) => r['variant_group_id'] as String).toList();
  }

  MenuItem _menuItemFromRow(Map<String, Object?> row, List<String> variantGroupIds) {
    return MenuItem(
      id: row['id'] as String,
      categoryId: row['category_id'] as String,
      categoryName: row['category_name'] as String,
      name: row['name'] as String,
      price: row['price'] as int,
      hpp: row['hpp'] as int?,
      unit: row['unit'] as String,
      isActive: (row['is_active'] as int) == 1,
      variantGroupIds: variantGroupIds,
    );
  }

  /// Creates a new menu item. `categoryName` is resolved to an existing
  /// category or a newly created one — the add-form's category dropdown
  /// is currently a fixed list (see [AddMenuItemModal]), but this keeps
  /// the repository correct even once categories become user-editable.
  Future<MenuItem> createMenuItem({
    required String categoryName,
    required String name,
    required int price,
    int? hpp,
    required String unit,
    List<String> variantGroupIds = const [],
  }) async {
    final db = await _db;
    final category = await getOrCreateCategory(categoryName);
    final now = DateTime.now().toIso8601String();
    final id = _uuid.v4();

    await db.insert('menu_items', {
      'id': id,
      'category_id': category.id,
      'name': name,
      'price': price,
      'hpp': hpp,
      'unit': unit,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    for (final groupId in variantGroupIds) {
      await db.insert('menu_item_variant_groups', {
        'menu_item_id': id,
        'variant_group_id': groupId,
      });
    }

    return MenuItem(
      id: id,
      categoryId: category.id,
      categoryName: category.name,
      name: name,
      price: price,
      hpp: hpp,
      unit: unit,
      isActive: true,
      variantGroupIds: variantGroupIds,
    );
  }

  Future<void> updateMenuItem(MenuItem item) async {
    final db = await _db;
    final category = await getOrCreateCategory(item.categoryName);
    final now = DateTime.now().toIso8601String();

    await db.update(
      'menu_items',
      {
        'category_id': category.id,
        'name': item.name,
        'price': item.price,
        'hpp': item.hpp,
        'unit': item.unit,
        'is_active': item.isActive ? 1 : 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );

    await db.delete('menu_item_variant_groups', where: 'menu_item_id = ?', whereArgs: [item.id]);
    for (final groupId in item.variantGroupIds) {
      await db.insert('menu_item_variant_groups', {
        'menu_item_id': item.id,
        'variant_group_id': groupId,
      });
    }
  }

  /// Soft-delete only — per edge-case rule ("Inactive masters cannot be
  /// newly selected; history remains snapshot-based"), menu items are
  /// never hard-deleted once real transactions can reference them. This
  /// flips `is_active` off rather than removing the row.
  Future<void> deactivateMenuItem(String id) async {
    final db = await _db;
    await db.update(
      'menu_items',
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> reactivateMenuItem(String id) async {
    final db = await _db;
    await db.update(
      'menu_items',
      {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Variant groups ---

  Future<List<VariantGroup>> getVariantGroups() async {
    final db = await _db;
    final groupRows = await db.query('variant_groups', orderBy: 'created_at ASC');

    final groups = <VariantGroup>[];
    for (final row in groupRows) {
      final optionRows = await db.query(
        'variant_options',
        where: 'variant_group_id = ?',
        whereArgs: [row['id']],
        orderBy: 'sort_order ASC',
      );
      groups.add(VariantGroup(
        id: row['id'] as String,
        name: row['name'] as String,
        isRequired: (row['is_required'] as int) == 1,
        maxSelection: row['max_selection'] as int,
        isActive: (row['is_active'] as int) == 1,
        options: optionRows
            .map((o) => VariantOption(
                  id: o['id'] as String,
                  name: o['name'] as String,
                  extraPrice: o['extra_price'] as int,
                ))
            .toList(),
      ));
    }
    return groups;
  }
}
