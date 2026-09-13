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
  final bool isLoading;
  final String? errorMessage;

  const DompetState({
    this.summary,
    this.recentMovements = const [],
    this.outstandingKasbon = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  DompetState copyWith({
    DompetSummary? summary,
    List<CashMovement>? recentMovements,
    List<Kasbon>? outstandingKasbon,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DompetState(
      summary: summary ?? this.summary,
      recentMovements: recentMovements ?? this.recentMovements,
      outstandingKasbon: outstandingKasbon ?? this.outstandingKasbon,
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

      state = state.copyWith(
        summary: summary,
        recentMovements: movements,
        outstandingKasbon: outstandingKasbon,
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
