import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // NOTE: Supabase.initialize(...) and the encrypted local DB bootstrap
  // belong here once the backend/local-db phases (see docs/06) land.
  // Kept out of this shell-first pass intentionally — see AGENTS.md:
  // "Do not build everything in one uncontrolled pass."

  runApp(const ProviderScope(child: MamamKasirApp()));
}
