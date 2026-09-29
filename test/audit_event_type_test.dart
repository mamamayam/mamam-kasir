// Test for AuditEventType (lib/core/audit/audit_event_type.dart).
// Pure Dart, no DB — runs with plain `flutter test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/audit/audit_event_type.dart';

void main() {
  test('AuditEventType has exactly the 7 events the task brief specified, no more', () {
    // "login, logout, PIN salah, lock, ganti PIN, perubahan permission,
    // auto-lock" — 7 events. This test exists so someone adding an 8th
    // event type for a feature that doesn't audit anything real yet
    // (e.g. a transaction-edit event ahead of Tahap B) has to
    // deliberately update this count, not add one silently.
    expect(AuditEventType.values.length, 7);
    expect(AuditEventType.values.map((e) => e.name).toSet(), {
      'login',
      'logout',
      'pinIncorrect',
      'pinLocked',
      'pinChanged',
      'permissionChanged',
      'autoLock',
    });
  });
}
