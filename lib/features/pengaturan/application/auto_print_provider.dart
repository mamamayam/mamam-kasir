import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the "Cetak Struk Otomatis" toggle shown in Pengaturan, same
/// plain-SharedPreferences pattern as [KasirGridColumnsController] (a UI
/// preference, not business data). The setting itself has no printer to
/// act on yet (no Bluetooth printer library wired up — see Pengaturan's
/// "Printer Bluetooth" row), so this only persists the user's choice for
/// whenever that feature lands.
const _prefKey = 'auto_print_receipt';
const _defaultValue = false;

final autoPrintReceiptProvider = StateNotifierProvider<AutoPrintReceiptController, bool>((ref) {
  return AutoPrintReceiptController();
});

class AutoPrintReceiptController extends StateNotifier<bool> {
  AutoPrintReceiptController() : super(_defaultValue) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_prefKey) ?? _defaultValue;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, state);
  }
}
