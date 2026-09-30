import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/audit/audit_event_type.dart';
import '../../../core/audit/audit_log_entry.dart';
import '../../../core/session/app_session.dart';
import '../../../core/session/app_session_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card_shell.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../application/audit_log_provider.dart';

/// "Log Aktivitas" — read-only list of the security events recorded to
/// `audit_logs` (login, logout, wrong PIN, lock, PIN change, auto-lock;
/// see [AuditEventType]). Owner-only: the Pengaturan row is hidden for
/// everyone else, AND this screen checks the role itself, so it doesn't
/// rely on the hidden row alone (an audit trail is more sensitive than
/// most screens).
///
/// Deliberately minimal — newest first, no filters, no search, no
/// export. Just enough to answer "who did what, when". Add filtering
/// later only if the plain list turns out to be too much to scan.
class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(appSessionProvider.select((s) => s.role)) == AppRole.owner;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Log Aktivitas')),
            Expanded(
              child: isOwner
                  ? const _AuditLogBody()
                  : const Center(
                      child: AppEmptyState(
                        icon: Icons.lock_outline_rounded,
                        title: 'Hanya untuk Owner',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditLogBody extends ConsumerWidget {
  const _AuditLogBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(auditLogEntriesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(auditLogEntriesProvider);
        await ref.read(auditLogEntriesProvider.future);
      },
      child: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const SizedBox(height: 60),
            const AppEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Gagal memuat log',
              subtitle: 'Tarik ke bawah untuk coba lagi',
            ),
          ],
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return ListView(
              padding: const EdgeInsets.only(top: 80),
              children: const [
                AppEmptyState(
                  icon: Icons.history_rounded,
                  title: 'Belum ada aktivitas tercatat',
                  subtitle: 'Login, salah PIN, dan kunci otomatis akan muncul di sini',
                ),
              ],
            );
          }

          final wasCutOff = entries.length >= kAuditLogPageSize;
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: entries.length + (wasCutOff ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              if (i == entries.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(
                    'Menampilkan $kAuditLogPageSize catatan terbaru',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                );
              }
              return _AuditLogRow(entry: entries[i]);
            },
          );
        },
      ),
    );
  }
}

class _AuditLogRow extends StatelessWidget {
  final AuditLogEntry entry;

  const _AuditLogRow({required this.entry});

  // Switch expressions with no default: adding a value to
  // AuditEventType without giving it a label/icon/color here is a
  // compile error, not a silently-blank row.
  String get _label => switch (entry.eventType) {
        AuditEventType.login => 'Login',
        AuditEventType.logout => 'Logout',
        AuditEventType.pinIncorrect => 'PIN salah',
        AuditEventType.pinLocked => 'Akun terkunci',
        AuditEventType.pinChanged => 'PIN diganti',
        AuditEventType.permissionChanged => 'Permission diubah',
        AuditEventType.autoLock => 'Terkunci otomatis',
      };

  IconData get _icon => switch (entry.eventType) {
        AuditEventType.login => Icons.login_rounded,
        AuditEventType.logout => Icons.logout_rounded,
        AuditEventType.pinIncorrect => Icons.error_outline_rounded,
        AuditEventType.pinLocked => Icons.lock_rounded,
        AuditEventType.pinChanged => Icons.pin_rounded,
        AuditEventType.permissionChanged => Icons.admin_panel_settings_outlined,
        AuditEventType.autoLock => Icons.timer_outlined,
      };

  Color get _color => switch (entry.eventType) {
        AuditEventType.login => AppColors.info,
        AuditEventType.logout => AppColors.textSecondary,
        AuditEventType.pinIncorrect => AppColors.danger,
        AuditEventType.pinLocked => AppColors.danger,
        AuditEventType.pinChanged => AppColors.brand,
        AuditEventType.permissionChanged => AppColors.brand,
        AuditEventType.autoLock => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final actor = entry.actorUsername != null ? '@${entry.actorUsername}' : 'Tidak diketahui';
    final time = DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(entry.createdAt);

    return AppCardShell(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _color.withValues(alpha: 0.12)),
            child: Icon(_icon, size: 18, color: _color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text('$actor · $time', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                if (entry.metadata != null) ...[
                  const SizedBox(height: 2),
                  Text(entry.metadata!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
