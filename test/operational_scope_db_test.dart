// Tahap B / B3 — branch scoping of operational data, against the real
// (encrypted) database schema: a second branch's rows must be invisible
// to the first branch, every write must be stamped with the acting user
// and branch, and one branch cannot delete another branch's entry.
//
// IMPORTANT — like test/app_database_auth_test.dart and
// test/app_database_branch_scope_test.dart, this needs a real device or
// emulator (sqflite_sqlcipher has no host-side test mode). It has been
// written and syntax-checked but NOT run; the host-runnable part of B3 is
// test/operational_context_test.dart.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/core/data/app_database.dart';
import 'package:mamam_kasir/core/session/operational_context.dart';
import 'package:mamam_kasir/features/arus_kas/application/arus_kas_repository.dart';
import 'package:mamam_kasir/features/arus_kas/domain/arus_kas_models.dart';
import 'package:mamam_kasir/features/dashboard/application/dashboard_repository.dart';
import 'package:mamam_kasir/features/dompet/application/dompet_repository.dart';
import 'package:mamam_kasir/features/history/application/history_repository.dart';
import 'package:mamam_kasir/features/hpp_opname/application/hpp_opname_repository.dart';
import 'package:mamam_kasir/features/pos/application/pos_repository.dart';
import 'package:mamam_kasir/features/pos/domain/order_models.dart';
import 'package:mamam_kasir/features/pos/domain/transaction.dart' as txn;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String tempDirPath;
  _FakePathProvider.withPath(this.tempDirPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDirPath;
}

/// The branch the fresh database is seeded with (all demo rows belong to it).
const _branch1 = 'branch-cibarusah';
const _branch2 = 'branch-2';

OperationalContextReader _as(String userId, String branchId) {
  return () => OperationalContext(userId: userId, branchId: branchId);
}

/// Everything the app shows for one branch, boiled down to comparable values.
Future<Map<String, Object?>> _viewOf(OperationalContextReader context) async {
  final history = HistoryRepository(context: context);
  final dashboard = DashboardRepository(context: context);
  final dompet = DompetRepository(context: context);
  final arusKas = ArusKasRepository(dompet, context: context);
  final opname = HppOpnameRepository(context: context);

  final metrics = await dashboard.getMetrics();
  return {
    'transactions': (await history.getTransactions()).map((t) => t.id).toList(),
    'omzetHariIni': metrics.omzetHariIni,
    'totalPesanan': metrics.totalPesanan,
    'totalPengeluaran': metrics.totalPengeluaran,
    'arusKasOut': await arusKas.getTotal(direction: ArusKasDirection.pengeluaran),
    'arusKasEntries': (await arusKas.getEntries(direction: ArusKasDirection.pengeluaran)).map((e) => e.id).toList(),
    'movements': (await dompet.getMovements()).map((m) => m.id).toList(),
    'locations': (await dompet.getCashLocations()).map((l) => l.id).toList(),
    'storeBalance': await dompet.getLocationBalance('loc-store'),
    'closings': (await dompet.getClosings()).map((c) => c.id).toList(),
    'opname': (await opname.getSessions()).map((s) => s.id).toList(),
  };
}

/// One row of each operational kind, all belonging to branch 2.
Future<void> _seedBranch2(Database db) async {
  final now = DateTime.now().toIso8601String();
  final today = DateTime.now().toIso8601String();

  await db.insert('branches', {
    'id': _branch2,
    'name': 'Cabang 2',
    'is_active': 1,
    'sort_order': 1,
    'created_at': now,
    'updated_at': now,
  });
  await db.insert('transactions', {
    'id': 'b2-t1',
    'display_number': '#B2-1',
    'status': 'paid',
    'order_type': 'Takeaway',
    'subtotal': 777000,
    'voucher_discount': 0,
    'manual_discount_amount': 0,
    'tax_amount': 0,
    'service_amount': 0,
    'delivery_fee': 0,
    'rounding_adjustment': 0,
    'total': 777000,
    'created_at': now,
    'paid_at': today,
    'created_by': 'user-2',
    'branch_id': _branch2,
  });
  await db.insert('cash_locations', {
    'id': 'loc-b2',
    'type': 'courier',
    'name': 'Kurir Cabang 2',
    'is_active': 1,
    'created_at': now,
    'updated_at': now,
    'branch_id': _branch2,
  });
  await db.insert('cash_movements', {
    'id': 'b2-m1',
    'type': 'expense',
    'from_location_id': 'loc-b2',
    'amount': 5000,
    'reason': 'Belanja',
    'created_at': now,
    'created_by': 'user-2',
    'branch_id': _branch2,
  });
  await db.insert('cash_expenses', {
    'id': 'b2-e1',
    'direction': 'pengeluaran',
    'category': 'Belanja',
    'amount': 5000,
    'transaction_date': today,
    'source_location_id': 'loc-b2',
    'funding_source': 'cash_location',
    'cash_movement_id': 'b2-m1',
    'created_at': now,
    'created_by': 'user-2',
    'branch_id': _branch2,
  });
  await db.insert('dompet_closings', {
    'id': 'b2-c1',
    'period_start': now,
    'period_end': now,
    'opening_balance': 0,
    'cash_sales_total': 0,
    'courier_deposits_total': 0,
    'cash_expenses_total': 5000,
    'expected_cash': -5000,
    'counted_cash': -5000,
    'discrepancy': 0,
    'status': 'closed',
    'created_at': now,
    'created_by': 'user-2',
    'branch_id': _branch2,
  });
  await db.insert('stock_opname_sessions', {
    'id': 'b2-o1',
    'status': 'completed',
    'created_at': now,
    'completed_at': now,
    'created_by': 'user-2',
    'branch_id': _branch2,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database db;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mamam_kasir_scope_test_');
    PathProviderPlatform.instance = _FakePathProvider.withPath(tempDir.path);
    db = await AppDatabase.instance.database;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final branch1 = _as('user-1', _branch1);
  final branch2 = _as('user-2', _branch2);

  group('reads are limited to the acting branch', () {
    test("another branch's rows never change what branch 1 sees", () async {
      final before = await _viewOf(branch1);

      await _seedBranch2(db);

      expect(await _viewOf(branch1), equals(before));
    });

    test('branch 2 sees exactly its own rows', () async {
      await _seedBranch2(db);

      final view = await _viewOf(branch2);

      expect(view['transactions'], ['b2-t1']);
      expect(view['omzetHariIni'], 777000);
      expect(view['totalPesanan'], 1);
      expect(view['totalPengeluaran'], 5000);
      expect(view['arusKasOut'], 5000);
      expect(view['arusKasEntries'], ['b2-e1']);
      expect(view['movements'], ['b2-m1']);
      expect(view['locations'], ['loc-b2']);
      expect(view['storeBalance'], 0, reason: "branch 1's store drawer is not branch 2's cash");
      expect(view['closings'], ['b2-c1']);
      expect(view['opname'], ['b2-o1']);
    });
  });

  group('writes are stamped with the acting user and branch', () {
    Future<Map<String, Object?>> newest(String table, String orderBy) async {
      final rows = await db.query(table, orderBy: '$orderBy DESC', limit: 1);
      return rows.first;
    }

    test('Arus Kas entry (non-cash) and its cash movement (cash location)', () async {
      await _seedBranch2(db);
      final dompet = DompetRepository(context: branch2);
      final arusKas = ArusKasRepository(dompet, context: branch2);

      await arusKas.addEntry(
        direction: ArusKasDirection.pengeluaran,
        category: 'Stamp non-cash',
        amount: 1000,
        transactionDate: DateTime.now(),
        fundingSource: ArusKasFundingSource.nonCash,
      );
      await arusKas.addEntry(
        direction: ArusKasDirection.pengeluaran,
        category: 'Stamp cash',
        amount: 2000,
        transactionDate: DateTime.now(),
        fundingSource: ArusKasFundingSource.cashLocation,
        sourceLocationId: 'loc-b2',
      );

      for (final category in ['Stamp non-cash', 'Stamp cash']) {
        final entry = await db.query('cash_expenses', where: 'category = ?', whereArgs: [category]);
        expect(entry.single['branch_id'], _branch2, reason: category);
        expect(entry.single['created_by'], 'user-2', reason: category);
      }
      final movement = await db.query('cash_movements', where: 'reason = ?', whereArgs: ['Stamp cash']);
      expect(movement.single['branch_id'], _branch2);
      expect(movement.single['created_by'], 'user-2');
    });

    test('Dompet cash sale', () async {
      await _seedBranch2(db);

      await DompetRepository(context: branch2).recordCashSale(toLocationId: 'loc-b2', amount: 1000, transactionId: 'x');

      final row = await newest('cash_movements', 'created_at');
      expect(row['type'], 'cash_sale');
      expect(row['branch_id'], _branch2);
      expect(row['created_by'], 'user-2');
    });

    test('Stok Opname session', () async {
      await _seedBranch2(db);

      await HppOpnameRepository(context: branch2).submitSession(items: const [], asDraft: true);

      final row = await newest('stock_opname_sessions', 'created_at');
      expect(row['branch_id'], _branch2);
      expect(row['created_by'], 'user-2');
    });

    test('POS checkout', () async {
      await _seedBranch2(db);

      final saved = await PosRepository(context: branch2).saveTransaction(
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
      );

      final row = (await db.query('transactions', where: 'id = ?', whereArgs: [saved.id])).single;
      expect(row['branch_id'], _branch2);
      expect(row['created_by'], 'user-2');
    });
  });

  test("one branch cannot delete another branch's Arus Kas entry", () async {
    await _seedBranch2(db);
    final dompet = DompetRepository(context: branch1);

    await ArusKasRepository(dompet, context: branch1).deleteEntry('b2-e1');

    expect(await db.query('cash_expenses', where: 'id = ?', whereArgs: ['b2-e1']), hasLength(1));
    expect(await db.query('cash_movements', where: 'id = ?', whereArgs: ['b2-m1']), hasLength(1));
  });
}
