import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/admin_context.dart';
import '../../ticket_operations/domain/ticket.dart';
import '../../ticket_operations/presentation/ticket_providers.dart';
import '../domain/customer_account.dart';
import '../domain/service_location.dart';
import 'customer_account_form_dialog.dart';
import 'customer_account_providers.dart';
import 'service_location_form_dialog.dart';

class CustomerAccountListPage extends ConsumerStatefulWidget {
  const CustomerAccountListPage({super.key});

  @override
  ConsumerState<CustomerAccountListPage> createState() =>
      _CustomerAccountListPageState();
}

class _CustomerAccountListPageState
    extends ConsumerState<CustomerAccountListPage> {
  _AccountView _selectedView = _AccountView.residential;
  _ResidentialScopeView _selectedResidentialScope = _ResidentialScopeView.all;
  String? _selectedAccountId;
  String? _selectedLocationId;

  @override
  Widget build(BuildContext context) {
    final activeContext = ref.watch(activeAdminContextProvider);

    return activeContext.when(
      data: (contextValue) {
        final tenantId =
            contextValue?.isTenant == true ? contextValue!.scopeId : null;
        final accountFilter = CustomerAccountListFilter(
          tenantId: tenantId,
        );
        final accounts = ref.watch(customerAccountListProvider(accountFilter));
        final visibleAccounts = accounts.whenData(
          (items) => _accountsForView(
            items,
            _selectedView,
            _selectedResidentialScope,
          ),
        );
        final visibleAccountIds =
            visibleAccounts.asData?.value.map((account) => account.id).toSet();
        final locationFilter = ServiceLocationListFilter(
          tenantId: tenantId,
          customerAccountId: _selectedAccountId,
        );
        final locations =
            ref.watch(serviceLocationListProvider(locationFilter));
        final visibleLocations = locations.whenData(
          (items) => _locationsForView(items, visibleAccountIds),
        );
        final selectedLocation = _selectedLocationFrom(
          visibleLocations.asData?.value,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 980;
            final pagePadding = constraints.maxWidth < 720 ? 16.0 : 24.0;

            return Padding(
              padding: EdgeInsets.all(pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    selectedView: _selectedView,
                    onViewChanged: (value) {
                      setState(() {
                        _selectedView = value;
                        _selectedAccountId = null;
                        _selectedLocationId = null;
                        _selectedResidentialScope = _ResidentialScopeView.all;
                      });
                    },
                    onRefresh: () {
                      ref.invalidate(
                          customerAccountListProvider(accountFilter));
                      ref.invalidate(
                        serviceLocationListProvider(locationFilter),
                      );
                    },
                    onCreateAccount: () => _openAccountDialog(
                      context,
                      tenantId: tenantId,
                    ),
                    onCreateLocation:
                        visibleAccounts.asData?.value.isEmpty == false
                            ? () => _openLocationDialog(
                                  context,
                                  tenantId: tenantId,
                                  accounts:
                                      visibleAccounts.asData?.value ?? const [],
                                )
                            : null,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: isCompact
                        ? Column(
                            children: [
                              Expanded(
                                child: _AccountList(
                                  accounts: visibleAccounts,
                                  selectedView: _selectedView,
                                  selectedResidentialScope:
                                      _selectedResidentialScope,
                                  selectedAccountId: _selectedAccountId,
                                  onResidentialScopeChanged:
                                      _selectResidentialScope,
                                  onSelected: _selectAccount,
                                  onEdit: (account) => _openAccountDialog(
                                    context,
                                    tenantId: tenantId,
                                    account: account,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: _LocationWorkspace(
                                  locations: visibleLocations,
                                  selectedLocationId: _selectedLocationId,
                                  selectedLocation: selectedLocation,
                                  onSelected: _selectLocation,
                                  onEdit: (location) => _openLocationDialog(
                                    context,
                                    tenantId: tenantId,
                                    accounts: visibleAccounts.asData?.value ??
                                        const [],
                                    location: location,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 420,
                                child: _AccountList(
                                  accounts: visibleAccounts,
                                  selectedView: _selectedView,
                                  selectedResidentialScope:
                                      _selectedResidentialScope,
                                  selectedAccountId: _selectedAccountId,
                                  onResidentialScopeChanged:
                                      _selectResidentialScope,
                                  onSelected: _selectAccount,
                                  onEdit: (account) => _openAccountDialog(
                                    context,
                                    tenantId: tenantId,
                                    account: account,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _LocationWorkspace(
                                  locations: visibleLocations,
                                  selectedLocationId: _selectedLocationId,
                                  selectedLocation: selectedLocation,
                                  onSelected: _selectLocation,
                                  onEdit: (location) => _openLocationDialog(
                                    context,
                                    tenantId: tenantId,
                                    accounts: visibleAccounts.asData?.value ??
                                        const [],
                                    location: location,
                                  ),
                                ),
                              ),
                            ],
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

  void _selectAccount(CustomerAccount account) {
    setState(() {
      _selectedAccountId = account.id == _selectedAccountId ? null : account.id;
      _selectedLocationId = null;
    });
  }

  void _selectResidentialScope(_ResidentialScopeView value) {
    setState(() {
      _selectedResidentialScope = value;
      _selectedAccountId = null;
      _selectedLocationId = null;
    });
  }

  void _selectLocation(ServiceLocation location) {
    setState(() {
      _selectedLocationId = location.id;
    });
  }

  List<CustomerAccount> _accountsForView(
    List<CustomerAccount> accounts,
    _AccountView view,
    _ResidentialScopeView residentialScope,
  ) {
    final filtered = accounts.where((account) {
      return switch (view) {
        _AccountView.residential =>
          account.accountType == CustomerAccountType.community &&
              residentialScope.includes(account),
        _AccountView.commercial =>
          account.accountType == CustomerAccountType.commercial,
        _AccountView.rollOff =>
          account.accountType == CustomerAccountType.rollOff,
      };
    }).toList();

    filtered.sort((a, b) {
      if (view == _AccountView.residential) {
        final typeCompare =
            _residentialSortGroup(a).compareTo(_residentialSortGroup(b));
        if (typeCompare != 0) return typeCompare;
      }

      return a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          );
    });

    return filtered;
  }

  List<ServiceLocation> _locationsForView(
    List<ServiceLocation> locations,
    Set<String>? accountIds,
  ) {
    if (accountIds == null) return locations;

    return locations
        .where((location) => accountIds.contains(location.customerAccountId))
        .toList();
  }

  ServiceLocation? _selectedLocationFrom(List<ServiceLocation>? locations) {
    if (_selectedLocationId == null || locations == null) return null;

    for (final location in locations) {
      if (location.id == _selectedLocationId) return location;
    }

    return null;
  }

  int _residentialSortGroup(CustomerAccount account) {
    return _isCityAccount(account) ? 0 : 1;
  }

  Future<void> _openAccountDialog(
    BuildContext context, {
    required String? tenantId,
    CustomerAccount? account,
  }) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CustomerAccountFormDialog(
        initialValue: account,
        tenantId: tenantId,
      ),
    );

    if (result != null) {
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
    if (accounts.isEmpty) {
      return;
    }

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
    required this.selectedView,
    required this.onViewChanged,
    required this.onRefresh,
    required this.onCreateAccount,
    required this.onCreateLocation,
  });

  final _AccountView selectedView;
  final ValueChanged<_AccountView> onViewChanged;
  final VoidCallback onRefresh;
  final VoidCallback onCreateAccount;
  final VoidCallback? onCreateLocation;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Customers',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
        FilledButton.icon(
          onPressed: onCreateAccount,
          icon: const Icon(Icons.add),
          label: const Text('Create Account'),
        ),
        OutlinedButton.icon(
          onPressed: onCreateLocation,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add Service Address'),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: DropdownButtonFormField<_AccountView>(
            initialValue: selectedView,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Account type',
              border: OutlineInputBorder(),
            ),
            items: _AccountView.values
                .map(
                  (view) => DropdownMenuItem<_AccountView>(
                    value: view,
                    child: Text(view.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onViewChanged(value);
              }
            },
          ),
        ),
      ],
    );
  }
}

enum _AccountView {
  residential,
  commercial,
  rollOff;

  String get label {
    return switch (this) {
      _AccountView.residential => 'Residential',
      _AccountView.commercial => 'Commercial',
      _AccountView.rollOff => 'Roll-Off',
    };
  }
}

enum _ResidentialScopeView {
  all,
  city,
  community;

  String get label {
    return switch (this) {
      _ResidentialScopeView.all => 'All',
      _ResidentialScopeView.city => 'City',
      _ResidentialScopeView.community => 'Community',
    };
  }

  bool includes(CustomerAccount account) {
    return switch (this) {
      _ResidentialScopeView.all => true,
      _ResidentialScopeView.city => _isCityAccount(account),
      _ResidentialScopeView.community => !_isCityAccount(account),
    };
  }
}

bool _isCityAccount(CustomerAccount account) {
  return account.accountType == CustomerAccountType.community &&
      account.metadata['community_type'] == 'city';
}

String _accountScopeLabel(CustomerAccount account) {
  if (_isCityAccount(account)) return 'City';
  if (account.accountType == CustomerAccountType.community) return 'Community';
  return account.accountType.label;
}

IconData _accountIcon(CustomerAccount account) {
  if (_isCityAccount(account)) return Icons.location_city_outlined;

  return switch (account.accountType) {
    CustomerAccountType.residential => Icons.home_outlined,
    CustomerAccountType.community => Icons.groups_2_outlined,
    CustomerAccountType.commercial => Icons.storefront_outlined,
    CustomerAccountType.rollOff => Icons.inventory_2_outlined,
  };
}

class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.accounts,
    required this.selectedView,
    required this.selectedResidentialScope,
    required this.selectedAccountId,
    required this.onResidentialScopeChanged,
    required this.onSelected,
    required this.onEdit,
  });

  final AsyncValue<List<CustomerAccount>> accounts;
  final _AccountView selectedView;
  final _ResidentialScopeView selectedResidentialScope;
  final String? selectedAccountId;
  final ValueChanged<_ResidentialScopeView> onResidentialScopeChanged;
  final ValueChanged<CustomerAccount> onSelected;
  final ValueChanged<CustomerAccount> onEdit;

  @override
  Widget build(BuildContext context) {
    return accounts.when(
      data: (items) {
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (selectedView == _AccountView.residential)
                _ResidentialScopeTabs(
                  selectedScope: selectedResidentialScope,
                  onChanged: onResidentialScopeChanged,
                ),
              if (selectedView == _AccountView.residential)
                const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const _EmptyState(
                        icon: Icons.account_tree_outlined,
                        title: 'No records found',
                        subtitle: 'Create a city, community, or account here.',
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final account = items[index];
                          final isSelected = account.id == selectedAccountId;

                          return ListTile(
                            selected: isSelected,
                            leading: Icon(_accountIcon(account)),
                            title: Text(
                              account.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${_accountScopeLabel(account)} · ${account.status.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: 'Edit account',
                              onPressed: () => onEdit(account),
                              icon: Icon(
                                isSelected
                                    ? Icons.edit_note_outlined
                                    : Icons.edit_outlined,
                              ),
                            ),
                            onTap: () => onSelected(account),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        title: 'Unable to load customer accounts',
        error: error,
      ),
    );
  }
}

class _ResidentialScopeTabs extends StatelessWidget {
  const _ResidentialScopeTabs({
    required this.selectedScope,
    required this.onChanged,
  });

  final _ResidentialScopeView selectedScope;
  final ValueChanged<_ResidentialScopeView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_ResidentialScopeView>(
          showSelectedIcon: false,
          segments: _ResidentialScopeView.values
              .map(
                (scope) => ButtonSegment<_ResidentialScopeView>(
                  value: scope,
                  icon: Icon(
                    switch (scope) {
                      _ResidentialScopeView.all => Icons.list_alt_outlined,
                      _ResidentialScopeView.city =>
                        Icons.location_city_outlined,
                      _ResidentialScopeView.community =>
                        Icons.groups_2_outlined,
                    },
                    size: 18,
                  ),
                  label: Text(scope.label),
                ),
              )
              .toList(),
          selected: {selectedScope},
          onSelectionChanged: (selection) => onChanged(selection.single),
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class _LocationWorkspace extends StatelessWidget {
  const _LocationWorkspace({
    required this.locations,
    required this.selectedLocationId,
    required this.selectedLocation,
    required this.onSelected,
    required this.onEdit,
  });

  final AsyncValue<List<ServiceLocation>> locations;
  final String? selectedLocationId;
  final ServiceLocation? selectedLocation;
  final ValueChanged<ServiceLocation> onSelected;
  final ValueChanged<ServiceLocation> onEdit;

  @override
  Widget build(BuildContext context) {
    return locations.when(
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.location_on_outlined,
            title: 'No service addresses found',
            subtitle: 'Select a city, community, or account to see addresses.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 760;
            final selected = selectedLocation ?? items.first;

            if (isCompact) {
              return Column(
                children: [
                  Expanded(
                    child: _LocationList(
                      items: items,
                      selectedLocationId: selectedLocationId ?? selected.id,
                      onSelected: onSelected,
                      onEdit: onEdit,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _ServiceLocationDetail(location: selected),
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 430,
                  child: _LocationList(
                    items: items,
                    selectedLocationId: selectedLocationId ?? selected.id,
                    onSelected: onSelected,
                    onEdit: onEdit,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ServiceLocationDetail(location: selected),
                ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        title: 'Unable to load service addresses',
        error: error,
      ),
    );
  }
}

class _LocationList extends StatelessWidget {
  const _LocationList({
    required this.items,
    required this.selectedLocationId,
    required this.onSelected,
    required this.onEdit,
  });

  final List<ServiceLocation> items;
  final String? selectedLocationId;
  final ValueChanged<ServiceLocation> onSelected;
  final ValueChanged<ServiceLocation> onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final location = items[index];
          final isSelected = location.id == selectedLocationId;

          return ListTile(
            selected: isSelected,
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
                  tooltip: 'Edit location',
                  onPressed: () => onEdit(location),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            onTap: () => onSelected(location),
          );
        },
      ),
    );
  }
}

class _ServiceLocationDetail extends ConsumerWidget {
  const _ServiceLocationDetail({required this.location});

  final ServiceLocation location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressId = _ticketAddressId(location);
    final tickets = ref.watch(
      ticketListProvider(TicketListFilter(addressId: addressId)),
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                location.isActive
                    ? Icons.location_on_outlined
                    : Icons.location_off_outlined,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.singleLine,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(_locationSubtitle(location)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(label: location.statusLabel),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _DetailFact(
                label: 'Customer account',
                value: location.customerAccountName ??
                    location.customerAccountNumber ??
                    'Not set',
              ),
              _DetailFact(
                label: 'External reference',
                value: _emptyToNotSet(location.externalLocationRef),
              ),
              _DetailFact(
                label: 'Normalized key',
                value: location.normalizedKey,
              ),
              _DetailFact(
                label: 'Created',
                value: _dateLabel(location.createdAt),
              ),
              _DetailFact(
                label: 'Updated',
                value: _dateLabel(location.updatedAt),
              ),
            ],
          ),
          const Divider(height: 32),
          Text(
            'Service ticket history',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          tickets.when(
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No service tickets have been submitted here.'),
                );
              }

              return Column(
                children: [
                  for (final ticket in items)
                    _TicketHistoryTile(ticket: ticket),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Unable to load ticket history: $error'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailFact extends StatelessWidget {
  const _DetailFact({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TicketHistoryTile extends StatelessWidget {
  const _TicketHistoryTile({required this.ticket});

  final ServiceTicket ticket;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.confirmation_number_outlined),
      title: Text(
        ticket.subject,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${ticket.type.label} · ${ticket.priority.label} · ${_dateLabel(ticket.createdAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusPill(label: ticket.status.label),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => context.go('/admin/tickets/${ticket.id}?from=tickets'),
    );
  }
}

String _locationSubtitle(ServiceLocation location) {
  final accountName = location.customerAccountName?.trim();
  final accountNumber = location.customerAccountNumber?.trim();
  final accountLabel = accountName != null && accountName.isNotEmpty
      ? accountName
      : accountNumber != null && accountNumber.isNotEmpty
          ? 'Account $accountNumber'
          : 'Customer account';

  return '$accountLabel · ${location.normalizedKey}';
}

String _ticketAddressId(ServiceLocation location) {
  final legacyAddressId = location.metadata['legacy_address_id'];
  if (legacyAddressId is String && legacyAddressId.trim().isNotEmpty) {
    return legacyAddressId.trim();
  }

  return location.id;
}

String _emptyToNotSet(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? 'Not set' : trimmed;
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month/$day/${local.year}';
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
        constraints: const BoxConstraints(maxWidth: 420),
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
