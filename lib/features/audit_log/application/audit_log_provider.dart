import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audit/audit_log_entry.dart';
import '../../../core/audit/audit_providers.dart';

/// How many entries the "Log Aktivitas" screen loads. Exposed so the
/// screen can tell the user when the list was cut off at this limit.
const kAuditLogPageSize = 200;

/// Newest-first audit entries for the Owner-only log screen.
/// `.autoDispose` so reopening the screen always reads fresh data —
/// pull-to-refresh on the screen uses `ref.invalidate` on this.
final auditLogEntriesProvider = FutureProvider.autoDispose<List<AuditLogEntry>>((ref) {
  return ref.watch(auditRepositoryProvider).listRecent(limit: kAuditLogPageSize);
});
