import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dompet_models.dart';
import 'dompet_repository.dart';

final dompetRepositoryProvider = Provider<DompetRepository>((ref) => DompetRepository());

/// All active cash locations (Store Cash + couriers) — used by the
/// checkout-side [CashLocationPicker] as well as the Dompet page.
final cashLocationsProvider = FutureProvider.autoDispose<List<CashLocation>>((ref) async {
  return ref.watch(dompetRepositoryProvider).getCashLocations();
});

/// Dompet page state: summary + recent movements + outstanding kasbon,
/// loaded together so the page can show everything without juggling
/// several separate async providers with independent loading states.
class DompetState {
  final DompetSummary? summary;
  final List<CashMovement> recentMovements;
  final List<Kasbon> outstandingKasbon;
  final DompetClosing? lastClosing;
  final bool isLoading;
  final String? errorMessage;

  const DompetState({
    this.summary,
    this.recentMovements = const [],
    this.outstandingKasbon = const [],
    this.lastClosing,
    this.isLoading = true,
    this.errorMessage,
  });

  DompetState copyWith({
    DompetSummary? summary,
    List<CashMovement>? recentMovements,
    List<Kasbon>? outstandingKasbon,
    DompetClosing? lastClosing,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DompetState(
      summary: summary ?? this.summary,
      recentMovements: recentMovements ?? this.recentMovements,
      outstandingKasbon: outstandingKasbon ?? this.outstandingKasbon,
      lastClosing: lastClosing ?? this.lastClosing,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

final dompetProvider = StateNotifierProvider.autoDispose<DompetController, DompetState>((ref) {
  return DompetController(ref.watch(dompetRepositoryProvider));
});

class DompetController extends StateNotifier<DompetState> {
  final DompetRepository _repository;

  DompetController(this._repository) : super(const DompetState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final summary = await _repository.getSummary();
      final movements = await _repository.getMovements();
      final kasbon = await _repository.getKasbonList();
      final outstandingKasbon = kasbon.where((k) => k.status != KasbonStatus.paid).toList();
      final lastClosing = await _repository.getLastClosing();

      state = state.copyWith(
        summary: summary,
        recentMovements: movements,
        outstandingKasbon: outstandingKasbon,
        lastClosing: lastClosing,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat data Dompet: $e');
    }
  }

  /// "Sudah Disetor" — see [[dompet-prd]] §5/§7A.
  Future<void> recordCourierDeposit({required String courierLocationId, required int amount}) async {
    try {
      await _repository.recordCourierDeposit(courierLocationId: courierLocationId, amount: amount);
      await load();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal mencatat setoran: $e');
    }
  }

  /// "Jadikan Kasbon" — see [[dompet-prd]] §7B.
  Future<void> convertToKasbon({required String courierLocationId, required String courierName, required int amount}) async {
    try {
      await _repository.convertToKasbon(courierLocationId: courierLocationId, courierName: courierName, amount: amount);
      await load();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal mengkonversi ke kasbon: $e');
    }
  }

  Future<void> recordKasbonRepayment({required String kasbonId, required int amount, String? note}) async {
    try {
      await _repository.recordKasbonRepayment(kasbonId: kasbonId, amount: amount, note: note);
      await load();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal mencatat pembayaran kasbon: $e');
    }
  }
}

/// State for the Tutup Dompet screen — loads its own preview
/// (independent of [dompetProvider]'s summary) so re-opening this
/// screen always reflects the ledger as of "now", not a stale summary.
class ClosingState {
  final DompetClosingPreview? preview;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final DompetClosing? committed;

  const ClosingState({
    this.preview,
    this.isLoading = true,
    this.isSubmitting = false,
    this.errorMessage,
    this.committed,
  });

  ClosingState copyWith({
    DompetClosingPreview? preview,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    DompetClosing? committed,
  }) {
    return ClosingState(
      preview: preview ?? this.preview,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      committed: committed ?? this.committed,
    );
  }
}

final closingProvider = StateNotifierProvider.autoDispose<ClosingController, ClosingState>((ref) {
  return ClosingController(ref.watch(dompetRepositoryProvider));
});

class ClosingController extends StateNotifier<ClosingState> {
  final DompetRepository _repository;

  ClosingController(this._repository) : super(const ClosingState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final preview = await _repository.buildClosingPreview();
      state = state.copyWith(preview: preview, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat ringkasan tutup dompet: $e');
    }
  }

  /// Commits the close. [isOverdue] should be true if this close is
  /// happening after the day it covers (per PRD's overdue-closing
  /// rule) — the caller is still responsible for supplying the real
  /// counted amount, never a guess.
  Future<bool> submit({required int countedCash, String? note, bool isOverdue = false}) async {
    final preview = state.preview;
    if (preview == null) return false;
    if (!preview.canClose) {
      state = state.copyWith(errorMessage: 'Masih ada uang kurir yang belum diselesaikan.');
      return false;
    }

    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final closing = await _repository.closeDompet(
        preview: preview,
        countedCash: countedCash,
        status: isOverdue ? DompetClosingStatus.overdueClosing : DompetClosingStatus.closed,
        note: note,
      );
      state = state.copyWith(isSubmitting: false, committed: closing);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, errorMessage: 'Gagal menutup dompet: $e');
      return false;
    }
  }
}
