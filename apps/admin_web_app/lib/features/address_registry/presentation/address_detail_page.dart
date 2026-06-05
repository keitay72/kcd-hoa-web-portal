import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'address_form_dialog.dart';
import 'address_providers.dart';

class AddressDetailPage extends ConsumerWidget {
  const AddressDetailPage({
    required this.addressId,
    super.key,
  });

  final String addressId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(addressDetailProvider(addressId));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.go('/admin/addresses'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Address Detail',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              address.maybeWhen(
                data: (item) => FilledButton.icon(
                  onPressed: () => showDialog<Object?>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => AddressFormDialog(initialValue: item),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Address'),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: address.when(
              data: (item) => Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.singleLine,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      _DetailRow(label: 'ID', value: item.id),
                      _DetailRow(label: 'HOA', value: item.hoaName ?? item.hoaId),
                      _DetailRow(label: 'HOA Code', value: item.hoaCode ?? 'Unknown'),
                      _DetailRow(label: 'Line 1', value: item.line1),
                      _DetailRow(label: 'Line 2', value: item.line2 ?? ''),
                      _DetailRow(label: 'City', value: item.city),
                      _DetailRow(label: 'State', value: item.state),
                      _DetailRow(label: 'Postal Code', value: item.postalCode),
                      _DetailRow(label: 'Status', value: item.statusLabel),
                      _DetailRow(label: 'Normalized Key', value: item.normalizedKey),
                      _DetailRow(
                        label: 'Created',
                        value: item.createdAt.toLocal().toString(),
                      ),
                      _DetailRow(
                        label: 'Updated',
                        value: item.updatedAt.toLocal().toString(),
                      ),
                    ],
                  ),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load address: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
