// Tahap B / B3 — WHO acts and in WHICH branch.
//
// These tests need NO database, so unlike the DB tests they run with a
// plain `flutter test test/operational_context_test.dart`. They cover:
//   * the actor/branch is read from the LIVE session at the time of the
//     call (auto-lock -> unlock keeps the same user; "Ganti akun" and
//     logout take effect on the very next call),
//   * every operational write and read refuses to run without a session,
//     and does so BEFORE touching the database.
//
// What they do not cover: the lock-screen UI flow itself
// (AppLifecycleGuard -> PinLoginScreen). By reading the code, that flow
// never writes AppSession (only login/logout/restore/setActiveBranch do),
// which is what the auto-lock test below relies on; driving the real
// widgets needs a widget/integration test.
import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/audit/audit_event_type.dart';
import 'package:mamam_kasir/core/audit/audit_repository.dart';
import 'package:mamam_kasir/core/session/app_session.dart';
import 'package:mamam_kasir/core/session/app_session_provider.dart';
import 'package:mamam_kasir/core/session/branch_access_repository.dart';
import 'package:mamam_kasir/core/session/operational_context.dart';
import 'package:mamam_kasir/features/arus_kas/application/arus_kas_repository.dart';
import 'package:mamam_kasir/features/arus_kas/domain/arus_kas_models.dart';
import 'package:mamam_kasir/features/dashboard/application/dashboard_repository.dart';
import 'package:mamam_kasir/features/dompet/application/dompet_repository.dart';
import 'package:mamam_kasir/features/dompet/domain/dompet_models.dart';
import 'package:mamam_kasir/features/history/application/history_repository.dart';
import 'package:mamam_kasir/features/hpp_opname/application/hpp_opname_repository.dart';
import 'package:mamam_kasir/features/pos/application/pos_repository.dart';
import 'package:mamam_kasir/features/pos/domain/order_models.dart';
import 'package:mamam_kasir/features/pos/domain/transaction.dart' as txn;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudit extends AuditRepository {
  @override
  Future<void> record({
    required AuditEventType eventType,
    String? actorUserId,
    String? metadata,
  }) async {}
}

/// Stands in for the database-backed branch lookup: a user's default
/// branch is whatever the test says it is.
class _FakeBranchAccess extends BranchAccessRepository {
  final Map<String, String?> defaultBranchByUser;

  _FakeBranchAccess(this.defaultBranchByUser);

  @override
  Future<List<AccessibleBranch>> accessibleBranches({
    required String userId,
    required AppRole role,
  }) async {
    return const <AccessibleBranch>[];
  }

  @override
  Future<String?> resolveActiveBranchId({
    required String userId,
    required AppRole role,
    String? preferredBranchId,
  }) async {
    return preferredBranchId ?? defaultBranchByUser[userId];
  }
}

/// A reader for "nobody is signed in".
OperationalContext _noSession() {
  throw const NoOperationalContextException('tidak ada sesi');
}

AppSessionController _newSession() {
  return AppSessionController(
    audit: _FakeAudit(),
    branchAccess: _FakeBranchAccess({'user-a': 'branch-1', 'user-b': 'branch-2'}),
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

  group('OperationalContext.fromSession', () {
    test('no signed-in user is refused', () {
      expect(
        () => OperationalContext.fromSession(AppSession.empty),
        throwsA(isA<NoOperationalContextException>()),
      );
    });

    test('a signed-in user without an active branch is refused', () {
      const session = AppSession(userId: 'user-c', username: 'c', role: AppRole.manager);
      expect(
        () => OperationalContext.fromSession(session),
        throwsA(isA<NoOperationalContextException>()),
      );
    });

    test('user + active branch become the context', () {
      const session = AppSession(userId: 'user-a', username: 'a', role: AppRole.manager, branchId: 'branch-1');
      final context = OperationalContext.fromSession(session);
      expect(context.userId, 'user-a');
      expect(context.branchId, 'branch-1');
    });
  });

  group('the actor follows the live session', () {
    late AppSessionController session;

    OperationalContext read() => OperationalContext.fromSession(_stateOf(session));

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      session = _newSession();
    });

    test('auto-lock then unlock: the actor is still the same user', () async {
      await session.login(userId: 'user-a', username: 'a', role: AppRole.manager);
      final before = read();
      final sessionBefore = _stateOf(session);

      // Auto-lock and unlock never write the session, so there is nothing
      // to do here — which is the property being asserted: the same
      // session object is still in place and yields the same actor.
      expect(identical(_stateOf(session), sessionBefore), isTrue);
      expect(read().userId, before.userId);
      expect(read().branchId, before.branchId);

      // The app may also be killed while locked. A cold start restores
      // the same identity from storage.
      final afterColdStart = _newSession();
      await afterColdStart.restore();
      final restored = OperationalContext.fromSession(_stateOf(afterColdStart));
      expect(restored.userId, 'user-a');
      expect(restored.branchId, 'branch-1');
    });

    test('"Ganti akun": the next call is attributed to the new user and their branch', () async {
      await session.login(userId: 'user-a', username: 'a', role: AppRole.manager);
      expect(read().userId, 'user-a');
      expect(read().branchId, 'branch-1');

      await session.login(userId: 'user-b', username: 'b', role: AppRole.staff);

      expect(read().userId, 'user-b');
      expect(read().branchId, 'branch-2');
    });

    test('logout leaves no stale actor behind', () async {
      await session.login(userId: 'user-a', username: 'a', role: AppRole.manager);
      expect(read().userId, 'user-a');

      await session.logout();

      expect(read, throwsA(isA<NoOperationalContextException>()));
    });
  });

  group('writes without a session are refused before touching the database', () {
    final dompet = DompetRepository(context: _noSession);

    test('Dompet: cash sale', () {
      expect(
        dompet.recordCashSale(toLocationId: 'loc', amount: 1000, transactionId: 't1'),
        throwsA(isA<NoOperationalContextException>()),
      );
    });

    test('Dompet: courier deposit', () {
      expect(
        dompet.recordCourierDeposit(courierLocationId: 'courier', amount: 1000),
        throwsA(isA<NoOperationalContextException>()),
      );
    });

    test('Dompet: cash expense', () {
      expect(
        dompet.recordCashExpense(fromLocationId: 'loc', amount: 1000),
        throwsA(isA<NoOperationalContextException>()),
      );
    });

    test('Dompet: cash income', () {
      expect(
        dompet.recordCashIncome(toLocationId: 'loc', amount: 1000),
        throwsA(isA<NoOperationalContextException>()),
      );
    });

    test('Dompet: convert to kasbon (its cash movement leg)', () {
      expect(
        dompet.convertToKasbon(courierLocationId: 'courier', courierName: 'Budi', amount: 1000),
        throwsA(isA<NoOperationalContextException>()),
      );
    });

    test('Dompet: closing', () {
      final preview = DompetClosingPreview(
        periodStart: DateTime(2026, 1, 1),
        openingBalance: 0,
        cashSalesTotal: 0,
        courierDepositsTotal: 0,
        cashExpensesTotal: 0,
        expectedCash: 0,
        outstandingCouriers: const [],
      );
      expect(
        dompet.closeDompet(preview: preview, countedCash: 0),
        throwsA(isA<NoOperationalContextException>()),
      );
    });

    test('Arus Kas: new entry', () {
      final arusKas = ArusKasRepository(dompet, context: _noSession);
      expect(
        arusKas.addEntry(
          direction: ArusKasDirection.pengeluaran,
          category: 'Belanja',
          amount: 1000,
          transactionDate: DateTime(2026, 1, 1),
          fundingSource: ArusKasFundingSource.nonCash,
        ),
        throwsA(isA<NoOperationalContextException>()),
      );
    });

    test('Stok Opname: new session', () {
      final opname = HppOpnameRepository(context: _noSession);
      expect(
        opname.submitSession(items: const [], asDraft: true),
        throwsA(isA<NoOperationalContextException>()),
      );
    });

    test('POS: checkout', () {
      final pos = PosRepository(context: _noSession);
      expect(
        pos.saveTransaction(
          status: txn.TransactionStatus.paid,
          orderType: OrderType.takeaway,
          items: const [],
          subtotal: 0,
          voucherDiscount: 0,
          manualDiscountAmount: 0,
          taxAmount: 0,
          serviceAmount: 0,
          deliveryFee: 0,
          roundingAdjustment: 0,
          total: 0,
        ),
        throwsA(isA<NoOperationalContextException>()),
      );
    });
  });

  group('reads without a session are refused too (never "all branches")', () {
    final dompet = DompetRepository(context: _noSession);

    test('Riwayat', () {
      expect(HistoryRepository(context: _noSession).getTransactions(), throwsA(isA<NoOperationalContextException>()));
    });

    test('Dashboard', () {
      expect(DashboardRepository(context: _noSession).getMetrics(), throwsA(isA<NoOperationalContextException>()));
      expect(DashboardRepository(context: _noSession).getSalesTrend(), throwsA(isA<NoOperationalContextException>()));
    });

    test('Arus Kas', () {
      final arusKas = ArusKasRepository(dompet, context: _noSession);
      expect(arusKas.getEntries(direction: ArusKasDirection.pengeluaran), throwsA(isA<NoOperationalContextException>()));
      expect(arusKas.getTotal(direction: ArusKasDirection.pengeluaran), throwsA(isA<NoOperationalContextException>()));
    });

    test('Dompet', () {
      expect(dompet.getMovements(), throwsA(isA<NoOperationalContextException>()));
      expect(dompet.getLocationBalance('loc'), throwsA(isA<NoOperationalContextException>()));
      expect(dompet.getClosings(), throwsA(isA<NoOperationalContextException>()));
      expect(dompet.getLastClosing(), throwsA(isA<NoOperationalContextException>()));
    });

    test('Stok Opname', () {
      expect(HppOpnameRepository(context: _noSession).getSessions(), throwsA(isA<NoOperationalContextException>()));
    });
  });
}
