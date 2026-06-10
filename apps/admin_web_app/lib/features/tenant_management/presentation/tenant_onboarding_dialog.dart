import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';
import 'tenant_management_providers.dart';

class TenantOnboardingDialog extends ConsumerStatefulWidget {
  const TenantOnboardingDialog({
    required this.tenantId,
    this.status,
    super.key,
  });

  final String tenantId;
  final TenantOnboardingStatus? status;

  @override
  ConsumerState<TenantOnboardingDialog> createState() => _TenantOnboardingDialogState();
}

class _TenantOnboardingDialogState extends ConsumerState<TenantOnboardingDialog> {
  late String _status;
  late final TextEditingController _blockedReason;
  late final TextEditingController _notes;
  late bool _kickoffCompleted;
  late bool _launchReady;
  late bool _launched;

  @override
  void initState() {
    super.initState();
    final status = widget.status;
    _status = status?.status ?? 'not_started';
    _blockedReason = TextEditingController(text: status?.blockedReason ?? '');
    _notes = TextEditingController(text: status?.notes ?? '');
    _kickoffCompleted = status?.kickoffCompletedAt != null;
    _launchReady = status?.launchReadyAt != null || status?.status == 'ready_to_launch';
    _launched = status?.launchedAt != null || status?.status == 'launched';
  }

  @override
  void dispose() {
    _blockedReason.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantMutationControllerProvider);

    return AlertDialog(
      title: const Text('Tenant Onboarding'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Onboarding status'),
                items: const [
                  DropdownMenuItem(value: 'not_started', child: Text('Not Started')),
                  DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                  DropdownMenuItem(value: 'ready_to_launch', child: Text('Ready to Launch')),
                  DropdownMenuItem(value: 'launched', child: Text('Launched')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (value) => setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _kickoffCompleted,
                onChanged: (value) => setState(() => _kickoffCompleted = value),
                title: const Text('Kickoff completed'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _launchReady,
                onChanged: (value) => setState(() => _launchReady = value),
                title: const Text('Ready to launch'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _launched,
                onChanged: (value) => setState(() => _launched = value),
                title: const Text('Launched'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _blockedReason,
                decoration: const InputDecoration(
                  labelText: 'Blocked reason',
                  helperText: 'Use when status is blocked or there is a known dependency.',
                ),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Onboarding notes'),
                minLines: 4,
                maxLines: 6,
              ),
              if (state.hasError) ...[
                const SizedBox(height: 16),
                Text(
                  'Unable to save onboarding status: ${state.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: state.isLoading ? null : _submit,
          child: const Text('Save Onboarding'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final existing = widget.status;
    final now = DateTime.now();
    final ok = await ref.read(tenantMutationControllerProvider.notifier).saveOnboardingStatus(
          tenantId: widget.tenantId,
          input: TenantOnboardingInput(
            status: _status,
            blockedReason: _blockedReason.text,
            notes: _notes.text,
            kickoffCompletedAt: _kickoffCompleted
                ? existing?.kickoffCompletedAt ?? now
                : null,
            launchReadyAt: _launchReady
                ? existing?.launchReadyAt ?? now
                : null,
            launchedAt: _launched
                ? existing?.launchedAt ?? now
                : null,
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}
