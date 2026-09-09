import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency.dart';
import '../../menu_shell/presentation/menu_bottom_sheet.dart';
import '../../menu_shell/presentation/swipe_up_trigger.dart';
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
  double _dragStartY = 0;
  bool _isDragging = false;

  static const double _pullTriggerThreshold = 60;
  static const double _maxPullDistance = 80;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    // Only start tracking a pull if the content is already scrolled to
    // the top — otherwise this would fight with normal list scrolling.
    _dragStartY = details.globalPosition.dy;
    _isDragging = true;
  }

  void _handleDragUpdate(DragUpdateDetails details, ScrollController controller) {
    if (!_isDragging) return;
    if (controller.hasClients && controller.offset > 0) return;

    final delta = details.globalPosition.dy - _dragStartY;
    if (delta <= 0) return;

    setState(() {
      _pullDistance = (delta * 0.4).clamp(0, _maxPullDistance);
    });
  }

  Future<void> _handleDragEnd(DragEndDetails details) async {
    _isDragging = false;
    if (_pullDistance >= _pullTriggerThreshold) {
      setState(() {
        _isRefreshing = true;
        _pullDistance = 34;
      });
      // NOTE: real refresh should trigger sync (push pending -> server
      // validation -> pull) per docs/07 §19. Placeholder delay for the
      // shell phase.
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        _isRefreshing = false;
        _pullDistance = 0;
      });
    } else {
      setState(() => _pullDistance = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // --- Frozen header: does not scroll away ---
                _DashboardHeader(summary: summary),
                InlineRefreshIndicator(
                  visible: _pullDistance > 4,
                  isRefreshing: _isRefreshing,
                ),
                // --- Scrollable content only ---
                Expanded(
                  child: GestureDetector(
                    onVerticalDragStart: _handleDragStart,
                    onVerticalDragUpdate: (d) => _handleDragUpdate(d, _scrollController),
                    onVerticalDragEnd: _handleDragEnd,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        110, // clearance for the frozen swipe-up trigger
                      ),
                      child: Column(
                        children: [
                          HeroSalesCard(
                            omzetHariIni: summary.metrics.omzetHariIni,
                            growthPercent: summary.metrics.growthPercent,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          MetricsGrid(metrics: summary.metrics),
                          const SizedBox(height: AppSpacing.lg),
                          SalesTrendChart(
                            points: summary.trend,
                            onPointTap: (point) => _showTrendDetail(context, point),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          QuickActionsRow(
                            onKasirTap: () {
                              // Route to Kasir/POS — out of scope for this shell pass.
                            },
                            onRiwayatTap: () {
                              // Route to Riwayat — out of scope for this shell pass.
                            },
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
                onTap: () => showMenuBottomSheet(context, summary: summary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTrendDetail(BuildContext context, SalesTrendPoint point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
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
  final DashboardSummary summary;
  const _DashboardHeader({required this.summary});

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
                SessionMarker(user: summary.user),
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
