import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../application/hrd_provider.dart';
import 'owner/hrd_owner_overview_screen.dart';

/// Entry point for the swipe-up menu's "Staff" tile.
///
/// Per the migration prompt there are two distinct entry points into
/// this module:
/// * this "Staff" tile — Owner flow only, should not even be visible in
///   a real shared-device staff session once real auth exists
/// * a separate "Cek Gaji Saya" action (menu_bottom_sheet.dart) — the
///   Staff PIN flow, open to anyone on the shared device
///
/// [hrdViewerModeProvider] is the documented placeholder seam for "who is
/// logged in" (see that file's doc comment). While it resolves to
/// [HrdViewerMode.owner] (the default), this screen opens the Owner flow
/// directly. If a dev preview sets it to [HrdViewerMode.sharedDevice],
/// this tile shows a explanatory empty state instead of silently
/// exposing Owner data — it must never fall through to Owner screens.
class HrdEntryScreen extends ConsumerWidget {
  const HrdEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(hrdViewerModeProvider);
    if (mode == HrdViewerMode.owner) return const HrdOwnerOverviewScreen();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const IosPageHeader(title: Text('Staff')),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: AppEmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Menu ini khusus Owner. Gunakan "Cek Gaji Saya" di menu utama untuk melihat gaji kamu.',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
