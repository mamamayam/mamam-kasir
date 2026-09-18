import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_nav.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_dropdown_title.dart';
import '../../../core/widgets/ios_page_header.dart';
import '../application/hpp_opname_provider.dart';
import 'widgets/add_ingredient_modal.dart';
import 'widgets/hpp_tab_content.dart';
import 'widgets/opname_tab_content.dart';

enum HppOpnamePage { hpp, opname }

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
            IosPageHeader(
              title: AppDropdownTitle<HppOpnamePage>(
                selected: _page,
                options: const [HppOpnamePage.hpp, HppOpnamePage.opname],
                labelBuilder: (p) => p == HppOpnamePage.hpp ? 'HPP' : 'Stok Opname',
                onSelected: (page) => setState(() => _page = page),
              ),
              trailingIcon: _page == HppOpnamePage.hpp ? Icons.add_rounded : null,
              onTrailingTap: _page == HppOpnamePage.hpp
                  ? () => AppNav.showModal(
                        context,
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
