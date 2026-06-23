// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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
        _AttachmentCard(attachments: snapshot.attachments),
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
                _StatusChip(
                  status: ticket.status,
                  label: ticket.statusLabel,
                ),
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

class _AttachmentCard extends ConsumerWidget {
  const _AttachmentCard({required this.attachments});

  final List<CustomerPortalTicketAttachment> attachments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attachments',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (attachments.isEmpty)
              const Text('No attachments are available for this issue.')
            else
              ...attachments.map(
                (attachment) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_attachmentIcon(attachment.mimeType)),
                  title: Text(attachment.fileName),
                  subtitle: Text(
                    [
                      attachment.uploadedBy,
                      attachment.fileSizeLabel,
                      _formatDateTime(attachment.createdAt),
                    ].join(' · '),
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: 'Open',
                        onPressed: () => _openAttachment(
                          context,
                          ref,
                          attachment,
                          download: false,
                        ),
                        icon: const Icon(Icons.open_in_new),
                      ),
                      IconButton(
                        tooltip: 'Download',
                        onPressed: () => _openAttachment(
                          context,
                          ref,
                          attachment,
                          download: true,
                        ),
                        icon: const Icon(Icons.download_outlined),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(
    BuildContext context,
    WidgetRef ref,
    CustomerPortalTicketAttachment attachment, {
    required bool download,
  }) async {
    try {
      final url = await ref
          .read(supabaseClientProvider)
          .storage
          .from('ticket-attachments')
          .createSignedUrl(attachment.storagePath, 60 * 10);
      if (download) {
        final separator = url.contains('?') ? '&' : '?';
        final downloadUrl =
            '$url${separator}download=${Uri.encodeComponent(attachment.fileName)}';
        html.AnchorElement(href: downloadUrl)
          ..download = attachment.fileName
          ..target = '_blank'
          ..click();
      } else {
        html.window.open(url, '_blank');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We could not open this attachment.'),
          ),
        );
      }
    }
  }

  IconData _attachmentIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.attach_file;
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
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.radio_button_checked,
              size: 18,
              color: _ticketStatusStyle(
                event.newStatus ?? event.oldStatus ?? 'unknown',
              ).foreground,
            ),
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
  const _StatusChip({
    required this.status,
    required this.label,
  });

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = _ticketStatusStyle(status);
    return Chip(
      avatar: Icon(Icons.circle, size: 10, color: style.foreground),
      label: Text(label),
      backgroundColor: style.background,
      side: BorderSide(color: style.border),
      labelStyle: TextStyle(color: style.foreground),
    );
  }
}

class _TicketStatusStyle {
  const _TicketStatusStyle({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

_TicketStatusStyle _ticketStatusStyle(String status) {
  return switch (status) {
    'new' => const _TicketStatusStyle(
        background: Color(0xFFE8F5E9),
        border: Color(0xFFA5D6A7),
        foreground: Color(0xFF1B5E20),
      ),
    'open' => const _TicketStatusStyle(
        background: Color(0xFFE3F2FD),
        border: Color(0xFF90CAF9),
        foreground: Color(0xFF0D47A1),
      ),
    'assigned' => const _TicketStatusStyle(
        background: Color(0xFFEDE7F6),
        border: Color(0xFFB39DDB),
        foreground: Color(0xFF4527A0),
      ),
    'in_progress' => const _TicketStatusStyle(
        background: Color(0xFFFFF8E1),
        border: Color(0xFFFFD54F),
        foreground: Color(0xFF7A4F00),
      ),
    'resolved' => const _TicketStatusStyle(
        background: Color(0xFFE0F2F1),
        border: Color(0xFF80CBC4),
        foreground: Color(0xFF004D40),
      ),
    'closed' => const _TicketStatusStyle(
        background: Color(0xFFECEFF1),
        border: Color(0xFFB0BEC5),
        foreground: Color(0xFF37474F),
      ),
    _ => const _TicketStatusStyle(
        background: Color(0xFFF5F5F5),
        border: Color(0xFFBDBDBD),
        foreground: Color(0xFF424242),
      ),
  };
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
