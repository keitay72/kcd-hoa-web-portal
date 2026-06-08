import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../hoa_management/domain/hoa_community.dart';
import '../../hoa_management/presentation/hoa_providers.dart';
import '../data/service_schedule_repository.dart';
import '../domain/service_schedule.dart';
import 'service_schedule_form_dialog.dart';
import 'service_schedule_providers.dart';

class ServiceScheduleListPage extends ConsumerStatefulWidget {
  const ServiceScheduleListPage({super.key});

  @override
  ConsumerState<ServiceScheduleListPage> createState() => _ServiceScheduleListPageState();
}

class _ServiceScheduleListPageState extends ConsumerState<ServiceScheduleListPage> {
  final _searchController = TextEditingController();
  String? _hoaId;
  String? _serviceType;
  String? _status = ServiceScheduleStatus.active.name;
  String? _scope = ServiceScheduleScope.hoaWide.value;

  ServiceScheduleListFilter get _filter => ServiceScheduleListFilter(
        hoaId: _hoaId,
        serviceType: _serviceType,
        status: _status,
        scope: _scope,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedules = ref.watch(serviceScheduleListProvider(_filter));
    final hoas = ref.watch(hoaListProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Service Schedules',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.event_repeat_outlined),
                label: const Text('Create Schedule'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _ServiceScheduleFilterBar(
                hoas: hoas,
                hoaId: _hoaId,
                serviceType: _serviceType,
                status: _status,
                scope: _scope,
                searchController: _searchController,
                onHoaChanged: (value) => setState(() => _hoaId = value),
                onServiceTypeChanged: (value) => setState(() => _serviceType = value),
                onStatusChanged: (value) => setState(() => _status = value),
                onScopeChanged: (value) => setState(() => _scope = value),
                onApply: () => setState(() {}),
                onReset: () {
                  setState(() {
                    _hoaId = null;
                    _serviceType = null;
                    _status = ServiceScheduleStatus.active.name;
                    _scope = ServiceScheduleScope.hoaWide.value;
                    _searchController.clear();
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: schedules.when(
              data: (items) => _ServiceScheduleTable(schedules: items),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load service schedules: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ServiceScheduleFormDialog(),
    );

    if (result != null) {
      ref.invalidate(serviceScheduleListProvider);
    }
  }
}

class _ServiceScheduleFilterBar extends StatelessWidget {
  const _ServiceScheduleFilterBar({
    required this.hoas,
    required this.hoaId,
    required this.serviceType,
    required this.status,
    required this.scope,
    required this.searchController,
    required this.onHoaChanged,
    required this.onServiceTypeChanged,
    required this.onStatusChanged,
    required this.onScopeChanged,
    required this.onApply,
    required this.onReset,
  });

  final AsyncValue<List<HoaCommunity>> hoas;
  final String? hoaId;
  final String? serviceType;
  final String? status;
  final String? scope;
  final TextEditingController searchController;
  final ValueChanged<String?> onHoaChanged;
  final ValueChanged<String?> onServiceTypeChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onScopeChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  static const _spacing = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hoaFilter = hoas.when(
          data: (items) => _HoaFilter(
            hoas: items,
            value: hoaId,
            onChanged: onHoaChanged,
          ),
          loading: () => const SizedBox(
            height: 56,
            child: Center(child: LinearProgressIndicator()),
          ),
          error: (error, _) => SizedBox(
            height: 56,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Unable to load HOAs: $error'),
            ),
          ),
        );
        final typeFilter = _ServiceTypeFilter(
          value: serviceType,
          onChanged: onServiceTypeChanged,
        );
        final statusFilter = _StatusFilter(value: status, onChanged: onStatusChanged);
        final scopeFilter = _ScopeFilter(value: scope, onChanged: onScopeChanged);
        final searchFilter = TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Search',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => onApply(),
        );
        final actions = _FilterActions(onApply: onApply, onReset: onReset);

        if (constraints.maxWidth >= 1240) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: hoaFilter),
              const SizedBox(width: _spacing),
              SizedBox(width: 180, child: typeFilter),
              const SizedBox(width: _spacing),
              SizedBox(width: 155, child: statusFilter),
              const SizedBox(width: _spacing),
              SizedBox(width: 190, child: scopeFilter),
              const SizedBox(width: _spacing),
              Expanded(flex: 3, child: searchFilter),
              const SizedBox(width: _spacing),
              actions,
            ],
          );
        }

        final fieldWidth = constraints.maxWidth < 560
            ? constraints.maxWidth
            : (constraints.maxWidth - _spacing) / 2;

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: fieldWidth, child: hoaFilter),
            SizedBox(width: fieldWidth, child: typeFilter),
            SizedBox(width: fieldWidth, child: statusFilter),
            SizedBox(width: fieldWidth, child: scopeFilter),
            SizedBox(width: fieldWidth, child: searchFilter),
            actions,
          ],
        );
      },
    );
  }
}

class _HoaFilter extends StatelessWidget {
  const _HoaFilter({required this.hoas, required this.value, required this.onChanged});

  final List<HoaCommunity> hoas;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'HOA', border: OutlineInputBorder()),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All HOAs')),
        ...hoas.map(
          (hoa) => DropdownMenuItem<String?>(
            value: hoa.id,
            child: Text('${hoa.name} (${hoa.code})', overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      selectedItemBuilder: (context) {
        return [
          const Text('All HOAs', overflow: TextOverflow.ellipsis),
          ...hoas.map(
            (hoa) => Text('${hoa.name} (${hoa.code})', overflow: TextOverflow.ellipsis),
          ),
        ];
      },
      onChanged: onChanged,
    );
  }
}

class _ServiceTypeFilter extends StatelessWidget {
  const _ServiceTypeFilter({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _allValue = '__all__';

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value ?? _allValue,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Service Type', border: OutlineInputBorder()),
      items: [
        const DropdownMenuItem<String>(value: _allValue, child: Text('All Types')),
        ...ServiceScheduleType.values.map(
          (type) => DropdownMenuItem<String>(
            value: type.databaseValue,
            child: Text(type.label),
          ),
        ),
      ],
      selectedItemBuilder: (context) {
        return [
          const Text('All Types', overflow: TextOverflow.ellipsis),
          ...ServiceScheduleType.values.map(
            (type) => Text(type.label, overflow: TextOverflow.ellipsis),
          ),
        ];
      },
      onChanged: (nextValue) => onChanged(nextValue == _allValue ? null : nextValue),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _allValue = '__all__';

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value ?? _allValue,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
      items: [
        const DropdownMenuItem<String>(value: _allValue, child: Text('All Statuses')),
        ...ServiceScheduleStatus.values.map(
          (status) => DropdownMenuItem<String>(
            value: status.name,
            child: Text(status.label),
          ),
        ),
      ],
      selectedItemBuilder: (context) {
        return [
          const Text('All Statuses', overflow: TextOverflow.ellipsis),
          ...ServiceScheduleStatus.values.map(
            (status) => Text(status.label, overflow: TextOverflow.ellipsis),
          ),
        ];
      },
      onChanged: (nextValue) => onChanged(nextValue == _allValue ? null : nextValue),
    );
  }
}

class _ScopeFilter extends StatelessWidget {
  const _ScopeFilter({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _allValue = '__all__';

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value ?? _allValue,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Scope', border: OutlineInputBorder()),
      items: [
        const DropdownMenuItem<String>(value: _allValue, child: Text('All Scopes')),
        ...ServiceScheduleScope.values.map(
          (scope) => DropdownMenuItem<String>(value: scope.value, child: Text(scope.label)),
        ),
      ],
      onChanged: (nextValue) => onChanged(nextValue == _allValue ? null : nextValue),
    );
  }
}

class _FilterActions extends StatelessWidget {
  const _FilterActions({required this.onApply, required this.onReset});

  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.search),
            label: const Text('Apply'),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onReset, child: const Text('Reset')),
        ],
      ),
    );
  }
}

class _ServiceScheduleTable extends StatelessWidget {
  const _ServiceScheduleTable({required this.schedules});

  final List<ServiceSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return const Center(child: Text('No service schedules found.'));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: schedules.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final schedule = schedules[index];
          return ListTile(
            leading: Icon(
              schedule.isOverride ? Icons.home_work_outlined : Icons.domain_outlined,
            ),
            title: Text('${schedule.serviceTypeLabel}: ${schedule.scheduleRule}'),
            subtitle: Text(
              '${schedule.hoaLabel} - ${schedule.scheduleScopeLabel} - Route: ${schedule.routeNameLabel}',
            ),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(schedule.statusLabel)),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.go('/admin/service-schedules/${schedule.id}'),
          );
        },
      ),
    );
  }
}
