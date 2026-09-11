/// Suggested quick-cash amounts for a given total — "exact amount", next
/// round 10k, next round 50k, and a flat 100k — deduplicated and filtered
/// to only amounts >= total. Direct port of the reference app's
/// `quickCashOptions` derivation in PaymentModal.jsx.
List<int> buildQuickCashOptions(int total) {
  final candidates = <int>[
    total,
    ((total + 9999) ~/ 10000) * 10000,
    ((total + 49999) ~/ 50000) * 50000,
    100000,
  ];

  final seen = <int>{};
  final result = <int>[];
  for (final c in candidates) {
    if (c >= total && seen.add(c)) {
      result.add(c);
    }
  }
  return result;
}
