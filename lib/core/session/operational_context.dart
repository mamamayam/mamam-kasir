import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_session.dart';
import 'app_session_provider.dart';

/// WHO is acting and in WHICH branch, at the moment of a write or a read
/// (Tahap B / B3).
///
/// Every operational repository (POS checkout, Arus Kas, Dompet, Stok
/// Opname, Dashboard, Riwayat, Laporan) obtains this itself, from the
/// live session, at the time of the call. Widgets and controllers never
/// pass a user id or a branch id into a repository, so a screen cannot
/// attribute a row to somebody else or read another branch's numbers by
/// passing a different id.
///
/// Read at call time, never cached:
/// * after auto-lock -> unlock the session is untouched, so the actor is
///   still the same user (the lock flow never writes [AppSession]);
/// * after "Ganti akun" the new user's `login()` replaces the session, so
///   the very next write is attributed to the new user and their branch;
/// * after logout there is no session, so the next call is refused
///   instead of being attributed to the previous user.
///
/// LOCAL-ONLY ENFORCEMENT: this guards the local app layer only. Server
/// side enforcement (RLS / Supabase) is Tahap E and does not exist yet —
/// anyone with direct access to the device database is not stopped by it.
class OperationalContext {
  final String userId;
  final String branchId;

  const OperationalContext({required this.userId, required this.branchId});

  /// Builds the context from [session], or throws
  /// [NoOperationalContextException] when there is no authenticated user
  /// or no active branch. Failing closed is deliberate: a row written
  /// with a missing actor or branch can never be attributed afterwards.
  factory OperationalContext.fromSession(AppSession session) {
    final userId = session.userId;
    if (!session.isLoggedIn || userId == null) {
      throw const NoOperationalContextException(
        'Tidak ada pengguna yang sedang login, jadi data operasional tidak bisa dibaca atau disimpan.',
      );
    }

    final branchId = session.branchId;
    if (branchId == null) {
      throw const NoOperationalContextException(
        'Belum ada cabang aktif untuk akun ini, jadi data operasional tidak bisa dibaca atau disimpan. '
        'Minta Owner memberi akses ke sebuah cabang.',
      );
    }

    return OperationalContext(userId: userId, branchId: branchId);
  }
}

/// Thrown instead of reading/writing operational data without a
/// authenticated user or an active branch.
class NoOperationalContextException implements Exception {
  final String message;

  const NoOperationalContextException(this.message);

  /// The message itself, so screens that show `error.toString()` show
  /// something a person can act on.
  @override
  String toString() => message;
}

/// Returns the current [OperationalContext] (throwing
/// [NoOperationalContextException] when there is none). Repositories hold
/// one of these and call it at the start of every read and write.
typedef OperationalContextReader = OperationalContext Function();

/// A stable reader over the live session. Reading the session inside the
/// closure (rather than watching it) means repositories are not rebuilt on
/// login/logout and can never act on a stale user.
final operationalContextReaderProvider = Provider<OperationalContextReader>((ref) {
  return () => OperationalContext.fromSession(ref.read(appSessionProvider));
});
