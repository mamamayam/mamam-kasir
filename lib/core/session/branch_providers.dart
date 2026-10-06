import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_session_provider.dart';
import 'branch_access_repository.dart';

/// Branches the signed-in user may switch between (Owner: every active
/// branch; Manager/Staff: their granted, active branches — see
/// [BranchAccessRepository]). Empty when nobody is signed in.
///
/// Re-reads when the signed-in user changes. Anything that edits the
/// branch list (Manajemen Cabang) invalidates this provider so pickers
/// never show a stale name or a switched-off branch.
final accessibleBranchesProvider = FutureProvider.autoDispose<List<AccessibleBranch>>((ref) async {
  final userId = ref.watch(appSessionProvider.select((s) => s.userId));
  final role = ref.watch(appSessionProvider.select((s) => s.role));
  if (userId == null || role == null) return const <AccessibleBranch>[];

  return ref.watch(branchAccessRepositoryProvider).accessibleBranches(userId: userId, role: role);
});

/// The active branch id. Every provider that holds branch-scoped data
/// (Dashboard, Riwayat, Arus Kas, Dompet, Stok Opname) watches this, so
/// switching branches rebuilds it and it reloads from the new branch.
/// The repositories themselves read the live session on every call
/// (OperationalContext) — this only tells the *controllers* to reload.
final activeBranchIdProvider = Provider<String?>((ref) {
  return ref.watch(appSessionProvider.select((s) => s.branchId));
});
