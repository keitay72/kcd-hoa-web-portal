import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/admin_context.dart';
import '../../../core/subscriptions/subscription_providers.dart';
import '../../../core/subscriptions/tenant_entitlements.dart';
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
    final access = ref.watch(activeAdminAccessProvider);
    final csrEntitlement = ref.watch(adminFeatureEntitlementProvider(
        TenantFeature.advancedTicketManagement));

    final canReadTickets = access.maybeWhen(
      data: (value) => value.can('tickets.read'),
      orElse: () => false,
    );
    final canOpenCsrDashboard = canReadTickets &&
        csrEntitlement.maybeWhen(
          data: (result) => result.isEnabled,
          orElse: () => false,
        );

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
              Text('Tickets',
                  style: Theme.of(context).textTheme.headlineMedium),
              if (canOpenCsrDashboard)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => context.go('/admin/tickets/csr'),
                      icon: const Icon(Icons.support_agent),
                      label: const Text('CSR Queue'),
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
              error: (error, _) =>
                  Center(child: Text('Unable to load tickets: $error')),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 24,
            constraints: const BoxConstraints(minWidth: 24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              value.toString(),
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
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
          data: (items) =>
              _HoaFilter(hoas: items, value: hoaId, onChanged: onHoaChanged),
          loading: () => const SizedBox(
              height: 56, child: Center(child: LinearProgressIndicator())),
          error: (error, _) => Text('Unable to load HOAs: $error'),
        );
        final statusFilter = DropdownButtonFormField<String>(
          value: status ?? _allValue,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Status',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
                value: _allValue, child: Text('All Statuses')),
            ...TicketStatus.values
                .where((item) => item != TicketStatus.waitingOnCustomer)
                .map(
                  (item) => DropdownMenuItem(
                      value: item.databaseValue, child: Text(item.label)),
                ),
          ],
          onChanged: (value) =>
              onStatusChanged(value == _allValue ? null : value),
        );
        final priorityFilter = DropdownButtonFormField<String>(
          value: priority ?? _allValue,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Priority',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(
                value: _allValue, child: Text('All Priorities')),
            ...TicketPriority.values.map(
              (item) =>
                  DropdownMenuItem(value: item.name, child: Text(item.label)),
            ),
          ],
          onChanged: (value) =>
              onPriorityChanged(value == _allValue ? null : value),
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
  const _HoaFilter(
      {required this.hoas, required this.value, required this.onChanged});

  final List<HoaCommunity> hoas;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Community',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All Communities'),
        ),
        ...hoas.map(
          (hoa) => DropdownMenuItem<String?>(
            value: hoa.id,
            child: Text('${hoa.name} (${hoa.code})',
                overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      selectedItemBuilder: (context) {
        return [
          const Text('All Communities', overflow: TextOverflow.ellipsis),
          ...hoas.map(
            (hoa) => Text('${hoa.name} (${hoa.code})',
                overflow: TextOverflow.ellipsis),
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
          OutlinedButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.search),
              label: const Text('Apply')),
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
    final scheme = Theme.of(context).colorScheme;
    if (tickets.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 42,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'No tickets found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Adjust the filters or search to find matching service issues.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: tickets.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          return _TicketListRow(ticket: ticket);
        },
      ),
    );
  }
}

class _TicketListRow extends StatelessWidget {
  const _TicketListRow({required this.ticket});

  final ServiceTicket ticket;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slaColor = _slaColor(context, ticket);
    final ticketId =
        ticket.id.length <= 8 ? ticket.id : ticket.id.substring(0, 8);

    return InkWell(
      onTap: () => context.go('/admin/tickets/${ticket.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 820;
            final titleBlock = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: '${ticket.slaState.label}: ${ticket.slaLabel}',
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: slaColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.confirmation_number_outlined,
                      color: slaColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket.subject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (compact) const SizedBox(width: 8),
                          if (compact)
                            _TicketBadge(
                              label: ticket.status.label,
                              style: _statusBadgeStyle(context, ticket.status),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          _TicketMeta(
                            icon: Icons.tag_outlined,
                            label: 'Ticket $ticketId',
                          ),
                          _TicketMeta(
                            icon: Icons.category_outlined,
                            label: ticket.type.label,
                          ),
                          _TicketMeta(
                            icon: Icons.person_outline,
                            label: ticket.requesterLabel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _TicketMeta(
                            icon: Icons.apartment_outlined,
                            label: ticket.hoaLabel,
                          ),
                          _TicketMeta(
                            icon: Icons.location_on_outlined,
                            label: ticket.addressLabel,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );

            final statusBlock = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _TicketBadge(
                  label: ticket.priority.label,
                  style: _priorityBadgeStyle(context, ticket.priority),
                ),
                if (!compact)
                  _TicketBadge(
                    label: ticket.status.label,
                    style: _statusBadgeStyle(context, ticket.status),
                  ),
                _TicketBadge(
                  label: ticket.slaLabel,
                  style: _BadgeStyle(
                    foreground: slaColor,
                    background: slaColor.withOpacity(0.10),
                    border: slaColor.withOpacity(0.35),
                  ),
                  icon: Icons.timer_outlined,
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 54),
                    child: statusBlock,
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: titleBlock),
                const SizedBox(width: 16),
                SizedBox(
                  width: 320,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: statusBlock,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TicketMeta extends StatelessWidget {
  const _TicketMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _TicketBadge extends StatelessWidget {
  const _TicketBadge({
    required this.label,
    required this.style,
    this.icon,
  });

  final String label;
  final _BadgeStyle style;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: style.foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: style.foreground,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

_BadgeStyle _statusBadgeStyle(BuildContext context, TicketStatus status) {
  final scheme = Theme.of(context).colorScheme;
  final color = switch (status) {
    TicketStatus.newTicket => scheme.secondary,
    TicketStatus.open => scheme.primary,
    TicketStatus.assigned => const Color(0xff3347a8),
    TicketStatus.inProgress => const Color(0xffb26a00),
    TicketStatus.waitingOnCustomer => const Color(0xff7c3aed),
    TicketStatus.resolved => const Color(0xff2f855a),
    TicketStatus.closed => scheme.onSurfaceVariant,
  };
  return _BadgeStyle(
    foreground: color,
    background: color.withOpacity(0.10),
    border: color.withOpacity(0.35),
  );
}

_BadgeStyle _priorityBadgeStyle(BuildContext context, TicketPriority priority) {
  final scheme = Theme.of(context).colorScheme;
  final color = switch (priority) {
    TicketPriority.low => scheme.onSurfaceVariant,
    TicketPriority.normal => scheme.primary,
    TicketPriority.high => const Color(0xffb7791f),
    TicketPriority.urgent => scheme.error,
  };
  return _BadgeStyle(
    foreground: color,
    background: color.withOpacity(0.10),
    border: color.withOpacity(0.35),
  );
}
