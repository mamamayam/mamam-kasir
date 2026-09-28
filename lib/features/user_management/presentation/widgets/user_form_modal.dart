import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/app_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_sheet_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../application/user_management_provider.dart';
import '../../domain/managed_user.dart';

/// Add/edit form for a login account, shown as a swipe-up modal via
/// [AppNav.showModal] — same pattern as [AddMenuItemModal] (the
/// reference list+add-form screen per component-standards-prompt.md).
///
/// Pass [existingUser] to edit that account; omit it (or pass null) to
/// create a new one. Password is REQUIRED when creating, OPTIONAL when
/// editing (leaving it blank keeps the current password — see
/// [UserManagementRepository.updateUser]'s doc comment).
class UserFormModal extends ConsumerStatefulWidget {
  final ManagedUser? existingUser;

  const UserFormModal({super.key, this.existingUser});

  bool get isEditing => existingUser != null;

  @override
  ConsumerState<UserFormModal> createState() => _UserFormModalState();
}

class _UserFormModalState extends ConsumerState<UserFormModal> {
  late final TextEditingController _usernameController;
  late final TextEditingController _displayNameController;
  late final TextEditingController _passwordController;
  late AppRole _selectedRole;
  bool _obscurePassword = true;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingUser;
    _usernameController = TextEditingController(text: existing?.username ?? '');
    _displayNameController = TextEditingController(text: existing?.displayName ?? '');
    _passwordController = TextEditingController();
    _selectedRole = existing?.role ?? AppRole.staff;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || displayName.isEmpty) {
      setState(() => _errorText = 'Username dan nama wajib diisi');
      return;
    }
    if (!widget.isEditing && password.isEmpty) {
      setState(() => _errorText = 'Password wajib diisi untuk akun baru');
      return;
    }
    if (password.isNotEmpty && password.length < 4) {
      setState(() => _errorText = 'Password minimal 4 karakter');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final controller = ref.read(userManagementProvider.notifier);
    final String? error;
    if (widget.isEditing) {
      error = await controller.updateUser(
        userId: widget.existingUser!.id,
        username: username,
        displayName: displayName,
        role: _selectedRole,
        newPassword: password.isEmpty ? null : password,
      );
    } else {
      error = await controller.createUser(
        username: username,
        password: password,
        displayName: displayName,
        role: _selectedRole,
      );
    }

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isSaving = false;
        _errorText = error;
      });
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSheetHeader(title: widget.isEditing ? 'Edit Akun' : 'Tambah Akun'),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField.form(
                      controller: _usernameController,
                      label: 'Username',
                      hintText: 'contoh: budi',
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField.form(
                      controller: _displayNameController,
                      label: 'Nama Tampilan',
                      hintText: 'contoh: Budi Santoso',
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      widget.isEditing ? 'Password Baru (kosongkan jika tidak diubah)' : 'Password',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    // AppTextField has no obscureText support (checked
                    // its source — form/search variants only), so this
                    // one field uses a plain TextField instead, styled
                    // to match. Same approach login_screen.dart's
                    // password field already uses.
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      enabled: !_isSaving,
                      decoration: InputDecoration(
                        hintText: widget.isEditing ? 'Biarkan kosong jika tidak ganti' : 'Minimal 4 karakter',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w500),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            size: 20,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Role', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    _RoleSelector(
                      selected: _selectedRole,
                      onSelected: _isSaving ? null : (role) => setState(() => _selectedRole = role),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(_errorText!, style: const TextStyle(fontSize: 13, color: AppColors.danger, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    AppButton.primary(
                      label: widget.isEditing ? 'Simpan Perubahan' : 'Tambah Akun',
                      onPressed: _isSaving ? null : _submit,
                      isLoading: _isSaving,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  final AppRole selected;
  final ValueChanged<AppRole>? onSelected;

  const _RoleSelector({required this.selected, required this.onSelected});

  static const _roleLabels = {
    AppRole.owner: 'Owner',
    AppRole.manager: 'Manager',
    AppRole.staff: 'Staff',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: AppRole.values.map((role) {
        final isSelected = role == selected;
        return ChoiceChip(
          label: Text(_roleLabels[role]!),
          selected: isSelected,
          onSelected: onSelected == null ? null : (_) => onSelected!(role),
          selectedColor: AppColors.brand,
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
          backgroundColor: AppColors.background,
          side: BorderSide(color: isSelected ? AppColors.brand : AppColors.border),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
