// Tests for AppDatabase's v9->v10 migration (users/roles/permissions/
// user_roles/user_branch_access tables) and the auth seed data.
//
// IMPORTANT — these tests need a real device or emulator to run:
// sqflite_sqlcipher has no FFI/desktop test-mode equivalent to
// sqflite_common_ffi (which only supports plain sqflite, not the
// SQLCipher-linked variant this app uses for encryption). There was no
// prior precedent for testing AppDatabase directly in this codebase —
// every existing test file (hrd_payroll_engine_test.dart etc.) tests
// pure-Dart domain logic with no database involved at all.
//
// Run with: `flutter test integration_test/` on a connected device/
// emulator (NOT plain `flutter test`, which uses a host-side VM that
// cannot load the native SQLCipher library) — or move this under
// integration_test/ using the integration_test package if migrating
// that tooling in is preferred. Left under test/ for now to match this
// PR's file layout; flag this in the Tahap-A report as unverified in
// this sandboxed environment (no Flutter/device access at all here —
// see [[mamam-kasir-flutter]] notes on the sandbox's tooling limits).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/data/app_database.dart';
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
    tempDir = await Directory.systemTemp.createTemp('mamam_kasir_test_');
    PathProviderPlatform.instance = _FakePathProvider.withPath(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AppDatabase v10 auth tables (fresh install via onCreate)', () {
    test('seeds exactly 3 default roles: owner, manager, staff', () async {
      final db = await AppDatabase.instance.database;
      final roles = await db.query('roles');

      expect(roles.length, 3);
      expect(roles.map((r) => r['name']).toSet(), {'owner', 'manager', 'staff'});
      expect(roles.every((r) => r['is_default'] == 1), isTrue);
    });

    test('seeds exactly 3 users, each with a hashed (non-plaintext) password', () async {
      final db = await AppDatabase.instance.database;
      final users = await db.query('users');

      expect(users.length, 3);
      expect(users.map((u) => u['username']).toSet(), {'owner', 'manager', 'staff'});
      for (final user in users) {
        // The seeded plaintext passwords are 'owner123'/'manager123'/
        // 'staff123' — none of those literal strings should appear as
        // the stored hash.
        expect(user['password_hash'], isNot(equals('owner123')));
        expect(user['password_hash'], isNot(equals('manager123')));
        expect(user['password_hash'], isNot(equals('staff123')));
        expect(user['password_salt'], isNotNull);
        expect((user['password_salt'] as String).isNotEmpty, isTrue);
        // No PIN set yet — that's the "set PIN after first login" flow.
        expect(user['pin_hash'], isNull);
        expect(user['failed_pin_attempts'], 0);
        expect(user['locked_at'], isNull);
      }
    });

    test('there is only ever one Owner (single-Owner rule)', () async {
      final db = await AppDatabase.instance.database;
      final ownerAssignments = await db.rawQuery('''
        SELECT COUNT(*) as cnt FROM user_roles
        JOIN roles ON roles.id = user_roles.role_id
        WHERE roles.name = 'owner'
      ''');

      expect(ownerAssignments.first['cnt'], 1);
    });

    test('each seeded user has exactly one role assignment', () async {
      final db = await AppDatabase.instance.database;
      final users = await db.query('users');

      for (final user in users) {
        final roles = await db.query('user_roles', where: 'user_id = ?', whereArgs: [user['id']]);
        expect(roles.length, 1, reason: '${user['username']} should have exactly one role');
      }
    });

    test('existing tables (categories, menu_items, branches, ...) are untouched', () async {
      final db = await AppDatabase.instance.database;

      // Sanity check that the auth-table addition didn't regress the
      // pre-existing seed data from _seedDemoData/_seedIngredients/
      // _seedSampleTransactions.
      final categories = await db.query('categories');
      final menuItems = await db.query('menu_items');
      final branches = await db.query('branches');

      expect(categories, isNotEmpty);
      expect(menuItems, isNotEmpty);
      expect(branches, isNotEmpty);
    });
  });

  group('roles table supports custom roles (schema-level)', () {
    test('a role beyond the 3 defaults can be inserted', () async {
      final db = await AppDatabase.instance.database;
      final now = DateTime.now().toIso8601String();

      await db.insert('roles', {
        'id': 'custom-role-test',
        'name': 'kurir',
        'is_default': 0,
        'created_at': now,
        'updated_at': now,
      });

      final roles = await db.query('roles');
      expect(roles.length, 4);
      expect(roles.any((r) => r['name'] == 'kurir' && r['is_default'] == 0), isTrue);
    });
  });
}

// NOTE: a true "upgrade from v9 preserves existing data" test — opening
// a database file seeded by a v9-only onCreate (no auth tables), then
// re-opening it at v10 and asserting the pre-existing rows AND the new
// auth tables both exist — needs either:
//   (a) a fixture .db file frozen at v9 checked into the repo, or
//   (b) temporarily forcing AppDatabase._dbVersion to 9, opening once,
//       then forcing it back to 10 and reopening the same file path.
// (b) isn't possible from an external test file since _dbVersion is a
// private static const; doing this properly means either exposing a
// test-only seam in AppDatabase or adding a fixture file. Flagged as a
// genuine gap in this checkpoint's test coverage rather than skipped
// silently — see the Tahap-A report's "belum diverifikasi" section.
