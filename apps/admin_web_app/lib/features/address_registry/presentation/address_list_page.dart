import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_context.dart';
import '../../customer_accounts/domain/customer_account.dart';
import '../../customer_accounts/domain/service_location.dart';
import '../../customer_accounts/presentation/customer_account_providers.dart';
import '../../customer_accounts/presentation/service_address_form_dialog.dart';
import '../../customer_accounts/presentation/service_location_form_dialog.dart';
import '../../hoa_management/domain/hoa_community.dart';
import '../../hoa_management/presentation/hoa_providers.dart';

class AddressListPage extends ConsumerStatefulWidget {
  const AddressListPage({super.key});

  @override
  ConsumerState<AddressListPage> createState() => _AddressListPageState();
}

class _AddressListPageState extends ConsumerState<AddressListPage> {
  String? _selectedAccountId;

  @override
  Widget build(BuildContext context) {
    final activeContext = ref.watch(activeAdminContextProvider);

    return activeContext.when(
      data: (contextValue) {
        final tenantId =
            contextValue?.isTenant == true ? contextValue!.scopeId : null;
        final accountFilter = CustomerAccountListFilter(tenantId: tenantId);
        final accounts = ref.watch(customerAccountListProvider(accountFilter));
        final locationFilter = ServiceLocationListFilter(
          tenantId: tenantId,
          customerAccountId: _selectedAccountId,
        );
        final locations =
            ref.watch(serviceLocationListProvider(locationFilter));
        final communities = ref.watch(hoaListProvider);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;
            final pagePadding = isCompact ? 16.0 : 24.0;

            return Padding(
              padding: EdgeInsets.all(pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    accounts: accounts,
                    selectedAccountId: _selectedAccountId,
                    onAccountChanged: (value) {
                      setState(() => _selectedAccountId = value);
                    },
                    onRefresh: () {
                      ref.invalidate(
                          customerAccountListProvider(accountFilter));
                      ref.invalidate(
                        serviceLocationListProvider(locationFilter),
                      );
                      ref.invalidate(hoaListProvider);
                    },
                    onAddServiceAddress: accounts.hasValue &&
                            communities.hasValue
                        ? () => _openServiceAddressDialog(
                              context,
                              tenantId: tenantId,
                              accounts: accounts.valueOrNull ?? const [],
                              communities: communities.valueOrNull ?? const [],
                            )
                        : null,
                    onCreateLocation: accounts.asData?.value.isEmpty == false
                        ? () => _openLocationDialog(
                              context,
                              tenantId: tenantId,
                              accounts: accounts.asData!.value,
                            )
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _LocationList(
                      locations: locations,
                      onEdit: (location) => _openLocationDialog(
                        context,
                        tenantId: tenantId,
                        accounts: accounts.asData?.value ?? const [],
                        location: location,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Unable to resolve active admin context: $error'),
      ),
    );
  }

  Future<void> _openServiceAddressDialog(
    BuildContext context, {
    required String? tenantId,
    required List<CustomerAccount> accounts,
    required List<HoaCommunity> communities,
  }) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ServiceAddressFormDialog(
        tenantId: tenantId,
        accounts: accounts,
        communities: communities,
      ),
    );

    if (result is ServiceLocation) {
      setState(() => _selectedAccountId = result.customerAccountId);
      ref.invalidate(customerAccountListProvider);
      ref.invalidate(serviceLocationListProvider);
    }
  }

  Future<void> _openLocationDialog(
    BuildContext context, {
    required String? tenantId,
    required List<CustomerAccount> accounts,
    ServiceLocation? location,
  }) async {
    if (accounts.isEmpty) return;

    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ServiceLocationFormDialog(
        accounts: accounts,
        initialValue: location,
        initialAccountId: location?.customerAccountId ?? _selectedAccountId,
        tenantId: tenantId,
      ),
    );

    if (result != null) {
      ref.invalidate(serviceLocationListProvider);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.accounts,
    required this.selectedAccountId,
    required this.onAccountChanged,
    required this.onRefresh,
    required this.onAddServiceAddress,
    required this.onCreateLocation,
  });

  final AsyncValue<List<CustomerAccount>> accounts;
  final String? selectedAccountId;
  final ValueChanged<String?> onAccountChanged;
  final VoidCallback onRefresh;
  final VoidCallback? onAddServiceAddress;
  final VoidCallback? onCreateLocation;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Service Addresses',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
        FilledButton.icon(
          onPressed: onAddServiceAddress,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add Service Address'),
        ),
        OutlinedButton.icon(
          onPressed: onCreateLocation,
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: const Text('Add Address to Existing Account'),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: accounts.when(
            data: (items) => DropdownButtonFormField<String?>(
              initialValue: selectedAccountId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filter by customer account',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All service addresses'),
                ),
                ...items.map(
                  (account) => DropdownMenuItem<String?>(
                    value: account.id,
                    child: Text(
                      account.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: onAccountChanged,
            ),
            loading: () => const SizedBox(
              height: 56,
              child: Align(
                alignment: Alignment.centerLeft,
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, _) => Text('Unable to load account filters: $error'),
          ),
        ),
      ],
    );
  }
}

class _LocationList extends StatelessWidget {
  const _LocationList({
    required this.locations,
    required this.onEdit,
  });

  final AsyncValue<List<ServiceLocation>> locations;
  final ValueChanged<ServiceLocation> onEdit;

  @override
  Widget build(BuildContext context) {
    return locations.when(
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.location_on_outlined,
            title: 'No service locations found',
            subtitle:
                'Create a residential account for a standalone customer, or a community account for HOA/community service, then add service locations.',
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final location = items[index];

              return ListTile(
                leading: Icon(
                  location.isActive
                      ? Icons.location_on_outlined
                      : Icons.location_off_outlined,
                ),
                title: Text(
                  location.singleLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _locationSubtitle(location),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusPill(label: location.statusLabel),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Edit service location',
                      onPressed: () => onEdit(location),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        title: 'Unable to load service locations',
        error: error,
      ),
    );
  }

  String _locationSubtitle(ServiceLocation location) {
    final accountName = location.customerAccountName?.trim();
    final accountNumber = location.customerAccountNumber?.trim();
    final accountLabel = accountName != null && accountName.isNotEmpty
        ? accountName
        : accountNumber != null && accountNumber.isNotEmpty
            ? 'Account $accountNumber'
            : 'Customer account';

    return '$accountLabel - ${location.normalizedKey}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.error,
  });

  final String title;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
