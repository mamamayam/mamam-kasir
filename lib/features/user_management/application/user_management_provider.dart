import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/app_session.dart';
import '../data/user_management_repository.dart';
import '../domain/managed_user.dart';

final userManagementRepositoryProvider = Provider<UserManagementRepository>((ref) => UserManagementRepository());

class UserManagementState {
  final List<ManagedUser> users;
  final bool isLoading;
  final String? errorMessage;

  const UserManagementState({
    this.users = const [],
    this.isLoading = true,
    this.errorMessage,
  });

  UserManagementState copyWith({
    List<ManagedUser>? users,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserManagementState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final userManagementProvider = StateNotifierProvider.autoDispose<UserManagementController, UserManagementState>((ref) {
  return UserManagementController(ref.watch(userManagementRepositoryProvider));
});

class UserManagementController extends StateNotifier<UserManagementState> {
  final UserManagementRepository _repository;

  UserManagementController(this._repository) : super(const UserManagementState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final users = await _repository.listUsers();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal memuat daftar akun: $e');
    }
  }

  /// Returns null on success, or a user-facing error message on failure
  /// — the caller (the form modal) shows this inline rather than this
  /// controller owning a SnackBar/dialog itself.
  Future<String?> createUser({
    required String username,
    required String password,
    required String displayName,
    required AppRole role,
  }) async {
    try {
      await _repository.createUser(username: username, password: password, displayName: displayName, role: role);
      await load();
      return null;
    } on UsernameTakenException {
      return 'Username sudah dipakai akun lain';
    } on MultipleOwnersException {
      return 'Sudah ada akun Owner — hanya boleh 1 Owner';
    } catch (e) {
      return 'Gagal membuat akun: $e';
    }
  }

  Future<String?> updateUser({
    required String userId,
    required String username,
    required String displayName,
    required AppRole role,
    String? newPassword,
  }) async {
    try {
      await _repository.updateUser(
        userId: userId,
        username: username,
        displayName: displayName,
        role: role,
        newPassword: newPassword,
      );
      await load();
      return null;
    } on UsernameTakenException {
      return 'Username sudah dipakai akun lain';
    } on MultipleOwnersException {
      return 'Sudah ada akun Owner — hanya boleh 1 Owner';
    } catch (e) {
      return 'Gagal menyimpan perubahan: $e';
    }
  }

  Future<String?> deactivateUser(String userId) async {
    try {
      await _repository.deactivateUser(userId);
      await load();
      return null;
    } on CannotDeactivateOwnerException {
      return 'Akun Owner tidak bisa dinonaktifkan';
    } catch (e) {
      return 'Gagal menonaktifkan akun: $e';
    }
  }

  Future<String?> reactivateUser(String userId, {required AppRole role}) async {
    try {
      await _repository.reactivateUser(userId, role: role);
      await load();
      return null;
    } on MultipleOwnersException {
      return 'Sudah ada akun Owner — hanya boleh 1 Owner';
    } catch (e) {
      return 'Gagal mengaktifkan akun: $e';
    }
  }
}
