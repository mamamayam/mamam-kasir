import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../../pos/domain/order_models.dart';
import '../application/history_provider.dart';
import '../domain/history_models.dart';
import 'transaction_detail_screen.dart';
import 'widgets/date_filter_tabs.dart';
import 'widgets/payment_breakdown_card.dart';
import 'widgets/sort_sheet.dart';
import 'widgets/transaction_card.dart';

/// Riwayat (transaction history) screen. Reached via [AppNav.push] from
/// the dashboard's "Riwayat" quick action.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomDateRange(BuildContext context, HistoryController controller) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
    );
    if (range != null) {
      controller.setCustomDateRange(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final controller = ref.read(historyProvider.notifier);

    ref.listen(historyProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.danger));
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Riwayat')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: controller.setSearchQuery,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Cari ID, nomor, pelanggan, nominal...',
                        hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 13),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Material(
                    color: AppColors.surface,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: InkWell(
                      onTap: () => showSortSheet(context, current: state.sortKey, onSelect: controller.setSortKey),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.border)),
                        child: const Icon(Icons.sort_rounded, size: 19, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DateFilterTabs(
              selected: state.dateFilter,
              onChanged: (filter) {
                if (filter == HistoryDateFilter.custom) {
                  _pickCustomDateRange(context, controller);
                } else {
                  controller.setDateFilter(filter);
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _OrderTypeFilterRow(selected: state.orderTypeFilter, onChanged: controller.setOrderTypeFilter),
            const SizedBox(height: AppSpacing.sm),
            PaymentBreakdownCard(
              breakdown: state.paymentBreakdown,
              selectedMethod: state.paymentMethodFilter,
              onSelect: controller.setPaymentMethodFilter,
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                  : RefreshIndicator(
                      color: AppColors.brand,
                      onRefresh: controller.load,
                      child: state.filteredTransactions.isEmpty
                          // RefreshIndicator needs a scrollable child to
                          // detect the pull gesture even when there's
                          // nothing to list — AlwaysScrollableScrollPhysics
                          // keeps the ListView draggable with zero/short
                          // content. The SizedBox(height: full viewport)
                          // wrapper keeps _EmptyState's internal Center
                          // actually centering in the visible area, since
                          // a bare ListView child only sizes to its own
                          // content, not the viewport.
                          ? LayoutBuilder(
                              builder: (context, constraints) => ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: constraints.maxHeight,
                                    child: const _EmptyState(),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
                              itemCount: state.filteredTransactions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final transaction = state.filteredTransactions[index];
                                return TransactionCard(
                                  transaction: transaction,
                                  onTap: () => AppNav.push(context, (_) => TransactionDetailScreen(transaction: transaction)),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTypeFilterRow extends StatelessWidget {
  final OrderType? selected;
  final ValueChanged<OrderType?> onChanged;
  const _OrderTypeFilterRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          _Chip(label: 'Semua Tipe', isSelected: selected == null, onTap: () => onChanged(null)),
          const SizedBox(width: AppSpacing.sm),
          ...OrderType.values.map((type) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _Chip(label: type.label, isSelected: selected == type, onTap: () => onChanged(type)),
              )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brand.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: isSelected ? AppColors.brand : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isSelected ? AppColors.brand : AppColors.textSecondary)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),
          const Text('Tidak ada transaksi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Coba ubah filter atau kata kunci pencarian.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
