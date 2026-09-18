import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pos/domain/order_models.dart';
import '../../pos/domain/transaction.dart';
import '../domain/history_models.dart';
import 'history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) => HistoryRepository());

class HistoryState {
  final List<Transaction> transactions;
  final bool isLoading;
  final String? errorMessage;

  final String searchQuery;
  final HistoryDateFilter dateFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final OrderType? orderTypeFilter; // null = semua
  final String? paymentMethodFilter; // null = semua
  final HistorySortKey sortKey;
  final HistoryStatusFilter statusFilter;

  const HistoryState({
    this.transactions = const [],
    this.isLoading = true,
    this.errorMessage,
    this.searchQuery = '',
    this.dateFilter = HistoryDateFilter.hariIni,
    this.customStartDate,
    this.customEndDate,
    this.orderTypeFilter,
    this.paymentMethodFilter,
    this.sortKey = HistorySortKey.dateDesc,
    this.statusFilter = HistoryStatusFilter.diproses,
  });

  HistoryState copyWith({
    List<Transaction>? transactions,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    HistoryDateFilter? dateFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    OrderType? orderTypeFilter,
    bool clearOrderTypeFilter = false,
    String? paymentMethodFilter,
    bool clearPaymentMethodFilter = false,
    HistorySortKey? sortKey,
    HistoryStatusFilter? statusFilter,
  }) {
    return HistoryState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      dateFilter: dateFilter ?? this.dateFilter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      orderTypeFilter: clearOrderTypeFilter ? null : (orderTypeFilter ?? this.orderTypeFilter),
      paymentMethodFilter: clearPaymentMethodFilter ? null : (paymentMethodFilter ?? this.paymentMethodFilter),
      sortKey: sortKey ?? this.sortKey,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }

  bool _withinDateRange(DateTime date) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    switch (dateFilter) {
      case HistoryDateFilter.semua:
        return true;
      case HistoryDateFilter.hariIni:
        final endOfToday = startOfToday.add(const Duration(days: 1));
        return (date.isAfter(startOfToday) || date.isAtSameMomentAs(startOfToday)) && date.isBefore(endOfToday);
      case HistoryDateFilter.kemarin:
        final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
        return date.isAfter(startOfYesterday) && date.isBefore(startOfToday);
      case HistoryDateFilter.hariSebelumnya:
        final sevenDaysAgo = startOfToday.subtract(const Duration(days: 7));
        return date.isAfter(sevenDaysAgo);
      case HistoryDateFilter.bulanIni:
        return date.year == now.year && date.month == now.month;
      case HistoryDateFilter.custom:
        if (customStartDate == null) return true;
        final start = DateTime(customStartDate!.year, customStartDate!.month, customStartDate!.day);
        final endBase = customEndDate ?? customStartDate!;
        final end = DateTime(endBase.year, endBase.month, endBase.day, 23, 59, 59);
        return (date.isAfter(start) || date.isAtSameMomentAs(start)) && date.isBefore(end);
    }
  }

  bool _matchesSearch(Transaction t) {
    if (searchQuery.isEmpty) return true;
    final q = searchQuery.toLowerCase();
    return t.id.toLowerCase().contains(q) ||
        t.displayNumber.toLowerCase().contains(q) ||
        (t.customerName?.toLowerCase().contains(q) ?? false) ||
        t.total.toString().contains(q);
  }

  bool _matchesStatus(Transaction t) {
    switch (statusFilter) {
      case HistoryStatusFilter.diproses:
        return t.status == TransactionStatus.open;
      case HistoryStatusFilter.selesai:
        return t.status == TransactionStatus.paid;
      case HistoryStatusFilter.dibatalkan:
        return t.status == TransactionStatus.canceled;
    }
  }

  /// Filtered by everything except the payment-method filter — used for
  /// the payment breakdown card, which should always show the full
  /// composition within the active date/search/order-type filter (same
  /// rationale as the reference app, kept because it's a sound UX
  /// pattern independent of which parts of that app are or aren't
  /// PRD-sanctioned).
  List<Transaction> get _filteredForBreakdown {
    return transactions.where((t) {
      return _matchesStatus(t) && _matchesSearch(t) && _withinDateRange(t.createdAt) && (orderTypeFilter == null || t.orderType == orderTypeFilter);
    }).toList();
  }

  List<Transaction> get filteredTransactions {
    final base = _filteredForBreakdown.where((t) {
      return paymentMethodFilter == null || t.paymentMethodLabel == paymentMethodFilter;
    }).toList();

    base.sort((a, b) {
      switch (sortKey) {
        case HistorySortKey.dateDesc:
          return b.createdAt.compareTo(a.createdAt);
        case HistorySortKey.dateAsc:
          return a.createdAt.compareTo(b.createdAt);
        case HistorySortKey.totalDesc:
          return b.total.compareTo(a.total);
        case HistorySortKey.totalAsc:
          return a.total.compareTo(b.total);
      }
    });
    return base;
  }

  List<PaymentMethodBreakdown> get paymentBreakdown {
    final totals = <String, PaymentMethodBreakdown>{};
    for (final t in _filteredForBreakdown) {
      if (t.isCanceled) continue; // canceled excluded from omzet, per PRD
      final key = t.paymentMethodLabel ?? 'Lainnya';
      final existing = totals[key];
      totals[key] = PaymentMethodBreakdown(
        method: key,
        total: (existing?.total ?? 0) + t.total,
        count: (existing?.count ?? 0) + 1,
      );
    }
    final list = totals.values.toList()..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  List<String> get availablePaymentMethods =>
      transactions.map((t) => t.paymentMethodLabel).whereType<String>().toSet().toList();
}

final historyProvider = StateNotifierProvider.autoDispose<HistoryController, HistoryState>((ref) {
  return HistoryController(ref.watch(historyRepositoryProvider));
});

class HistoryController extends StateNotifier<HistoryState> {
  final HistoryRepository _repository;

  HistoryController(this._repository) : super(const HistoryState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final transactions = await _repository.getTransactions();
      state = state.copyWith(transactions: transactions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat riwayat: $e');
    }
  }

  void setSearchQuery(String query) => state = state.copyWith(searchQuery: query);

  void setDateFilter(HistoryDateFilter filter) => state = state.copyWith(dateFilter: filter);

  void setCustomDateRange(DateTime? start, DateTime? end) {
    state = state.copyWith(dateFilter: HistoryDateFilter.custom, customStartDate: start, customEndDate: end);
  }

  void setOrderTypeFilter(OrderType? type) {
    state = type == null ? state.copyWith(clearOrderTypeFilter: true) : state.copyWith(orderTypeFilter: type);
  }

  void setPaymentMethodFilter(String? method) {
    state = method == null ? state.copyWith(clearPaymentMethodFilter: true) : state.copyWith(paymentMethodFilter: method);
  }

  void setSortKey(HistorySortKey key) => state = state.copyWith(sortKey: key);

  void setStatusFilter(HistoryStatusFilter filter) => state = state.copyWith(statusFilter: filter);

  Future<void> cancelTransaction(String transactionId, {String? reason}) async {
    try {
      await _repository.cancelTransaction(transactionId, reason: reason);
      await load();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal membatalkan transaksi: $e');
    }
  }

  Future<void> completeTransaction(
    String transactionId, {
    required String paymentMethodLabel,
    required int amountPaid,
    String? cashLocationId,
  }) async {
    try {
      await _repository.completeTransaction(
        transactionId,
        paymentMethodLabel: paymentMethodLabel,
        amountPaid: amountPaid,
        cashLocationId: cashLocationId,
      );
      await load();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal menyelesaikan pesanan: $e');
    }
  }
}
