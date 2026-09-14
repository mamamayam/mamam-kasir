import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/hpp_opname_provider.dart';
import 'widgets/add_ingredient_modal.dart';
import 'widgets/hpp_opname_header.dart';
import 'widgets/hpp_tab_content.dart';
import 'widgets/opname_tab_content.dart';

/// HPP & Stok Opname screen — combined per the approved HTML mockup,
/// switchable via the header's dropdown title rather than being two
/// separate pushed screens.
class HppOpnameScreen extends ConsumerStatefulWidget {
  const HppOpnameScreen({super.key});

  @override
  ConsumerState<HppOpnameScreen> createState() => _HppOpnameScreenState();
}

class _HppOpnameScreenState extends ConsumerState<HppOpnameScreen> {
  HppOpnamePage _page = HppOpnamePage.hpp;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hppOpnameProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            HppOpnameHeader(
              currentPage: _page,
              onPageSelected: (page) => setState(() => _page = page),
              onBack: () => Navigator.of(context).pop(),
              onAdd: _page == HppOpnamePage.hpp
                  ? () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => AddIngredientModal(initialCategory: state.hppCategory),
                      )
                  : null,
            ),
            Expanded(
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.tileHpp))
                  : _page == HppOpnamePage.hpp
                      ? const HppTabContent()
                      : const OpnameTabContent(),
            ),
          ],
        ),
      ),
    );
  }
}
