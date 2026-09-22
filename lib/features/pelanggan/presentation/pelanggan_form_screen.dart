import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/pelanggan_provider.dart';
import '../domain/pelanggan_logic.dart';
import '../domain/pelanggan_models.dart';
import 'pelanggan_detail_screen.dart';
import 'widgets/pelanggan_chrome.dart';

/// Form Tambah / Edit Pelanggan — a full page (not a sheet) for
/// consistent navigation, as in the approved mockup.
///
/// [editingId] == null → "Tambah Pelanggan"; otherwise "Edit Pelanggan"
/// prefilled from the customer. Pops `true` when saved so the caller can
/// show the success snackbar.
///
/// Rules (AGENTS.md `## Customer`): name required; phone optional;
/// multiple phones (all equal — no primary); one phone belongs to one
/// customer. On a duplicate phone this form does what the handoff asks
/// for and the mockup did NOT: it rejects the save AND offers the
/// existing customer (a "Lihat <nama>" action) instead of only a generic
/// error line.
class PelangganFormScreen extends ConsumerStatefulWidget {
  final int? editingId;
  const PelangganFormScreen({super.key, this.editingId});

  @override
  ConsumerState<PelangganFormScreen> createState() => _PelangganFormScreenState();
}

class _PelangganFormScreenState extends ConsumerState<PelangganFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  final List<TextEditingController> _phoneControllers = [];

  bool _nameError = false;
  PhoneClash? _phoneClash;

  bool get _isEditing => widget.editingId != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();

    final existing = _isEditing ? ref.read(pelangganProvider).byId(widget.editingId!) : null;
    if (existing != null) {
      _nameController.text = existing.name;
      _addressController.text = existing.address;
      for (final p in existing.phones) {
        _phoneControllers.add(TextEditingController(text: p));
      }
    }
    // Always show at least one (empty) phone field.
    if (_phoneControllers.isEmpty) _phoneControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    for (final c in _phoneControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPhoneField() => setState(() => _phoneControllers.add(TextEditingController()));

  void _removePhoneField(int index) {
    setState(() {
      _phoneControllers.removeAt(index).dispose();
      // Keep at least one empty field visible when everything is removed.
      if (_phoneControllers.isEmpty) _phoneControllers.add(TextEditingController());
      _phoneClash = null;
    });
  }

  void _save() {
    final result = ref.read(pelangganProvider.notifier).save(
          editingId: widget.editingId,
          name: _nameController.text,
          phones: _phoneControllers.map((c) => c.text).toList(),
          address: _addressController.text,
        );

    switch (result) {
      case PelangganNameRequired():
        setState(() {
          _nameError = true;
          _phoneClash = null;
        });
      case PelangganPhoneTaken(:final clash):
        setState(() {
          _nameError = false;
          _phoneClash = clash;
        });
      case PelangganNotFound():
        // The customer was deleted while this edit form was open —
        // nothing to save into. Say so and leave the form (popping
        // `false`, i.e. "not saved", so the caller shows no success toast).
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Pelanggan sudah tidak ada'), backgroundColor: AppColors.danger),
          );
        Navigator.of(context).pop(false);
      case PelangganSaved():
        Navigator.of(context).pop(true);
    }
  }

  /// Offers the existing owner of the duplicated number: opens that
  /// customer's detail. Pushed on top of this form (stack semantics, see
  /// docs/ui-priority-rules.md §3) so backing out returns to the form
  /// with the user's input intact.
  Future<void> _openExistingOwner(PhoneClash clash) async {
    await AppNav.push<void>(context, (_) => PelangganDetailScreen(customerId: clash.owner.id));
    if (!mounted) return;

    // The user may have deleted (or edited away the number of) that
    // customer while looking at their detail. The notice holds a stale
    // snapshot, so re-check against live data: if the number is free now,
    // drop the notice instead of offering a customer that no longer
    // exists / a clash that no longer applies.
    final stillClashes = PelangganLogic.findPhoneClash(
      ref.read(pelangganProvider).customers,
      _phoneControllers.map((c) => c.text).toList(),
      editingId: widget.editingId,
    );
    setState(() => _phoneClash = stillClashes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pelangganBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                PelangganHeader(
                  title: _isEditing ? 'Edit Pelanggan' : 'Tambah Pelanggan',
                  leadingIcon: Icons.close_rounded,
                  onLeadingTap: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    // bottom 120 = mockup `.form-body` (room for the fixed CTA).
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(
                          'Nama',
                          suffix: const TextSpan(text: ' *', style: TextStyle(color: AppColors.pelangganDanger)),
                          first: true,
                        ),
                        _PillInput(
                          controller: _nameController,
                          hintText: 'Nama pelanggan',
                          hasError: _nameError,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) {
                            if (_nameError) setState(() => _nameError = false);
                          },
                        ),
                        if (_nameError) const _FieldError('Nama wajib diisi.'),
                        const _FieldLabel('Nomor HP', optional: true),
                        for (var i = 0; i < _phoneControllers.length; i++)
                          _PhoneRow(
                            key: ObjectKey(_phoneControllers[i]),
                            controller: _phoneControllers[i],
                            hasError: _phoneClash != null &&
                                PelangganLogic.digitsOnly(_phoneClash!.phone) ==
                                    PelangganLogic.digitsOnly(_phoneControllers[i].text),
                            onChanged: () {
                              if (_phoneClash != null) setState(() => _phoneClash = null);
                            },
                            onRemove: () => _removePhoneField(i),
                          ),
                        _AddPhoneButton(onTap: _addPhoneField),
                        const _FieldHint('Bisa tambah lebih dari satu nomor. Satu nomor hanya untuk satu pelanggan.'),
                        if (_phoneClash != null)
                          _DuplicatePhoneNotice(
                            clash: _phoneClash!,
                            onOpenExisting: () => _openExistingOwner(_phoneClash!),
                          ),
                        const _FieldLabel('Alamat', optional: true),
                        _PillInput(
                          controller: _addressController,
                          hintText: 'Alamat pelanggan',
                          hasError: false,
                          multiline: true,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Fixed bottom CTA (mockup `.bottom-action`: left/right 16, bottom 20).
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.xl,
              child: Material(
                color: AppColors.pelangganTextPrimary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: _save,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 17),
                    child: Center(
                      child: Text(
                        'Simpan Pelanggan',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Field label (13/w600 secondary). Mockup `.field-label`: 8px below, 18px
/// above (0 for the first one).
class _FieldLabel extends StatelessWidget {
  final String text;
  final bool optional;
  final TextSpan? suffix;
  final bool first;
  const _FieldLabel(this.text, {this.optional = false, this.suffix, this.first = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 18, bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          children: [
            if (suffix != null) suffix!,
            if (optional)
              const TextSpan(
                text: ' (Opsional)',
                style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.pelangganTextMuted),
              ),
          ],
        ),
      ),
    );
  }
}

/// White pill input. Mockup `.field-input`: radius pill, padding 16/18,
/// 14.5/w600, 1.5px border transparent → textPrimary on focus, danger on
/// error. [multiline] uses radius md (16) and min-height 76 (`.textarea`).
class _PillInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool hasError;
  final bool multiline;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const _PillInput({
    required this.controller,
    required this.hintText,
    required this.hasError,
    this.multiline = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(multiline ? AppRadius.md : AppRadius.pill);

    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: 1.5),
        );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: multiline ? TextInputType.multiline : keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 5 : 1,
      cursorColor: AppColors.pelangganTextPrimary,
      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.pelangganTextPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.pelangganTextMuted),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: border(hasError ? AppColors.pelangganDanger : Colors.transparent),
        enabledBorder: border(hasError ? AppColors.pelangganDanger : Colors.transparent),
        focusedBorder: border(hasError ? AppColors.pelangganDanger : AppColors.pelangganTextPrimary),
      ),
    );
  }
}

/// One phone input + a 38px circular remove button. Mockup `.phone-row`
/// (gap 8, margin-bottom 8). Auto-groups digits as typed ("0812 3456 7890").
class _PhoneRow extends StatelessWidget {
  final TextEditingController controller;
  final bool hasError;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _PhoneRow({
    super.key,
    required this.controller,
    required this.hasError,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: _PillInput(
              controller: controller,
              hintText: '08xx xxxx xxxx',
              hasError: hasError,
              keyboardType: TextInputType.phone,
              inputFormatters: [_PhoneGroupFormatter()],
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 38,
                height: 38,
                child: Icon(Icons.close_rounded, size: 16, color: AppColors.pelangganDanger),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Re-groups the digits as the user types, keeping the cursor at the end.
/// Delegates the actual grouping to [PelangganLogic.formatPhone] so the
/// rule lives in one testable place.
class _PhoneGroupFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = PelangganLogic.formatPhone(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// "+ Tambah nomor lain" text button. Mockup `.add-phone-btn`.
class _AddPhoneButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhoneButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.pelangganTextPrimary),
            SizedBox(width: 6),
            Text(
              'Tambah nomor lain',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.pelangganTextPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldHint extends StatelessWidget {
  final String text;
  const _FieldHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.pelangganTextMuted)),
    );
  }
}

class _FieldError extends StatelessWidget {
  final String text;
  const _FieldError(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.pelangganDanger),
      ),
    );
  }
}

/// Duplicate-phone notice. Beyond the mockup's single red error line, this
/// also OFFERS the existing customer that owns the number (handoff:
/// "tolak dan tawarkan pelanggan yang sudah ada").
class _DuplicatePhoneNotice extends StatelessWidget {
  final PhoneClash clash;
  final VoidCallback onOpenExisting;
  const _DuplicatePhoneNotice({required this.clash, required this.onOpenExisting});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nomor ${clash.phone} sudah terdaftar untuk ${clash.owner.name}.',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.pelangganDanger),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onOpenExisting,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Lihat ${clash.owner.name}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.pelangganTextPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
