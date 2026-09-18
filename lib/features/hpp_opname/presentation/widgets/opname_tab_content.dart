import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/sliding_pill_tabs.dart';
import '../../application/hpp_opname_provider.dart';
import '../../domain/hpp_opname_models.dart';
import 'hpp_tab_content.dart';

/// Stok Opname tab: Riwayat (history) / Input Baru sub-tabs, ported 1:1
/// from the HTML mockup.
class OpnameTabContent extends StatefulWidget {
  const OpnameTabContent({super.key});

  @override
  State<OpnameTabContent> createState() => _OpnameTabContentState();
}

class _OpnameTabContentState extends State<OpnameTabContent> {
  int _subTabIndex = 0; // 0 = Riwayat, 1 = Input Baru

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: SlidingPillTabs(
            labels: const ['Riwayat', 'Input Baru'],
            selectedIndex: _subTabIndex,
            onSelected: (i) => setState(() => _subTabIndex = i),
          ),
        ),
        Expanded(
          child: _subTabIndex == 0 ? const _RiwayatList() : const _InputBaruForm(),
        ),
      ],
    );
  }
}

class _RiwayatList extends ConsumerWidget {
  const _RiwayatList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(hppOpnameProvider).sessions;

    if (sessions.isEmpty) {
      return const Center(
        child: Text('Belum ada sesi opname.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isSelesai = session.status == StockOpnameStatus.selesai;
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (isSelesai ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelesai ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
                  size: 19,
                  color: isSelesai ? AppColors.success : AppColors.warning,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opname · ${session.itemCount} bahan',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(session.createdAt)} · ${formatRupiah(session.totalValue)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isSelesai ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  session.status.label,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: isSelesai ? AppColors.success : AppColors.warning),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InputBaruForm extends ConsumerWidget {
  const _InputBaruForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hppOpnameProvider);
    final controller = ref.read(hppOpnameProvider.notifier);
    final items = state.opnameFilteredIngredients;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SearchBarField(onChanged: controller.setOpnameSearchQuery),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SlidingPillTabs(
            labels: IngredientCategory.values.map((c) => c.label).toList(),
            selectedIndex: IngredientCategory.values.indexOf(state.opnameCategory),
            onSelected: (i) => controller.setOpnameCategory(IngredientCategory.values[i]),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text('Bahan tidak ditemukan.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: items.length,
                  itemBuilder: (context, index) => _OpnameItemCard(
                    key: ValueKey(items[index].id),
                    ingredient: items[index],
                  ),
                ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Nilai Stok (kategori ini)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              Text(formatRupiah(state.opnameCategoryTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await controller.submitSession(asDraft: false);
                if (context.mounted) {
                  final error = ref.read(hppOpnameProvider).errorMessage;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error ?? 'Sesi opname berhasil disimpan.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tileHpp,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                elevation: 0,
              ),
              child: const Text('Simpan Sesi Opname', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ],
    );
  }
}

class _OpnameItemCard extends ConsumerStatefulWidget {
  final Ingredient ingredient;
  const _OpnameItemCard({super.key, required this.ingredient});

  @override
  ConsumerState<_OpnameItemCard> createState() => _OpnameItemCardState();
}

class _OpnameItemCardState extends ConsumerState<_OpnameItemCard> {
  late final TextEditingController _qtyController;
  late final TextEditingController _priceController;
  bool _priceEditable = false;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController();
    _priceController = TextEditingController(text: widget.ingredient.lastPrice.toString());
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(hppOpnameProvider.notifier);
    final draft = ref.watch(hppOpnameProvider.select((s) => s.opnameDraft[widget.ingredient.id]));
    final subtotal = draft?.qty != null ? (draft!.qty! * draft.priceUsed).round() : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg)),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.ingredient.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text('Satuan: ${widget.ingredient.unit}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _FieldBox(
                  label: 'Qty Fisik',
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(hintText: '0', border: InputBorder.none, isDense: true),
                    onChanged: (value) {
                      final qty = double.tryParse(value.replaceAll(',', '.'));
                      controller.setDraftQty(widget.ingredient.id, qty);
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _FieldBox(
                  label: 'Harga / ${widget.ingredient.unit}',
                  editable: _priceEditable,
                  child: TextField(
                    controller: _priceController,
                    enabled: _priceEditable,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _priceEditable ? AppColors.textPrimary : AppColors.textSecondary),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                    onChanged: (value) {
                      final price = int.tryParse(value.replaceAll('.', '').replaceAll(',', ''));
                      if (price != null) controller.setDraftPrice(widget.ingredient.id, price);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _priceEditable = !_priceEditable),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.edit_outlined, size: 12, color: AppColors.textSecondary),
                SizedBox(width: 5),
                Text('Edit harga manual', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              Text(formatRupiah(subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  final String label;
  final Widget child;
  final bool editable;
  const _FieldBox({required this.label, required this.child, this.editable = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.3)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(AppRadius.sm)),
          child: child,
        ),
      ],
    );
  }
}
