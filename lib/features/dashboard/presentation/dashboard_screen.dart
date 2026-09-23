import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../menu_shell/presentation/menu_bottom_sheet.dart';
import '../../menu_shell/presentation/swipe_up_trigger.dart';
import '../../history/presentation/history_screen.dart';
import '../../pos/presentation/pos_screen.dart';
import '../application/dashboard_provider.dart';
import '../domain/dashboard_models.dart';
import 'widgets/hero_sales_card.dart';
import 'widgets/inline_refresh_indicator.dart';
import 'widgets/metrics_grid.dart';
import 'widgets/quick_actions_row.dart';
import 'widgets/sales_trend_chart.dart';
import 'widgets/session_marker.dart';

/// Dashboard (Beranda) screen.
///
/// Layout is intentionally NOT a single CustomScrollView: the header and
/// the swipe-up trigger are frozen chrome that live outside the scrollable
/// content area, per instruction ("header serta tombol swipe up menu
/// dibekukan kaya awal"). Only the middle content region scrolls, and a
/// small inline refresh row appears there — not a full-page spinner —
/// when the user pulls down.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  double _pullDistance = 0;
  bool _isRefreshing = false;

  static const double _pullTriggerThreshold = 60;
  static const double _maxPullDistance = 80;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Pull-to-refresh via ScrollNotification rather than a GestureDetector
  // wrapping the SingleChildScrollView: a GestureDetector's drag
  // recognizer competes with the Scrollable's own internal recognizer
  // for the same touch in the gesture arena, and on real devices
  // (unlike the emulator's mouse-drag simulation) the Scrollable wins
  // that race far more often — onVerticalDragStart/Update then never
  // fire at all, so the pull silently does nothing. A
  // NotificationListener instead listens to notifications the
  // Scrollable itself dispatches as it scrolls, so it always sees the
  // gesture regardless of who "owns" it.
  bool _handleScrollNotification(ScrollNotification notification) {
    // Overscrolling past the top (content already at offset 0 and the
    // user keeps dragging down) is exactly the "pulling to refresh"
    // gesture — dragOverscrollAmount is negative while pulling down.
    if (notification is OverscrollNotification && notification.dragDetails != null) {
      if (_scrollController.hasClients && _scrollController.offset <= 0 && notification.overscroll < 0 && !_isRefreshing) {
        setState(() {
          _pullDistance = (_pullDistance - notification.overscroll * 0.4).clamp(0, _maxPullDistance);
        });
      }
    } else if (notification is ScrollEndNotification) {
      if (_pullDistance >= _pullTriggerThreshold && !_isRefreshing) {
        _triggerRefresh();
      } else if (!_isRefreshing && _pullDistance > 0) {
        setState(() => _pullDistance = 0);
      }
    }
    return false;
  }

  Future<void> _triggerRefresh() async {
    setState(() {
      _isRefreshing = true;
      _pullDistance = 34;
    });
    // Local-DB refresh only for now. Once Supabase sync lands (docs/07
    // §19), add the sync pull call INSIDE DashboardController.load()
    // (push pending -> server validation -> pull, then re-read local
    // DB) — this widget doesn't need to change at all when that
    // happens, since it just awaits whatever load() does.
    await ref.read(dashboardProvider.notifier).load();
    if (!mounted) return;
    setState(() {
      _isRefreshing = false;
      _pullDistance = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final metrics = state.metrics;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // --- Frozen header: does not scroll away ---
                _DashboardHeader(user: state.user),
                InlineRefreshIndicator(
                  visible: _pullDistance > 4,
                  isRefreshing: _isRefreshing,
                ),
                // --- Scrollable content only ---
                Expanded(
                  child: state.isLoading && metrics == null
                      ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                      : NotificationListener<ScrollNotification>(
                          onNotification: _handleScrollNotification,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              AppSpacing.md,
                              AppSpacing.lg,
                              110, // clearance for the frozen swipe-up trigger
                            ),
                            child: Column(
                              children: [
                                HeroSalesCard(
                                  omzetHariIni: metrics?.omzetHariIni ?? 0,
                                  growthPercent: metrics?.growthPercent ?? 0,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                MetricsGrid(
                                  metrics: metrics ??
                                      const DashboardMetrics(
                                        omzetHariIni: 0,
                                        totalPengeluaran: 0,
                                        labaKotor: 0,
                                        totalPesanan: 0,
                                        rataRata: 0,
                                        growthPercent: 0,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                QuickActionsRow(
                                  onKasirTap: () => AppNav.push(context, (_) => const PosScreen()),
                                  onRiwayatTap: () => AppNav.push(context, (_) => const HistoryScreen()),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                SalesTrendChart(
                                  points: state.trend,
                                  onPointTap: (point) => _showTrendDetail(context, point),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
            // --- Frozen swipe-up trigger, anchored to the bottom ---
            Positioned(
              left: AppSpacing.xxl,
              right: AppSpacing.xxl,
              bottom: AppSpacing.md,
              child: SwipeUpTrigger(
                onTap: () => showMenuBottomSheet(
                  context,
                  unreadNotifications: state.unreadNotifications,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrendDetail(BuildContext context, SalesTrendPoint point) {
    AppNav.showModal(
      context,
      isScrollControlled: false,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Detail Omzet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(formatRupiah(point.value), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.brand)),
            const SizedBox(height: 4),
            Text(
              point.isWeekend ? 'Weekend' : 'Hari Biasa',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frozen header: store identity + online status + who's logged in.
/// Lives outside the scroll area entirely (see [DashboardScreen] layout
/// note) so it never moves as the user scrolls the content below it.
class _DashboardHeader extends StatelessWidget {
  final SessionUser user;
  const _DashboardHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(AppRadius.pill)),
            child: const Icon(Icons.storefront_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Mamam Kasir',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3),
                ),
                const SizedBox(height: 2),
                SessionMarker(user: user),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('ONLINE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.success, letterSpacing: 0.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
