import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Required before any DateFormat(..., 'id_ID') call (used by the
  // dashboard's sales trend chart) — without this, intl throws
  // LocaleDataException: Locale data has not been initialized.
  await initializeDateFormatting('id_ID', null);

  // NOTE: Supabase.initialize(...) and the encrypted local DB bootstrap
  // belong here once the backend/local-db phases (see docs/06) land.
  // Kept out of this shell-first pass intentionally — see AGENTS.md:
  // "Do not build everything in one uncontrolled pass."

  runApp(const ProviderScope(child: MamamKasirApp()));
}
