// Tests for PermissionService (lib/core/permissions/permission_service.dart)
// and the v11 permissions-seed migration in app_database.dart.
//
// Same environment limitation as app_database_auth_test.dart/
// pin_auth_repository_test.dart: needs a real device/emulator, not plain
// `flutter test`, because sqflite_sqlcipher has no FFI/desktop test
// mode. See app_database_auth_test.dart's header for the full
// explanation — not repeated here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/data/app_database.dart';
import 'package:mamam_kasir/core/permissions/permission_defaults.dart';
import 'package:mamam_kasir/core/permissions/permission_key.dart';
import 'package:mamam_kasir/core/permissions/permission_mode.dart';
import 'package:mamam_kasir/core/permissions/permission_service.dart';
import 'package:mamam_kasir/core/session/app_session.dart';
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
    tempDir = await Directory.systemTemp.createTemp('mamam_kasir_permission_test_');
    PathProviderPlatform.instance = _FakePathProvider.withPath(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('v11 migration seeds the permissions table', () {
    test('permissions table has one row per (key, role) pair in defaultPermissions', () async {
      final db = await AppDatabase.instance.database;
      final rows = await db.query('permissions');

      final expectedCount = PermissionKey.values.length * AppRole.values.length;
      expect(rows.length, expectedCount);
    });

    test('seeded rows match defaultPermissions exactly', () async {
      final db = await AppDatabase.instance.database;

      for (final key in PermissionKey.values) {
        for (final role in AppRole.values) {
          final rows = await db.rawQuery(
            '''
            SELECT permissions.mode
            FROM permissions
            JOIN roles ON roles.id = permissions.role_id
            WHERE roles.name = ? AND permissions.permission_key = ?
            ''',
            [role.name, key.name],
          );
          expect(rows.length, 1, reason: 'expected exactly one row for ($key, $role)');
          expect(rows.first['mode'], defaultPermissions[key]![role]!.name);
        }
      }
    });

    test('seeding is idempotent — table is not double-seeded on a second open', () async {
      final dbFirst = await AppDatabase.instance.database;
      final firstCount = (await dbFirst.query('permissions')).length;

      // AppDatabase.instance.database returns the same already-open
      // connection on a second call within the same process, so this
      // mainly re-confirms the guard in _seedPermissionsData rather
      // than exercising a true re-open — a true "close and reopen the
      // same file" idempotency check would need the same kind of
      // multi-run device test noted as a gap in app_database_auth_test.dart.
      final dbSecond = await AppDatabase.instance.database;
      final secondCount = (await dbSecond.query('permissions')).length;

      expect(secondCount, firstCount);
    });
  });

  group('PermissionService.resolve', () {
    test('null role always resolves to deny', () async {
      final service = PermissionService();
      final mode = await service.resolve(null, PermissionKey.viewOwnerMenu);
      expect(mode, PermissionMode.deny);
    });

    test('resolves viewOwnerMenu correctly for all 3 roles from the seeded DB rows', () async {
      final service = PermissionService();

      expect(await service.resolve(AppRole.owner, PermissionKey.viewOwnerMenu), PermissionMode.direct);
      expect(await service.resolve(AppRole.manager, PermissionKey.viewOwnerMenu), PermissionMode.direct);
      expect(await service.resolve(AppRole.staff, PermissionKey.viewOwnerMenu), PermissionMode.deny);
    });

    test('resolves editExpense correctly (Staff gets approval, not deny or direct)', () async {
      final service = PermissionService();
      expect(await service.resolve(AppRole.staff, PermissionKey.editExpense), PermissionMode.approval);
    });

    test('resolves restoreTransaction correctly (Owner AND Manager both approval, not direct)', () async {
      final service = PermissionService();
      expect(await service.resolve(AppRole.owner, PermissionKey.restoreTransaction), PermissionMode.approval);
      expect(await service.resolve(AppRole.manager, PermissionKey.restoreTransaction), PermissionMode.approval);
    });

    test('a DB row overrides the hardcoded default when they differ', () async {
      final db = await AppDatabase.instance.database;
      final service = PermissionService();

      // Sanity-check the default first.
      expect(await service.resolve(AppRole.staff, PermissionKey.viewOwnerMenu), PermissionMode.deny);

      // Manually flip the DB row to `direct` for Staff — simulates a
      // future Owner-facing permission-editing screen changing this.
      final staffRole = (await db.query('roles', where: 'name = ?', whereArgs: ['staff'])).first;
      await db.update(
        'permissions',
        {'mode': 'direct'},
        where: 'role_id = ? AND permission_key = ?',
        whereArgs: [staffRole['id'], PermissionKey.viewOwnerMenu.name],
      );

      // resolve() re-queries every call (no cache) — per "perubahan
      // permission berlaku langsung" — so this should now be direct.
      expect(await service.resolve(AppRole.staff, PermissionKey.viewOwnerMenu), PermissionMode.direct);
    });

    test('isAllowed is true only for direct, not approval or deny', () async {
      final service = PermissionService();

      expect(await service.isAllowed(AppRole.owner, PermissionKey.viewOwnerMenu), isTrue); // direct
      expect(await service.isAllowed(AppRole.staff, PermissionKey.editExpense), isFalse); // approval
      expect(await service.isAllowed(AppRole.staff, PermissionKey.viewOwnerMenu), isFalse); // deny
    });
  });
}
