import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/resident_verification.dart';
import 'resident_verification_providers.dart';

class ResidentVerificationDetailPage extends ConsumerWidget {
  const ResidentVerificationDetailPage({
    required this.verificationId,
    super.key,
  });

  final String verificationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verification = ref.watch(
      residentVerificationDetailProvider(verificationId),
    );
    final commandState = ref.watch(residentVerificationCommandProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.go('/admin/resident-verification'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Resident Verification Detail',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(
                  residentVerificationDetailProvider(verificationId),
                ),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (commandState.hasError) ...[
            Text(
              commandState.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: verification.when(
              data: (item) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _VerificationDetailsCard(
                      item: item,
                      isBusy: commandState.isLoading,
                      onViewResident: () => _showResidentDialog(context, item),
                      onApprove: () => _approve(context, ref, item),
                      onReset: () => _reset(context, ref, item),
                      onDeactivate: () => _deactivate(context, ref, item),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: _VerificationHistoryCard(userId: item.userId),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load resident verification: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    ResidentVerification item,
  ) async {
    final confirmed = await _confirmApprovalWithOverageCheck(
      context: context,
      ref: ref,
      item: item,
    );

    if (!confirmed) {
      return;
    }

    await ref
        .read(residentVerificationCommandProvider.notifier)
        .approveVerification(item.id);
  }

  Future<bool> _confirmApprovalWithOverageCheck({
    required BuildContext context,
    required WidgetRef ref,
    required ResidentVerification item,
  }) async {
    ResidentApprovalImpact impact;
    try {
      impact = await ref
          .read(residentVerificationRepositoryProvider)
          .approvalImpact(item.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to calculate resident overage impact: $error'),
          ),
        );
      }
      return false;
    }

    if (!context.mounted) return false;

    if (impact.shouldWarn) {
      return _confirm(
        context: context,
        title: 'Resident overage may apply',
        message: _residentOverageMessage(impact),
        actionLabel: 'Approve Anyway',
      );
    }

    return _confirm(
      context: context,
      title: 'Approve Verification',
      message: 'Approve this resident verification and mark all factors verified?',
      actionLabel: 'Approve',
    );
  }

  Future<void> _reset(
    BuildContext context,
    WidgetRef ref,
    ResidentVerification item,
  ) async {
    final confirmed = await _confirm(
      context: context,
      title: 'Reset Verification',
      message: 'Reset this verification to pending and clear all verification factors?',
      actionLabel: 'Reset',
    );

    if (!confirmed) {
      return;
    }

    await ref
        .read(residentVerificationCommandProvider.notifier)
        .resetVerification(item.id);
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    ResidentVerification item,
  ) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (_) => const _DeactivateResidentDialog(),
    );

    if (reason == null) {
      return;
    }

    await ref.read(residentVerificationCommandProvider.notifier).deactivateResident(
          userId: item.userId,
          reason: reason,
          verificationId: item.id,
        );
  }

  Future<bool> _confirm({
    required BuildContext context,
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showResidentDialog(BuildContext context, ResidentVerification item) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resident Profile'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(label: 'Resident', value: item.residentLabel),
              _DetailRow(label: 'Email', value: item.residentEmail ?? ''),
              _DetailRow(label: 'Phone', value: item.residentPhone ?? ''),
              _DetailRow(label: 'Profile Status', value: item.residentStatus ?? ''),
              _DetailRow(label: 'User ID', value: item.userId),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

String _residentOverageMessage(ResidentApprovalImpact impact) {
  final limit = impact.residentLimit;
  final projectedMonthly = impact.projectedMonthlyOverageCents;
  final projectedAnnual = projectedMonthly * 12;

  return '${impact.tenantName} is using ${_formatCount(impact.currentResidentCount)} '
      'of ${_formatCount(limit ?? 0)} included residents for '
      '${impact.planName}.\n\n'
      'Approving this resident may add \$0.05/month to this tenant '
      'subscription. Projected resident overage: '
      '${_formatCount(impact.projectedOverageCount)} resident(s), estimated '
      '${_formatMoneyCents(projectedMonthly)}/month '
      '(${_formatMoneyCents(projectedAnnual)}/year).\n\n'
      'Billing is not automated yet, but this keeps approvals moving while '
      'making the cost clear.';
}

String _formatCount(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String _formatMoneyCents(int cents) {
  final amount = cents / 100;
  final precision = cents % 100 == 0 ? 0 : 2;
  return '\$${amount.toStringAsFixed(precision)}';
}

class _VerificationDetailsCard extends StatelessWidget {
  const _VerificationDetailsCard({
    required this.item,
    required this.isBusy,
    required this.onViewResident,
    required this.onApprove,
    required this.onReset,
    required this.onDeactivate,
  });

  final ResidentVerification item;
  final bool isBusy;
  final VoidCallback onViewResident;
  final VoidCallback onApprove;
  final VoidCallback onReset;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.residentLabel,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                _StatusPill(status: item.statusLabel),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onViewResident,
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('View Resident'),
                ),
                FilledButton.icon(
                  onPressed: isBusy || item.status == ResidentVerificationStatus.verified
                      ? null
                      : onApprove,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Approve Verification'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onReset,
                  icon: const Icon(Icons.restart_alt_outlined),
                  label: const Text('Reset Verification'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy || item.residentStatus == 'disabled'
                      ? null
                      : onDeactivate,
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Deactivate Resident'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailRow(label: 'Verification ID', value: item.id),
            _DetailRow(label: 'Resident Name', value: item.residentLabel),
            _DetailRow(label: 'Email', value: item.residentEmail ?? ''),
            _DetailRow(label: 'Profile Status', value: item.residentStatus ?? ''),
            _DetailRow(label: 'HOA', value: item.hoaLabel),
            _DetailRow(
              label: 'Address',
              value: item.addressLabel.isEmpty ? item.addressId ?? '' : item.addressLabel,
            ),
            _DetailRow(label: 'Address Verified', value: _yesNo(item.addressVerified)),
            _DetailRow(label: 'Email Verified', value: _yesNo(item.emailVerified)),
            _DetailRow(
              label: 'Activation Code Verified',
              value: _yesNo(item.activationCodeVerified),
            ),
            _DetailRow(label: 'Verification Status', value: item.statusLabel),
            _DetailRow(
              label: 'Verified At',
              value: item.verifiedAt?.toLocal().toString() ?? '',
            ),
            _DetailRow(label: 'Created', value: item.createdAt.toLocal().toString()),
            _DetailRow(label: 'Updated', value: item.updatedAt.toLocal().toString()),
          ],
        ),
      ),
    );
  }

  String _yesNo(bool value) => value ? 'Yes' : 'No';
}

class _VerificationHistoryCard extends ConsumerWidget {
  const _VerificationHistoryCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(residentVerificationHistoryProvider(userId));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Verification History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh history',
                  onPressed: () => ref.invalidate(
                    residentVerificationHistoryProvider(userId),
                  ),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: history.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Text('No address membership history found.');
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item.isCurrent
                              ? Icons.home_outlined
                              : Icons.history_outlined,
                        ),
                        title: Text(item.addressLabel.isEmpty
                            ? item.addressId
                            : item.addressLabel),
                        subtitle: Text(
                          [
                            item.hoaLabel,
                            '${item.occupancyType} · ${item.isCurrent ? 'Current' : 'Historical'}',
                            'Start: ${item.startDate.toLocal().toString().substring(0, 10)}',
                            if (item.endDate != null)
                              'End: ${item.endDate!.toLocal().toString().substring(0, 10)}',
                          ].join('\n'),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Unable to load history: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeactivateResidentDialog extends StatefulWidget {
  const _DeactivateResidentDialog();

  @override
  State<_DeactivateResidentDialog> createState() => _DeactivateResidentDialogState();
}

class _DeactivateResidentDialogState extends State<_DeactivateResidentDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Deactivate Resident'),
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
          icon: const Icon(Icons.person_off_outlined),
          label: const Text('Deactivate'),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          status,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
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
            width: 190,
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
