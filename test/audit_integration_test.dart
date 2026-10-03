// Tests verifying AuthRepository and PinAuthRepository actually record
// the audit events they're documented to record — using a fake
// AuditRepository (constructor-injected) to assert WHAT was recorded,
// separate from audit_repository_test.dart's DB-round-trip tests.
//
// Still needs a real device/emulator for the underlying users/PIN
// operations (same sqflite_sqlcipher limitation as every other DB test
// in this suite) — the fake only replaces the audit-writing side, not
// the users-table operations these repositories perform.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/audit/audit_event_type.dart';
import 'package:mamam_kasir/core/audit/audit_repository.dart';
import 'package:mamam_kasir/core/data/app_database.dart';
import 'package:mamam_kasir/features/auth/data/auth_repository.dart';
import 'package:mamam_kasir/features/auth/data/pin_auth_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String tempDirPath;
  _FakePathProvider.withPath(this.tempDirPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDirPath;
}

/// Records calls in memory instead of writing to the DB — lets these
/// tests assert exactly which event types were (or weren't) recorded,
/// without needing to separately query audit_logs back out.
class _RecordingAuditRepository extends AuditRepository {
  final List<AuditEventType> recordedEvents = [];

  @override
  Future<void> record({required AuditEventType eventType, String? actorUserId, String? metadata}) async {
    recordedEvents.add(eventType);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String ownerId;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mamam_kasir_audit_integration_test_');
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

  group('AuthRepository records login', () {
    test('successful login records exactly one login event', () async {
      final audit = _RecordingAuditRepository();
      final repo = AuthRepository(audit: audit);

      final result = await repo.verifyCredentials('owner', 'owner123');

      expect(result, isNotNull);
      expect(audit.recordedEvents, [AuditEventType.login]);
    });

    test('failed login (wrong password) records nothing', () async {
      final audit = _RecordingAuditRepository();
      final repo = AuthRepository(audit: audit);

      final result = await repo.verifyCredentials('owner', 'wrong-password');

      expect(result, isNull);
      expect(audit.recordedEvents, isEmpty);
    });
  });

  group('PinAuthRepository records PIN events', () {
    test('setPin records exactly one pinChanged event', () async {
      final audit = _RecordingAuditRepository();
      final repo = PinAuthRepository(audit: audit);

      await repo.setPin(ownerId, '1111');

      expect(audit.recordedEvents, [AuditEventType.pinChanged]);
    });

    test('a wrong PIN attempt (not yet locked) records exactly one pinIncorrect event', () async {
      final audit = _RecordingAuditRepository();
      final repo = PinAuthRepository(audit: audit);
      await repo.setPin(ownerId, '1111');
      audit.recordedEvents.clear(); // Drop the pinChanged from setPin above.

      await repo.verifyPin(ownerId, '0000');

      expect(audit.recordedEvents, [AuditEventType.pinIncorrect]);
    });

    test('the 5th wrong attempt records BOTH pinIncorrect and pinLocked, in that order', () async {
      final audit = _RecordingAuditRepository();
      final repo = PinAuthRepository(audit: audit);
      await repo.setPin(ownerId, '1111');

      for (var i = 0; i < PinAuthRepository.maxAttempts - 1; i++) {
        await repo.verifyPin(ownerId, '0000');
      }
      audit.recordedEvents.clear(); // Drop everything before the 5th attempt.

      final result = await repo.verifyPin(ownerId, '0000');

      expect(result, PinVerifyResult.justLocked);
      expect(audit.recordedEvents, [AuditEventType.pinIncorrect, AuditEventType.pinLocked]);
    });

    test('an attempt against an already-locked account records nothing (no re-check happens)', () async {
      final audit = _RecordingAuditRepository();
      final repo = PinAuthRepository(audit: audit);
      await repo.setPin(ownerId, '1111');
      for (var i = 0; i < PinAuthRepository.maxAttempts; i++) {
        await repo.verifyPin(ownerId, '0000');
      }
      audit.recordedEvents.clear();

      final result = await repo.verifyPin(ownerId, '1111'); // even the correct PIN

      expect(result, PinVerifyResult.alreadyLocked);
      expect(audit.recordedEvents, isEmpty, reason: 'alreadyLocked never reaches the audited wrong-PIN path');
    });

    test('a correct PIN attempt records nothing (only wrong/lock/change are audited, not success)', () async {
      final audit = _RecordingAuditRepository();
      final repo = PinAuthRepository(audit: audit);
      await repo.setPin(ownerId, '1111');
      audit.recordedEvents.clear();

      final result = await repo.verifyPin(ownerId, '1111');

      expect(result, PinVerifyResult.correct);
      expect(audit.recordedEvents, isEmpty);
    });

    test('changePin records exactly one pinChanged event (not two, and not a pinIncorrect for the correct current-PIN check)', () async {
      final audit = _RecordingAuditRepository();
      final repo = PinAuthRepository(audit: audit);
      await repo.setPin(ownerId, '1111');
      audit.recordedEvents.clear();

      final success = await repo.changePin(ownerId, currentPin: '1111', newPin: '2222');

      expect(success, isTrue);
      expect(audit.recordedEvents, [AuditEventType.pinChanged]);
    });
  });
}
