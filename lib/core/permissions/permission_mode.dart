/// The 3-mode permission model from the PRD's "### Access" section
/// ("Permission modes: deny/direct/approval") and AGENTS.md. Every
/// (role, [PermissionKey]) pair resolves to exactly one of these.
enum PermissionMode {
  /// The action is not available at all for this role.
  deny,

  /// The action is available and executes immediately, no approval
  /// step.
  direct,

  /// The action requires approval (from a Manager/Owner, depending on
  /// the specific action) before it takes effect. A2/A3's already-built
  /// PIN/session model doesn't yet include an approval queue — building
  /// that is separate work, out of scope for the engine itself.
  approval,
}
