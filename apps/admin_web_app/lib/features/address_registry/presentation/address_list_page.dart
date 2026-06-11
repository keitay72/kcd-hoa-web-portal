import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../hoa_management/presentation/hoa_providers.dart';
import 'address_csv_import_dialog.dart';
import 'address_form_dialog.dart';
import 'address_providers.dart';

class AddressListPage extends ConsumerStatefulWidget {
  const AddressListPage({super.key});

  @override
  ConsumerState<AddressListPage> createState() => _AddressListPageState();
}

class _AddressListPageState extends ConsumerState<AddressListPage> {
  String? _selectedHoaId;

  @override
  Widget build(BuildContext context) {
    final hoas = ref.watch(hoaListProvider);
    final addresses = ref.watch(addressListProvider(_selectedHoaId));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final pagePadding = isCompact ? 16.0 : 24.0;

        return Padding(
          padding: EdgeInsets.all(pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isCompact ? constraints.maxWidth : null,
                    child: Text(
                      'Address Registry',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => ref.invalidate(addressListProvider(_selectedHoaId)),
                    icon: const Icon(Icons.refresh),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openImportDialog(context),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Import CSV'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openCreateDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Address'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              hoas.when(
                data: (items) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isCompact ? constraints.maxWidth : 420,
                  ),
                  child: DropdownButtonFormField<String?>(
                    value: _selectedHoaId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Filter by HOA',
                      border: OutlineInputBorder(),
                    ),
                    selectedItemBuilder: (context) {
                      return [
                        const Text(
                          'All HOA communities',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        ...items.map(
                          (hoa) => Text(
                            '${hoa.name} (${hoa.code})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ];
                    },
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All HOA communities'),
                      ),
                      ...items.map(
                        (hoa) => DropdownMenuItem<String?>(
                          value: hoa.id,
                          child: Text(
                            '${hoa.name} (${hoa.code})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedHoaId = value),
                  ),
                ),
                loading: () => const SizedBox(
                  height: 56,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Text('Unable to load HOA filters: $error'),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: addresses.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(child: Text('No addresses found.'));
                    }

                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final address = items[index];

                          return ListTile(
                            leading: Icon(
                              address.isActive
                                  ? Icons.location_on_outlined
                                  : Icons.location_off_outlined,
                            ),
                            title: Text(
                              address.singleLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${address.hoaName ?? 'HOA'} · ${address.statusLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _StatusPill(label: address.activationCodeStatusLabel),
                                const SizedBox(width: 8),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => context.go('/admin/addresses/${address.id}'),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text('Unable to load addresses: $error'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddressFormDialog(initialHoaId: _selectedHoaId),
    );

    if (result != null) {
      ref.invalidate(addressListProvider(_selectedHoaId));
    }
  }

  Future<void> _openImportDialog(BuildContext context) async {
    await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddressCsvImportDialog(),
    );
    ref.invalidate(addressListProvider(_selectedHoaId));
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
