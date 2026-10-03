// Tests for branch access against the real database: the v13 seed,
// BranchAccessRepository's per-role rules, pickDefaultBranchId, and the
// branch grant that UserManagementRepository gives new accounts.
//
// Needs a real device/emulator, not plain `flutter test` — same
// sqflite_sqlcipher limitation as the other DB tests; see
// app_database_auth_test.dart's header for the full explanation. The
// pure parts of this feature (pickActiveBranchId, the session
// controller's branch handling) are covered separately in
// app_session_controller_branch_test.dart, which needs no device.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/data/app_database.dart';
import 'package:mamam_kasir/core/data/branch_defaults.dart';
import 'package:mamam_kasir/core/session/app_session.dart';
import 'package:mamam_kasir/core/session/branch_access_repository.dart';
import 'package:mamam_kasir/features/user_management/data/user_management_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PlatformInterface implements PathProviderPlatform {
  static final Object _token = Object();
  final String tempDirPath;
  _FakePathProvider.withPath(this.tempDirPath) : super(token: _token);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDirPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mamam_kasir_branch_test_');
    PathProviderPlatform.instance = _FakePathProvider.withPath(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<String> userId(String username) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('users', where: 'username = ?', whereArgs: [username], limit: 1);
    return rows.first['id'] as String;
  }

  Future<String> addBranch(String name, {int sortOrder = 99, bool active = true}) async {
    final db = await AppDatabase.instance.database;
    final id = 'branch-test-${name.toLowerCase()}';
    final now = DateTime.now().toIso8601String();
    await db.insert('branches', {
      'id': id,
      'name': name,
      'is_active': active ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  group('seed (fresh install runs the same code as the v13 upgrade)', () {
    test('Manager and Staff each get exactly one branch grant, to the default branch', () async {
      final db = await AppDatabase.instance.database;
      final defaultBranch = await pickDefaultBranchId(db);

      for (final username in ['manager', 'staff']) {
        final rows = await db.query('user_branch_access', where: 'user_id = ?', whereArgs: [await userId(username)]);
        expect(rows.length, 1, reason: '$username should have exactly one grant');
        expect(rows.first['branch_id'], defaultBranch);
      }
    });

    test('Owner gets no grants (Owner is unrestricted, not enumerated)', () async {
      final db = await AppDatabase.instance.database;
      final rows = await db.query('user_branch_access', where: 'user_id = ?', whereArgs: [await userId('owner')]);
      expect(rows, isEmpty);
    });
  });

  group('BranchAccessRepository.accessibleBranches', () {
    test('Owner sees every ACTIVE branch', () async {
      await addBranch('Cabang B', sortOrder: 50);
      await addBranch('Cabang Mati', sortOrder: 60, active: false);

      final branches = await BranchAccessRepository().accessibleBranches(userId: await userId('owner'), role: AppRole.owner);

      final names = branches.map((b) => b.name).toList();
      expect(names, contains('Cabang B'));
      expect(names, isNot(contains('Cabang Mati')));
    });

    test('Manager sees ONLY the branch they were granted, not every branch', () async {
      await addBranch('Cabang B', sortOrder: 50);

      final branches = await BranchAccessRepository().accessibleBranches(userId: await userId('manager'), role: AppRole.manager);

      expect(branches.length, 1, reason: 'the second branch exists but was never granted to this account');
      expect(branches.map((b) => b.name), isNot(contains('Cabang B')));
    });

    test('a branch that gets switched off disappears from a Manager\'s access (fails closed)', () async {
      final db = await AppDatabase.instance.database;
      final defaultBranch = (await pickDefaultBranchId(db))!;
      await db.update('branches', {'is_active': 0}, where: 'id = ?', whereArgs: [defaultBranch]);

      final branches = await BranchAccessRepository().accessibleBranches(userId: await userId('manager'), role: AppRole.manager);

      expect(branches, isEmpty);
    });

    test('an account with no grants has no branches (no rows = no access)', () async {
      final db = await AppDatabase.instance.database;
      await db.delete('user_branch_access', where: 'user_id = ?', whereArgs: [await userId('staff')]);

      final branches = await BranchAccessRepository().accessibleBranches(userId: await userId('staff'), role: AppRole.staff);

      expect(branches, isEmpty);
    });

    test('resolveActiveBranchId falls back to the first accessible branch when the preferred one is not allowed', () async {
      final other = await addBranch('Cabang B', sortOrder: 50);
      final repo = BranchAccessRepository();

      final resolved = await repo.resolveActiveBranchId(
        userId: await userId('manager'),
        role: AppRole.manager,
        preferredBranchId: other, // exists, but not granted to the Manager
      );

      // Compare with what was actually granted to the Manager, not with a
      // fresh pickDefaultBranchId(): the extra branch added above could
      // change which branch counts as "default" now, but not the grant
      // that was made at seed time.
      final db = await AppDatabase.instance.database;
      final grant = await db.query('user_branch_access', where: 'user_id = ?', whereArgs: [await userId('manager')]);
      expect(resolved, grant.first['branch_id']);
    });
  });

  group('pickDefaultBranchId', () {
    test('prefers an active branch over an earlier-sorted inactive one', () async {
      final db = await AppDatabase.instance.database;
      await addBranch('Aaa Mati', sortOrder: -10, active: false);
      final activeLater = await addBranch('Zzz Hidup', sortOrder: 500);
      // Switch every pre-existing branch off so the only active one is the new one.
      await db.update('branches', {'is_active': 0}, where: 'id != ?', whereArgs: [activeLater]);

      expect(await pickDefaultBranchId(db), activeLater);
    });
  });

  group('UserManagementRepository grants a branch to accounts it creates', () {
    test('a new Staff account gets the default branch', () async {
      final newId = await UserManagementRepository().createUser(
        username: 'kasir2',
        password: 'rahasia123',
        displayName: 'Kasir Dua',
        role: AppRole.staff,
      );

      final db = await AppDatabase.instance.database;
      final rows = await db.query('user_branch_access', where: 'user_id = ?', whereArgs: [newId]);
      expect(rows.length, 1);
      expect(rows.first['branch_id'], await pickDefaultBranchId(db));
    });

    test('changing an account\'s role does not stack a second grant on top of an existing one', () async {
      final repo = UserManagementRepository();
      final staffId = await userId('staff');

      await repo.updateUser(
        userId: staffId,
        username: 'staff',
        displayName: 'Staff',
        role: AppRole.manager,
      );

      final db = await AppDatabase.instance.database;
      final rows = await db.query('user_branch_access', where: 'user_id = ?', whereArgs: [staffId]);
      expect(rows.length, 1);
    });
  });
}
