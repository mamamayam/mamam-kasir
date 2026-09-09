import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dashboard_models.dart';

/// Shell-phase placeholder provider. Real implementation reads from the
/// dashboard module (repositories/local DB + sync), scoped by branch and
/// permission (see AGENTS.md: "Server enforces permissions").
final dashboardSummaryProvider = Provider<DashboardSummary>((ref) {
  return DashboardSummary(
    user: const SessionUser(name: 'Andi Saputra', role: 'Owner'),
    metrics: const DashboardMetrics(
      omzetHariIni: 2450000,
      totalPengeluaran: 300000,
      labaKotor: 2150000,
      totalPesanan: 42,
      rataRata: 58000,
      growthPercent: 8.5,
    ),
    trend: _demoTrend(),
    unreadNotifications: 3,
    pendingApprovals: 2,
  );
});

List<SalesTrendPoint> _demoTrend() {
  // Mirrors the shape/pattern of the supplied React mockup's chartData
  // (weekday dip, weekend spike) so the shell renders a comparable chart.
  final base = DateTime(2026, 8, 8);
  final weekendOffsets = {5, 6, 12, 13, 19, 20, 26, 27};
  final values = [
    1200000, 1350000, 1100000, 1400000, 1500000, 2300000, 2600000,
    1250000, 1300000, 1900000, 1350000, 1450000, 2150000, 2500000,
    1150000, 1250000, 1300000, 1400000, 1550000, 2200000, 2450000,
    1200000, 1300000, 1400000, 1450000, 1600000, 2250000, 2600000,
    1250000, 1350000, 1500000,
  ];

  return List.generate(values.length, (i) {
    return SalesTrendPoint(
      date: base.add(Duration(days: i)),
      value: values[i],
      isWeekend: weekendOffsets.contains(i),
    );
  });
}
