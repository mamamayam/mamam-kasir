// Tests for the active-branch handling added to the session:
//  - pickActiveBranchId (the pure rule)
//  - AppSessionController: login / restore / setActiveBranch / logout
//
// Pure Dart: branch access and audit are faked, SharedPreferences is the
// in-memory mock, so there is no database and this runs with plain
// `flutter test`.
//
// The SharedPreferences keys below ('session_user_id', ...) are the
// private constants in app_session_provider.dart written out literally —
// if those constants are ever renamed, update them here too.
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/audit/audit_event_type.dart';
import 'package:mamam_kasir/core/audit/audit_repository.dart';
import 'package:mamam_kasir/core/session/app_session.dart';
import 'package:mamam_kasir/core/session/app_session_provider.dart';
import 'package:mamam_kasir/core/session/branch_access_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopAuditRepository extends AuditRepository {
  @override
  Future<void> record({required AuditEventType eventType, String? actorUserId, String? metadata}) async {}
}

class _FakeBranchAccess extends BranchAccessRepository {
  _FakeBranchAccess(this.byUser);

  final Map<String, List<AccessibleBranch>> byUser;
  bool throwOnLookup = false;

  @override
  Future<List<AccessibleBranch>> accessibleBranches({required String userId, required AppRole role}) async {
    if (throwOnLookup) throw StateError('simulated database failure');
    return byUser[userId] ?? const [];
  }
}

const _b1 = AccessibleBranch(id: 'b1', name: 'Cabang 1');
const _b2 = AccessibleBranch(id: 'b2', name: 'Cabang 2');

AppSessionController _controller(_FakeBranchAccess access) =>
    AppSessionController(audit: _NoopAuditRepository(), branchAccess: access);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('pickActiveBranchId', () {
    test('no accessible branches -> null', () {
      expect(pickActiveBranchId(accessibleBranchIds: [], preferredBranchId: 'b1'), isNull);
    });

    test('keeps the preferred branch while it is still accessible', () {
      expect(pickActiveBranchId(accessibleBranchIds: ['b1', 'b2'], preferredBranchId: 'b2'), 'b2');
    });

    test('drops a preferred branch that is no longer accessible -> first accessible', () {
      expect(pickActiveBranchId(accessibleBranchIds: ['b1', 'b2'], preferredBranchId: 'gone'), 'b1');
    });

    test('no preference -> first accessible', () {
      expect(pickActiveBranchId(accessibleBranchIds: ['b1', 'b2']), 'b1');
    });
  });

  group('login', () {
    test('resolves the first accessible branch and remembers it', () async {
      final c = _controller(_FakeBranchAccess({'u1': [_b1, _b2]}));

      await c.login(userId: 'u1', username: 'budi', role: AppRole.manager);

      expect(c.state.isLoggedIn, isTrue);
      expect(c.state.branchId, 'b1');
      expect((await SharedPreferences.getInstance()).getString('session_branch_id'), 'b1');
    });

    test('a user with no accessible branch still signs in, just without a branch', () async {
      final c = _controller(_FakeBranchAccess({}));

      await c.login(userId: 'u1', username: 'budi', role: AppRole.staff);

      expect(c.state.isLoggedIn, isTrue, reason: 'no branch must not block sign-in');
      expect(c.state.branchId, isNull);
    });

    test('if the branch lookup itself fails, sign-in still succeeds (without a branch)', () async {
      final access = _FakeBranchAccess({'u1': [_b1]})..throwOnLookup = true;
      final c = _controller(access);

      await c.login(userId: 'u1', username: 'budi', role: AppRole.staff);

      expect(c.state.isLoggedIn, isTrue);
      expect(c.state.branchId, isNull);
    });

    test("does NOT inherit the previous account's remembered branch", () async {
      SharedPreferences.setMockInitialValues({'session_branch_id': 'b2'});
      final c = _controller(_FakeBranchAccess({'u2': [_b1, _b2]}));

      await c.login(userId: 'u2', username: 'sari', role: AppRole.staff);

      expect(c.state.branchId, 'b1', reason: "b2 was left over from someone else's session");
    });
  });

  group('restore', () {
    Map<String, Object> savedSession(String branch) => {
          'session_user_id': 'u1',
          'session_username': 'budi',
          'session_role': 'manager',
          'session_branch_id': branch,
        };

    test('keeps the remembered branch while the user can still access it', () async {
      SharedPreferences.setMockInitialValues(savedSession('b2'));
      final c = _controller(_FakeBranchAccess({'u1': [_b1, _b2]}));

      await c.restore();

      expect(c.state.branchId, 'b2');
    });

    test('replaces a remembered branch the user can no longer access', () async {
      SharedPreferences.setMockInitialValues(savedSession('b2'));
      final c = _controller(_FakeBranchAccess({'u1': [_b1]})); // b2 access revoked / switched off

      await c.restore();

      expect(c.state.branchId, 'b1');
      expect((await SharedPreferences.getInstance()).getString('session_branch_id'), 'b1');
    });

    test('drops the remembered branch entirely if nothing is accessible any more', () async {
      SharedPreferences.setMockInitialValues(savedSession('b2'));
      final c = _controller(_FakeBranchAccess({}));

      await c.restore();

      expect(c.state.isLoggedIn, isTrue);
      expect(c.state.branchId, isNull);
      expect((await SharedPreferences.getInstance()).getString('session_branch_id'), isNull);
    });
  });

  group('setActiveBranch', () {
    test('switches to an accessible branch', () async {
      final c = _controller(_FakeBranchAccess({'u1': [_b1, _b2]}));
      await c.login(userId: 'u1', username: 'budi', role: AppRole.manager);

      final switched = await c.setActiveBranch('b2');

      expect(switched, isTrue);
      expect(c.state.branchId, 'b2');
      expect((await SharedPreferences.getInstance()).getString('session_branch_id'), 'b2');
    });

    test('refuses a branch the user has no access to, and changes nothing', () async {
      final c = _controller(_FakeBranchAccess({'u1': [_b1]}));
      await c.login(userId: 'u1', username: 'budi', role: AppRole.manager);

      final switched = await c.setActiveBranch('b2');

      expect(switched, isFalse);
      expect(c.state.branchId, 'b1');
    });

    test('does nothing when nobody is signed in', () async {
      final c = _controller(_FakeBranchAccess({'u1': [_b1]}));

      expect(await c.setActiveBranch('b1'), isFalse);
      expect(c.state.branchId, isNull);
    });
  });

  group('logout', () {
    test('clears the branch from both the state and storage', () async {
      final c = _controller(_FakeBranchAccess({'u1': [_b1]}));
      await c.login(userId: 'u1', username: 'budi', role: AppRole.staff);

      await c.logout();

      expect(c.state.isLoggedIn, isFalse);
      expect(c.state.branchId, isNull);
      expect((await SharedPreferences.getInstance()).getString('session_branch_id'), isNull);
    });
  });
}
