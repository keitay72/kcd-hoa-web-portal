// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/admin_context.dart';
import '../domain/ticket.dart';
import '../domain/ticket_inputs.dart';
import 'ticket_assignment_dialog.dart';
import 'ticket_customer_update_dialog.dart';
import 'ticket_internal_note_dialog.dart';
import 'ticket_priority_dialog.dart';
import 'ticket_providers.dart';

class TicketDetailPage extends ConsumerWidget {
  const TicketDetailPage({
    required this.ticketId,
    this.backSource,
    super.key,
  });

  final String ticketId;
  final String? backSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(ticketDetailProvider(ticketId));

    return ticket.when(
      data: (item) => _TicketDetailContent(
        ticket: item,
        backSource: backSource,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () =>
                  context.go(_backDestination(ref, backSource).path),
              icon: const Icon(Icons.arrow_back),
              label: Text(_backDestination(ref, backSource).label),
            ),
            const SizedBox(height: 16),
            Text('Unable to load ticket: $error'),
          ],
        ),
      ),
    );
  }
}

class _TicketDetailContent extends ConsumerWidget {
  const _TicketDetailContent({
    required this.ticket,
    required this.backSource,
  });

  final ServiceTicket ticket;
  final String? backSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManageTicket = ref.watch(activeAdminAccessProvider).maybeWhen(
          data: (value) => value.can('tickets.update'),
          orElse: () => false,
        );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _TicketHeader(ticket: ticket, backSource: backSource),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1040) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: _TicketWorkspaceCard(
                          ticket: ticket,
                          canManageTicket: canManageTicket,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: _TicketMetadataCard(ticket: ticket),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _TicketTimeline(
                    ticket: ticket,
                    showInternalNotes: canManageTicket,
                    canManageTicket: canManageTicket,
                  ),
                ],
              );
            }

            return Column(
              children: [
                _TicketWorkspaceCard(
                  ticket: ticket,
                  canManageTicket: canManageTicket,
                ),
                const SizedBox(height: 20),
                _TicketMetadataCard(ticket: ticket),
                const SizedBox(height: 20),
                _TicketTimeline(
                  ticket: ticket,
                  showInternalNotes: canManageTicket,
                  canManageTicket: canManageTicket,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TicketWorkspaceCard extends StatelessWidget {
  const _TicketWorkspaceCard({
    required this.ticket,
    required this.canManageTicket,
  });

  final ServiceTicket ticket;
  final bool canManageTicket;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useColumns = constraints.maxWidth >= 720;
            final details = _TicketDetailsSection(ticket: ticket);
            final workflow = _TicketWorkflowSection(
              ticket: ticket,
              canManageTicket: canManageTicket,
            );
            final attachments = _InlineAttachmentSection(ticketId: ticket.id);

            if (!useColumns) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  workflow,
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  attachments,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: details),
                const SizedBox(width: 28),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      workflow,
                      const SizedBox(height: 24),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      attachments,
                    ],
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

class _TicketDetailsSection extends StatelessWidget {
  const _TicketDetailsSection({required this.ticket});

  final ServiceTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ticket Details', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _InfoRow(label: 'Subject', value: ticket.subject),
        _InfoRow(label: 'Description', value: ticket.description),
        _InfoRow(label: 'Type', value: ticket.type.label),
        _InfoRow(
          label: 'SLA',
          value: '${ticket.slaState.label} - ${ticket.slaLabel}',
        ),
        _InfoRow(label: 'Age', value: ticket.ageLabel),
      ],
    );
  }
}

class _TicketWorkflowSection extends StatelessWidget {
  const _TicketWorkflowSection({
    required this.ticket,
    required this.canManageTicket,
  });

  final ServiceTicket ticket;
  final bool canManageTicket;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Workflow', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _InlineStatusPicker(
          ticket: ticket,
          canManageTicket: canManageTicket,
        ),
        const Divider(height: 32),
        _WorkflowRow(
          icon: Icons.priority_high,
          label: 'Priority',
          value: ticket.priority.label,
          accent: _priorityColor(ticket.priority),
          actionLabel: 'Change',
          enabled: canManageTicket,
          onPressed: () => _openPriorityDialog(context, ticket),
        ),
        const Divider(height: 28),
        _WorkflowRow(
          icon: Icons.assignment_ind_outlined,
          label: 'Assignment',
          value: 'Route to CSR or dispatch',
          accent: Theme.of(context).colorScheme.primary,
          actionLabel: 'Assign',
          enabled: canManageTicket,
          onPressed: () => _openAssignDialog(context, ticket),
        ),
      ],
    );
  }
}

class _InlineAttachmentSection extends ConsumerWidget {
  const _InlineAttachmentSection({required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(ticketAttachmentsProvider(ticketId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_file),
            const SizedBox(width: 8),
            Text('Attachments', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        attachments.when(
          data: (items) {
            if (items.isEmpty) {
              return const Text('No attachments uploaded.');
            }
            return Column(
              children: items
                  .map((item) => _AttachmentTile(attachment: item))
                  .toList(),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('Unable to load attachments: $error'),
        ),
      ],
    );
  }
}

Future<void> _openAssignDialog(BuildContext context, ServiceTicket ticket) {
  return showDialog<void>(
    context: context,
    builder: (_) => TicketAssignmentDialog(ticket: ticket),
  );
}

Future<void> _openPriorityDialog(BuildContext context, ServiceTicket ticket) {
  return showDialog<void>(
    context: context,
    builder: (_) => TicketPriorityDialog(ticket: ticket),
  );
}

Future<void> _openInternalNoteDialog(
    BuildContext context, ServiceTicket ticket) {
  return showDialog<void>(
    context: context,
    builder: (_) => TicketInternalNoteDialog(ticket: ticket),
  );
}

Future<void> _openCustomerUpdateDialog(
    BuildContext context, ServiceTicket ticket) {
  return showDialog<void>(
    context: context,
    builder: (_) => TicketCustomerUpdateDialog(ticket: ticket),
  );
}

class _BackDestination {
  const _BackDestination({required this.path, required this.label});

  final String path;
  final String label;
}

_BackDestination _backDestination(WidgetRef ref, String? source) {
  switch (source) {
    case 'csr':
      return const _BackDestination(
        path: '/admin/tickets/csr',
        label: 'Back to CSR Queue',
      );
    case 'dispatch':
      return const _BackDestination(
        path: '/admin/tickets/dispatch',
        label: 'Back to Dispatch Queue',
      );
    case 'urgent':
      return const _BackDestination(
        path: '/admin/tickets/urgent',
        label: 'Back to Urgent Queue',
      );
    case 'aging':
      return const _BackDestination(
        path: '/admin/tickets/aging',
        label: 'Back to Aging Queue',
      );
  }

  final activeContext = ref.read(activeAdminContextProvider).asData?.value;
  return _BackDestination(
    path:
        activeContext?.isHoa == true ? '/admin/hoa/tickets' : '/admin/tickets',
    label: 'Back to Tickets',
  );
}

class _TicketHeader extends ConsumerWidget {
  const _TicketHeader({
    required this.ticket,
    required this.backSource,
  });

  final ServiceTicket ticket;
  final String? backSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backDestination = _backDestination(ref, backSource);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => context.go(backDestination.path),
          icon: const Icon(Icons.arrow_back),
          label: Text(backDestination.label),
        ),
        const SizedBox(height: 8),
        Text(ticket.subject, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ToneChip(label: ticket.status.label, color: _statusColor(ticket)),
            _ToneChip(
              label: ticket.priority.label,
              color: _priorityColor(ticket.priority),
            ),
            _ToneChip(
              label: ticket.type.label,
              color: Theme.of(context).colorScheme.secondary,
            ),
            _ToneChip(
              label: ticket.slaLabel,
              color: _slaColor(ticket.slaState),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkflowRow extends StatelessWidget {
  const _WorkflowRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.actionLabel,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String actionLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        TextButton(
          onPressed: enabled ? onPressed : null,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _InlineStatusPicker extends ConsumerWidget {
  const _InlineStatusPicker({
    required this.ticket,
    required this.canManageTicket,
  });

  final ServiceTicket ticket;
  final bool canManageTicket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commandState = ref.watch(ticketCommandProvider);
    final isBusy = commandState.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _statusColor(ticket).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.rule_outlined, color: _statusColor(ticket)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(
                    ticket.status.label,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TicketStatus.values.map((status) {
            final selected = status == ticket.status;
            final accent = _statusColorForStatus(status);
            return ChoiceChip(
              label: Text(status.label),
              selected: selected,
              showCheckmark: selected,
              selectedColor: accent.withOpacity(0.18),
              side: BorderSide(
                color: selected ? accent : Theme.of(context).dividerColor,
              ),
              labelStyle: TextStyle(
                color: selected ? accent : null,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              onSelected: !canManageTicket || isBusy || selected
                  ? null
                  : (_) => _setStatus(context, ref, status),
            );
          }).toList(),
        ),
        if (commandState.hasError) ...[
          const SizedBox(height: 10),
          Text(
            commandState.error.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    TicketStatus status,
  ) async {
    final result = await ref.read(ticketCommandProvider.notifier).updateStatus(
          TicketStatusUpdateInput(
            ticket: ticket,
            status: status,
          ),
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Unable to update status.'
              : 'Ticket status changed to ${status.label}.',
        ),
      ),
    );
  }
}

class _TicketMetadataCard extends StatelessWidget {
  const _TicketMetadataCard({required this.ticket});

  final ServiceTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer and Community',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _InfoRow(label: 'Community', value: ticket.hoaLabel),
            _InfoRow(label: 'Customer', value: ticket.requesterLabel),
            _InfoRow(
                label: 'Email',
                value: ticket.requesterEmail ?? 'Not available'),
            _InfoRow(label: 'Address', value: ticket.addressLabel),
            _InfoRow(
                label: 'Created', value: _formatDateTime(ticket.createdAt)),
            _InfoRow(
                label: 'Updated', value: _formatDateTime(ticket.updatedAt)),
          ],
        ),
      ),
    );
  }
}

class _TicketTimeline extends ConsumerWidget {
  const _TicketTimeline({
    required this.ticket,
    required this.showInternalNotes,
    required this.canManageTicket,
  });

  final ServiceTicket ticket;
  final bool showInternalNotes;
  final bool canManageTicket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(ticketEventsProvider(ticket.id));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
                if (canManageTicket)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openInternalNoteDialog(context, ticket),
                        icon: const Icon(Icons.sticky_note_2_outlined),
                        label: const Text('Internal note'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () =>
                            _openCustomerUpdateDialog(context, ticket),
                        icon: const Icon(Icons.forum_outlined),
                        label: const Text('Customer update'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            events.when(
              data: (items) {
                final visibleItems = showInternalNotes
                    ? items
                    : items.where((event) => !event.isInternalNote).toList();
                if (visibleItems.isEmpty) {
                  return const Text('No ticket events yet.');
                }
                return Column(
                  children: visibleItems
                      .map((event) => _TimelineItem(event: event))
                      .toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Unable to load timeline: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.event});

  final TicketEvent event;

  @override
  Widget build(BuildContext context) {
    final transition = _transitionLabel(event);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transition,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                    '${event.actorLabel} on ${_formatDateTime(event.createdAt)}'),
                if (event.note != null && event.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (event.isInternalNote)
                        const Chip(label: Text('Internal')),
                      if (event.isAssignment)
                        const Chip(label: Text('Assignment')),
                      if (event.isAutomation)
                        const Chip(label: Text('Automation')),
                    ],
                  ),
                  if (event.isInternalNote ||
                      event.isAssignment ||
                      event.isAutomation)
                    const SizedBox(height: 6),
                  Text(event.displayNote),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _transitionLabel(TicketEvent event) {
    final oldStatus = event.oldStatus?.label;
    final newStatus = event.newStatus?.label;
    if (oldStatus != null && newStatus != null) {
      return '$oldStatus to $newStatus';
    }
    if (newStatus != null) return 'Status set to $newStatus';
    return 'Ticket event';
  }
}

class _AttachmentTile extends ConsumerWidget {
  const _AttachmentTile({required this.attachment});

  final TicketAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.attach_file),
      title: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${attachment.mimeType} - ${attachment.fileSizeLabel} - ${attachment.scanStatus}',
      ),
      trailing: IconButton(
        tooltip: 'Open attachment',
        icon: const Icon(Icons.open_in_new),
        onPressed: () => _openAttachment(context, ref),
      ),
    );
  }

  Future<void> _openAttachment(BuildContext context, WidgetRef ref) async {
    try {
      final url = await ref
          .read(ticketRepositoryProvider)
          .createAttachmentUrl(attachment);
      html.window.open(url, '_blank');
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open attachment: $error')),
      );
    }
  }
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

Color _statusColor(ServiceTicket ticket) {
  return _statusColorForStatus(ticket.status);
}

Color _statusColorForStatus(TicketStatus status) {
  return switch (status) {
    TicketStatus.newTicket => Colors.blueGrey,
    TicketStatus.open => Colors.blue,
    TicketStatus.assigned => Colors.indigo,
    TicketStatus.inProgress => Colors.orange,
    TicketStatus.waitingOnCustomer => Colors.purple,
    TicketStatus.resolved => Colors.green,
    TicketStatus.closed => Colors.grey,
  };
}

Color _priorityColor(TicketPriority priority) {
  return switch (priority) {
    TicketPriority.low => Colors.blueGrey,
    TicketPriority.normal => Colors.green,
    TicketPriority.high => Colors.orange,
    TicketPriority.urgent => Colors.red,
  };
}

Color _slaColor(SlaState state) {
  return switch (state) {
    SlaState.onTrack => Colors.green,
    SlaState.dueSoon => Colors.orange,
    SlaState.breached => Colors.red,
    SlaState.complete => Colors.blueGrey,
  };
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(value.isEmpty ? 'Not provided' : value),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final date =
      '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}/${local.year}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
