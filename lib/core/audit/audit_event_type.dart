/// Every security-relevant event this app records to `audit_logs`.
///
/// Deliberately scoped to EXACTLY what the Tahap A task brief's A5 step
/// asked for — "login, logout, PIN salah, lock, ganti PIN, perubahan
/// permission, auto-lock. Actor = user id. Hanya itu." — nothing more.
/// Transaction/Dompet audit trails (editing a paid transaction,
/// restoring a canceled one, cash movements) are explicitly Tahap B,
/// not this enum's job; do not add event types for those here ahead of
/// that work actually happening, same "don't invent keys for features
/// that don't exist" principle A4's [PermissionKey] followed.
enum AuditEventType {
  /// Successful username+password login. Logged by
  /// [AuthRepository.verifyCredentials] on success.
  login,

  /// Explicit logout via Pengaturan's "Keluar Akun". Logged by
  /// [AppSessionController.logout].
  logout,

  /// A PIN attempt that did not match. Logged by
  /// [PinAuthRepository.verifyPin] on [PinVerifyResult.incorrect] and
  /// [PinVerifyResult.justLocked] (the failed attempt itself, distinct
  /// from the lock event below) — NOT logged for
  /// [PinVerifyResult.alreadyLocked], since that case never even checks
  /// the PIN (see PinVerifyResult's doc comment) and so isn't really a
  /// new "wrong PIN" event.
  pinIncorrect,

  /// An account crossing the 5-failed-attempt threshold and becoming
  /// locked. Logged by [PinAuthRepository.verifyPin] on
  /// [PinVerifyResult.justLocked], alongside (not instead of) the
  /// [pinIncorrect] event for that same attempt — the attempt is both
  /// "a wrong PIN" and "the one that caused a lock."
  pinLocked,

  /// A PIN successfully changed via [PinAuthRepository.setPin] —
  /// covers both the initial "buat PIN baru" flow and later "Ganti PIN"
  /// (ChangePinScreen). Both call the same underlying method, so both
  /// are logged the same way; metadata distinguishes them if needed
  /// (see [AuditLogEntry.metadata]).
  pinChanged,

  /// A role's permission mode for some [PermissionKey] was changed
  /// (i.e. a `permissions` table row was updated). Not currently
  /// triggered by anything in the app — there is no permission-editing
  /// UI yet (see [[mamam-kasir-flutter]]'s A4 notes) — but the event
  /// type exists now per the task brief's explicit list, ready for
  /// whichever future screen edits `permissions` rows directly.
  permissionChanged,

  /// The 30-minute auto-lock actually firing (not just the app being
  /// backgrounded — only when [AppLifecycleGuard] decides enough time
  /// has passed and pushes the lock screen). Logged by
  /// [AppLifecycleGuard]'s resume handler.
  autoLock,
}
