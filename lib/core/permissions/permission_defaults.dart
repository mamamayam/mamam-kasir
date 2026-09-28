import '../session/app_session.dart';
import 'permission_key.dart';
import 'permission_mode.dart';

/// Hardcoded (role, key) -> mode table mirroring the PRD's explicit
/// mode language — see each [PermissionKey] value's doc comment for the
/// exact PRD line each row traces back to.
///
/// Used by TWO independent things, which is why this table lives in its
/// own file rather than inside [PermissionService] or AppDatabase:
/// - [PermissionService.resolve] falls back to this table when the
///   `permissions` DB table has no row for a (role, key) pair.
/// - AppDatabase's v11 migration seeds the `permissions` table's actual
///   rows FROM this table, so the seed data and the runtime fallback
///   can never drift out of sync with each other.
///
/// Importing this file from AppDatabase does not create a circular
/// import (this file doesn't import AppDatabase), unlike importing
/// PermissionService itself would.
const Map<PermissionKey, Map<AppRole, PermissionMode>> defaultPermissions = {
  PermissionKey.viewOwnerMenu: {
    AppRole.owner: PermissionMode.direct,
    AppRole.manager: PermissionMode.direct,
    AppRole.staff: PermissionMode.deny,
  },
  PermissionKey.enterExpense: {
    AppRole.owner: PermissionMode.direct,
    AppRole.manager: PermissionMode.direct,
    AppRole.staff: PermissionMode.direct,
  },
  PermissionKey.editExpense: {
    AppRole.owner: PermissionMode.direct,
    AppRole.manager: PermissionMode.direct,
    AppRole.staff: PermissionMode.approval,
  },
  PermissionKey.correctShiftAfterClose: {
    AppRole.owner: PermissionMode.direct,
    AppRole.manager: PermissionMode.direct,
    AppRole.staff: PermissionMode.deny,
  },
  PermissionKey.editCustomer: {
    AppRole.owner: PermissionMode.direct,
    AppRole.manager: PermissionMode.direct,
    AppRole.staff: PermissionMode.direct,
  },
  PermissionKey.editPaidTransaction: {
    AppRole.owner: PermissionMode.direct,
    AppRole.manager: PermissionMode.direct,
    AppRole.staff: PermissionMode.deny,
  },
  PermissionKey.restoreTransaction: {
    AppRole.owner: PermissionMode.approval,
    AppRole.manager: PermissionMode.approval,
    AppRole.staff: PermissionMode.deny,
  },
};
