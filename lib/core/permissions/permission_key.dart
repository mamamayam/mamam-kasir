/// Every permission-gated action in the app. Per the task brief's
/// explicit instruction: a key exists here ONLY for an action the PRD
/// states an explicit deny/direct/approval mode for — never invented
/// ahead of a feature actually needing one. See
/// [[mamam-kasir-flutter]]'s A4 notes for the PRD line each key traces
/// back to.
///
/// [viewOwnerMenu] is the one key with a real UI hookup right now
/// (menu_bottom_sheet.dart's 9-tile grid + Approval card) — it's not
/// literally named in the PRD's per-module mode language the way the
/// others are, but the PRD's "### Access" section is explicit that
/// Owner "manages roles/permissions" and that Manager's data access is
/// branch-scoped (implying Staff's is narrower still), which is what
/// this key encodes as a single gate. The rest exist in the enum now
/// (per PRD sections that DO state modes explicitly) but have no UI
/// caller yet — see each key's doc comment for its PRD line, and
/// [[mamam-kasir-flutter]]'s A4 notes for why hooking them into their
/// still-placeholder modules is deferred rather than done now.
enum PermissionKey {
  /// Whether the 9-tile grid + Approval card in the swipe-up menu are
  /// visible at all. PRD "### Access": "Owner manages roles/
  /// permissions... Branch-scoped operational data for Manager."
  viewOwnerMenu,

  /// Creating a new expense entry. PRD Expenses: "Cashier/Manager/Owner
  /// entry" — all three roles can create one directly.
  enterExpense,

  /// Editing an existing expense entry. PRD Expenses: "Cashier edits
  /// require approval; Manager direct + Owner notification; Owner
  /// unrestricted."
  editExpense,

  /// Correcting shift/Dompet numbers after the shift has already been
  /// closed. PRD Shift: "Manager/Owner can correct after close with
  /// audit; Manager changes notify Owner." Staff/Cashier is not
  /// mentioned as being able to do this at all.
  correctShiftAfterClose,

  /// Editing an existing customer's data. PRD Customer: "Edit Owner/
  /// Manager or Cashier by permission" — resolved (see
  /// [[mamam-kasir-flutter]] A4 notes) as direct for all three roles,
  /// same as Owner/Manager.
  editCustomer,

  /// Editing a transaction that has already been paid. PRD Edit/
  /// cancel/restore: "Manager edits paid transaction directly; Owner
  /// unrestricted." Staff/Cashier is not mentioned as being able to do
  /// this at all.
  editPaidTransaction,

  /// Restoring a transaction after it was canceled. PRD Edit/cancel/
  /// restore: "Restore requires Manager/Owner approval" — approval for
  /// BOTH Manager and Owner, not direct for either.
  restoreTransaction,
}
