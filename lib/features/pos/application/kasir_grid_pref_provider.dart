import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's chosen menu-grid column count (2 or 3) for the
/// Kasir screen across app restarts. This is a pure UI preference (not
/// app/business data), so plain `shared_preferences` is used rather than
/// the encrypted SQLite store or secure storage used elsewhere.
const _prefKey = 'kasir_grid_columns';
const _defaultColumns = 2;

final kasirGridColumnsProvider = StateNotifierProvider<KasirGridColumnsController, int>((ref) {
  return KasirGridColumnsController();
});

class KasirGridColumnsController extends StateNotifier<int> {
  KasirGridColumnsController() : super(_defaultColumns) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_prefKey);
    if (saved == 2 || saved == 3) {
      state = saved!;
    }
  }

  Future<void> toggle() async {
    state = state == 2 ? 3 : 2;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, state);
  }
}
