import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cabang_models.dart';
import 'cabang_repository.dart';

final cabangRepositoryProvider = Provider<CabangRepository>((ref) => CabangRepository());

class CabangState {
  final List<Cabang> branches;
  final bool isLoading;
  final String? errorMessage;

  const CabangState({
    this.branches = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  CabangState copyWith({
    List<Cabang>? branches,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CabangState(
      branches: branches ?? this.branches,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  CabangSummary get summary => CabangSummary(
        maxBranches: kDefaultMaxBranches,
        totalBranches: branches.length,
        activeBranches: branches.where((b) => b.isActive).length,
      );
}

final cabangProvider = StateNotifierProvider.autoDispose<CabangController, CabangState>((ref) {
  return CabangController(ref.watch(cabangRepositoryProvider));
});

class CabangController extends StateNotifier<CabangState> {
  final CabangRepository _repository;

  CabangController(this._repository) : super(const CabangState()) {
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final branches = await _repository.getBranches();
      if (!mounted) return;
      state = state.copyWith(branches: branches, isLoading: false, clearError: true);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat data cabang: $e');
    }
  }

  Future<void> toggleActive(Cabang branch) async {
    try {
      await _repository.setActive(branch.id, !branch.isActive);
      await load();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(errorMessage: 'Gagal mengubah status cabang: $e');
    }
  }
}
