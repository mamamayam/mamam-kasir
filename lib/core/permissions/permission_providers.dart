import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/app_session_provider.dart';
import 'permission_key.dart';
import 'permission_mode.dart';
import 'permission_service.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) => PermissionService());

/// Resolves [key]'s [PermissionMode] for whoever is currently logged in
/// (from [appSessionProvider]), re-resolving on every session change so
/// a role change takes effect immediately — no stale cache (per the
/// task brief's "perubahan permission berlaku langsung").
///
/// Deliberately NOT `.autoDispose`: once resolved for a given role, the
/// result stays cached (Riverpod only re-runs this when the watched
/// `role` actually changes) so reopening the same sheet repeatedly
/// doesn't re-query the DB and re-flicker every time — see
/// menu_bottom_sheet.dart's canViewOwnerMenu comment for why the first
/// resolution (right after login) can still show one transient frame
/// before the DB answers.
///
/// `.family` because different call sites need different keys; each
/// resolves independently.
final currentRolePermissionProvider = FutureProvider.family<PermissionMode, PermissionKey>((ref, key) async {
  final role = ref.watch(appSessionProvider.select((s) => s.role));
  return ref.watch(permissionServiceProvider).resolve(role, key);
});
