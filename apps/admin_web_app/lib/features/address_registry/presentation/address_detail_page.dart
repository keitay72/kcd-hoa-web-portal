import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../activation_codes/domain/activation_code.dart';
import '../../activation_codes/domain/activation_code_inputs.dart';
import '../../activation_codes/presentation/activation_code_providers.dart';
import '../../activation_codes/presentation/generate_activation_code_dialog.dart';
import '../../activation_codes/presentation/reset_activation_code_dialog.dart';
import '../domain/hoa_address.dart';
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
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: _ActivationCodeSection(address: item),
                  ),
                ],
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

class _ActivationCodeSection extends ConsumerWidget {
  const _ActivationCodeSection({required this.address});

  final HoaAddress address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activationCodeId = address.activationCodeId;
    final activationCode = activationCodeId == null
        ? null
        : ref.watch(activationCodeDetailProvider(activationCodeId));
    final commandState = ref.watch(activationCodeCommandProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Activation Code',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _DetailRow(
              label: 'Status',
              value: address.activationCodeStatusLabel,
            ),
            _DetailRow(
              label: 'Expires At',
              value: _dateTime(address.activationCodeExpiresAt),
            ),
            _DetailRow(
              label: 'Consumed At',
              value: _dateTime(address.activationCodeConsumedAt),
            ),
            _DetailRow(
              label: 'Reset Count',
              value: address.activationCodeResetCount?.toString() ?? '',
            ),
            const SizedBox(height: 16),
            if (commandState.hasError) ...[
              Text(
                commandState.error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: activationCodeId == null
                      ? null
                      : () => context.go('/admin/activation-codes/$activationCodeId'),
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('View Activation Code Details'),
                ),
                FilledButton.icon(
                  onPressed: activationCodeId != null || commandState.isLoading
                      ? null
                      : () => _openGenerateDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Generate Activation Code'),
                ),
                activationCode == null
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.restart_alt_outlined),
                        label: const Text('Reset Activation Code'),
                      )
                    : activationCode.when(
                        data: (code) => OutlinedButton.icon(
                          onPressed: commandState.isLoading
                              ? null
                              : () => _openResetDialog(context, ref, code),
                          icon: const Icon(Icons.restart_alt_outlined),
                          label: const Text('Reset Activation Code'),
                        ),
                        loading: () => OutlinedButton.icon(
                          onPressed: null,
                          icon: const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          label: const Text('Reset Activation Code'),
                        ),
                        error: (_, __) => OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.restart_alt_outlined),
                          label: const Text('Reset Activation Code'),
                        ),
                      ),
                OutlinedButton.icon(
                  onPressed: activationCodeId == null ||
                          commandState.isLoading ||
                          address.activationCodeStatus == 'revoked'
                      ? null
                      : () => _revoke(context, ref, activationCodeId),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Revoke Activation Code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGenerateDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GenerateActivationCodeDialog(
        initialAddressId: address.id,
      ),
    );

    if (result != null) {
      _refreshAddressViews(ref);
    }
  }

  Future<void> _openResetDialog(
    BuildContext context,
    WidgetRef ref,
    ActivationCode activationCode,
  ) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResetActivationCodeDialog(activationCode: activationCode),
    );

    if (result != null) {
      _refreshAddressViews(ref);
    }
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    String activationCodeId,
  ) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (_) => const _RevokeActivationCodeDialog(),
    );

    if (reason == null) {
      return;
    }

    final result = await ref.read(activationCodeCommandProvider.notifier).revokeCode(
          RevokeActivationCodeInput(
            activationCodeId: activationCodeId,
            reason: reason,
          ),
        );

    if (result != null) {
      _refreshAddressViews(ref);
    }
  }

  void _refreshAddressViews(WidgetRef ref) {
    ref.invalidate(addressDetailProvider(address.id));
    ref.invalidate(addressListProvider);
  }

  String _dateTime(DateTime? value) {
    return value?.toLocal().toString() ?? '';
  }
}

class _RevokeActivationCodeDialog extends StatefulWidget {
  const _RevokeActivationCodeDialog();

  @override
  State<_RevokeActivationCodeDialog> createState() =>
      _RevokeActivationCodeDialogState();
}

class _RevokeActivationCodeDialogState extends State<_RevokeActivationCodeDialog> {
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
