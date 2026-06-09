import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../hoa_management/domain/hoa_community.dart';
import '../../hoa_management/presentation/hoa_providers.dart';
import '../domain/ticket.dart';
import 'ticket_providers.dart';

class TicketListPage extends ConsumerStatefulWidget {
  const TicketListPage({super.key});

  @override
  ConsumerState<TicketListPage> createState() => _TicketListPageState();
}

class _TicketListPageState extends ConsumerState<TicketListPage> {
  final _searchController = TextEditingController();
  String? _hoaId;
  String? _status;
  String? _priority;

  TicketListFilter get _filter => TicketListFilter(
        hoaId: _hoaId,
        status: _status,
        priority: _priority,
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
    final tickets = ref.watch(ticketListProvider(_filter));
    final hoas = ref.watch(hoaListProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Tickets', style: Theme.of(context).textTheme.headlineMedium),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/admin/tickets/csr'),
                    icon: const Icon(Icons.support_agent),
                    label: const Text('CSR Dashboard'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/admin/tickets/dispatch'),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Dispatch Dashboard'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TicketMetricsPanel(),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _TicketFilterBar(
                hoas: hoas,
                hoaId: _hoaId,
                status: _status,
                priority: _priority,
                searchController: _searchController,
                onHoaChanged: (value) => setState(() => _hoaId = value),
                onStatusChanged: (value) => setState(() => _status = value),
                onPriorityChanged: (value) => setState(() => _priority = value),
                onApply: () => setState(() {}),
                onReset: () {
                  setState(() {
                    _hoaId = null;
                    _status = null;
                    _priority = null;
                    _searchController.clear();
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: tickets.when(
              data: (items) => _TicketTable(tickets: items),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Unable to load tickets: $error')),
            ),
          ),
        ],
      ),
    );
  }
}

Color _slaColor(BuildContext context, ServiceTicket ticket) {
  return switch (ticket.slaState) {
    SlaState.breached => Theme.of(context).colorScheme.error,
    SlaState.dueSoon => Colors.orange,
    SlaState.complete => Colors.green,
    SlaState.onTrack => Theme.of(context).colorScheme.primary,
  };
}

class _TicketMetricsPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(ticketMetricsProvider);

    return metrics.when(
      data: (value) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricChip(label: 'Open', value: value.totalOpen),
          _MetricChip(label: 'New', value: value.newTickets),
          _MetricChip(label: 'Assigned', value: value.assigned),
          _MetricChip(label: 'Urgent', value: value.urgent),
          _MetricChip(label: 'SLA Breached', value: value.slaBreached),
          _MetricChip(label: 'Due Soon', value: value.slaDueSoon),
        ],
      ),
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('Unable to load metrics: $error'),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(child: Text(value.toString())),
      label: Text(label),
    );
  }
}

class _TicketFilterBar extends StatelessWidget {
  const _TicketFilterBar({
    required this.hoas,
    required this.hoaId,
    required this.status,
    required this.priority,
    required this.searchController,
    required this.onHoaChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onApply,
    required this.onReset,
  });

  final AsyncValue<List<HoaCommunity>> hoas;
  final String? hoaId;
  final String? status;
  final String? priority;
  final TextEditingController searchController;
  final ValueChanged<String?> onHoaChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onPriorityChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  static const _spacing = 12.0;
  static const _allValue = '__all__';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hoaFilter = hoas.when(
          data: (items) => _HoaFilter(hoas: items, value: hoaId, onChanged: onHoaChanged),
          loading: () => const SizedBox(height: 56, child: Center(child: LinearProgressIndicator())),
          error: (error, _) => Text('Unable to load HOAs: $error'),
        );
        final statusFilter = DropdownButtonFormField<String>(
          value: status ?? _allValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: _allValue, child: Text('All Statuses')),
            ...TicketStatus.values
                .where((item) => item != TicketStatus.waitingOnCustomer)
                .map(
                  (item) => DropdownMenuItem(value: item.databaseValue, child: Text(item.label)),
                ),
          ],
          onChanged: (value) => onStatusChanged(value == _allValue ? null : value),
        );
        final priorityFilter = DropdownButtonFormField<String>(
          value: priority ?? _allValue,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: _allValue, child: Text('All Priorities')),
            ...TicketPriority.values.map(
              (item) => DropdownMenuItem(value: item.name, child: Text(item.label)),
            ),
          ],
          onChanged: (value) => onPriorityChanged(value == _allValue ? null : value),
        );
        final search = TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Search',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => onApply(),
        );
        final actions = _FilterActions(onApply: onApply, onReset: onReset);

        if (constraints.maxWidth >= 1120) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: hoaFilter),
              const SizedBox(width: _spacing),
              SizedBox(width: 190, child: statusFilter),
              const SizedBox(width: _spacing),
              SizedBox(width: 170, child: priorityFilter),
              const SizedBox(width: _spacing),
              Expanded(flex: 3, child: search),
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
            SizedBox(width: fieldWidth, child: statusFilter),
            SizedBox(width: fieldWidth, child: priorityFilter),
            SizedBox(width: fieldWidth, child: search),
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
          OutlinedButton.icon(onPressed: onApply, icon: const Icon(Icons.search), label: const Text('Apply')),
          const SizedBox(width: 8),
          TextButton(onPressed: onReset, child: const Text('Reset')),
        ],
      ),
    );
  }
}

class _TicketTable extends StatelessWidget {
  const _TicketTable({required this.tickets});

  final List<ServiceTicket> tickets;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) return const Center(child: Text('No tickets found.'));

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: tickets.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          return ListTile(
            leading: Tooltip(
              message: '${ticket.slaState.label}: ${ticket.slaLabel}',
              child: Icon(
                Icons.confirmation_number_outlined,
                color: _slaColor(context, ticket),
              ),
            ),
            title: Text(ticket.subject),
            subtitle: Text(
              '${ticket.hoaLabel} - ${ticket.type.label} - ${ticket.requesterLabel} - ${ticket.slaLabel}',
            ),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(ticket.priority.label)),
                Chip(label: Text(ticket.status.label)),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.go('/admin/tickets/${ticket.id}'),
          );
        },
      ),
    );
  }
}
