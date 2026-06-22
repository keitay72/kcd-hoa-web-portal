import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/tenant_management_models.dart';
import 'tenant_form_dialog.dart';
import 'tenant_management_providers.dart';

class TenantListPage extends ConsumerStatefulWidget {
  const TenantListPage({super.key});

  @override
  ConsumerState<TenantListPage> createState() => _TenantListPageState();
}

class _TenantListPageState extends ConsumerState<TenantListPage> {
  final _searchController = TextEditingController();
  String? _status;
  String? _readiness;
  String? _subscriptionHealth;
  String? _billingReadiness;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenants = ref.watch(tenantListProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Platform Tenants',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(tenantListProvider),
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _openCreateDialog(context),
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Create Tenant'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TenantFilters(
            searchController: _searchController,
            status: _status,
            readiness: _readiness,
            subscriptionHealth: _subscriptionHealth,
            billingReadiness: _billingReadiness,
            onStatusChanged: (value) => setState(() => _status = value),
            onReadinessChanged: (value) => setState(() => _readiness = value),
            onSubscriptionHealthChanged: (value) =>
                setState(() => _subscriptionHealth = value),
            onBillingReadinessChanged: (value) =>
                setState(() => _billingReadiness = value),
            onApply: _applyFilters,
            onReset: _resetFilters,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: tenants.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                      child: Text('No platform tenants found.'));
                }
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final tenant = items[index];
                      return _TenantListItem(tenant: tenant);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load platform tenants: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    ref.read(tenantListFiltersProvider.notifier).state = TenantListFilters(
      search: _searchController.text,
      status: _status,
      readiness: _readiness,
      subscriptionHealth: _subscriptionHealth,
      billingReadiness: _billingReadiness,
    );
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _status = null;
      _readiness = null;
      _subscriptionHealth = null;
      _billingReadiness = null;
    });
    ref.read(tenantListFiltersProvider.notifier).state =
        const TenantListFilters();
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final tenant = await showDialog<PlatformTenant?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TenantFormDialog(),
    );
    if (tenant != null && mounted) {
      context.go('/admin/tenants/${tenant.id}');
    }
  }
}

class _TenantListItem extends StatelessWidget {
  const _TenantListItem({required this.tenant});

  final PlatformTenant tenant;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.go('/admin/tenants/${tenant.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: tenant.isPrimary
                  ? colorScheme.primaryContainer
                  : colorScheme.secondaryContainer,
              foregroundColor: tenant.isPrimary
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSecondaryContainer,
              child: Icon(
                tenant.isPrimary
                    ? Icons.verified_outlined
                    : Icons.business_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TenantHeader(tenant: tenant),
                  const SizedBox(height: 6),
                  _TenantSubtitle(tenant: tenant),
                  const SizedBox(height: 12),
                  _TenantMetricsWrap(tenant: tenant),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right, color: colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

class _TenantHeader extends StatelessWidget {
  const _TenantHeader({required this.tenant});

  final PlatformTenant tenant;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          tenant.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        _MiniStatusPill(label: tenant.statusLabel),
        if (tenant.isPrimary) const _MiniStatusPill(label: 'Primary'),
        if (tenant.isFreeBeta)
          _MiniStatusPill(
            label: tenant.betaStatus == 'active_beta'
                ? 'Active Beta'
                : 'Free Beta',
            icon: Icons.science_outlined,
          ),
        if (tenant.readyForHoaOnboarding)
          const _MiniStatusPill(
            label: 'HOA Ready',
            icon: Icons.check_circle_outline,
          ),
      ],
    );
  }
}

class _TenantSubtitle extends StatelessWidget {
  const _TenantSubtitle({required this.tenant});

  final PlatformTenant tenant;

  @override
  Widget build(BuildContext context) {
    final details = [
      tenant.code,
      'Onboarding: ${tenant.onboardingStatusLabel}',
      if (tenant.isFreeBeta) 'Beta: ${tenant.betaStatusLabel}',
      'Plan: ${tenant.subscriptionPlanName ?? tenant.subscriptionStatusLabel}',
      if (tenant.isFreeBeta) 'HOA data: ${tenant.hoaDataStatusLabel}',
    ];
    if (tenant.onboardingBlockedReason != null) {
      details.add('Blocked: ${tenant.onboardingBlockedReason}');
    }

    return Tooltip(
      message: details.join('\n'),
      waitDuration: const Duration(milliseconds: 400),
      child: Text(
        details.join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _TenantMetricsWrap extends StatelessWidget {
  const _TenantMetricsWrap({required this.tenant});

  final PlatformTenant tenant;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ReadinessChip(tenant: tenant),
        if (tenant.isFreeBeta)
          _CompactInfoChip(
            icon: tenant.readyForHoaOnboarding
                ? Icons.check_circle_outline
                : Icons.science_outlined,
            label: tenant.readyForHoaOnboarding
                ? 'HOA onboarding ready'
                : 'Beta ${tenant.betaStatusLabel}',
            isReady: tenant.readyForHoaOnboarding ||
                tenant.betaStatus == 'active_beta',
            warning: tenant.betaStatus == 'configuring' ||
                tenant.betaStatus == 'tenant_review',
          ),
        if (tenant.isFreeBeta)
          _CompactInfoChip(
            icon: Icons.table_chart_outlined,
            label: 'Data ${tenant.hoaDataStatusLabel}',
            isReady: tenant.hoaDataStatus == 'imported',
            warning: tenant.hoaDataStatus == 'requested' ||
                tenant.hoaDataStatus == 'received' ||
                tenant.hoaDataStatus == 'importing',
            isError: tenant.hoaDataStatus == 'needs_cleanup',
          ),
        _CompactInfoChip(
          icon: Icons.credit_card_outlined,
          label: tenant.subscriptionPlanName ?? tenant.subscriptionStatusLabel,
          isReady: tenant.hasSubscription && !tenant.hasStripePending,
          warning: tenant.hasStripePending,
        ),
        _CompactInfoChip(
          icon: Icons.home_work_outlined,
          label: 'HOAs ${_usageText(tenant.hoaCount, tenant.includedHoaCount)}',
          isReady: !tenant.isHoaOverIncluded,
          warning: tenant.isHoaApproachingLimit,
          isError: tenant.isHoaOverIncluded,
        ),
        _CompactInfoChip(
          icon: Icons.groups_outlined,
          label:
              'Residents ${_usageText(tenant.residentCount, tenant.includedResidentCount)}',
          isReady: !tenant.isResidentOverIncluded,
          warning: tenant.isResidentApproachingLimit,
          isError: tenant.isResidentOverIncluded,
        ),
        _CompactInfoChip(
          icon: Icons.admin_panel_settings_outlined,
          label: '${tenant.tenantAdminCount} staff',
          isReady: tenant.hasTenantAdmin,
        ),
        _CompactInfoChip(
          icon: Icons.receipt_long_outlined,
          label: '${tenant.billingContactCount} billing contacts',
          isReady: tenant.hasBillingContact,
        ),
      ],
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessChip extends StatelessWidget {
  const _ReadinessChip({required this.tenant});

  final PlatformTenant tenant;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = tenant.isLaunched
        ? 'Launched'
        : tenant.isLaunchReady
            ? 'Ready'
            : tenant.isOnboardingBlocked
                ? 'Blocked'
                : 'Needs Setup';
    final backgroundColor = tenant.isLaunched
        ? colorScheme.primaryContainer
        : tenant.isLaunchReady
            ? colorScheme.tertiaryContainer
            : tenant.isOnboardingBlocked
                ? colorScheme.errorContainer
                : colorScheme.surfaceVariant;
    final foregroundColor = tenant.isLaunched
        ? colorScheme.onPrimaryContainer
        : tenant.isLaunchReady
            ? colorScheme.onTertiaryContainer
            : tenant.isOnboardingBlocked
                ? colorScheme.onErrorContainer
                : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tenant.onboardingBlockedReason ?? tenant.onboardingStatusLabel,
      waitDuration: const Duration(milliseconds: 400),
      child: Chip(
        avatar: Icon(
          tenant.isLaunched
              ? Icons.check_circle_outline
              : tenant.isLaunchReady
                  ? Icons.rocket_launch_outlined
                  : tenant.isOnboardingBlocked
                      ? Icons.warning_amber_outlined
                      : Icons.pending_actions_outlined,
          size: 18,
          color: foregroundColor,
        ),
        label: Text(label),
        backgroundColor: backgroundColor,
        labelStyle: TextStyle(color: foregroundColor),
        side: BorderSide(color: backgroundColor),
      ),
    );
  }
}

class _CompactInfoChip extends StatelessWidget {
  const _CompactInfoChip({
    required this.icon,
    required this.label,
    required this.isReady,
    this.warning = false,
    this.isError = false,
  });

  final IconData icon;
  final String label;
  final bool isReady;
  final bool warning;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isError
        ? colorScheme.error
        : warning
            ? Colors.orange.shade700
            : isReady
                ? colorScheme.primary
                : colorScheme.outline;
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 400),
      child: Chip(
        avatar: Icon(
          icon,
          size: 16,
          color: iconColor,
        ),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
        ),
        labelStyle: Theme.of(context).textTheme.bodySmall,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

String _usageText(int current, int? limit) {
  if (limit == null) return '${_formatCount(current)} / Unlimited';
  return '${_formatCount(current)} / ${_formatCount(limit)}';
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

class _TenantFilters extends StatelessWidget {
  const _TenantFilters({
    required this.searchController,
    required this.status,
    required this.readiness,
    required this.subscriptionHealth,
    required this.billingReadiness,
    required this.onStatusChanged,
    required this.onReadinessChanged,
    required this.onSubscriptionHealthChanged,
    required this.onBillingReadinessChanged,
    required this.onApply,
    required this.onReset,
  });

  final TextEditingController searchController;
  final String? status;
  final String? readiness;
  final String? subscriptionHealth;
  final String? billingReadiness;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onReadinessChanged;
  final ValueChanged<String?> onSubscriptionHealthChanged;
  final ValueChanged<String?> onBillingReadinessChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 420,
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Search tenants',
                  prefixIcon: Icon(Icons.search),
                ),
                onSubmitted: (_) => onApply(),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                      value: null, child: Text('All Tenant Statuses')),
                  DropdownMenuItem(value: 'trialing', child: Text('Trialing')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'past_due', child: Text('Past Due')),
                  DropdownMenuItem(value: 'paused', child: Text('Paused')),
                  DropdownMenuItem(
                      value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: onStatusChanged,
              ),
            ),
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<String?>(
                value: readiness,
                decoration: const InputDecoration(labelText: 'Readiness'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Readiness')),
                  DropdownMenuItem(
                      value: 'needs_setup', child: Text('Needs Setup')),
                  DropdownMenuItem(
                      value: 'ready_to_launch', child: Text('Ready to Launch')),
                  DropdownMenuItem(value: 'launched', child: Text('Launched')),
                  DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                  DropdownMenuItem(
                      value: 'missing_subscription',
                      child: Text('Missing Subscription')),
                  DropdownMenuItem(
                      value: 'missing_admin',
                      child: Text('Missing Tenant Owner')),
                  DropdownMenuItem(
                      value: 'missing_hoa', child: Text('Missing HOA')),
                ],
                onChanged: onReadinessChanged,
              ),
            ),
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String?>(
                value: subscriptionHealth,
                decoration:
                    const InputDecoration(labelText: 'Subscription Health'),
                items: const [
                  DropdownMenuItem(
                      value: null, child: Text('All Subscription Health')),
                  DropdownMenuItem(
                      value: 'missing_subscription',
                      child: Text('No Subscription')),
                  DropdownMenuItem(
                      value: 'over_limits',
                      child: Text('Over Included Limits')),
                  DropdownMenuItem(
                      value: 'approaching_limits',
                      child: Text('Approaching Limits')),
                  DropdownMenuItem(
                      value: 'stripe_pending', child: Text('Stripe Pending')),
                ],
                onChanged: onSubscriptionHealthChanged,
              ),
            ),
            SizedBox(
              width: 250,
              child: DropdownButtonFormField<String?>(
                value: billingReadiness,
                decoration:
                    const InputDecoration(labelText: 'Billing Readiness'),
                items: const [
                  DropdownMenuItem(
                      value: null, child: Text('All Billing Readiness')),
                  DropdownMenuItem(
                      value: 'missing_subscription',
                      child: Text('No Plan Assigned')),
                  DropdownMenuItem(
                      value: 'missing_billing_contact',
                      child: Text('No Billing Contact')),
                  DropdownMenuItem(
                      value: 'over_limits',
                      child: Text('Over Included Limits')),
                  DropdownMenuItem(
                      value: 'stripe_pending', child: Text('Stripe Pending')),
                ],
                onChanged: onBillingReadinessChanged,
              ),
            ),
            FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.search),
              label: const Text('Apply'),
            ),
            TextButton(onPressed: onReset, child: const Text('Reset')),
          ],
        ),
      ),
    );
  }
}
