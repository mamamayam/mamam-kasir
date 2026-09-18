import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../../core/data/app_database.dart';
import '../domain/cabang_models.dart';

/// Reads/writes the `branches` table for Manajemen Cabang.
///
/// Read-only plus an activate/deactivate toggle for now. Create/edit/
/// delete are deliberately not here yet: adding a branch is entangled
/// with branch-scoped menu prices, user branch access and the "Maks
/// Toko" ceiling, none of which exist — see kDefaultMaxBranches.
class CabangRepository {
  Future<Database> get _db => AppDatabase.instance.database;

  Future<List<Cabang>> getBranches() async {
    final db = await _db;
    final rows = await db.query('branches', orderBy: 'sort_order ASC, name ASC');
    return rows.map(Cabang.fromRow).toList();
  }

  /// Flips a branch's operational on/off state. Never deletes — an
  /// inactive branch keeps all of its history (see [Cabang.isActive]).
  Future<void> setActive(String id, bool isActive) async {
    final db = await _db;
    await db.update(
      'branches',
      {'is_active': isActive ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
