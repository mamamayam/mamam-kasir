import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/laporan_models.dart';
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
}

final laporanProvider = StateNotifierProvider.autoDispose<LaporanController, LaporanState>((ref) {
  return LaporanController(ref.watch(laporanRepositoryProvider));
});

class LaporanController extends StateNotifier<LaporanState> {
  final LaporanRepository _repository;

  LaporanController(this._repository) : super(LaporanState(selectedMonth: DateTime(DateTime.now().year, DateTime.now().month, 1))) {
    load();
  }

  Future<void> load() async {
    if (!state.reportType.isImplemented) {
      // Laba/Produk/Customer have no designed report body yet — nothing
      // to query, so this just clears loading without inventing data.
      state = state.copyWith(isLoading: false, data: ReportData.empty(), clearError: true);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = state.reportType == ReportType.pendapatan
          ? await _repository.getPendapatanReport(state.selectedMonth)
          : await _repository.getPengeluaranReport(state.selectedMonth);
      state = state.copyWith(data: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat laporan: $e');
    }
  }

  void setReportType(ReportType type) {
    state = state.copyWith(reportType: type);
    load();
  }

  void setMonth(DateTime month) {
    state = state.copyWith(selectedMonth: DateTime(month.year, month.month, 1));
    load();
  }
}
