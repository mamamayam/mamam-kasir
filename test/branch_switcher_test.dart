// The branch switcher UI (BranchSwitcherPill + BranchSwitcherSheet) and the
// plumbing that makes every branch-scoped screen reload when it is used.
//
// NO database needed: the branch list and the session are driven by fakes,
// so this runs with a plain `flutter test test/branch_switcher_test.dart`.
// It also exercises the case the real app cannot show yet — TWO branches —
// because "Tambah cabang" in Manajemen Cabang is still a disabled stub and
// the app only seeds one branch.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/audit/audit_event_type.dart';
import 'package:mamam_kasir/core/audit/audit_repository.dart';
import 'package:mamam_kasir/core/session/app_session.dart';
import 'package:mamam_kasir/core/session/app_session_provider.dart';
import 'package:mamam_kasir/core/session/branch_access_repository.dart';
import 'package:mamam_kasir/core/session/branch_providers.dart';
import 'package:mamam_kasir/core/widgets/branch_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudit extends AuditRepository {
  @override
  Future<void> record({
    required AuditEventType eventType,
    String? actorUserId,
    String? metadata,
  }) async {}
}

/// Branch access backed by a list the test can change.
class _FakeBranchAccess extends BranchAccessRepository {
  final List<AccessibleBranch> branches;

  _FakeBranchAccess(this.branches);

  @override
  Future<List<AccessibleBranch>> accessibleBranches({
    required String userId,
    required AppRole role,
  }) async {
    return List.of(branches);
  }

  @override
  Future<String?> resolveActiveBranchId({
    required String userId,
    required AppRole role,
    String? preferredBranchId,
  }) async {
    final ids = branches.map((b) => b.id).toList();
    if (preferredBranchId != null && ids.contains(preferredBranchId)) return preferredBranchId;
    return ids.isEmpty ? null : ids.first;
  }
}

const _cibarusah = AccessibleBranch(id: 'branch-1', name: 'Mamam Ayam Cibarusah');
const _bekasi = AccessibleBranch(id: 'branch-2', name: 'Mamam Ayam Bekasi');

Future<AppSessionController> _signedIn(_FakeBranchAccess access) async {
  SharedPreferences.setMockInitialValues({});
  final session = AppSessionController(audit: _FakeAudit(), branchAccess: access);
  await session.login(userId: 'user-a', username: 'a', role: AppRole.owner);
  return session;
}

Widget _app(AppSessionController session, List<AccessibleBranch> branches) {
  return ProviderScope(
    overrides: [
      appSessionProvider.overrideWith((ref) => session),
      accessibleBranchesProvider.overrideWith((ref) async => branches),
    ],
    child: const MaterialApp(
      home: Scaffold(body: Center(child: BranchSwitcherPill())),
    ),
  );
}

/// The controller's current state, read through the public listener API
/// (`state` is protected and `debugState` is deprecated). The listener fires
/// once, synchronously, with the current value.
AppSession _stateOf(AppSessionController controller) {
  late AppSession current;
  final remove = controller.addListener((state) => current = state);
  remove();
  return current;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BranchSwitcherPill', () {
    testWidgets('one branch: a plain label, no chevron, nothing to open', (tester) async {
      final session = await _signedIn(_FakeBranchAccess([_cibarusah]));
      await tester.pumpWidget(_app(session, [_cibarusah]));
      await tester.pumpAndSettle();

      expect(find.text('Mamam Ayam Cibarusah'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

      await tester.tap(find.text('Mamam Ayam Cibarusah'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih Cabang'), findsNothing);
    });

    testWidgets('no accessible branch: says so', (tester) async {
      final session = await _signedIn(_FakeBranchAccess([]));
      await tester.pumpWidget(_app(session, const []));
      await tester.pumpAndSettle();

      expect(find.text('Tanpa cabang'), findsOneWidget);
    });

    testWidgets('two branches: shows the active one with a chevron; tapping lists both', (tester) async {
      final session = await _signedIn(_FakeBranchAccess([_cibarusah, _bekasi]));
      await tester.pumpWidget(_app(session, [_cibarusah, _bekasi]));
      await tester.pumpAndSettle();

      expect(find.text('Mamam Ayam Cibarusah'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      await tester.tap(find.byType(BranchSwitcherPill));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Cabang'), findsOneWidget);
      expect(find.text('Mamam Ayam Bekasi'), findsOneWidget);
      // Active branch appears in the pill AND in the sheet, with a check.
      expect(find.text('Mamam Ayam Cibarusah'), findsNWidgets(2));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('picking the other branch switches the session, closes the sheet and confirms', (tester) async {
      final session = await _signedIn(_FakeBranchAccess([_cibarusah, _bekasi]));
      await tester.pumpWidget(_app(session, [_cibarusah, _bekasi]));
      await tester.pumpAndSettle();
      expect(_stateOf(session).branchId, 'branch-1');

      await tester.tap(find.byType(BranchSwitcherPill));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mamam Ayam Bekasi'));
      await tester.pumpAndSettle();

      expect(_stateOf(session).branchId, 'branch-2');
      expect(find.text('Pilih Cabang'), findsNothing);
      expect(find.text('Cabang aktif: Mamam Ayam Bekasi'), findsOneWidget);
      // The pill now shows the new branch.
      expect(find.text('Mamam Ayam Bekasi'), findsOneWidget);
    });

    testWidgets('picking the already-active branch just closes the sheet', (tester) async {
      final session = await _signedIn(_FakeBranchAccess([_cibarusah, _bekasi]));
      await tester.pumpWidget(_app(session, [_cibarusah, _bekasi]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BranchSwitcherPill));
      await tester.pumpAndSettle();
      // Two matches: the pill and the sheet row. The row is the last one.
      await tester.tap(find.text('Mamam Ayam Cibarusah').last);
      await tester.pumpAndSettle();

      expect(_stateOf(session).branchId, 'branch-1');
      expect(find.text('Pilih Cabang'), findsNothing);
    });
  });

  group('the session side of switching', () {
    test('activeBranchIdProvider notifies exactly when the branch changes', () async {
      final session = await _signedIn(_FakeBranchAccess([_cibarusah, _bekasi]));
      final container = ProviderContainer(overrides: [
        appSessionProvider.overrideWith((ref) => session),
      ]);
      addTearDown(container.dispose);

      final seen = <String?>[];
      container.listen<String?>(activeBranchIdProvider, (_, next) => seen.add(next), fireImmediately: true);

      await session.setActiveBranch('branch-2');
      await session.setActiveBranch('branch-2'); // same branch again: no new notification

      expect(seen, ['branch-1', 'branch-2']);
    });

    test('a branch the user cannot access is refused and the session stays put', () async {
      final session = await _signedIn(_FakeBranchAccess([_cibarusah]));

      final switched = await session.setActiveBranch('branch-2');

      expect(switched, isFalse);
      expect(_stateOf(session).branchId, 'branch-1');
    });

    test('refreshActiveBranch moves off a branch that is no longer accessible', () async {
      final access = _FakeBranchAccess([_cibarusah, _bekasi]);
      final session = await _signedIn(access);
      await session.setActiveBranch('branch-2');
      expect(_stateOf(session).branchId, 'branch-2');

      // Bekasi gets switched off in Manajemen Cabang.
      access.branches.remove(_bekasi);
      await session.refreshActiveBranch();

      expect(_stateOf(session).branchId, 'branch-1');
    });

    test('refreshActiveBranch leaves a still-valid branch alone', () async {
      final access = _FakeBranchAccess([_cibarusah, _bekasi]);
      final session = await _signedIn(access);
      await session.setActiveBranch('branch-2');
      final before = _stateOf(session);

      await session.refreshActiveBranch();

      expect(identical(_stateOf(session), before), isTrue);
    });

    test('refreshActiveBranch with no branch left leaves the session without one', () async {
      final access = _FakeBranchAccess([_cibarusah]);
      final session = await _signedIn(access);

      access.branches.clear();
      await session.refreshActiveBranch();

      expect(_stateOf(session).branchId, isNull);
      expect(_stateOf(session).userId, 'user-a');
    });

    test('refreshActiveBranch is a no-op when signed out', () async {
      SharedPreferences.setMockInitialValues({});
      final session = AppSessionController(audit: _FakeAudit(), branchAccess: _FakeBranchAccess([_cibarusah]));

      await session.refreshActiveBranch();

      expect(_stateOf(session).isLoggedIn, isFalse);
    });
  });
}
