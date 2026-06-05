import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'hoa_form_dialog.dart';
import 'hoa_providers.dart';

class HoaDetailPage extends ConsumerWidget {
  const HoaDetailPage({
    required this.hoaId,
    super.key,
  });

  final String hoaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoa = ref.watch(hoaDetailProvider(hoaId));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.go('/admin/hoas'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'HOA Detail',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              hoa.maybeWhen(
                data: (item) => FilledButton.icon(
                  onPressed: () => showDialog<Object?>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => HoaFormDialog(initialValue: item),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit HOA'),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: hoa.when(
              data: (item) => Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      _DetailRow(label: 'ID', value: item.id),
                      _DetailRow(label: 'Tenant ID', value: item.tenantId),
                      _DetailRow(label: 'Code', value: item.code),
                      _DetailRow(label: 'Name', value: item.name),
                      _DetailRow(label: 'Status', value: item.status.name),
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
                child: Text('Unable to load HOA: $error'),
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
            width: 120,
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
