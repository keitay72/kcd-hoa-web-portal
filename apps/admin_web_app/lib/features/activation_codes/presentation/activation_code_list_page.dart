import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/activation_code.dart';
import 'activation_code_providers.dart';
import 'generate_activation_code_dialog.dart';

class ActivationCodeListPage extends ConsumerStatefulWidget {
  const ActivationCodeListPage({super.key});

  @override
  ConsumerState<ActivationCodeListPage> createState() =>
      _ActivationCodeListPageState();
}

class _ActivationCodeListPageState extends ConsumerState<ActivationCodeListPage> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final codes = ref.watch(activationCodeListProvider(_status));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Activation Codes',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(activationCodeListProvider(_status)),
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _openGenerateDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Generate Code'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<String?>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Filter by Status',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All statuses'),
                ),
                ...ActivationCodeStatus.values.map(
                  (status) => DropdownMenuItem<String?>(
                    value: status.name,
                    child: Text(status.name),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _status = value),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: codes.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No activation codes found.'));
                }

                return Card(
                  margin: EdgeInsets.zero,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final code = items[index];

                      return ListTile(
                        leading: Icon(
                          code.isActive
                              ? Icons.password_outlined
                              : Icons.password_rounded,
                        ),
                        title: Text(code.addressLabel.isEmpty
                            ? code.addressId
                            : code.addressLabel),
                        subtitle: Text(
                          '${code.hoaName ?? 'HOA'} · ${code.statusLabel} · Expires ${code.expiresAt.toLocal()}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/admin/activation-codes/${code.id}'),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load activation codes: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGenerateDialog(BuildContext context) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const GenerateActivationCodeDialog(),
    );

    if (result != null) {
      ref.invalidate(activationCodeListProvider(_status));
    }
  }
}
