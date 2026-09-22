import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/laporan_models.dart';
import 'laporan_dummy_data.dart';
import 'laporan_repository.dart';

final laporanRepositoryProvider = Provider<LaporanRepository>((ref) => LaporanRepository());

class LaporanState {
  final ReportType reportType;
  final DateTime selectedMonth; // day is always 1 — month-granularity only
  final ReportData data;
  final bool isLoading;
  final String? errorMessage;

  const LaporanState({
    this.reportType = ReportType.pendapatan,
    required this.selectedMonth,
    this.data = const ReportData(totalValue: 0, transactionCount: 0, averagePerTransaction: 0, averagePerDay: 0, trend: [], rows: []),
    this.isLoading = true,
    this.errorMessage,
  });

  LaporanState copyWith({
    ReportType? reportType,
    DateTime? selectedMonth,
    ReportData? data,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LaporanState(
      reportType: reportType ?? this.reportType,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// True when the query succeeded but the month genuinely has no rows —
  /// distinct from "failed to load", which the screen renders as a retry
  /// state instead of an empty state.
  bool get hasNoData => errorMessage == null && data.rows.isEmpty && data.totalValue == 0;
}

final laporanProvider = StateNotifierProvider.autoDispose<LaporanController, LaporanState>((ref) {
  return LaporanController(ref.watch(laporanRepositoryProvider));
});

class LaporanController extends StateNotifier<LaporanState> {
  /// Kept (injected, unused for now) so swapping `load()` below back to
  /// real queries — once the blank-render bug in LaporanRepository's
  /// cross-feature DB read is found — is a small diff, not a rewire.
  // ignore: unused_field
  final LaporanRepository _repository;

  /// Guards against an out-of-order result overwriting a newer one when
  /// the user flicks between report types or months faster than a query
  /// completes — only the most recent request is allowed to commit.
  int _requestId = 0;

  LaporanController(this._repository) : super(LaporanState(selectedMonth: DateTime(DateTime.now().year, DateTime.now().month, 1))) {
    load();
  }

  Future<void> load() async {
    final requestId = ++_requestId;

    if (!state.reportType.isImplemented) {
      // Laba Rugi / Produk / Customer have no designed report body yet —
      // nothing to query, so this just clears loading without inventing
      // data.
      _commit(requestId, (s) => s.copyWith(isLoading: false, data: ReportData.empty(), clearError: true));
      return;
    }

    _commit(requestId, (s) => s.copyWith(isLoading: true, clearError: true));

    // Dummy data (LaporanDummyData) instead of _repository's real
    // transactions/cash_expenses queries — see that file's doc comment
    // for why. Still routed through the same await/isLoading/try
    // structure as a real fetch so swapping the source back later
    // doesn't change this screen's control flow.
    await Future<void>.delayed(Duration.zero);
    try {
      final type = state.reportType;
      final month = state.selectedMonth;
      final data = type == ReportType.pendapatan ? LaporanDummyData.pendapatan(month) : LaporanDummyData.pengeluaran(month);
      _commit(requestId, (s) => s.copyWith(data: data, isLoading: false, clearError: true));
    } catch (e) {
      _commit(requestId, (s) => s.copyWith(isLoading: false, data: ReportData.empty(), errorMessage: 'Gagal memuat laporan: $e'));
    }
  }

  /// Every state write goes through here. Two things it protects against,
  /// both of which used to surface as a crash on this screen:
  ///
  /// 1. `mounted` — the provider is autoDispose, so backing out while a
  ///    query is still in flight disposes the notifier; writing `state`
  ///    afterwards throws "Tried to use LaporanController after `dispose`
  ///    was called".
  /// 2. `_requestId` — a stale in-flight result must not clobber a newer
  ///    one (see the field's doc comment).
  void _commit(int requestId, LaporanState Function(LaporanState) update) {
    if (!mounted || requestId != _requestId) return;
    state = update(state);
  }

  void setReportType(ReportType type) {
    if (type == state.reportType) return;
    state = state.copyWith(reportType: type, clearError: true);
    load();
  }

  void setMonth(DateTime month) {
    final normalized = DateTime(month.year, month.month, 1);
    if (normalized == state.selectedMonth) return;
    state = state.copyWith(selectedMonth: normalized, clearError: true);
    load();
  }
}
