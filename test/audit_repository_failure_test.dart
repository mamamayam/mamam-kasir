// Tests that a failing audit write never blocks the action being audited.
//
// Pure Dart, no database: the raw write (insertEntry) is overridden, so
// this runs with plain `flutter test` — unlike audit_repository_test.dart
// which round-trips through the real encrypted DB.
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/audit/audit_event_type.dart';
import 'package:mamam_kasir/core/audit/audit_repository.dart';

class _AlwaysFailingAuditRepository extends AuditRepository {
  int attempts = 0;

  @override
  Future<void> insertEntry({
    required AuditEventType eventType,
    String? actorUserId,
    String? metadata,
  }) async {
    attempts++;
    throw StateError('simulated: audit_logs table is broken');
  }
}

class _CapturingAuditRepository extends AuditRepository {
  final List<({AuditEventType type, String? actor, String? metadata})> written = [];

  @override
  Future<void> insertEntry({
    required AuditEventType eventType,
    String? actorUserId,
    String? metadata,
  }) async {
    written.add((type: eventType, actor: actorUserId, metadata: metadata));
  }
}

void main() {
  group('AuditRepository.record never blocks the audited action', () {
    test('a failing write does not throw out of record()', () async {
      final repo = _AlwaysFailingAuditRepository();

      // If record() rethrew, this await would fail the test.
      await repo.record(eventType: AuditEventType.login, actorUserId: 'user-1');

      expect(repo.attempts, 1, reason: 'the write was attempted exactly once, then the failure was swallowed');
    });

    test('every event type is covered by the same never-throws guarantee', () async {
      final repo = _AlwaysFailingAuditRepository();

      for (final type in AuditEventType.values) {
        await repo.record(eventType: type, actorUserId: 'user-1');
      }

      expect(repo.attempts, AuditEventType.values.length);
    });

    test('a successful write passes the event, actor and metadata straight through', () async {
      final repo = _CapturingAuditRepository();

      await repo.record(eventType: AuditEventType.pinChanged, actorUserId: 'user-1', metadata: 'ctx');

      expect(repo.written.length, 1);
      expect(repo.written.first.type, AuditEventType.pinChanged);
      expect(repo.written.first.actor, 'user-1');
      expect(repo.written.first.metadata, 'ctx');
    });
  });
}
