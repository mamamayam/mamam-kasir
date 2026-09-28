// Tests for defaultPermissions (lib/core/permissions/permission_defaults.dart).
// Pure Dart, no DB — runs with plain `flutter test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/permissions/permission_defaults.dart';
import 'package:mamam_kasir/core/permissions/permission_key.dart';
import 'package:mamam_kasir/core/permissions/permission_mode.dart';
import 'package:mamam_kasir/core/session/app_session.dart';

void main() {
  group('defaultPermissions matches the PRD mode table', () {
    test('every PermissionKey has an entry for all 3 roles', () {
      for (final key in PermissionKey.values) {
        final rolesForKey = defaultPermissions[key];
        expect(rolesForKey, isNotNull, reason: '$key has no entry in defaultPermissions');
        expect(rolesForKey!.keys.toSet(), AppRole.values.toSet(), reason: '$key is missing a role');
      }
    });

    test('viewOwnerMenu: Owner+Manager direct, Staff deny', () {
      final modes = defaultPermissions[PermissionKey.viewOwnerMenu]!;
      expect(modes[AppRole.owner], PermissionMode.direct);
      expect(modes[AppRole.manager], PermissionMode.direct);
      expect(modes[AppRole.staff], PermissionMode.deny);
    });

    test('enterExpense: all 3 roles direct (PRD: "Cashier/Manager/Owner entry")', () {
      final modes = defaultPermissions[PermissionKey.enterExpense]!;
      expect(modes[AppRole.owner], PermissionMode.direct);
      expect(modes[AppRole.manager], PermissionMode.direct);
      expect(modes[AppRole.staff], PermissionMode.direct);
    });

    test('editExpense: Owner+Manager direct, Staff approval (PRD: Cashier edits require approval)', () {
      final modes = defaultPermissions[PermissionKey.editExpense]!;
      expect(modes[AppRole.owner], PermissionMode.direct);
      expect(modes[AppRole.manager], PermissionMode.direct);
      expect(modes[AppRole.staff], PermissionMode.approval);
    });

    test('correctShiftAfterClose: Owner+Manager direct, Staff deny (not mentioned in PRD)', () {
      final modes = defaultPermissions[PermissionKey.correctShiftAfterClose]!;
      expect(modes[AppRole.owner], PermissionMode.direct);
      expect(modes[AppRole.manager], PermissionMode.direct);
      expect(modes[AppRole.staff], PermissionMode.deny);
    });

    test('editCustomer: all 3 roles direct (resolved ambiguity — see [[mamam-kasir-flutter]] notes)', () {
      final modes = defaultPermissions[PermissionKey.editCustomer]!;
      expect(modes[AppRole.owner], PermissionMode.direct);
      expect(modes[AppRole.manager], PermissionMode.direct);
      expect(modes[AppRole.staff], PermissionMode.direct);
    });

    test('editPaidTransaction: Owner+Manager direct, Staff deny (PRD: Manager edits directly, Owner unrestricted, Staff not mentioned)', () {
      final modes = defaultPermissions[PermissionKey.editPaidTransaction]!;
      expect(modes[AppRole.owner], PermissionMode.direct);
      expect(modes[AppRole.manager], PermissionMode.direct);
      expect(modes[AppRole.staff], PermissionMode.deny);
    });

    test('restoreTransaction: Owner+Manager BOTH approval, Staff deny (PRD: "Restore requires Manager/Owner approval")', () {
      final modes = defaultPermissions[PermissionKey.restoreTransaction]!;
      expect(modes[AppRole.owner], PermissionMode.approval);
      expect(modes[AppRole.manager], PermissionMode.approval);
      expect(modes[AppRole.staff], PermissionMode.deny);
    });
  });
}
