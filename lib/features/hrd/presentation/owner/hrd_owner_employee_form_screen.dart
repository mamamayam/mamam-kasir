import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/ios_page_header.dart';
import '../../application/hrd_provider.dart';
import '../../domain/hrd_date_utils.dart';
import '../../domain/hrd_models.dart';
import 'hrd_owner_employee_detail_screen.dart';

/// Owner Screen 4 — Tambah/Edit Karyawan. Role management (add/remove) is
/// inline here via a Level-2 sheet, not a separate screen, per the
/// migration prompt.
class HrdOwnerEmployeeFormScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  const HrdOwnerEmployeeFormScreen({super.key, this.employeeId});

  bool get isEdit => employeeId != null;

  @override
  ConsumerState<HrdOwnerEmployeeFormScreen> createState() => _HrdOwnerEmployeeFormScreenState();
}

class _HrdOwnerEmployeeFormScreenState extends ConsumerState<HrdOwnerEmployeeFormScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _wageController = TextEditingController();
  final _bonusController = TextEditingController();
  final _overtimeRateController = TextEditingController(text: '5000');

  String _role = 'Kasir';
  EmployeeStatus _status = EmployeeStatus.aktif;
  String? _resignDate;
  late String _startDate;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _wageController.dispose();
    _bonusController.dispose();
    _overtimeRateController.dispose();
    super.dispose();
  }

  void _initFromExisting(Employee e) {
    _nameController.text = e.name;
    _phoneController.text = e.phone;
    _addressController.text = e.address;
    _wageController.text = e.wagePerHour == 0 ? '' : '${e.wagePerHour}';
    _bonusController.text = e.bonusFullTime == 0 ? '' : '${e.bonusFullTime}';
    _overtimeRateController.text = '${e.overtimeRatePer30Min}';
    _role = e.role;
    _status = e.status;
    _resignDate = e.resignDate;
    _startDate = e.startDate;
  }

  Future<void> _pickStartDate(String today) async {
    final initial = DateTime.tryParse(_startDate) ?? parseIsoDate(today);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2015), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (picked != null) setState(() => _startDate = formatIsoDate(picked));
  }

  Future<void> _pickResignDate(String today) async {
    final initial = DateTime.tryParse(_resignDate ?? today) ?? parseIsoDate(today);
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2015), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (picked != null) setState(() => _resignDate = formatIsoDate(picked));
  }

  void _save() {
    final controller = ref.read(hrdControllerProvider.notifier);
    final result = controller.saveEmployee(
      editingId: widget.employeeId,
      name: _nameController.text,
      phone: _phoneController.text,
      address: _addressController.text,
      role: _role,
      status: _status,
      resignDate: _resignDate,
      startDate: _startDate,
      wagePerHourText: _wageController.text,
      bonusFullTimeText: _bonusController.text,
      overtimeRateText: _overtimeRateController.text,
    );
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: AppColors.danger));
      return;
    }
    if (widget.isEdit) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HrdOwnerEmployeeDetailScreen(employeeId: result.savedId!)),
      );
    }
  }

  void _openRoleSheet(List<HrdRole> roles) {
    AppNav.showModal(
      context,
      builder: (context) => _RoleManagementSheet(
        currentRoles: roles,
        onRoleAdded: (name) => setState(() => _role = name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hrdControllerProvider);
    if (!_initialized) {
      _initialized = true;
      final existing = widget.isEdit ? state.employeeById(widget.employeeId!) : null;
      if (existing != null) {
        _initFromExisting(existing);
      } else {
        _startDate = state.today;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            IosPageHeader(title: Text(widget.isEdit ? 'Edit Karyawan' : 'Tambah Karyawan')),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                children: [
                  const _SectionLabel('DATA PERSONAL'),
                  AppTextField.form(label: 'Nama lengkap', controller: _nameController, hintText: 'Nama karyawan'),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField.form(label: 'Nomor HP', controller: _phoneController, hintText: '0812-xxxx-xxxx', keyboardType: TextInputType.phone),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField.form(label: 'Alamat', controller: _addressController, hintText: 'Alamat domisili'),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Role', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final r in state.roles) _Chip(label: r.name, selected: _role == r.name, onTap: () => setState(() => _role = r.name)),
                      _Chip(label: '+ Tambah role baru', selected: false, dashed: true, onTap: () => _openRoleSheet(state.roles)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Role bisa ditambah bebas sesuai kebutuhan bisnis. Role "Manajer" dikunci karena itu level permission tetap satu tingkat di bawah Owner.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final s in EmployeeStatus.values)
                        _Chip(label: s.label, selected: _status == s, onTap: () => setState(() => _status = s)),
                    ],
                  ),
                  if (_status == EmployeeStatus.resign) ...[
                    const SizedBox(height: AppSpacing.md),
                    _DatePickerField(label: 'Tanggal resign', value: _resignDate, onTap: () => _pickResignDate(state.today)),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionLabel('MASA KERJA'),
                  _DatePickerField(label: 'Tanggal mulai bekerja', value: _startDate, onTap: () => _pickStartDate(state.today)),
                  const SizedBox(height: 6),
                  Text('Lama bekerja: ${tenureLabel(_startDate, state.today)} — dihitung otomatis.', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionLabel('GAJI & TARIF'),
                  AppTextField.form(label: 'Upah per jam', controller: _wageController, hintText: '0', keyboardType: TextInputType.number, prefixText: 'Rp '),
                  const SizedBox(height: 6),
                  const Text('Total upah bulanan dihitung otomatis dari jam kerja tercatat.', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField.form(
                    label: 'Bonus full time (per hari, jika masuk ≤09:00 & pulang ≥19:00)',
                    controller: _bonusController,
                    hintText: '0',
                    keyboardType: TextInputType.number,
                    prefixText: 'Rp ',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField.form(label: 'Tarif lembur per 30 menit', controller: _overtimeRateController, hintText: '0', keyboardType: TextInputType.number, prefixText: 'Rp '),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton.primary(label: widget.isEdit ? 'Simpan Perubahan' : 'Simpan Karyawan', fullWidth: true, onPressed: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dashed;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: selected ? AppColors.brand : AppColors.border, style: dashed ? BorderStyle.solid : BorderStyle.solid),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DatePickerField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border), color: AppColors.surface),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value != null ? formatDateLong(value!) : 'Pilih tanggal', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline role management sheet — reachable only from within the employee
/// form's "+ Tambah role baru" chip, per the migration prompt (no
/// separate "Kelola Role" screen).
class _RoleManagementSheet extends ConsumerStatefulWidget {
  final List<HrdRole> currentRoles;
  final ValueChanged<String> onRoleAdded;

  const _RoleManagementSheet({required this.currentRoles, required this.onRoleAdded});

  @override
  ConsumerState<_RoleManagementSheet> createState() => _RoleManagementSheetState();
}

class _RoleManagementSheetState extends ConsumerState<_RoleManagementSheet> {
  final _nameController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final result = ref.read(hrdControllerProvider.notifier).addRole(_nameController.text);
    if (!result.ok) {
      setState(() => _error = result.message);
      return;
    }
    widget.onRoleAdded(_nameController.text.trim());
    setState(() {
      _error = null;
      _nameController.clear();
    });
  }

  void _remove(String roleId) {
    final result = ref.read(hrdControllerProvider.notifier).removeRole(roleId);
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(hrdControllerProvider.select((s) => s.roles));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Kelola Role', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                  AppIconButton.standard(icon: Icons.close_rounded, iconSize: 18, onTap: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField.form(label: 'Nama role baru', controller: _nameController, hintText: 'Contoh: Kitchen, Warehouse'),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
              ],
              const SizedBox(height: AppSpacing.md),
              AppButton.primary(label: 'Tambah Role', fullWidth: true, onPressed: _submit),
              const SizedBox(height: AppSpacing.lg),
              const Text('ROLE SAAT INI', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
                child: Column(
                  children: [
                    for (int i = 0; i < roles.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                        decoration: BoxDecoration(border: i == 0 ? null : const Border(top: BorderSide(color: AppColors.border))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: roles[i].name,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                  children: roles[i].locked
                                      ? const [TextSpan(text: '  (terkunci)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted))]
                                      : null,
                                ),
                              ),
                            ),
                            if (!roles[i].locked) AppIconButton.standard(icon: Icons.close_rounded, iconSize: 16, iconColor: AppColors.danger, onTap: () => _remove(roles[i].id)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
