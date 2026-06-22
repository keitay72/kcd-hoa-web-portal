import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_context.dart';
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
  CustomerAccountType? _selectedType;
  String? _selectedAccountId;

  @override
  Widget build(BuildContext context) {
    final activeContext = ref.watch(activeAdminContextProvider);

    return activeContext.when(
      data: (contextValue) {
        final tenantId =
            contextValue?.isTenant == true ? contextValue!.scopeId : null;
        final accountFilter = CustomerAccountListFilter(
          tenantId: tenantId,
          accountType: _selectedType,
        );
        final accounts = ref.watch(customerAccountListProvider(accountFilter));
        final locationFilter = ServiceLocationListFilter(
          tenantId: tenantId,
          customerAccountId: _selectedAccountId,
        );
        final locations =
            ref.watch(serviceLocationListProvider(locationFilter));

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
                    selectedType: _selectedType,
                    onTypeChanged: (value) {
                      setState(() {
                        _selectedType = value;
                        _selectedAccountId = null;
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
                    child: isCompact
                        ? Column(
                            children: [
                              Expanded(
                                child: _AccountList(
                                  accounts: accounts,
                                  selectedAccountId: _selectedAccountId,
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
                                child: _LocationList(
                                  locations: locations,
                                  onEdit: (location) => _openLocationDialog(
                                    context,
                                    tenantId: tenantId,
                                    accounts:
                                        accounts.asData?.value ?? const [],
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
                                  accounts: accounts,
                                  selectedAccountId: _selectedAccountId,
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
                                child: _LocationList(
                                  locations: locations,
                                  onEdit: (location) => _openLocationDialog(
                                    context,
                                    tenantId: tenantId,
                                    accounts:
                                        accounts.asData?.value ?? const [],
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
    });
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
    required this.selectedType,
    required this.onTypeChanged,
    required this.onRefresh,
    required this.onCreateAccount,
    required this.onCreateLocation,
  });

  final CustomerAccountType? selectedType;
  final ValueChanged<CustomerAccountType?> onTypeChanged;
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
          'Customer Accounts',
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
          label: const Text('Create Location'),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: DropdownButtonFormField<CustomerAccountType?>(
            initialValue: selectedType,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Account type',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<CustomerAccountType?>(
                value: null,
                child: Text('All account types'),
              ),
              ...CustomerAccountType.values.map(
                (type) => DropdownMenuItem<CustomerAccountType?>(
                  value: type,
                  child: Text(type.label),
                ),
              ),
            ],
            onChanged: onTypeChanged,
          ),
        ),
      ],
    );
  }
}

class _AccountList extends StatelessWidget {
  const _AccountList({
    required this.accounts,
    required this.selectedAccountId,
    required this.onSelected,
    required this.onEdit,
  });

  final AsyncValue<List<CustomerAccount>> accounts;
  final String? selectedAccountId;
  final ValueChanged<CustomerAccount> onSelected;
  final ValueChanged<CustomerAccount> onEdit;

  @override
  Widget build(BuildContext context) {
    return accounts.when(
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.account_tree_outlined,
            title: 'No customer accounts found',
            subtitle: 'Run the customer portal backfill or add accounts here.',
          );
        }

        return Card(
          margin: EdgeInsets.zero,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final account = items[index];
              final isSelected = account.id == selectedAccountId;

              return ListTile(
                selected: isSelected,
                leading: Icon(_accountIcon(account.accountType)),
                title: Text(
                  account.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${account.accountType.label} · ${account.status.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Edit account',
                  onPressed: () => onEdit(account),
                  icon: Icon(
                    isSelected ? Icons.edit_note_outlined : Icons.edit_outlined,
                  ),
                ),
                onTap: () => onSelected(account),
              );
            },
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

  IconData _accountIcon(CustomerAccountType type) {
    return switch (type) {
      CustomerAccountType.residential => Icons.home_outlined,
      CustomerAccountType.community => Icons.domain_outlined,
      CustomerAccountType.commercial => Icons.storefront_outlined,
      CustomerAccountType.rollOff => Icons.inventory_2_outlined,
    };
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
            subtitle: 'Select an account or load service locations.',
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
                      tooltip: 'Edit location',
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

    return '$accountLabel · ${location.normalizedKey}';
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
