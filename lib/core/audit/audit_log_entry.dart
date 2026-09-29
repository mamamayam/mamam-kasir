import 'audit_event_type.dart';

/// One row from `audit_logs`, as read back (e.g. for a future
/// Owner-facing audit viewer — not built yet, this model just exists so
/// reading isn't blocked on that screen's design).
///
/// [actorUserId]/[actorUsername] can both be null: some events (e.g. a
/// PIN attempt against a user id that turned out not to exist) may not
/// cleanly resolve to a real actor, and this app has no "system" actor
/// concept to fall back to — a null actor means "unknown," not "the
/// system did this."
class AuditLogEntry {
  final String id;
  final String? actorUserId;
  final String? actorUsername;
  final AuditEventType eventType;
  final String? metadata;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.actorUserId,
    required this.actorUsername,
    required this.eventType,
    required this.metadata,
    required this.createdAt,
  });
}
