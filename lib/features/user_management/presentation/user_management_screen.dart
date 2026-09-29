import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/session/app_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card_shell.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../application/user_management_provider.dart';
import '../domain/managed_user.dart';
import 'widgets/user_form_modal.dart';

/// "Kelola Karyawan" — manages login accounts (users/roles), not HRD
/// employee records (see [[mamam-kasir-flutter]] notes on keeping those
/// two concepts separate). Owner-only: reached from menu_grid_items.dart
/// only when the logged-in role is Owner (see that file's guard).
///
/// List+add-form structure follows [MenuManagementScreen] (the reference
/// pattern per component-standards-prompt.md) — IosPageHeader with a
/// trailing add button, RefreshIndicator, AppCardShell rows,
/// AppNav.showModal for the add/edit form.
class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  void _openForm(BuildContext context, {ManagedUser? existingUser}) {
    AppNav.showModal(
      context,
      builder: (_) => UserFormModal(existingUser: existingUser),
    );
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref, ManagedUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nonaktifkan Akun?'),
        content: Text('${user.displayName} (${user.username}) tidak akan bisa login lagi. Riwayat aktivitasnya tetap tersimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Nonaktifkan', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await ref.read(userManagementProvider.notifier).deactivateUser(user.id);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _reactivate(BuildContext context, WidgetRef ref, ManagedUser user) async {
    final error = await ref.read(userManagementProvider.notifier).reactivateUser(user.id, role: user.role);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userManagementProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(
              title: const Text('Kelola Karyawan'),
              trailingIcon: Icons.add_rounded,
              onTrailingTap: () => _openForm(context),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(userManagementProvider.notifier).load(),
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.users.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.only(top: 80),
                            children: const [
                              AppEmptyState(
                                icon: Icons.people_alt_outlined,
                                title: 'Belum ada akun',
                                subtitle: 'Tambah akun untuk Manager atau Staff',
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: state.users.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, i) {
                              final user = state.users[i];
                              return _UserRow(
                                user: user,
                                onTap: () => _openForm(context, existingUser: user),
                                onDeactivate: () => _confirmDeactivate(context, ref, user),
                                onReactivate: () => _reactivate(context, ref, user),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final ManagedUser user;
  final VoidCallback onTap;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;

  const _UserRow({
    required this.user,
    required this.onTap,
    required this.onDeactivate,
    required this.onReactivate,
  });

  static const _roleColors = {
    AppRole.owner: AppColors.brand,
    AppRole.manager: AppColors.info,
    AppRole.staff: AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    return AppCardShell(
      onTap: onTap,
      backgroundColor: user.isActive ? null : AppColors.background,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: user.isActive ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppStatusBadge(user.roleLabel, _roleColors[user.role]!),
                    if (!user.isActive) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const AppStatusBadge('Nonaktif', AppColors.textMuted),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('@${user.username}', style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              user.isActive ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined,
              size: 20,
              color: user.isActive ? AppColors.danger : AppColors.info,
            ),
            onPressed: user.isActive ? onDeactivate : onReactivate,
          ),
        ],
      ),
    );
  }
}
