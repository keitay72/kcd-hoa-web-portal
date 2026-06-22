import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/customer_portal_home.dart';
import 'customer_portal_home_providers.dart';
import 'resident_portal_labels.dart';

class CustomerTicketDetailPage extends ConsumerWidget {
  const CustomerTicketDetailPage({
    required this.tenantCode,
    required this.ticketId,
    super.key,
  });

  final String tenantCode;
  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portalTitle = customerPortalTitle(tenantCode);
    final detail = ref.watch(customerPortalTicketDetailProvider(ticketId));

    return Title(
      title: '$portalTitle - Service Issue',
      color: Theme.of(context).colorScheme.primary,
      child: Scaffold(
        appBar: AppBar(
          title: Text(portalTitle),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => context.go('/portal/$tenantCode/home'),
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                await ref.read(supabaseClientProvider).auth.signOut();
                ref.invalidate(authStateProvider);
                ref.invalidate(currentUserProvider);
                if (context.mounted) {
                  context.replace('/portal/$tenantCode/sign-in');
                }
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _TicketDetailError(
            error: error,
            onRetry: () =>
                ref.invalidate(customerPortalTicketDetailProvider(ticketId)),
          ),
          data: (snapshot) => _TicketDetailContent(snapshot: snapshot),
        ),
      ),
    );
  }
}

class _TicketDetailContent extends StatelessWidget {
  const _TicketDetailContent({required this.snapshot});

  final CustomerPortalTicketDetail snapshot;

  @override
  Widget build(BuildContext context) {
    final ticket = snapshot.ticket;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Service issue',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          ticket.subject,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        _TicketSummaryCard(ticket: ticket),
        const SizedBox(height: 16),
        _TimelineCard(events: snapshot.events),
      ],
    );
  }
}

class _TicketSummaryCard extends StatelessWidget {
  const _TicketSummaryCard({required this.ticket});

  final CustomerPortalTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ticket ${ticket.shortId}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _StatusChip(status: ticket.statusLabel),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(label: 'Type', value: ticket.typeLabel),
            _DetailRow(label: 'Priority', value: ticket.priorityLabel),
            _DetailRow(
                label: 'Submitted', value: _formatDateTime(ticket.createdAt)),
            const SizedBox(height: 12),
            Text('Details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(ticket.description),
          ],
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events});

  final List<CustomerPortalTicketEvent> events;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status history',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (events.isEmpty)
              const Text('No updates have been posted yet.')
            else
              ...events.map((event) => _TimelineItem(event: event)),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.event});

  final CustomerPortalTicketEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.radio_button_checked, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                    '${event.actorLabel} · ${_formatDateTime(event.createdAt)}'),
                if (event.displayNote.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(event.displayNote),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(status),
      backgroundColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
    );
  }
}

class _TicketDetailError extends StatelessWidget {
  const _TicketDetailError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Unable to load service issue: $error'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
          ? local.hour - 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${_month(local.month)} ${local.day}, ${local.year} '
      '$hour:$minute $suffix';
}

String _month(int value) {
  return switch (value) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
}
