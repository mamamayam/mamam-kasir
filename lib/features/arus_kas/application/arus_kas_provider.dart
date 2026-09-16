import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dompet/application/dompet_provider.dart';
import '../domain/arus_kas_models.dart';
import 'arus_kas_repository.dart';

final arusKasRepositoryProvider = Provider<ArusKasRepository>((ref) {
  return ArusKasRepository(ref.watch(dompetRepositoryProvider));
});

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

class ArusKasState {
  final ArusKasDirection direction;
  final ArusKasDateFilter dateFilter;
  final DateTime? customDate;
  final List<ArusKasEntry> entries;
  final int total;
  final List<String> categories;
  final bool isLoading;
  final String? errorMessage;

  const ArusKasState({
    this.direction = ArusKasDirection.pengeluaran,
    this.dateFilter = ArusKasDateFilter.bulanIni,
    this.customDate,
    this.entries = const [],
    this.total = 0,
    this.categories = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  ArusKasState copyWith({
    ArusKasDirection? direction,
    ArusKasDateFilter? dateFilter,
    DateTime? customDate,
    List<ArusKasEntry>? entries,
    int? total,
    List<String>? categories,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ArusKasState(
      direction: direction ?? this.direction,
      dateFilter: dateFilter ?? this.dateFilter,
      customDate: customDate ?? this.customDate,
      entries: entries ?? this.entries,
      total: total ?? this.total,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  (DateTime?, DateTime?) get dateRange {
    final now = DateTime.now();
    switch (dateFilter) {
      case ArusKasDateFilter.hariIni:
        return (_startOfDay(now), _endOfDay(now));
      case ArusKasDateFilter.kemarin:
        final yesterday = now.subtract(const Duration(days: 1));
        return (_startOfDay(yesterday), _endOfDay(yesterday));
      case ArusKasDateFilter.bulanIni:
        return (DateTime(now.year, now.month, 1), _endOfDay(DateTime(now.year, now.month + 1, 0)));
      case ArusKasDateFilter.bulanKemarin:
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        final lastMonth = firstOfThisMonth.subtract(const Duration(days: 1));
        return (DateTime(lastMonth.year, lastMonth.month, 1), _endOfDay(lastMonth));
      case ArusKasDateFilter.pilihTanggal:
        final d = customDate ?? now;
        return (_startOfDay(d), _endOfDay(d));
    }
  }
}

final arusKasProvider = StateNotifierProvider.autoDispose<ArusKasController, ArusKasState>((ref) {
  return ArusKasController(ref.watch(arusKasRepositoryProvider));
});

class ArusKasController extends StateNotifier<ArusKasState> {
  final ArusKasRepository _repository;

  ArusKasController(this._repository) : super(const ArusKasState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final (from, to) = state.dateRange;
      final entries = await _repository.getEntries(direction: state.direction, from: from, to: to);
      final total = await _repository.getTotal(direction: state.direction, from: from, to: to);
      final categories = await _repository.getCategories(state.direction);

      state = state.copyWith(entries: entries, total: total, categories: categories, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat data Arus Kas: $e');
    }
  }

  Future<void> setDirection(ArusKasDirection direction) async {
    state = state.copyWith(direction: direction);
    await load();
  }

  Future<void> setDateFilter(ArusKasDateFilter filter, {DateTime? customDate}) async {
    state = state.copyWith(dateFilter: filter, customDate: customDate);
    await load();
  }

  Future<bool> addEntry({
    required String category,
    required int amount,
    required DateTime transactionDate,
    required ArusKasFundingSource fundingSource,
    String? sourceLocationId,
    String? storeOrSupplierName,
    String? detail,
  }) async {
    try {
      await _repository.addEntry(
        direction: state.direction,
        category: category,
        amount: amount,
        transactionDate: transactionDate,
        fundingSource: fundingSource,
        sourceLocationId: sourceLocationId,
        storeOrSupplierName: storeOrSupplierName,
        detail: detail,
      );
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal menyimpan: $e');
      return false;
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      await _repository.deleteEntry(id);
      await load();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal menghapus: $e');
    }
  }
}
