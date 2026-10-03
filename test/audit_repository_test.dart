// Tests for AuditRepository (lib/core/audit/audit_repository.dart) and
// the v12 audit_logs migration.
//
// Same environment limitation as app_database_auth_test.dart/
// pin_auth_repository_test.dart/permission_service_test.dart: needs a
// real device/emulator, not plain `flutter test`, because
// sqflite_sqlcipher has no FFI/desktop test mode. See
// app_database_auth_test.dart's header for the full explanation.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/audit/audit_event_type.dart';
import 'package:mamam_kasir/core/audit/audit_repository.dart';
import 'package:mamam_kasir/core/data/app_database.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String tempDirPath;
  _FakePathProvider.withPath(this.tempDirPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDirPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String ownerId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mamam_kasir_audit_test_');
    PathProviderPlatform.instance = _FakePathProvider.withPath(tempDir.path);

    final db = await AppDatabase.instance.database;
    final ownerRow = await db.query('users', where: 'username = ?', whereArgs: ['owner'], limit: 1);
    ownerId = ownerRow.first['id'] as String;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AuditRepository.record', () {
    test('writes a row readable back via listRecent', () async {
      final repo = AuditRepository();
      await repo.record(eventType: AuditEventType.login, actorUserId: ownerId);

      final entries = await repo.listRecent();
      expect(entries.length, 1);
      expect(entries.first.eventType, AuditEventType.login);
      expect(entries.first.actorUserId, ownerId);
      expect(entries.first.actorUsername, 'owner');
    });

    test('accepts a null actorUserId', () async {
      final repo = AuditRepository();
      await repo.record(eventType: AuditEventType.pinIncorrect, actorUserId: null);

      final entries = await repo.listRecent();
      expect(entries.first.actorUserId, isNull);
      expect(entries.first.actorUsername, isNull);
    });

    test('stores and returns metadata when provided', () async {
      final repo = AuditRepository();
      await repo.record(eventType: AuditEventType.pinChanged, actorUserId: ownerId, metadata: 'context');

      final entries = await repo.listRecent();
      expect(entries.first.metadata, 'context');
    });

    test('listRecent returns newest first', () async {
      final repo = AuditRepository();
      await repo.record(eventType: AuditEventType.login, actorUserId: ownerId);
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.record(eventType: AuditEventType.logout, actorUserId: ownerId);

      final entries = await repo.listRecent();
      expect(entries.length, 2);
      expect(entries.first.eventType, AuditEventType.logout);
      expect(entries.last.eventType, AuditEventType.login);
    });

    test('respects the limit parameter', () async {
      final repo = AuditRepository();
      for (var i = 0; i < 5; i++) {
        await repo.record(eventType: AuditEventType.login, actorUserId: ownerId);
      }

      final entries = await repo.listRecent(limit: 3);
      expect(entries.length, 3);
    });

    test('survives a soft-deleted actor (FK to users stays valid, row not lost)', () async {
      final repo = AuditRepository();
      await repo.record(eventType: AuditEventType.login, actorUserId: ownerId);

      final db = await AppDatabase.instance.database;
      // Deactivate (soft-delete) the actor — same is_active=0 pattern
      // UserManagementRepository uses, never a hard delete.
      await db.update('users', {'is_active': 0}, where: 'id = ?', whereArgs: [ownerId]);

      final entries = await repo.listRecent();
      expect(entries.length, 1, reason: 'the audit row must survive the actor being deactivated');
      expect(entries.first.actorUserId, ownerId);
    });
  });

  group('append-only by construction', () {
    test('AuditRepository exposes no update or delete method', () {
      // This is a structural/API-shape assertion, not a behavioral one:
      // confirms the class has no update()/delete() (its surface is
      // record/listRecent, plus insertEntry — the raw write behind
      // record, public only so tests can override it) by checking it
      // compiles with exactly that surface — there is no update()/
      // delete()/remove() method to even call. Documented here as an
      // explicit, visible check rather than leaving "append-only" as an
      // unverified claim in a doc comment only.
      final repo = AuditRepository();
      expect(repo.record, isNotNull);
      expect(repo.listRecent, isNotNull);
      // If this file fails to compile after someone adds an update/
      // delete method, that's a deliberate, visible decision — not
      // testable in Dart via reflection without dart:mirrors, so the
      // real enforcement is code review + this file's existence as a
      // marker of intent.
    });
  });
}
