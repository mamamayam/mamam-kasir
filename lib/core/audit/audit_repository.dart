import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import 'audit_event_type.dart';
import 'audit_log_entry.dart';

const _uuid = Uuid();

/// Append-only writer/reader for `audit_logs` (A5 — see
/// [[mamam-kasir-flutter]] notes). "Append-only" is enforced by this
/// class's own shape, not just convention: there is no `update` or
/// `delete` method here at all, on purpose — per the task brief's
/// "Tabel audit_logs append-only (tanpa update/delete di level
/// repository)." If a future need arises to correct or purge audit
/// data, that is a deliberate, separate decision to make later, not
/// something this class should make easy by accident.
class AuditRepository {
  /// Records one event. [actorUserId] should be the acting user's id
  /// where known; pass null only when there genuinely isn't one to
  /// attribute the event to (see [AuditLogEntry]'s doc comment).
  /// [metadata] is a free-form string (e.g. a short JSON blob) for
  /// event-specific context — optional, since most of the 7 event types
  /// this app logs don't need any (the event type + actor + timestamp
  /// already says what happened).
  Future<void> record({
    required AuditEventType eventType,
    String? actorUserId,
    String? metadata,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.insert('audit_logs', {
      'id': _uuid.v4(),
      'actor_user_id': actorUserId,
      'event_type': eventType.name,
      'metadata': metadata,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Reads recent entries, newest first. Not used by anything yet (no
  /// audit-viewer UI exists) — exists so reading isn't blocked on that
  /// screen's design, same reasoning as [AuditLogEntry]'s doc comment.
  Future<List<AuditLogEntry>> listRecent({int limit = 200}) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT audit_logs.id, audit_logs.actor_user_id, audit_logs.event_type,
             audit_logs.metadata, audit_logs.created_at, users.username AS actor_username
      FROM audit_logs
      LEFT JOIN users ON users.id = audit_logs.actor_user_id
      ORDER BY audit_logs.created_at DESC
      LIMIT ?
      ''',
      [limit],
    );

    return rows
        .map((row) {
          final eventType = AuditEventType.values.where((e) => e.name == row['event_type']).firstOrNull;
          if (eventType == null) return null; // Unrecognized event_type string — skip rather than crash.
          return AuditLogEntry(
            id: row['id'] as String,
            actorUserId: row['actor_user_id'] as String?,
            actorUsername: row['actor_username'] as String?,
            eventType: eventType,
            metadata: row['metadata'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          );
        })
        .whereType<AuditLogEntry>()
        .toList();
  }
}
