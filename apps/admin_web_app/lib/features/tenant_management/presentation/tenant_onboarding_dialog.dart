import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';
import 'tenant_management_providers.dart';

class TenantOnboardingDialog extends ConsumerStatefulWidget {
  const TenantOnboardingDialog({
    required this.tenantId,
    required this.detail,
    this.status,
    super.key,
  });

  final String tenantId;
  final TenantDetail detail;
  final TenantOnboardingStatus? status;

  @override
  ConsumerState<TenantOnboardingDialog> createState() => _TenantOnboardingDialogState();
}


class _LaunchReadinessPanel extends StatelessWidget {
  const _LaunchReadinessPanel({required this.blockers});

  final List<OnboardingChecklistItem> blockers;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReady = blockers.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isReady
            ? colorScheme.primaryContainer.withOpacity(0.28)
            : colorScheme.errorContainer.withOpacity(0.35),
        border: Border.all(
          color: isReady
              ? colorScheme.primary.withOpacity(0.25)
              : colorScheme.error.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReady ? Icons.check_circle_outline : Icons.lock_outline,
                color: isReady ? colorScheme.primary : colorScheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isReady ? 'Ready to launch' : 'Launch readiness blockers',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isReady)
            const Text('All required onboarding items are complete. This tenant can be marked ready to launch.')
          else ...[
            const Text('Complete these required items before marking this tenant ready to launch:'),
            const SizedBox(height: 8),
            ...blockers.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text('${item.label}: ${item.description}'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _TenantOnboardingDialogState extends ConsumerState<TenantOnboardingDialog> {
  late String _status;
  late final TextEditingController _blockedReason;
  late final TextEditingController _notes;
  late bool _kickoffCompleted;
  late bool _launchReady;
  late bool _launched;

  List<OnboardingChecklistItem> get _launchBlockers {
    return widget.detail.onboardingChecklist
        .where((item) => item.action != 'onboarding_status' && !item.isComplete)
        .toList();
  }

  bool get _canMarkLaunchReady => _launchBlockers.isEmpty;
  bool get _isLaunchState => _status == 'ready_to_launch' || _status == 'launched';

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
                items: [
                  const DropdownMenuItem(value: 'not_started', child: Text('Not Started')),
                  const DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                  const DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                  DropdownMenuItem(
                    value: 'ready_to_launch',
                    enabled: _canMarkLaunchReady,
                    child: const Text('Ready to Launch'),
                  ),
                  DropdownMenuItem(
                    value: 'launched',
                    enabled: _canMarkLaunchReady,
                    child: const Text('Launched'),
                  ),
                  const DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _status = value;
                    if (value == 'ready_to_launch') _launchReady = true;
                    if (value == 'launched') {
                      _launchReady = true;
                      _launched = true;
                    }
                    if (value != 'ready_to_launch' && value != 'launched') {
                      _launched = false;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              _LaunchReadinessPanel(blockers: _launchBlockers),
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
                onChanged: _canMarkLaunchReady
                    ? (value) => setState(() {
                          _launchReady = value;
                          if (!value && _status == 'ready_to_launch') {
                            _status = 'in_progress';
                          }
                        })
                    : null,
                title: const Text('Ready to launch'),
                subtitle: _canMarkLaunchReady
                    ? null
                    : const Text('Complete required launch items first.'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _launched,
                onChanged: _canMarkLaunchReady
                    ? (value) => setState(() {
                          _launched = value;
                          if (value) {
                            _launchReady = true;
                            _status = 'launched';
                          } else if (_status == 'launched') {
                            _status = _launchReady ? 'ready_to_launch' : 'in_progress';
                          }
                        })
                    : null,
                title: const Text('Launched'),
                subtitle: _canMarkLaunchReady
                    ? null
                    : const Text('Launch is locked until required setup is complete.'),
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
          onPressed: state.isLoading || (_isLaunchState && !_canMarkLaunchReady)
              ? null
              : _submit,
          child: const Text('Save Onboarding'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final existing = widget.status;
    final now = DateTime.now();
    final effectiveLaunchReady = _canMarkLaunchReady &&
        (_launchReady || _status == 'ready_to_launch' || _status == 'launched');
    final effectiveLaunched = _canMarkLaunchReady &&
        (_launched || _status == 'launched');
    final ok = await ref.read(tenantMutationControllerProvider.notifier).saveOnboardingStatus(
          tenantId: widget.tenantId,
          input: TenantOnboardingInput(
            status: _status,
            blockedReason: _blockedReason.text,
            notes: _notes.text,
            kickoffCompletedAt: _kickoffCompleted
                ? existing?.kickoffCompletedAt ?? now
                : null,
            launchReadyAt: effectiveLaunchReady
                ? existing?.launchReadyAt ?? now
                : null,
            launchedAt: effectiveLaunched
                ? existing?.launchedAt ?? now
                : null,
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}
