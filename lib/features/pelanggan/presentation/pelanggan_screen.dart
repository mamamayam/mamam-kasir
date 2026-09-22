import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/pelanggan_provider.dart';
import '../domain/pelanggan_models.dart';
import 'pelanggan_detail_screen.dart';
import 'pelanggan_form_screen.dart';
import 'widgets/pelanggan_cards.dart';
import 'widgets/pelanggan_chrome.dart';

/// List Pelanggan — reached from the swipe-up menu's "Pelanggan" tile via
/// [AppNav.push] (a Level-4 full page, see docs/ui-priority-rules.md).
///
/// PLACEHOLDER PHASE: renders static dummy data from an in-memory
/// provider, laid out to match the approved `pelanggan_v3_gabungan.html`
/// mockup. It is deliberately NOT wired to the POS customer picker, the
/// database, sync, or any report (see the handoff doc / instructions:
/// "jangan digabungkan atau di-port kemana-mana").
class PelangganScreen extends ConsumerStatefulWidget {
  const PelangganScreen({super.key});

  @override
  ConsumerState<PelangganScreen> createState() => _PelangganScreenState();
}

class _PelangganScreenState extends ConsumerState<PelangganScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm() async {
    final created = await AppNav.push<bool>(context, (_) => const PelangganFormScreen());
    if (!mounted) return;
    if (created == true) _showSnack('Pelanggan ditambahkan');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pelangganProvider);
    final controller = ref.read(pelangganProvider.notifier);
    final visible = state.visible;

    return Scaffold(
      backgroundColor: AppColors.pelangganBackground,
      body: SafeArea(
        child: Column(
          children: [
            PelangganHeader(
              title: 'Pelanggan',
              onLeadingTap: () => Navigator.of(context).pop(),
              trailingIcon: Icons.add_rounded,
              onTrailingTap: _openForm,
            ),
            PelangganSearchPill(
              controller: _searchController,
              onChanged: controller.setSearchQuery,
              onClear: () {
                _searchController.clear();
                controller.clearSearch();
              },
            ),
            PelangganPillTab(
              labels: const ['Loyal', 'Semua'],
              selectedIndex: state.sort == PelangganSort.loyal ? 0 : 1,
              onSelected: (i) => controller.setSort(i == 0 ? PelangganSort.loyal : PelangganSort.semua),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.brand,
                // Placeholder: nothing to re-fetch yet. Once the real
                // repository + sync exist, this awaits controller.load()
                // (see docs/refresh-pattern.md "titik ekstensi").
                onRefresh: () async {},
                child: visible.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: constraints.maxHeight,
                              child: _EmptyState(
                                isSearching: state.isSearching,
                                query: state.searchQuery.trim(),
                                onAdd: _openForm,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        // bottom 110 = mockup `.list` padding-bottom.
                        padding: const EdgeInsets.only(bottom: 110),
                        children: [
                          for (var i = 0; i < visible.length; i++)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, 10),
                              child: PelangganListCard(
                                customer: visible[i],
                                rank: i + 1,
                                highlightTop: state.sort == PelangganSort.loyal,
                                onTap: () => AppNav.push(
                                  context,
                                  (_) => PelangganDetailScreen(customerId: visible[i].id),
                                ),
                              ),
                            ),
                          if (state.showActiveFooter)
                            _ActiveFooter(active: state.activeCount, total: state.totalCount),
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

/// "Pelanggan aktif X/Y" — small, unobtrusive, only on the Loyal tab and
/// only when not searching. X = ordered within the last 30 days, Y = ALL
/// registered customers (computed over the whole dataset, never over the
/// top-5 slice). Mockup `.active-footer`.
class _ActiveFooter extends StatelessWidget {
  final int active;
  final int total;
  const _ActiveFooter({required this.active, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 4, AppSpacing.lg, 8),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.pelangganTextMuted,
          ),
          children: [
            const TextSpan(text: 'Pelanggan aktif '),
            TextSpan(
              text: '$active/$total',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Contextual empty state. Mockup `.empty-state`: 52px muted icon at 60%
/// opacity, 15/w700 title, 13/w500 sub, optional white pill action.
///
/// AGENTS.md `## Search/UX` says the empty state is `Tidak ada data`
/// "or a contextual variant, as exemplified in the mockup". The mockup's
/// variants are kept: "Tidak ada hasil" while searching, "Belum ada
/// pelanggan" when the list is truly empty.
class _EmptyState extends StatelessWidget {
  final bool isSearching;
  final String query;
  final VoidCallback onAdd;
  const _EmptyState({required this.isSearching, required this.query, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: 0.6,
              child: const Icon(Icons.person_search_outlined, size: 52, color: AppColors.pelangganTextMuted),
            ),
            const SizedBox(height: 12),
            Text(
              isSearching ? 'Tidak ada hasil' : 'Belum ada pelanggan',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              isSearching ? 'Tidak ditemukan pelanggan untuk "$query"' : 'Tambahkan pelanggan pertama Anda',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.pelangganTextMuted),
            ),
            if (!isSearching) ...[
              const SizedBox(height: 16),
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: AppColors.pelangganTextPrimary),
                        SizedBox(width: 6),
                        Text(
                          'Tambah Pelanggan',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.pelangganTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
