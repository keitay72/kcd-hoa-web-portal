// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/admin_context.dart';
import '../domain/ticket.dart';
import 'ticket_assignment_dialog.dart';
import 'ticket_internal_note_dialog.dart';
import 'ticket_priority_dialog.dart';
import 'ticket_providers.dart';
import 'ticket_status_dialog.dart';

class TicketDetailPage extends ConsumerWidget {
  const TicketDetailPage({required this.ticketId, super.key});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(ticketDetailProvider(ticketId));

    return ticket.when(
      data: (item) => _TicketDetailContent(ticket: item),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/admin/tickets'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Tickets'),
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
  const _TicketDetailContent({required this.ticket});

  final ServiceTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _TicketHeader(ticket: ticket),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1040) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _TicketSummaryCard(ticket: ticket)),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: _TicketMetadataCard(ticket: ticket)),
                ],
              );
            }

            return Column(
              children: [
                _TicketSummaryCard(ticket: ticket),
                const SizedBox(height: 20),
                _TicketMetadataCard(ticket: ticket),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1040) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: 3, child: _TicketTimeline(ticketId: ticket.id)),
                  const SizedBox(width: 20),
                  Expanded(
                      flex: 2, child: _AttachmentViewer(ticketId: ticket.id)),
                ],
              );
            }

            return Column(
              children: [
                _TicketTimeline(ticketId: ticket.id),
                const SizedBox(height: 20),
                _AttachmentViewer(ticketId: ticket.id),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TicketHeader extends ConsumerWidget {
  const _TicketHeader({required this.ticket});

  final ServiceTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManageTicket = ref.watch(activeAdminAccessProvider).maybeWhen(
          data: (value) => value.can('tickets.update'),
          orElse: () => false,
        );

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => context.go('/admin/tickets'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Tickets'),
              ),
              const SizedBox(height: 8),
              Text(ticket.subject,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(ticket.status.label)),
                  Chip(label: Text(ticket.priority.label)),
                  Chip(label: Text(ticket.type.label)),
                ],
              ),
            ],
          ),
        ),
        if (canManageTicket)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openAssignDialog(context, ticket),
                icon: const Icon(Icons.assignment_ind_outlined),
                label: const Text('Assign'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openPriorityDialog(context, ticket),
                icon: const Icon(Icons.priority_high),
                label: const Text('Priority'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openInternalNoteDialog(context, ticket),
                icon: const Icon(Icons.sticky_note_2_outlined),
                label: const Text('Internal Note'),
              ),
              OutlinedButton.icon(
                onPressed: () => _runAutomation(context, ref, ticket),
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Run Automation'),
              ),
              FilledButton.icon(
                onPressed: () => _openStatusDialog(context, ticket),
                icon: const Icon(Icons.rule_outlined),
                label: const Text('Update Status'),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _openStatusDialog(BuildContext context, ServiceTicket ticket) {
    return showDialog<void>(
      context: context,
      builder: (_) => TicketStatusDialog(ticket: ticket),
    );
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

  Future<void> _runAutomation(
    BuildContext context,
    WidgetRef ref,
    ServiceTicket ticket,
  ) async {
    final result = await ref
        .read(ticketCommandProvider.notifier)
        .runWorkflowAutomation(ticket);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null
              ? 'Workflow automation failed.'
              : 'Workflow automation completed.',
        ),
      ),
    );
  }
}

class _TicketSummaryCard extends StatelessWidget {
  const _TicketSummaryCard({required this.ticket});

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
            Text('Ticket Details',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _InfoRow(label: 'Subject', value: ticket.subject),
            _InfoRow(label: 'Description', value: ticket.description),
            _InfoRow(label: 'Type', value: ticket.type.label),
            _InfoRow(label: 'Priority', value: ticket.priority.label),
            _InfoRow(label: 'Status', value: ticket.status.label),
            _InfoRow(
                label: 'SLA',
                value: '${ticket.slaState.label} - ${ticket.slaLabel}'),
            _InfoRow(label: 'Age', value: ticket.ageLabel),
          ],
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
            Text('Resident and HOA',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _InfoRow(label: 'HOA', value: ticket.hoaLabel),
            _InfoRow(label: 'Resident', value: ticket.requesterLabel),
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
  const _TicketTimeline({required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(ticketEventsProvider(ticketId));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            events.when(
              data: (items) {
                if (items.isEmpty) return const Text('No ticket events yet.');
                return Column(
                  children: items
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
    if (oldStatus != null && newStatus != null)
      return '$oldStatus to $newStatus';
    if (newStatus != null) return 'Status set to $newStatus';
    return 'Ticket event';
  }
}

class _AttachmentViewer extends ConsumerWidget {
  const _AttachmentViewer({required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(ticketAttachmentsProvider(ticketId));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attachments', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            attachments.when(
              data: (items) {
                if (items.isEmpty)
                  return const Text('No attachments uploaded.');
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
        ),
      ),
    );
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
