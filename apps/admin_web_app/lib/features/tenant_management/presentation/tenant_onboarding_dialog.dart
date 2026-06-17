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



class _BetaTrackingSection extends StatelessWidget {
  const _BetaTrackingSection({
    required this.betaStatus,
    required this.hoaDataStatus,
    required this.betaContactName,
    required this.betaContactEmail,
    required this.betaTargetLaunchDate,
    required this.knownIssues,
    required this.readyForHoaOnboarding,
    required this.onBetaStatusChanged,
    required this.onHoaDataStatusChanged,
    required this.onReadyForHoaOnboardingChanged,
  });

  final String betaStatus;
  final String hoaDataStatus;
  final TextEditingController betaContactName;
  final TextEditingController betaContactEmail;
  final TextEditingController betaTargetLaunchDate;
  final TextEditingController knownIssues;
  final bool readyForHoaOnboarding;
  final ValueChanged<String> onBetaStatusChanged;
  final ValueChanged<String> onHoaDataStatusChanged;
  final ValueChanged<bool> onReadyForHoaOnboardingChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Beta tracking',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final children = [
                  _BetaDropdown(
                    value: betaStatus,
                    label: 'Beta status',
                    items: const {
                      'not_started': 'Not Started',
                      'agreement_pending': 'Agreement Pending',
                      'configuring': 'Configuring',
                      'tenant_review': 'Tenant Review',
                      'active_beta': 'Active Beta',
                      'paused': 'Paused',
                      'completed': 'Completed',
                    },
                    onChanged: onBetaStatusChanged,
                  ),
                  _BetaDropdown(
                    value: hoaDataStatus,
                    label: 'HOA data status',
                    items: const {
                      'not_requested': 'Not Requested',
                      'requested': 'Requested',
                      'received': 'Received',
                      'importing': 'Importing',
                      'imported': 'Imported',
                      'needs_cleanup': 'Needs Cleanup',
                    },
                    onChanged: onHoaDataStatusChanged,
                  ),
                ];
                if (compact) {
                  return Column(
                    children: [
                      children[0],
                      const SizedBox(height: 12),
                      children[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 12),
                    Expanded(child: children[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
                final nameField = TextField(
                  controller: betaContactName,
                  decoration: const InputDecoration(labelText: 'Beta contact name'),
                );
                final emailField = TextField(
                  controller: betaContactEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Beta contact email'),
                );
                if (compact) {
                  return Column(
                    children: [
                      nameField,
                      const SizedBox(height: 12),
                      emailField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: nameField),
                    const SizedBox(width: 12),
                    Expanded(child: emailField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: betaTargetLaunchDate,
              decoration: const InputDecoration(
                labelText: 'Target beta launch date',
                helperText: 'Use YYYY-MM-DD, for example 2026-07-01.',
              ),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: readyForHoaOnboarding,
              onChanged: onReadyForHoaOnboardingChanged,
              title: const Text('Ready for HOA onboarding'),
              subtitle: const Text('Use this when we can start adding HOAs, addresses, and tenant staff.'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: knownIssues,
              decoration: const InputDecoration(labelText: 'Known beta issues'),
              minLines: 3,
              maxLines: 5,
            ),
          ],
        ),
      ),
    );
  }
}

class _BetaDropdown extends StatelessWidget {
  const _BetaDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final String label;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items.entries
          .map((entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              ))
          .toList(),
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }
}

DateTime? _parseDate(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) return null;
  return DateTime.tryParse(text);
}

String _dateText(DateTime? value) {
  if (value == null) return '';
  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class _TenantOnboardingDialogState extends ConsumerState<TenantOnboardingDialog> {
  late String _status;
  late String _betaStatus;
  late String _hoaDataStatus;
  late final TextEditingController _blockedReason;
  late final TextEditingController _notes;
  late final TextEditingController _betaContactName;
  late final TextEditingController _betaContactEmail;
  late final TextEditingController _betaTargetLaunchDate;
  late final TextEditingController _knownIssues;
  late bool _kickoffCompleted;
  late bool _launchReady;
  late bool _launched;
  late bool _readyForHoaOnboarding;

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
    _betaStatus = status?.betaStatus ?? 'not_started';
    _hoaDataStatus = status?.hoaDataStatus ?? 'not_requested';
    _blockedReason = TextEditingController(text: status?.blockedReason ?? '');
    _notes = TextEditingController(text: status?.notes ?? '');
    _betaContactName = TextEditingController(text: status?.betaContactName ?? '');
    _betaContactEmail = TextEditingController(text: status?.betaContactEmail ?? '');
    _betaTargetLaunchDate = TextEditingController(text: _dateText(status?.betaTargetLaunchDate));
    _knownIssues = TextEditingController(text: status?.knownIssues ?? '');
    _kickoffCompleted = status?.kickoffCompletedAt != null;
    _launchReady = status?.launchReadyAt != null || status?.status == 'ready_to_launch';
    _launched = status?.launchedAt != null || status?.status == 'launched';
    _readyForHoaOnboarding = status?.readyForHoaOnboarding ?? false;
  }

  @override
  void dispose() {
    _blockedReason.dispose();
    _notes.dispose();
    _betaContactName.dispose();
    _betaContactEmail.dispose();
    _betaTargetLaunchDate.dispose();
    _knownIssues.dispose();
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
              _BetaTrackingSection(
                betaStatus: _betaStatus,
                hoaDataStatus: _hoaDataStatus,
                betaContactName: _betaContactName,
                betaContactEmail: _betaContactEmail,
                betaTargetLaunchDate: _betaTargetLaunchDate,
                knownIssues: _knownIssues,
                readyForHoaOnboarding: _readyForHoaOnboarding,
                onBetaStatusChanged: (value) => setState(() => _betaStatus = value),
                onHoaDataStatusChanged: (value) => setState(() => _hoaDataStatus = value),
                onReadyForHoaOnboardingChanged: (value) => setState(() => _readyForHoaOnboarding = value),
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
            betaStatus: _betaStatus,
            betaContactName: _betaContactName.text,
            betaContactEmail: _betaContactEmail.text,
            betaTargetLaunchDate: _parseDate(_betaTargetLaunchDate.text),
            hoaDataStatus: _hoaDataStatus,
            knownIssues: _knownIssues.text,
            readyForHoaOnboarding: _readyForHoaOnboarding,
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
