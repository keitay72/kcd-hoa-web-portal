import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/subscriptions/tenant_entitlements.dart';
import '../../hoa_management/presentation/hoa_form_dialog.dart';
import '../../user_management/presentation/invite_user_dialog.dart';
import '../domain/tenant_management_models.dart';
import 'billing_contact_dialog.dart';
import 'tenant_email_settings_dialog.dart';
import 'tenant_form_dialog.dart';
import 'tenant_management_providers.dart';
import 'tenant_onboarding_dialog.dart';
import 'tenant_settings_dialog.dart';
import 'tenant_staff_assignment_dialog.dart';
import 'tenant_sms_settings_dialog.dart';
import 'tenant_subscription_dialog.dart';

class TenantDetailPage extends ConsumerWidget {
  const TenantDetailPage({required this.tenantId, super.key});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(tenantDetailProvider(tenantId));

    return detail.when(
      data: (tenantDetail) => _TenantDetailView(detail: tenantDetail),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Unable to load tenant: $error'),
      ),
    );
  }
}

typedef _TenantDialogHelper = Future<void> Function(
  BuildContext context,
  WidgetRef ref,
  Widget dialog,
);

Future<void> _openCreateHoaWithLimitGuard({
  required BuildContext context,
  required WidgetRef ref,
  required TenantDetail detail,
  required String title,
  required _TenantDialogHelper useDialogHelper,
}) async {
  if (!await _confirmHoaOverageAllowsCreate(context, detail)) return;
  await useDialogHelper(
    context,
    ref,
    HoaFormDialog(
      tenantId: detail.tenant.id,
      title: title,
    ),
  );
}

TenantSubscriptionEntitlements _entitlementsForDetail(TenantDetail detail) {
  final current = _currentSubscription(detail.subscriptions);
  return TenantSubscriptionEntitlements(
    planCode: current?.planCode,
    enabledAddonCodes: detail.enabledAddons
        .where((addon) => addon.status == 'enabled')
        .map((addon) => addon.addonCode)
        .toSet(),
  );
}

TenantEntitlementResult _brandingEntitlementFor(
  TenantSubscriptionEntitlements entitlements,
) {
  final customBranding =
      entitlements.entitlementFor(TenantFeature.customBranding);
  if (customBranding.isEnabled) return customBranding;
  return entitlements.entitlementFor(TenantFeature.whiteLabelBranding);
}

Future<bool> _confirmHoaOverageAllowsCreate(
    BuildContext context, TenantDetail detail) async {
  if (!detail.isHoaLimitReached) return true;

  final planName = detail.currentPlan?.name ?? 'the current plan';
  final projectedOverage = detail.projectedHoaOverageAfterCreate;
  final projectedMonthly = detail.projectedHoaOverageMonthlyCentsAfterCreate;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('HOA overage may apply'),
      content: Text(
        '${detail.tenant.name} is using ${detail.hoaCount} of '
        '${detail.hoaLimit} included HOA communities for $planName.\n\n'
        'Adding one more HOA may add \$10/month to this tenant subscription. '
        'Projected HOA overage: $projectedOverage HOA(s), estimated '
        '${_formatRecurringMoneyCents(projectedMonthly)}.\n\n'
        'Billing is not automated yet, but this keeps the tenant growth path open while making the cost clear.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _BetaTrackingCard extends ConsumerWidget {
  const _BetaTrackingCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = detail.onboardingStatus;
    final colorScheme = Theme.of(context).colorScheme;
    final knownIssues =
        _fallbackText(status?.knownIssues, 'No known beta issues recorded.');
    final notes =
        _fallbackText(status?.notes, 'No internal onboarding notes recorded.');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.assignment_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beta Notes / Internal Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track no-cost beta coordination, data readiness, and handoff notes for this tenant.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: status?.betaStatusLabel ?? 'Not Started',
                  isPositive: status?.betaStatus == 'active_beta' ||
                      status?.betaStatus == 'completed',
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _openOnboardingStatus(context, ref),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Update Notes'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth >= 900
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth >= 620
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _BetaStatusTile(
                      width: cardWidth,
                      label: 'Beta status',
                      value: status?.betaStatusLabel ?? 'Not Started',
                      icon: Icons.science_outlined,
                    ),
                    _BetaStatusTile(
                      width: cardWidth,
                      label: 'HOA data status',
                      value: status?.hoaDataStatusLabel ?? 'Not Requested',
                      icon: Icons.table_chart_outlined,
                    ),
                    _BetaStatusTile(
                      width: cardWidth,
                      label: 'Target launch',
                      value: _formatDate(status?.betaTargetLaunchDate),
                      icon: Icons.event_outlined,
                    ),
                    _BetaStatusTile(
                      width: cardWidth,
                      label: 'Beta contact',
                      value: _contactText(status),
                      icon: Icons.contact_mail_outlined,
                    ),
                    _BetaStatusTile(
                      width: cardWidth,
                      label: 'HOA onboarding',
                      value: status?.readyForHoaOnboarding == true
                          ? 'Ready'
                          : 'Not ready yet',
                      icon: status?.readyForHoaOnboarding == true
                          ? Icons.check_circle_outline
                          : Icons.pending_actions_outlined,
                    ),
                    _BetaStatusTile(
                      width: cardWidth,
                      label: 'Tenant phase',
                      value: detail.tenant.statusLabel,
                      icon: Icons.flag_outlined,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Known beta issues',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(knownIssues),
                  const SizedBox(height: 14),
                  Text('Internal notes',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(notes),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOnboardingStatus(
      BuildContext context, WidgetRef ref) async {
    await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TenantOnboardingDialog(
        tenantId: detail.tenant.id,
        detail: detail,
        status: detail.onboardingStatus,
      ),
    );
    ref.invalidate(tenantDetailProvider(detail.tenant.id));
    ref.invalidate(tenantListProvider);
  }
}

class _BetaStatusTile extends StatelessWidget {
  const _BetaStatusTile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
          color: colorScheme.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Tooltip(
                    message: value,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _contactText(TenantOnboardingStatus? status) {
  final name = status?.betaContactName?.trim();
  final email = status?.betaContactEmail?.trim();
  if ((name == null || name.isEmpty) && (email == null || email.isEmpty)) {
    return 'Not set';
  }
  if (name == null || name.isEmpty) return email!;
  if (email == null || email.isEmpty) return name;
  return '$name · $email';
}

String _fallbackText(String? value, String fallback) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return fallback;
  return text;
}

class _TenantUsageCard extends StatelessWidget {
  const _TenantUsageCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context) {
    final plan = detail.currentPlan;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.speed_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan Usage',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        plan == null
                            ? 'Assign a subscription plan to start tracking tenant limits.'
                            : '${plan.name} limits are used to guide tenant onboarding.',
                      ),
                    ],
                  ),
                ),
                if (plan != null) Chip(label: Text(plan.name)),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 760
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _UsageMeter(
                      width: width,
                      label: 'HOA Communities',
                      current: detail.hoaCount,
                      limit: detail.hoaLimit,
                      ratio: detail.hoaUsageRatio,
                      isWarning: detail.isHoaUsageWarning,
                      isAtLimit:
                          detail.isHoaLimitReached && !detail.isHoaOverLimit,
                      isOverLimit: detail.isHoaOverLimit,
                      overageCount: detail.hoaOverageCount,
                      overageMonthlyCents: detail.hoaOverageMonthlyCents,
                    ),
                    _UsageMeter(
                      width: width,
                      label: 'Active Residents',
                      current: detail.residentCount,
                      limit: detail.residentLimit,
                      ratio: detail.residentUsageRatio,
                      isWarning: detail.isResidentUsageWarning,
                      isAtLimit: detail.isResidentLimitReached &&
                          !detail.isResidentOverLimit,
                      isOverLimit: detail.isResidentOverLimit,
                      overageCount: detail.residentOverageCount,
                      overageMonthlyCents: detail.residentOverageMonthlyCents,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageMeter extends StatelessWidget {
  const _UsageMeter({
    required this.width,
    required this.label,
    required this.current,
    required this.limit,
    required this.ratio,
    required this.isWarning,
    required this.isAtLimit,
    required this.isOverLimit,
    required this.overageCount,
    required this.overageMonthlyCents,
  });

  final double width;
  final String label;
  final int current;
  final int? limit;
  final double? ratio;
  final bool isWarning;
  final bool isAtLimit;
  final bool isOverLimit;
  final int overageCount;
  final int overageMonthlyCents;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isOverLimit
        ? colorScheme.error
        : isWarning
            ? Colors.orange.shade700
            : colorScheme.primary;
    final limitText = limit == null ? 'Unlimited' : _formatCount(limit!);
    final valueText = limit == null
        ? '${_formatCount(current)} / Unlimited'
        : '${_formatCount(current)} / ${_formatCount(limit!)}';
    final progress = ratio == null ? 0.0 : ratio!.clamp(0.0, 1.0).toDouble();

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOverLimit || isWarning
                ? color.withOpacity(0.45)
                : colorScheme.outlineVariant,
          ),
          color: isOverLimit
              ? colorScheme.errorContainer.withOpacity(0.25)
              : isWarning
                  ? Colors.orange.withOpacity(0.10)
                  : colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                if (isOverLimit)
                  const Chip(label: Text('Over Included Limit'))
                else if (isAtLimit)
                  const Chip(label: Text('At Included Limit'))
                else if (isWarning)
                  const Chip(label: Text('Approaching Limit')),
              ],
            ),
            const SizedBox(height: 6),
            Text(valueText, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (limit == null)
              Text('Plan limit: $limitText',
                  style: Theme.of(context).textTheme.bodySmall)
            else ...[
              LinearProgressIndicator(
                value: progress,
                color: color,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 6),
              Text('Plan limit: $limitText',
                  style: Theme.of(context).textTheme.bodySmall),
              if (overageCount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Overage: ${_formatCount(overageCount)} · Estimated ' +
                      _formatRecurringMoneyCents(overageMonthlyCents),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
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

String _formatRecurringMoneyCents(int monthlyCents) {
  final annualCents = monthlyCents * 12;
  return '${_formatMoneyCents(monthlyCents)}/month '
      '(${_formatMoneyCents(annualCents)}/year)';
}

String _formatMoneyCents(int cents) {
  final amount = cents / 100;
  final precision = cents % 100 == 0 ? 0 : 2;
  return '\$${amount.toStringAsFixed(precision)}';
}

String _addonStatusLabel(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _TenantDetailView extends ConsumerWidget {
  const _TenantDetailView({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = detail.tenant;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                final titleBlock = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: 'Back to tenants',
                      onPressed: () => context.go('/admin/tenants'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant.name,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text(tenant.code)),
                              Chip(label: Text(tenant.statusLabel)),
                              if (tenant.isPrimary)
                                const Chip(label: Text('Primary tenant')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final editButton = FilledButton.icon(
                  onPressed: () => _openTenantDialog(context, ref, tenant),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Tenant'),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 12),
                      Align(
                          alignment: Alignment.centerRight, child: editButton),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 16),
                    editButton,
                  ],
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList.list(
            children: [
              _OnboardingCard(detail: detail),
              const SizedBox(height: 16),
              _LaunchReadinessCard(detail: detail),
              const SizedBox(height: 16),
              _BetaTenantPlaybookCard(detail: detail),
              const SizedBox(height: 16),
              _BetaTrackingCard(detail: detail),
              const SizedBox(height: 16),
              _TenantUsageCard(detail: detail),
              const SizedBox(height: 16),
              _TenantStaffCard(detail: detail),
              const SizedBox(height: 16),
              _TenantHoasCard(detail: detail),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth =
                      _tenantSummaryCardWidth(constraints.maxWidth);
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _SettingsCard(detail: detail, width: cardWidth),
                      _EmailSettingsCard(detail: detail, width: cardWidth),
                      _SmsSettingsCard(detail: detail, width: cardWidth),
                      _SubscriptionCard(detail: detail, width: cardWidth),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              _BillingContactsCard(detail: detail),
              const SizedBox(height: 16),
              _AddonsCard(detail: detail),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openTenantDialog(
    BuildContext context,
    WidgetRef ref,
    PlatformTenant tenant,
  ) async {
    await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TenantFormDialog(tenant: tenant),
    );
  }
}

class _LaunchReadinessCard extends ConsumerWidget {
  const _LaunchReadinessCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSubscription = _currentSubscription(detail.subscriptions);
    final billingReady = detail.billingContacts.isNotEmpty;
    final emailReady = detail.emailSettings == null ||
        detail.emailSettings!.provider == 'platform_managed' ||
        detail.emailSettings!.verificationStatus == 'verified';
    final tenantAdminReady = detail.tenantAdminCount > 0;
    final hoaReady = detail.hoaCount > 0;
    final launchReady = detail.onboardingStatus?.status == 'ready_to_launch' ||
        detail.onboardingStatus?.status == 'launched' ||
        detail.onboardingStatus?.launchReadyAt != null;
    final incompleteCount = [
      currentSubscription?.planId != null &&
          (currentSubscription?.priceId != null ||
              currentSubscription?.isFreeBeta == true),
      billingReady,
      emailReady,
      tenantAdminReady,
      hoaReady,
      launchReady,
    ].where((ready) => !ready).length;

    final colorScheme = Theme.of(context).colorScheme;
    final readyForLaunch = incompleteCount == 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  readyForLaunch
                      ? Icons.verified_outlined
                      : Icons.task_alt_outlined,
                  color: readyForLaunch ? colorScheme.primary : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Launch Readiness',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        readyForLaunch
                            ? 'This tenant has the core SaaS setup required for launch.'
                            : '$incompleteCount launch item(s) still need attention.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: readyForLaunch ? 'Ready' : 'Needs Setup',
                  isPositive: readyForLaunch,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = constraints.maxWidth >= 1040
                    ? (constraints.maxWidth - 30) / 3
                    : constraints.maxWidth >= 680
                        ? (constraints.maxWidth - 15) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 15,
                  runSpacing: 12,
                  children: [
                    _ReadinessTile(
                      width: tileWidth,
                      label: 'Subscription',
                      value:
                          currentSubscription?.planName ?? 'No plan assigned',
                      isReady: currentSubscription?.planId != null &&
                          (currentSubscription?.priceId != null ||
                              currentSubscription?.isFreeBeta == true),
                      actionLabel: currentSubscription == null
                          ? 'Assign Plan'
                          : 'Review Plan',
                      onPressed: () =>
                          _openSubscription(context, ref, currentSubscription),
                    ),
                    _ReadinessTile(
                      width: tileWidth,
                      label: 'Billing Contact',
                      value: billingReady
                          ? detail.billingContacts.first.email
                          : 'Missing billing contact',
                      isReady: billingReady,
                      actionLabel:
                          billingReady ? 'Review Contact' : 'Add Contact',
                      onPressed: () => _openBillingContact(context, ref),
                    ),
                    _ReadinessTile(
                      width: tileWidth,
                      label: 'Email Sender',
                      value: detail.emailSettings?.providerLabel ??
                          'Platform Managed',
                      isReady: emailReady,
                      actionLabel: 'Configure Email',
                      onPressed: () => _openEmailSettings(context, ref),
                    ),
                    _ReadinessTile(
                      width: tileWidth,
                      label: 'Tenant Staff',
                      value: tenantAdminReady
                          ? '${detail.tenantAdminCount} admin/manager role(s)'
                          : 'No tenant admin assigned',
                      isReady: tenantAdminReady,
                      actionLabel:
                          tenantAdminReady ? 'Manage Staff' : 'Invite Admin',
                      onPressed: () => _openTenantStaff(context, ref),
                    ),
                    _ReadinessTile(
                      width: tileWidth,
                      label: 'HOA Setup',
                      value: hoaReady
                          ? '${detail.hoaCount} HOA community record(s)'
                          : 'No HOA created',
                      isReady: hoaReady,
                      actionLabel: hoaReady ? 'View HOAs' : 'Create HOA',
                      onPressed: () => _openHoaSetup(context, ref),
                    ),
                    _ReadinessTile(
                      width: tileWidth,
                      label: 'Launch Status',
                      value:
                          detail.onboardingStatus?.statusLabel ?? 'Not Started',
                      isReady: launchReady,
                      actionLabel: launchReady ? 'Review Status' : 'Mark Ready',
                      onPressed: () => _openOnboardingStatus(context, ref),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubscription(
    BuildContext context,
    WidgetRef ref,
    TenantSubscriptionSummary? currentSubscription,
  ) async {
    await _showAndRefresh(
      context,
      ref,
      TenantSubscriptionDialog(
        tenantId: detail.tenant.id,
        availablePlans: detail.availablePlans,
        subscription: currentSubscription,
      ),
    );
  }

  Future<void> _openBillingContact(BuildContext context, WidgetRef ref) async {
    await _showAndRefresh(
      context,
      ref,
      BillingContactDialog(
        tenantId: detail.tenant.id,
        contact: detail.billingContacts.isEmpty
            ? null
            : detail.billingContacts.first,
      ),
    );
  }

  Future<void> _openEmailSettings(BuildContext context, WidgetRef ref) async {
    await _showAndRefresh(
      context,
      ref,
      TenantEmailSettingsDialog(
        tenantId: detail.tenant.id,
        settings: detail.emailSettings,
      ),
    );
  }

  Future<void> _openTenantStaff(BuildContext context, WidgetRef ref) async {
    if (detail.tenantAdminCount > 0) {
      await _showAndRefresh(
        context,
        ref,
        TenantStaffAssignmentDialog(detail: detail),
      );
      return;
    }

    await _showAndRefresh(
      context,
      ref,
      InviteUserDialog(
        title: 'Invite Tenant Admin',
        initialCategory: 'platform',
        initialRoleCode: 'tenant_admin',
        initialTenantId: detail.tenant.id,
        lockScope: true,
      ),
    );
  }

  Future<void> _openHoaSetup(BuildContext context, WidgetRef ref) async {
    if (detail.hoaCount > 0) {
      context.go('/admin/hoas');
      return;
    }

    await _openCreateHoaWithLimitGuard(
      context: context,
      ref: ref,
      detail: detail,
      title: 'Create First HOA for ${detail.tenant.name}',
      useDialogHelper: _showAndRefresh,
    );
  }

  Future<void> _openOnboardingStatus(
      BuildContext context, WidgetRef ref) async {
    await _showAndRefresh(
      context,
      ref,
      TenantOnboardingDialog(
        tenantId: detail.tenant.id,
        detail: detail,
        status: detail.onboardingStatus,
      ),
    );
  }

  Future<void> _showAndRefresh(
    BuildContext context,
    WidgetRef ref,
    Widget dialog,
  ) async {
    await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
    ref.invalidate(tenantDetailProvider(detail.tenant.id));
    ref.invalidate(tenantListProvider);
  }
}

String _betaUsageText(int current, int? limit) {
  if (limit == null) return '${_formatCount(current)} / Unlimited';
  return '${_formatCount(current)} / ${_formatCount(limit)}';
}

class _BetaTenantPlaybookCard extends ConsumerWidget {
  const _BetaTenantPlaybookCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = detail.currentSubscription;
    final plan = detail.currentPlan;
    final betaReady = subscription?.isFreeBeta == true && plan != null;
    final staffReady = detail.tenantAdminCount > 0;
    final hoaReady = detail.hoaCount > 0;
    final supportReady = detail.settings?.supportEmail != null ||
        detail.settings?.supportPhone != null;
    final emailReady = detail.emailSettings == null ||
        detail.emailSettings!.provider == 'platform_managed' ||
        detail.emailSettings!.verificationStatus == 'verified';
    final billingContactReady = detail.billingContacts.isNotEmpty;
    final usageIsUsefulForBeta = detail.hasHoaLimit || detail.hasResidentLimit;
    final launchSafeCount = [
      betaReady || subscription?.planId != null,
      staffReady,
      hoaReady,
      supportReady,
      emailReady,
    ].where((value) => value).length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.rocket_launch_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beta Launch Playbook',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$launchSafeCount of 5 launch basics are ready. Use this to keep beta tenants free while still testing real plan limits and feature access.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  label: betaReady ? 'Free Beta' : 'Setup Needed',
                  isPositive: betaReady,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = constraints.maxWidth >= 1040
                    ? (constraints.maxWidth - 30) / 3
                    : constraints.maxWidth >= 680
                        ? (constraints.maxWidth - 15) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 15,
                  runSpacing: 12,
                  children: [
                    _BetaPlaybookTile(
                      width: tileWidth,
                      label: 'Beta plan',
                      value: betaReady
                          ? '${plan!.name} · ${subscription!.billingModeLabel}'
                          : plan == null
                              ? 'Assign Starter, Professional, or Enterprise.'
                              : 'Switch billing mode to Free beta if this tenant is testing at no cost.',
                      isReady: betaReady,
                      icon: Icons.science_outlined,
                      actionLabel: 'Review subscription',
                      onPressed: () => _openSubscription(context, ref),
                    ),
                    _BetaPlaybookTile(
                      width: tileWidth,
                      label: 'Limit testing',
                      value: usageIsUsefulForBeta
                          ? 'HOAs ${_betaUsageText(detail.hoaCount, detail.hoaLimit)} · Residents ${_betaUsageText(detail.residentCount, detail.residentLimit)}'
                          : 'Enterprise/unlimited plan. Use Starter for MHD if we want to test overage behavior.',
                      isReady: usageIsUsefulForBeta,
                      icon: Icons.speed_outlined,
                    ),
                    _BetaPlaybookTile(
                      width: tileWidth,
                      label: 'Tenant staff',
                      value: staffReady
                          ? '${detail.tenantAdminCount} tenant admin/manager role(s) assigned.'
                          : 'Invite at least one tenant admin before handoff.',
                      isReady: staffReady,
                      icon: Icons.admin_panel_settings_outlined,
                      actionLabel: staffReady ? 'Manage staff' : 'Invite admin',
                      onPressed: () => _openTenantStaff(context, ref),
                    ),
                    _BetaPlaybookTile(
                      width: tileWidth,
                      label: 'First HOA',
                      value: hoaReady
                          ? '${detail.hoaCount} HOA community record(s) ready.'
                          : 'Create the first HOA before inviting HOA users or residents.',
                      isReady: hoaReady,
                      icon: Icons.home_work_outlined,
                      actionLabel: hoaReady ? 'View HOAs' : 'Create HOA',
                      onPressed: () => _openHoaSetup(context, ref),
                    ),
                    _BetaPlaybookTile(
                      width: tileWidth,
                      label: 'Support and email',
                      value: supportReady && emailReady
                          ? 'Support contact and email sender are ready enough for beta.'
                          : 'Set support contact and confirm email sender behavior before external users rely on it.',
                      isReady: supportReady && emailReady,
                      icon: Icons.contact_mail_outlined,
                      actionLabel:
                          supportReady ? 'Review email' : 'Edit support',
                      onPressed: supportReady
                          ? () => _openEmailSettings(context, ref)
                          : () => _openSettings(context, ref),
                    ),
                    _BetaPlaybookTile(
                      width: tileWidth,
                      label: 'Billing contact',
                      value: billingContactReady
                          ? detail.billingContacts.first.email
                          : 'Optional during free beta, but useful before conversion to paid.',
                      isReady: billingContactReady,
                      icon: Icons.receipt_long_outlined,
                      actionLabel: billingContactReady
                          ? 'Review contact'
                          : 'Add contact',
                      onPressed: () => _openBillingContact(context, ref),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubscription(BuildContext context, WidgetRef ref) async {
    await _showAndRefresh(
      context,
      ref,
      TenantSubscriptionDialog(
        tenantId: detail.tenant.id,
        availablePlans: detail.availablePlans,
        subscription: detail.currentSubscription,
      ),
    );
  }

  Future<void> _openTenantStaff(BuildContext context, WidgetRef ref) async {
    if (detail.tenantAdminCount > 0) {
      await _showAndRefresh(
          context, ref, TenantStaffAssignmentDialog(detail: detail));
      return;
    }

    await _showAndRefresh(
      context,
      ref,
      InviteUserDialog(
        title: 'Invite Tenant Admin',
        initialCategory: 'platform',
        initialRoleCode: 'tenant_admin',
        initialTenantId: detail.tenant.id,
        lockScope: true,
      ),
    );
  }

  Future<void> _openHoaSetup(BuildContext context, WidgetRef ref) async {
    if (detail.hoaCount > 0) {
      context.go('/admin/hoas');
      return;
    }

    await _openCreateHoaWithLimitGuard(
      context: context,
      ref: ref,
      detail: detail,
      title: 'Create First HOA for ${detail.tenant.name}',
      useDialogHelper: _showAndRefresh,
    );
  }

  Future<void> _openSettings(BuildContext context, WidgetRef ref) async {
    final entitlements = _entitlementsForDetail(detail);
    final branding = _brandingEntitlementFor(entitlements);
    final customDomain =
        entitlements.entitlementFor(TenantFeature.customDomain);
    await _showAndRefresh(
      context,
      ref,
      TenantSettingsDialog(
        tenantId: detail.tenant.id,
        settings: detail.settings,
        canManageBranding: branding.isEnabled,
        canManageCustomDomain: customDomain.isEnabled,
        brandingLockReason: branding.sourceLabel,
        customDomainLockReason: customDomain.sourceLabel,
      ),
    );
  }

  Future<void> _openEmailSettings(BuildContext context, WidgetRef ref) async {
    await _showAndRefresh(
      context,
      ref,
      TenantEmailSettingsDialog(
        tenantId: detail.tenant.id,
        settings: detail.emailSettings,
      ),
    );
  }

  Future<void> _openBillingContact(BuildContext context, WidgetRef ref) async {
    await _showAndRefresh(
      context,
      ref,
      BillingContactDialog(
        tenantId: detail.tenant.id,
        contact: detail.billingContacts.isEmpty
            ? null
            : detail.billingContacts.first,
      ),
    );
  }

  Future<void> _showAndRefresh(
    BuildContext context,
    WidgetRef ref,
    Widget dialog,
  ) async {
    await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
    ref.invalidate(tenantDetailProvider(detail.tenant.id));
    ref.invalidate(tenantListProvider);
  }
}

class _BetaPlaybookTile extends StatelessWidget {
  const _BetaPlaybookTile({
    required this.width,
    required this.label,
    required this.value,
    required this.isReady,
    required this.icon,
    this.actionLabel,
    this.onPressed,
  });

  final double width;
  final String label;
  final String value;
  final bool isReady;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isReady
                ? colorScheme.primary.withOpacity(0.35)
                : colorScheme.outlineVariant,
          ),
          color: isReady
              ? colorScheme.primaryContainer.withOpacity(0.18)
              : colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon,
                    size: 20,
                    color: isReady ? colorScheme.primary : colorScheme.outline),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.bodySmall),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onPressed,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadinessTile extends StatelessWidget {
  const _ReadinessTile({
    required this.width,
    required this.label,
    required this.value,
    required this.isReady,
    this.actionLabel,
    this.onPressed,
  });

  final double width;
  final String label;
  final String value;
  final bool isReady;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isReady
                ? colorScheme.primary.withOpacity(0.35)
                : colorScheme.outlineVariant,
          ),
          color: isReady
              ? colorScheme.primaryContainer.withOpacity(0.20)
              : colorScheme.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isReady
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              color: isReady ? colorScheme.primary : colorScheme.outline,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Tooltip(
                    message: value,
                    waitDuration: const Duration(milliseconds: 400),
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (actionLabel != null && onPressed != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onPressed,
                        child: Text(actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.isPositive});

  final String label;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isPositive
            ? colorScheme.primaryContainer.withOpacity(0.35)
            : colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color:
              isPositive ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _OnboardingCard extends ConsumerWidget {
  const _OnboardingCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = detail.onboardingStatus;
    final progressPercent = (detail.onboardingProgress * 100).round();
    final checklist = detail.onboardingChecklist;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tenant Onboarding',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${detail.onboardingCompletedCount}/${detail.onboardingTotalCount} complete · $progressPercent%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(status?.statusLabel ?? 'Not Started')),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _openOnboardingStatus(context, ref),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Update'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: detail.onboardingProgress),
            if (status?.blockedReason != null) ...[
              const SizedBox(height: 16),
              _WarningPanel(
                title: 'Blocked',
                message: status!.blockedReason!,
              ),
            ],
            if (status?.notes != null) ...[
              const SizedBox(height: 16),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(status!.notes!),
            ],
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth > 900
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth > 620
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: checklist
                      .map(
                        (item) => SizedBox(
                          width: cardWidth,
                          child: _ChecklistTile(
                            item: item,
                            onTap: () =>
                                _handleChecklistAction(context, ref, item),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleChecklistAction(
    BuildContext context,
    WidgetRef ref,
    OnboardingChecklistItem item,
  ) async {
    switch (item.action) {
      case 'edit_tenant':
        await _showAndRefresh(
          context,
          ref,
          TenantFormDialog(tenant: detail.tenant),
        );
        return;
      case 'subscription':
        await _showAndRefresh(
          context,
          ref,
          TenantSubscriptionDialog(
            tenantId: detail.tenant.id,
            availablePlans: detail.availablePlans,
            subscription: _currentSubscription(detail.subscriptions),
          ),
        );
        return;
      case 'billing_contact':
        await _showAndRefresh(
          context,
          ref,
          BillingContactDialog(
            tenantId: detail.tenant.id,
            contact: detail.billingContacts.isEmpty
                ? null
                : detail.billingContacts.first,
          ),
        );
        return;
      case 'settings':
        final entitlements = _entitlementsForDetail(detail);
        final branding = _brandingEntitlementFor(entitlements);
        final customDomain =
            entitlements.entitlementFor(TenantFeature.customDomain);
        await _showAndRefresh(
          context,
          ref,
          TenantSettingsDialog(
            tenantId: detail.tenant.id,
            settings: detail.settings,
            canManageBranding: branding.isEnabled,
            canManageCustomDomain: customDomain.isEnabled,
            brandingLockReason: branding.sourceLabel,
            customDomainLockReason: customDomain.sourceLabel,
          ),
        );
        return;
      case 'email_settings':
        await _showAndRefresh(
          context,
          ref,
          TenantEmailSettingsDialog(
            tenantId: detail.tenant.id,
            settings: detail.emailSettings,
          ),
        );
        return;
      case 'sms_settings':
        final smsEntitlement = _entitlementsForDetail(detail).entitlementFor(
          TenantFeature.smsNotifications,
        );
        if (!smsEntitlement.isEnabled) {
          _showFeatureLockedSnackBar(context, smsEntitlement);
          return;
        }
        await _showAndRefresh(
          context,
          ref,
          TenantSmsSettingsDialog(
            tenantId: detail.tenant.id,
            settings: detail.smsSettings,
          ),
        );
        return;
      case 'tenant_admin':
        if (detail.assignableUsers.isEmpty) {
          await _showAndRefresh(
            context,
            ref,
            InviteUserDialog(
              title: 'Invite Tenant Admin',
              initialCategory: 'platform',
              initialRoleCode: 'tenant_admin',
              initialTenantId: detail.tenant.id,
              lockScope: true,
            ),
          );
        } else {
          await _showAndRefresh(
            context,
            ref,
            TenantStaffAssignmentDialog(detail: detail),
          );
        }
        return;
      case 'first_hoa':
        if (detail.hoaCount > 0) {
          context.go('/admin/hoas');
          return;
        }
        await _openCreateHoaWithLimitGuard(
          context: context,
          ref: ref,
          detail: detail,
          title: 'Create First HOA',
          useDialogHelper: _showAndRefresh,
        );
        return;
      case 'onboarding_status':
        await _openOnboardingStatus(context, ref);
        return;
      default:
        return;
    }
  }

  Future<void> _openOnboardingStatus(
      BuildContext context, WidgetRef ref) async {
    await _showAndRefresh(
      context,
      ref,
      TenantOnboardingDialog(
        tenantId: detail.tenant.id,
        detail: detail,
        status: detail.onboardingStatus,
      ),
    );
  }

  Future<void> _showAndRefresh(
    BuildContext context,
    WidgetRef ref,
    Widget dialog,
  ) async {
    await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
    ref.invalidate(tenantDetailProvider(detail.tenant.id));
    ref.invalidate(tenantListProvider);
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.item, required this.onTap});

  final OnboardingChecklistItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = item.isComplete
        ? colorScheme.primary.withOpacity(0.35)
        : colorScheme.outlineVariant;
    final backgroundColor = item.isComplete
        ? colorScheme.primaryContainer.withOpacity(0.22)
        : colorScheme.surface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    item.isComplete
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: item.isComplete
                        ? colorScheme.primary
                        : colorScheme.outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: Icon(item.isComplete
                      ? Icons.visibility_outlined
                      : Icons.arrow_forward),
                  label: Text(item.actionLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningPanel extends StatelessWidget {
  const _WarningPanel({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.errorContainer.withOpacity(0.45),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _tenantSummaryCardWidth(double availableWidth) {
  if (availableWidth >= 1320) return (availableWidth - 32) / 3;
  if (availableWidth >= 760) return (availableWidth - 16) / 2;
  return availableWidth;
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({required this.detail, required this.width});

  final TenantDetail detail;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = detail.settings;
    final entitlements = _entitlementsForDetail(detail);
    final branding = _brandingEntitlementFor(entitlements);
    final customDomain =
        entitlements.entitlementFor(TenantFeature.customDomain);
    return _TenantCard(
      title: 'Branding & Support',
      icon: Icons.tune_outlined,
      width: width,
      action: TextButton.icon(
        onPressed: () =>
            _open(context, branding: branding, customDomain: customDomain),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
      children: [
        if (!branding.isEnabled) ...[
          _FeatureLockBanner(result: branding),
          const SizedBox(height: 10),
        ],
        if (!customDomain.isEnabled) ...[
          _FeatureLockBanner(result: customDomain),
          const SizedBox(height: 10),
        ],
        _InfoLine(
            label: 'Support email', value: settings?.supportEmail ?? 'Not set'),
        _InfoLine(
            label: 'Support phone', value: settings?.supportPhone ?? 'Not set'),
        _InfoLine(
            label: 'Portal hostname',
            value: settings?.portalHostname ?? 'Not set'),
        _InfoLine(
            label: 'From name', value: settings?.emailFromName ?? 'Not set'),
        _InfoLine(
            label: 'Reply-to', value: settings?.emailReplyTo ?? 'Not set'),
        _InfoLine(
            label: 'Timezone', value: settings?.timezone ?? 'America/Chicago'),
      ],
    );
  }

  Future<void> _open(
    BuildContext context, {
    required TenantEntitlementResult branding,
    required TenantEntitlementResult customDomain,
  }) {
    return showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TenantSettingsDialog(
        tenantId: detail.tenant.id,
        settings: detail.settings,
        canManageBranding: branding.isEnabled,
        canManageCustomDomain: customDomain.isEnabled,
        brandingLockReason: branding.sourceLabel,
        customDomainLockReason: customDomain.sourceLabel,
      ),
    );
  }
}

class _EmailSettingsCard extends StatelessWidget {
  const _EmailSettingsCard({required this.detail, required this.width});

  final TenantDetail detail;
  final double width;

  @override
  Widget build(BuildContext context) {
    final settings = detail.emailSettings;
    return _TenantCard(
      title: 'Email Configuration',
      icon: Icons.mark_email_read_outlined,
      width: width,
      action: TextButton.icon(
        onPressed: () => showDialog<Object?>(
          context: context,
          barrierDismissible: false,
          builder: (_) => TenantEmailSettingsDialog(
            tenantId: detail.tenant.id,
            settings: settings,
          ),
        ),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
      children: [
        _EmailReadinessBanner(settings: settings),
        const SizedBox(height: 10),
        _InfoLine(
            label: 'Provider',
            value: settings?.providerLabel ?? 'Platform Managed'),
        _InfoLine(
            label: 'Verification',
            value: settings?.verificationStatusLabel ?? 'Not Configured'),
        _InfoLine(
            label: 'Sender domain', value: settings?.senderDomain ?? 'Not set'),
        _InfoLine(
            label: 'Sender email', value: settings?.senderEmail ?? 'Not set'),
        _InfoLine(
            label: 'Reply-to', value: settings?.replyToEmail ?? 'Not set'),
      ],
    );
  }
}

class _EmailReadinessBanner extends StatelessWidget {
  const _EmailReadinessBanner({required this.settings});

  final TenantEmailSettings? settings;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlatformManaged =
        settings == null || settings!.provider == 'platform_managed';
    final isVerified = settings?.verificationStatus == 'verified';
    final isReady = isPlatformManaged || isVerified;
    final message = isPlatformManaged
        ? 'Platform sender is active. Tenant sender can be configured later.'
        : isVerified
            ? 'Tenant sender domain is verified.'
            : 'Tenant sender setup is required before launch.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isReady
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.errorContainer.withOpacity(0.35),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isReady ? Icons.check_circle_outline : Icons.warning_amber_outlined,
            color: isReady ? colorScheme.primary : colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _SmsSettingsCard extends StatelessWidget {
  const _SmsSettingsCard({required this.detail, required this.width});

  final TenantDetail detail;
  final double width;

  @override
  Widget build(BuildContext context) {
    final settings = detail.smsSettings;
    final addon = _smsAddon(detail);
    final status = settings?.status ?? 'disabled';
    final hasPhone = _hasText(settings?.sendingPhoneNumber);
    final hasMessagingService = _hasText(settings?.twilioMessagingServiceSid);
    final canSend = status == 'active' && hasPhone && hasMessagingService;
    final smsEntitlement = _entitlementsForDetail(detail).entitlementFor(
      TenantFeature.smsNotifications,
    );

    return _TenantCard(
      title: 'SMS Add-On',
      icon: Icons.sms_outlined,
      width: width,
      action: TextButton.icon(
        onPressed: smsEntitlement.isEnabled
            ? () => showDialog<Object?>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => TenantSmsSettingsDialog(
                    tenantId: detail.tenant.id,
                    settings: settings,
                  ),
                )
            : null,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Configure'),
      ),
      children: [
        if (!smsEntitlement.isEnabled) ...[
          _FeatureLockBanner(result: smsEntitlement),
          const SizedBox(height: 10),
        ],
        _SmsStatusBanner(
          status: status,
          canSend: canSend,
          addonStatus: addon?.status,
        ),
        const SizedBox(height: 12),
        _InfoLine(
            label: 'Provider', value: settings?.providerLabel ?? 'Twilio'),
        _InfoLine(
            label: 'SMS setting', value: settings?.statusLabel ?? 'Disabled'),
        _InfoLine(
            label: 'Add-on status', value: addon?.statusLabel ?? 'Disabled'),
        _InfoLine(
            label: 'Phone number',
            value: settings?.formattedSendingPhoneNumber ?? 'Not set'),
        _InfoLine(
            label: 'Message limit',
            value: settings?.monthlyMessageLimit?.toString() ?? 'Not set'),
        _InfoLine(
            label: 'Twilio subaccount',
            value: settings?.twilioSubaccountSid ?? 'Not set'),
        _InfoLine(
            label: 'Messaging service',
            value: settings?.twilioMessagingServiceSid ?? 'Not set'),
        const SizedBox(height: 8),
        _MiniChecklistRow(
            label: 'Tenant wants SMS',
            complete: status == 'pending' || status == 'active'),
        _MiniChecklistRow(label: 'Sending number assigned', complete: hasPhone),
        _MiniChecklistRow(
            label: 'Messaging service connected',
            complete: hasMessagingService),
      ],
    );
  }

  TenantAddonSummary? _smsAddon(TenantDetail detail) {
    for (final addon in detail.enabledAddons) {
      if (addon.addonCode == 'sms_notifications') return addon;
    }
    return null;
  }

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;
}

class _SmsStatusBanner extends StatelessWidget {
  const _SmsStatusBanner({
    required this.status,
    required this.canSend,
    required this.addonStatus,
  });

  final String status;
  final bool canSend;
  final String? addonStatus;

  String _statusLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPositive = canSend || status == 'pending';
    final message = switch (status) {
      'active' when canSend =>
        'SMS is active and ready for tenant notifications.',
      'active' =>
        'SMS is marked active but setup is incomplete. Confirm phone number and messaging service.',
      'pending' => 'Tenant wants SMS. Finish Twilio setup before launch.',
      'suspended' => 'SMS is suspended. Tenant messages should not be sent.',
      _ =>
        'SMS is disabled. Enable when the tenant approves the texting add-on.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isPositive
            ? colorScheme.primaryContainer.withOpacity(0.35)
            : colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            canSend ? Icons.check_circle_outline : Icons.sms_failed_outlined,
            color: canSend ? colorScheme.primary : null,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              addonStatus == null
                  ? message
                  : '$message Add-on: ${_statusLabel(addonStatus!)}.',
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChecklistRow extends StatelessWidget {
  const _MiniChecklistRow({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            complete
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: 18,
            color: complete ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _SubscriptionSetupBanner extends StatelessWidget {
  const _SubscriptionSetupBanner({
    required this.icon,
    required this.title,
    required this.message,
    this.isWarning = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isWarning ? colorScheme.error : colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
        color: isWarning
            ? colorScheme.errorContainer.withOpacity(0.25)
            : colorScheme.primaryContainer.withOpacity(0.25),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantAddonOverview extends StatelessWidget {
  const _TenantAddonOverview({
    required this.addons,
    required this.enabledAddons,
    required this.enterpriseIncluded,
  });

  final List<AddonCatalogEntry> addons;
  final List<TenantAddonSummary> enabledAddons;
  final bool enterpriseIncluded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add-Ons', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...addons.where((addon) => addon.isActive).map(
              (addon) => _AddonLine(
                addon: addon,
                enabledAddon: _enabledAddon(addon),
                enterpriseIncluded:
                    enterpriseIncluded && addon.code == 'api_access',
              ),
            ),
      ],
    );
  }

  TenantAddonSummary? _enabledAddon(AddonCatalogEntry addon) {
    for (final enabled in enabledAddons) {
      if (enabled.addonId == addon.id || enabled.addonCode == addon.code)
        return enabled;
    }
    return null;
  }
}

class _AddonLine extends StatelessWidget {
  const _AddonLine({
    required this.addon,
    required this.enterpriseIncluded,
    this.enabledAddon,
  });

  final AddonCatalogEntry addon;
  final TenantAddonSummary? enabledAddon;
  final bool enterpriseIncluded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = enabledAddon != null || enterpriseIncluded;
    final status = enterpriseIncluded
        ? 'Included'
        : enabledAddon?.statusLabel ?? 'Available';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            enabled ? Icons.check_circle_outline : Icons.add_circle_outline,
            size: 18,
            color: enabled ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(addon.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (addon.description != null)
                  Text(
                    addon.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Chip(
            label: Text(status),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _TenantBillingSummary extends StatelessWidget {
  const _TenantBillingSummary({
    required this.detail,
    required this.subscription,
    required this.plan,
  });

  final TenantDetail detail;
  final TenantSubscriptionSummary subscription;
  final SubscriptionPlanSummary? plan;

  @override
  Widget build(BuildContext context) {
    final estimate = _BillingEstimate.from(detail, subscription, plan);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Billing Estimate',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(label: Text(estimate.billingModeLabel)),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(label: 'Base plan', value: estimate.basePlanLabel),
          _InfoLine(label: 'Add-ons', value: estimate.addonLabel),
          _InfoLine(label: 'HOA overage', value: estimate.hoaOverageLabel),
          _InfoLine(
              label: 'Resident overage', value: estimate.residentOverageLabel),
          const Divider(height: 20),
          _InfoLine(
            label: 'Estimated monthly',
            value: _formatMoneyCents(estimate.monthlyTotalCents),
          ),
          _InfoLine(
            label: 'Estimated annualized',
            value: _formatMoneyCents(estimate.annualizedTotalCents),
          ),
          Text(
            'Estimate only. Stripe overage and add-on billing automation is not connected yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _BillingEstimate {
  const _BillingEstimate({
    required this.billingModeLabel,
    required this.basePlanLabel,
    required this.addonLabel,
    required this.hoaOverageLabel,
    required this.residentOverageLabel,
    required this.monthlyTotalCents,
    required this.annualizedTotalCents,
  });

  final String billingModeLabel;
  final String basePlanLabel;
  final String addonLabel;
  final String hoaOverageLabel;
  final String residentOverageLabel;
  final int monthlyTotalCents;
  final int annualizedTotalCents;

  factory _BillingEstimate.from(
    TenantDetail detail,
    TenantSubscriptionSummary subscription,
    SubscriptionPlanSummary? plan,
  ) {
    final baseCents = subscription.unitAmountCents ?? 0;
    final interval = subscription.billingInterval ?? 'monthly';
    final monthlyBaseCents =
        interval == 'annual' ? (baseCents / 12).round() : baseCents;
    final annualBaseCents = interval == 'annual' ? baseCents : baseCents * 12;
    final addonMonthlyCents = _enabledAddonMonthlyCents(detail, plan);
    final overageMonthlyCents =
        detail.hoaOverageMonthlyCents + detail.residentOverageMonthlyCents;
    final monthlyTotalCents =
        monthlyBaseCents + addonMonthlyCents + overageMonthlyCents;
    final annualizedTotalCents =
        annualBaseCents + ((addonMonthlyCents + overageMonthlyCents) * 12);

    return _BillingEstimate(
      billingModeLabel:
          interval == 'annual' ? 'Annual billing' : 'Monthly billing',
      basePlanLabel: _basePlanLabel(subscription, monthlyBaseCents),
      addonLabel: _addonLabel(detail, plan, addonMonthlyCents),
      hoaOverageLabel: detail.hoaOverageCount == 0
          ? 'None'
          : '${_formatCount(detail.hoaOverageCount)} x \$10 = '
              '${_formatMoneyCents(detail.hoaOverageMonthlyCents)}/month',
      residentOverageLabel: detail.residentOverageCount == 0
          ? 'None'
          : '${_formatCount(detail.residentOverageCount)} x \$0.05 = '
              '${_formatMoneyCents(detail.residentOverageMonthlyCents)}/month',
      monthlyTotalCents: monthlyTotalCents,
      annualizedTotalCents: annualizedTotalCents,
    );
  }

  static String _basePlanLabel(
    TenantSubscriptionSummary subscription,
    int monthlyBaseCents,
  ) {
    if (subscription.unitAmountCents == null ||
        subscription.billingInterval == null) {
      return 'No price assigned';
    }
    if (subscription.billingInterval == 'annual') {
      return '${subscription.priceLabel} '
          '(${_formatMoneyCents(monthlyBaseCents)}/month equivalent)';
    }
    return subscription.priceLabel;
  }

  static String _addonLabel(
    TenantDetail detail,
    SubscriptionPlanSummary? plan,
    int addonMonthlyCents,
  ) {
    final enabled = detail.enabledAddons.where(
      (addon) => _isBillableAddonStatus(addon.status),
    );
    if (enabled.isEmpty) {
      return plan?.code == 'enterprise' ? 'API Access included' : 'None';
    }

    final parts = enabled.map((addon) {
      final cents = _addonMonthlyPriceCents(addon.addonCode, plan?.code);
      if (cents == 0) return '${addon.addonName}: Included';
      return '${addon.addonName}: ${_formatMoneyCents(cents)}/month';
    }).join(', ');
    return addonMonthlyCents == 0
        ? parts
        : '$parts (${_formatMoneyCents(addonMonthlyCents)}/month)';
  }
}

int _enabledAddonMonthlyCents(
    TenantDetail detail, SubscriptionPlanSummary? plan) {
  return detail.enabledAddons
      .where((addon) => _isBillableAddonStatus(addon.status))
      .fold<int>(
        0,
        (total, addon) =>
            total + _addonMonthlyPriceCents(addon.addonCode, plan?.code),
      );
}

bool _isBillableAddonStatus(String status) {
  return const {'requested', 'enabled'}.contains(status);
}

int _addonMonthlyPriceCents(String code, String? planCode) {
  if (code == 'api_access' && planCode == 'enterprise') return 0;
  return switch (code) {
    'sms_notifications' => 4900,
    'white_label_branding' => 29900,
    'custom_domain' => 9900,
    'advertising_platform' => 9900,
    'api_access' => 0,
    _ => 0,
  };
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.detail, required this.width});

  final TenantDetail detail;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = _currentSubscription(detail.subscriptions);
    final selectedPlan = _planForSubscription(current);
    final selectedPrice = _priceForSubscription(selectedPlan, current);
    final isFreeBeta = current?.isFreeBeta ?? false;
    final stripeReady = selectedPrice?.hasStripePrice ?? false;
    final canCheckout = current != null && !isFreeBeta && stripeReady;

    return _TenantCard(
      title: 'Subscription',
      icon: Icons.credit_card_outlined,
      width: width,
      action: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: () => _openSubscriptionDialog(context, ref, current),
            icon: const Icon(Icons.edit_outlined),
            label: Text(current == null ? 'Assign' : 'Change'),
          ),
          TextButton.icon(
            onPressed: canCheckout
                ? () => _startCheckout(context, ref, current)
                : null,
            icon: const Icon(Icons.open_in_new_outlined),
            label: const Text('Checkout'),
          ),
          TextButton.icon(
            onPressed: current == null || isFreeBeta
                ? null
                : () => _syncStripe(context, ref, current),
            icon: const Icon(Icons.sync_outlined),
            label: const Text('Sync'),
          ),
        ],
      ),
      children: [
        if (current == null) ...[
          _SubscriptionSetupBanner(
            icon: Icons.credit_card_off_outlined,
            title: 'Billing Setup Required',
            message:
                'Assign Starter, Professional, or Enterprise before this tenant can move into beta or paid onboarding.',
            isWarning: true,
          ),
          const SizedBox(height: 12),
          _EmptyActionPanel(
            icon: Icons.workspace_premium_outlined,
            title: 'No subscription assigned',
            message:
                'Choose a plan and billing mode. Free beta can remain active while Stripe is still being configured.',
            actionLabel: 'Assign Plan',
            onPressed: () => _openSubscriptionDialog(context, ref, null),
          ),
        ] else ...[
          if (isFreeBeta) ...[
            _SubscriptionSetupBanner(
              icon: Icons.science_outlined,
              title: 'Free Beta Active',
              message:
                  'This tenant is not being charged. Plan limits, feature gates, and overage warnings still apply.',
            ),
            const SizedBox(height: 12),
          ] else if (!stripeReady) ...[
            _SubscriptionSetupBanner(
              icon: Icons.credit_card_off_outlined,
              title: 'Stripe Checkout Pending',
              message:
                  'The plan is assigned, but checkout stays disabled until this rate has a Stripe price ID.',
              isWarning: true,
            ),
            const SizedBox(height: 12),
          ],
          _InfoLine(label: 'Plan', value: current.planDisplayName),
          _InfoLine(
              label: 'Limits',
              value: selectedPlan?.limitLabel ?? 'Plan limits unavailable'),
          _InfoLine(label: 'Status', value: current.statusLabel),
          _InfoLine(label: 'Price', value: current.priceLabel),
          _InfoLine(label: 'Billing mode', value: current.billingModeLabel),
          if (current.isFreeBeta)
            _InfoLine(
                label: 'Free beta ends',
                value: _formatDate(current.freeBetaEndsAt)),
          if (current.billingNotes != null)
            _InfoLine(label: 'Billing notes', value: current.billingNotes!),
          _InfoLine(
              label: 'Current period ends',
              value: _formatDate(current.currentPeriodEnd)),
          _InfoLine(
              label: 'Trial ends', value: _formatDate(current.trialEndsAt)),
          const SizedBox(height: 12),
          _TenantBillingSummary(
            detail: detail,
            subscription: current,
            plan: selectedPlan,
          ),
          const Divider(height: 28),
          _FeatureAccessSummary(
            entitlements: _entitlementsForDetail(detail),
          ),
        ],
        if (detail.availableAddons.isNotEmpty) ...[
          const Divider(height: 28),
          _TenantAddonOverview(
            addons: detail.availableAddons,
            enabledAddons: detail.enabledAddons,
            enterpriseIncluded: selectedPlan?.code == 'enterprise',
          ),
        ],
      ],
    );
  }

  SubscriptionPlanSummary? _planForSubscription(
      TenantSubscriptionSummary? subscription) {
    if (subscription?.planId == null) return null;
    for (final plan in detail.availablePlans) {
      if (plan.id == subscription!.planId) return plan;
    }
    return null;
  }

  SubscriptionPriceSummary? _priceForSubscription(
    SubscriptionPlanSummary? plan,
    TenantSubscriptionSummary? subscription,
  ) {
    if (plan == null || subscription?.priceId == null) return null;
    for (final price in plan.prices) {
      if (price.id == subscription!.priceId) return price;
    }
    return null;
  }

  Future<void> _openSubscriptionDialog(
    BuildContext context,
    WidgetRef ref,
    TenantSubscriptionSummary? subscription,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TenantSubscriptionDialog(
        tenantId: detail.tenant.id,
        availablePlans: detail.availablePlans,
        subscription: subscription,
      ),
    );
    if (saved != true || !context.mounted) return;

    ref.invalidate(tenantDetailProvider(detail.tenant.id));
    ref.invalidate(tenantListProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          subscription == null
              ? 'Subscription plan assigned.'
              : 'Subscription plan updated.',
        ),
      ),
    );
  }

  Future<void> _startCheckout(
    BuildContext context,
    WidgetRef ref,
    TenantSubscriptionSummary subscription,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(tenantMutationControllerProvider.notifier)
        .createCheckoutSession(
          tenantId: detail.tenant.id,
          subscriptionId: subscription.id,
        );
    if (result == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Unable to start Stripe checkout.')));
      return;
    }
    if (!result.success || result.checkoutUrl == null) {
      messenger.showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }
    if (!context.mounted) return;
    await showDialog<Object?>(
      context: context,
      builder: (_) => _CheckoutUrlDialog(url: result.checkoutUrl!),
    );
  }

  Future<void> _syncStripe(
    BuildContext context,
    WidgetRef ref,
    TenantSubscriptionSummary subscription,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref
        .read(tenantMutationControllerProvider.notifier)
        .syncStripeSubscription(
          tenantId: detail.tenant.id,
          subscriptionId: subscription.id,
        );
    messenger.showSnackBar(
      SnackBar(
          content: Text(result?.message ?? 'Unable to sync Stripe status.')),
    );
  }
}

void _showFeatureLockedSnackBar(
  BuildContext context,
  TenantEntitlementResult result,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '${result.feature.label} is not available yet: ${result.sourceLabel}.',
      ),
    ),
  );
}

class _FeatureLockBanner extends StatelessWidget {
  const _FeatureLockBanner({required this.result});

  final TenantEntitlementResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${result.feature.label} is locked for this tenant. ${result.sourceLabel}.',
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureAccessSummary extends StatelessWidget {
  const _FeatureAccessSummary({required this.entitlements});

  final TenantSubscriptionEntitlements entitlements;

  @override
  Widget build(BuildContext context) {
    final features = [
      ...TenantSubscriptionEntitlements.customerPortalFeatures,
      ...TenantSubscriptionEntitlements.addonFeatures,
    ];
    final results = entitlements.resultsFor(features);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.fact_check_outlined, size: 20),
            const SizedBox(width: 8),
            Text('Feature Access',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 2 : 1;
            final itemWidth =
                (constraints.maxWidth - ((columns - 1) * 8)) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: results
                  .map(
                    (result) => SizedBox(
                      width: itemWidth,
                      child: _FeatureAccessChip(result: result),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _FeatureAccessChip extends StatelessWidget {
  const _FeatureAccessChip({required this.result});

  final TenantEntitlementResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.isEnabled ? Colors.green : theme.colorScheme.outline;

    return Tooltip(
      message: result.sourceLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: result.isEnabled
              ? Colors.green.withOpacity(0.08)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: color.withOpacity(result.isEnabled ? 0.35 : 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                result.isEnabled
                    ? Icons.check_circle_outline
                    : Icons.lock_outline,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.feature.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight:
                        result.isEnabled ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TenantSubscriptionSummary? _currentSubscription(
  List<TenantSubscriptionSummary> subscriptions,
) {
  const currentStatuses = {
    'trialing',
    'active',
    'past_due',
    'paused',
    'incomplete',
  };

  for (final subscription in subscriptions) {
    if (currentStatuses.contains(subscription.status)) {
      return subscription;
    }
  }

  return subscriptions.isEmpty ? null : subscriptions.first;
}

class _CheckoutUrlDialog extends StatelessWidget {
  const _CheckoutUrlDialog({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stripe Checkout URL'),
      content: SizedBox(
        width: 560,
        child: SelectableText(url),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checkout URL copied.')),
              );
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy URL'),
        ),
      ],
    );
  }
}

class _BillingContactsCard extends StatelessWidget {
  const _BillingContactsCard({required this.detail});

  final TenantDetail detail;

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
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Billing Contacts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showDialog<Object?>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        BillingContactDialog(tenantId: detail.tenant.id),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Contact'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.billingContacts.isEmpty)
              _EmptyActionPanel(
                icon: Icons.receipt_long_outlined,
                title: 'No billing contact yet',
                message:
                    'Add a billing contact before assigning paid subscription workflows.',
                actionLabel: 'Add Billing Contact',
                onPressed: () => showDialog<Object?>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      BillingContactDialog(tenantId: detail.tenant.id),
                ),
              )
            else
              ...detail.billingContacts.map(
                (contact) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(contact.name),
                  subtitle: Text([
                    contact.email,
                    if (contact.phone != null) contact.phone!,
                  ].join(' · ')),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (contact.isPrimary) const Chip(label: Text('Primary')),
                      IconButton(
                        tooltip: 'Edit contact',
                        onPressed: () => showDialog<Object?>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => BillingContactDialog(
                            tenantId: detail.tenant.id,
                            contact: contact,
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddonsCard extends ConsumerWidget {
  const _AddonsCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutation = ref.watch(tenantMutationControllerProvider);
    final plan = detail.currentPlan;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.extension_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add-On Management',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Request, enable, suspend, or disable tenant add-ons. Pricing is shown before billable add-ons are activated.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.availableAddons.isEmpty)
              const _EmptyActionPanel(
                icon: Icons.extension_off_outlined,
                title: 'No add-ons in the catalog',
                message:
                    'Add-on catalog setup can wait until Stripe products and tenant add-ons are finalized.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  return Column(
                    children: detail.availableAddons.map((addon) {
                      final enabled = detail.addonFor(addon.id);
                      final status = enabled?.status ?? 'disabled';
                      final monthlyCents =
                          _addonMonthlyPriceCents(addon.code, plan?.code);
                      final priceLabel = monthlyCents == 0
                          ? addon.code == 'api_access' &&
                                  plan?.code == 'enterprise'
                              ? 'Included with Enterprise'
                              : 'No monthly charge configured'
                          : '${_formatMoneyCents(monthlyCents)}/month';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AddonManagementTile(
                          addon: addon,
                          status: status,
                          priceLabel: priceLabel,
                          compact: compact,
                          isLoading: mutation.isLoading,
                          onStatusChanged: (value) => _updateAddonStatus(
                            context: context,
                            ref: ref,
                            addon: addon,
                            currentStatus: status,
                            newStatus: value,
                            monthlyCents: monthlyCents,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            if (mutation.hasError) ...[
              const SizedBox(height: 12),
              Text(
                'Unable to update add-on: ${mutation.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateAddonStatus({
    required BuildContext context,
    required WidgetRef ref,
    required AddonCatalogEntry addon,
    required String currentStatus,
    required String newStatus,
    required int monthlyCents,
  }) async {
    if (newStatus == currentStatus) return;

    final isBillable =
        monthlyCents > 0 && const {'requested', 'enabled'}.contains(newStatus);
    if (isBillable) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Confirm ${addon.name} add-on'),
          content: Text(
            'Changing ${addon.name} to ${_addonStatusLabel(newStatus)} may add '
            '${_formatMoneyCents(monthlyCents)}/month to ${detail.tenant.name}. '
            'Billing automation is still pending, but this records the approved add-on state.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final saved = await ref
        .read(tenantMutationControllerProvider.notifier)
        .setAddonStatus(
          tenantId: detail.tenant.id,
          addonId: addon.id,
          status: newStatus,
        );
    if (!context.mounted) return;

    if (saved) {
      ref.invalidate(tenantDetailProvider(detail.tenant.id));
      ref.invalidate(tenantListProvider);
      messenger.showSnackBar(
        SnackBar(
            content:
                Text('${addon.name} set to ${_addonStatusLabel(newStatus)}.')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to update ${addon.name}.')),
      );
    }
  }
}

class _AddonManagementTile extends StatelessWidget {
  const _AddonManagementTile({
    required this.addon,
    required this.status,
    required this.priceLabel,
    required this.compact,
    required this.isLoading,
    required this.onStatusChanged,
  });

  final AddonCatalogEntry addon;
  final String status;
  final String priceLabel;
  final bool compact;
  final bool isLoading;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusField = SizedBox(
      width: compact ? double.infinity : 210,
      child: DropdownButtonFormField<String>(
        value: status,
        decoration: const InputDecoration(labelText: 'Status'),
        items: const [
          DropdownMenuItem(value: 'requested', child: Text('Requested')),
          DropdownMenuItem(value: 'enabled', child: Text('Enabled')),
          DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
          DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
        ],
        onChanged: isLoading
            ? null
            : (value) {
                if (value == null) return;
                onStatusChanged(value);
              },
      ),
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                addon.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Chip(
              label: Text(_addonStatusLabel(status)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(addon.description ?? addon.code),
        const SizedBox(height: 6),
        Text(
          priceLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surface,
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.add_circle_outline),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 12),
                statusField,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.add_circle_outline),
                const SizedBox(width: 12),
                Expanded(child: details),
                const SizedBox(width: 16),
                statusField,
              ],
            ),
    );
  }
}

class _TenantHoasCard extends ConsumerWidget {
  const _TenantHoasCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.apartment_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tenant HOAs',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${detail.tenantHoas.length} HOA community record(s)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openCreateHoa(context, ref),
                  icon: const Icon(Icons.add_business_outlined),
                  label: Text(detail.tenantHoas.isEmpty
                      ? 'Create First HOA'
                      : 'Add HOA'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.tenantHoas.isEmpty)
              _EmptyActionPanel(
                icon: Icons.home_work_outlined,
                title: 'No HOA communities yet',
                message:
                    'Create the first HOA community so this tenant can start onboarding addresses and residents.',
                actionLabel: 'Create First HOA',
                onPressed: () => _openCreateHoa(context, ref),
              )
            else
              ...detail.tenantHoas.map(
                (hoa) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Icon(hoa.isActive
                        ? Icons.home_work_outlined
                        : Icons.home_work),
                  ),
                  title: Text(hoa.name),
                  subtitle: Text('${hoa.code} · ${hoa.statusLabel}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/admin/hoas/${hoa.id}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateHoa(BuildContext context, WidgetRef ref) async {
    if (!await _confirmHoaOverageAllowsCreate(context, detail)) return;
    final created = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HoaFormDialog(
        tenantId: detail.tenant.id,
        title: detail.tenantHoas.isEmpty
            ? 'Create First HOA for ${detail.tenant.name}'
            : 'Add HOA for ${detail.tenant.name}',
      ),
    );
    if (created == null || !context.mounted) return;

    ref.invalidate(tenantDetailProvider(detail.tenant.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('HOA community created.')),
    );
  }
}

class _TenantStaffCard extends ConsumerWidget {
  const _TenantStaffCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutation = ref.watch(tenantMutationControllerProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.admin_panel_settings_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tenant Staff',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: mutation.isLoading
                          ? null
                          : () => _openInviteTenantAdmin(context, ref),
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('Invite Admin'),
                    ),
                    TextButton.icon(
                      onPressed: mutation.isLoading
                          ? null
                          : () => showDialog<Object?>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) =>
                                    TenantStaffAssignmentDialog(detail: detail),
                              ),
                      icon: const Icon(Icons.person_add_alt_outlined),
                      label: const Text('Assign Staff'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.tenantStaff.isEmpty)
              _EmptyActionPanel(
                icon: Icons.admin_panel_settings_outlined,
                title: 'No tenant staff assigned',
                message:
                    'Invite or assign a tenant admin before launch so the customer has an owner.',
                actionLabel: 'Invite Tenant Admin',
                onPressed: () => _openInviteTenantAdmin(context, ref),
              )
            else
              ...detail.tenantStaff.map(
                (staff) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(staff.displayName),
                  subtitle: Tooltip(
                    message: [
                      staff.email,
                      staff.roleName,
                      staff.statusLabel,
                    ].join('\n'),
                    waitDuration: const Duration(milliseconds: 400),
                    child: Text(
                      [staff.email, staff.roleName, staff.statusLabel]
                          .join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove tenant role',
                    onPressed: mutation.isLoading
                        ? null
                        : () => _confirmRemove(context, ref, staff),
                    icon: const Icon(Icons.person_remove_outlined),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInviteTenantAdmin(
      BuildContext context, WidgetRef ref) async {
    final invited = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => InviteUserDialog(
        title: 'Invite Tenant Admin',
        initialCategory: 'platform',
        initialRoleCode: 'tenant_admin',
        initialTenantId: detail.tenant.id,
        lockScope: true,
      ),
    );
    if (invited != true || !context.mounted) return;

    ref.invalidate(tenantDetailProvider(detail.tenant.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tenant admin invitation sent.')),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    TenantStaffAssignment staff,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Tenant Role?'),
        content: Text('Remove ${staff.roleName} from ${staff.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final removed = await ref
        .read(tenantMutationControllerProvider.notifier)
        .removeTenantStaff(staff);
    if (!context.mounted) return;
    if (removed) {
      messenger.showSnackBar(
        SnackBar(
            content:
                Text('Removed ${staff.roleName} from ${staff.displayName}.')),
      );
    }
  }
}

class _EmptyActionPanel extends StatelessWidget {
  const _EmptyActionPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(message),
                if (actionLabel != null && onPressed != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: onPressed,
                      icon: const Icon(Icons.arrow_forward_outlined),
                      label: Text(actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.title,
    required this.icon,
    required this.children,
    this.action,
    this.width = 420,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? action;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final titleRow = Row(
                    children: [
                      Icon(icon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  );

                  final actionWidget = action;
                  if (actionWidget == null) return titleRow;
                  if (constraints.maxWidth < 360) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleRow,
                        const SizedBox(height: 8),
                        Align(
                            alignment: Alignment.centerRight,
                            child: actionWidget),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleRow),
                      const SizedBox(width: 8),
                      Flexible(
                          child: Align(
                              alignment: Alignment.centerRight,
                              child: actionWidget)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Tooltip(
              message: value,
              waitDuration: const Duration(milliseconds: 400),
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Not set';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month/$day/${local.year}';
}
