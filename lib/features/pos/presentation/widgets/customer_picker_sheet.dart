import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/cart_provider.dart';
import '../../domain/customer.dart';

class CustomerPickerSheet extends ConsumerStatefulWidget {
  final List<Customer> customers;
  const CustomerPickerSheet({super.key, required this.customers});

  @override
  ConsumerState<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
  final _searchController = TextEditingController();
  final _newNameController = TextEditingController();
  bool _isAddingNew = false;

  @override
  void dispose() {
    _searchController.dispose();
    _newNameController.dispose();
    super.dispose();
  }

  List<Customer> get _filtered {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return widget.customers;
    return widget.customers.where((c) => c.name.toLowerCase().contains(query)).toList();
  }

  Future<void> _createCustomer() async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) return;
    final customer = await ref.read(cartProvider.notifier).createAndSetCustomer(name: name);
    if (!mounted) return;
    Navigator.of(context).pop(customer);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary)),
                    const Text('Pilih Pelanggan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _isAddingNew
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newNameController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Nama pelanggan baru',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          TextButton(onPressed: _createCustomer, child: const Text('Simpan')),
                        ],
                      )
                    : TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Cari pelanggan...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 19),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                        ),
                      ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline_rounded, color: AppColors.textMuted),
                      title: const Text('Pelanggan Umum', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    if (!_isAddingNew)
                      ListTile(
                        leading: const Icon(Icons.person_add_rounded, color: AppColors.brand),
                        title: const Text('Tambah Pelanggan Baru', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.brand)),
                        onTap: () => setState(() => _isAddingNew = true),
                      ),
                    const Divider(),
                    ..._filtered.map((c) => ListTile(
                          leading: const Icon(Icons.person_rounded, color: AppColors.textSecondary),
                          title: Text(c.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          subtitle: c.phone != null ? Text(c.phone!, style: const TextStyle(fontSize: 11.5)) : null,
                          onTap: () => Navigator.of(context).pop(c),
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
