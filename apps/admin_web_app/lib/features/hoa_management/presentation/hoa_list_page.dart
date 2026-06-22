import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/admin_context.dart';
import '../../tenant_management/domain/tenant_management_inputs.dart';
import '../../tenant_management/domain/tenant_management_models.dart';
import '../../tenant_management/presentation/tenant_management_providers.dart';
import 'hoa_form_dialog.dart';
import 'hoa_providers.dart';

class HoaListPage extends ConsumerWidget {
  const HoaListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoas = ref.watch(hoaListProvider);
    final tenantId = ref.watch(activeAdminContextProvider).maybeWhen(
          data: (contextValue) =>
              contextValue?.isTenant == true ? contextValue?.scopeId : null,
          orElse: () => null,
        );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Community Management',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(activeHoaIdsProvider);
                  ref.invalidate(hoaListProvider);
                },
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _openCreateDialog(
                  context,
                  ref,
                  tenantId: tenantId,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create Community'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _TenantActivationCodeDefaultCard(),
          const SizedBox(height: 16),
          Expanded(
            child: hoas.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No communities found.'));
                }

                return Card(
                  margin: EdgeInsets.zero,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final hoa = items[index];

                      return ListTile(
                        leading: Icon(
                          hoa.isActive
                              ? Icons.domain_outlined
                              : Icons.domain_disabled_outlined,
                        ),
                        title: Text(hoa.name),
                        subtitle: Text(
                          '${hoa.code} · ${hoa.status.name} · ${hoa.residentActivationCodeSettingLabel}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/admin/hoas/${hoa.id}'),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load communities: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog(
    BuildContext context,
    WidgetRef ref, {
    required String? tenantId,
  }) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HoaFormDialog(tenantId: tenantId),
    );

    if (result != null) {
      ref.invalidate(hoaListProvider);
    }
  }
}

class _TenantActivationCodeDefaultCard extends ConsumerWidget {
  const _TenantActivationCodeDefaultCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeContext = ref.watch(activeAdminContextProvider);

    return activeContext.when(
      data: (contextValue) {
        if (contextValue == null || !contextValue.isTenant) {
          return const SizedBox.shrink();
        }

        final tenantId = contextValue.scopeId;
        if (tenantId == null) return const SizedBox.shrink();

        final detail = ref.watch(tenantDetailProvider(tenantId));
        final mutationState = ref.watch(tenantMutationControllerProvider);

        return detail.when(
          data: (tenantDetail) {
            final settings = tenantDetail.settings;
            final requiresCodes =
                settings?.residentActivationCodesRequired ?? true;

            return Card(
              margin: EdgeInsets.zero,
              child: SwitchListTile(
                secondary: const Icon(Icons.pin_outlined),
                title: const Text('Tenant default: customer activation codes'),
                subtitle: Text(
                  requiresCodes
                      ? 'Communities using tenant default require activation codes.'
                      : 'Communities using tenant default bypass activation codes.',
                ),
                value: requiresCodes,
                onChanged: mutationState.isLoading
                    ? null
                    : (value) => _saveTenantDefault(
                          ref,
                          tenantId: tenantId,
                          settings: settings,
                          residentActivationCodesRequired: value,
                        ),
              ),
            );
          },
          loading: () => const Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Loading tenant activation-code default'),
            ),
          ),
          error: (error, _) => Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title:
                  const Text('Unable to load tenant activation-code default'),
              subtitle: Text('$error'),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _saveTenantDefault(
    WidgetRef ref, {
    required String tenantId,
    required TenantSettings? settings,
    required bool residentActivationCodesRequired,
  }) async {
    await ref.read(tenantMutationControllerProvider.notifier).updateSettings(
          tenantId: tenantId,
          input: TenantSettingsInput(
            supportEmail: settings?.supportEmail,
            supportPhone: settings?.supportPhone,
            portalHostname: settings?.portalHostname,
            logoUrl: settings?.logoUrl,
            emailFromName: settings?.emailFromName,
            emailReplyTo: settings?.emailReplyTo,
            primaryColor: settings?.primaryColor,
            secondaryColor: settings?.secondaryColor,
            timezone: settings?.timezone ?? 'America/Chicago',
            residentActivationCodesRequired: residentActivationCodesRequired,
          ),
        );
  }
}
