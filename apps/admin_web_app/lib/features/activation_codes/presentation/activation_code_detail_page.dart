import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/activation_code.dart';
import '../domain/activation_code_inputs.dart';
import 'activation_code_providers.dart';
import 'reset_activation_code_dialog.dart';

class ActivationCodeDetailPage extends ConsumerWidget {
  const ActivationCodeDetailPage({
    required this.activationCodeId,
    super.key,
  });

  final String activationCodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(activationCodeDetailProvider(activationCodeId));
    final events = ref.watch(activationCodeEventsProvider(activationCodeId));
    final commandState = ref.watch(activationCodeCommandProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.go('/admin/activation-codes'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Activation Code Detail',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              code.maybeWhen(
                data: (item) => Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: commandState.isLoading
                          ? null
                          : () => _openResetDialog(context, ref, item),
                      icon: const Icon(Icons.restart_alt_outlined),
                      label: const Text('Reset'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: commandState.isLoading || !item.isActive
                          ? null
                          : () => _revoke(context, ref, item),
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('Revoke'),
                    ),
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: code.when(
              data: (item) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.addressLabel.isEmpty
                                  ? item.addressId
                                  : item.addressLabel,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 20),
                            _DetailRow(label: 'ID', value: item.id),
                            _DetailRow(label: 'HOA', value: item.hoaName ?? item.hoaId),
                            _DetailRow(label: 'HOA Code', value: item.hoaCode ?? 'Unknown'),
                            _DetailRow(label: 'Address ID', value: item.addressId),
                            _DetailRow(label: 'Status', value: item.statusLabel),
                            _DetailRow(label: 'Expires', value: item.expiresAt.toLocal().toString()),
                            _DetailRow(label: 'Reset Count', value: item.resetCount.toString()),
                            _DetailRow(label: 'Consumed At', value: item.consumedAt?.toLocal().toString() ?? ''),
                            _DetailRow(label: 'Consumed By', value: item.consumedBy ?? ''),
                            _DetailRow(label: 'Created', value: item.createdAt.toLocal().toString()),
                            _DetailRow(label: 'Updated', value: item.updatedAt.toLocal().toString()),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activation History',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: events.when(
                                data: (items) {
                                  if (items.isEmpty) {
                                    return const Text('No activation events yet.');
                                  }

                                  return ListView.separated(
                                    itemCount: items.length,
                                    separatorBuilder: (_, __) => const Divider(),
                                    itemBuilder: (context, index) {
                                      final event = items[index];
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(event.actionLabel),
                                        subtitle: Text(
                                          [
                                            event.createdAt.toLocal().toString(),
                                            if (event.reason != null) event.reason!,
                                            if (event.actorUserId != null)
                                              'Actor: ${event.actorUserId}',
                                          ].join('\n'),
                                        ),
                                      );
                                    },
                                  );
                                },
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (error, _) => Text(
                                  'Unable to load history: $error',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load activation code: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openResetDialog(
    BuildContext context,
    WidgetRef ref,
    ActivationCode item,
  ) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResetActivationCodeDialog(activationCode: item),
    );

    if (result != null) {
      ref.invalidate(activationCodeDetailProvider(item.id));
      ref.invalidate(activationCodeEventsProvider(item.id));
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    ActivationCode item,
  ) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) => const _RevokeActivationCodeDialog(),
    );

    if (reason == null) {
      return;
    }

    await ref.read(activationCodeCommandProvider.notifier).revokeCode(
          RevokeActivationCodeInput(
            activationCodeId: item.id,
            reason: reason,
          ),
        );
  }
}

class _RevokeActivationCodeDialog extends StatefulWidget {
  const _RevokeActivationCodeDialog();

  @override
  State<_RevokeActivationCodeDialog> createState() =>
      _RevokeActivationCodeDialogState();
}

class _RevokeActivationCodeDialogState
    extends State<_RevokeActivationCodeDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Revoke Activation Code'),
      content: TextField(
        controller: _reasonController,
        decoration: const InputDecoration(
          labelText: 'Reason / Notes',
          border: OutlineInputBorder(),
        ),
        minLines: 2,
        maxLines: 4,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_reasonController.text),
          icon: const Icon(Icons.block_outlined),
          label: const Text('Revoke'),
        ),
      ],
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
