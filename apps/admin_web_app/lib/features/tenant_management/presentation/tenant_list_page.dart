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
            onStatusChanged: (value) => setState(() => _status = value),
            onApply: _applyFilters,
            onReset: _resetFilters,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: tenants.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No platform tenants found.'));
                }
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final tenant = items[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            tenant.isPrimary
                                ? Icons.verified_outlined
                                : Icons.business_outlined,
                          ),
                        ),
                        title: Text(tenant.name),
                        subtitle: _TenantSubtitle(tenant: tenant),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (tenant.isPrimary)
                              const Chip(label: Text('Primary')),
                            _OnboardingStatusChip(tenant: tenant),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => context.go('/admin/tenants/${tenant.id}'),
                      );
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
        );
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _status = null;
    });
    ref.read(tenantListFiltersProvider.notifier).state = const TenantListFilters();
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

class _TenantSubtitle extends StatelessWidget {
  const _TenantSubtitle({required this.tenant});

  final PlatformTenant tenant;

  @override
  Widget build(BuildContext context) {
    final parts = [
      tenant.code,
      tenant.statusLabel,
      'Onboarding: ${tenant.onboardingStatusLabel}',
    ];
    if (tenant.onboardingBlockedReason != null) {
      parts.add('Blocked: ${tenant.onboardingBlockedReason}');
    }

    return Tooltip(
      message: parts.join('\n'),
      waitDuration: const Duration(milliseconds: 400),
      child: Text(
        parts.join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _OnboardingStatusChip extends StatelessWidget {
  const _OnboardingStatusChip({required this.tenant});

  final PlatformTenant tenant;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
        label: Text(tenant.onboardingStatusLabel),
        backgroundColor: backgroundColor,
        labelStyle: TextStyle(color: foregroundColor),
        side: BorderSide(color: backgroundColor),
      ),
    );
  }
}

class _TenantFilters extends StatelessWidget {
  const _TenantFilters({
    required this.searchController,
    required this.status,
    required this.onStatusChanged,
    required this.onApply,
    required this.onReset,
  });

  final TextEditingController searchController;
  final String? status;
  final ValueChanged<String?> onStatusChanged;
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
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(value: 'trialing', child: Text('Trialing')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'past_due', child: Text('Past Due')),
                  DropdownMenuItem(value: 'paused', child: Text('Paused')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: onStatusChanged,
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
