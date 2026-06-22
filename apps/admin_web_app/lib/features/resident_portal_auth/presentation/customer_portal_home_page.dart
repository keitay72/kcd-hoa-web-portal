import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/customer_portal_home.dart';
import 'customer_portal_home_providers.dart';
import 'resident_portal_labels.dart';

class CustomerPortalHomePage extends ConsumerWidget {
  const CustomerPortalHomePage({required this.tenantCode, super.key});

  final String tenantCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portalTitle = customerPortalTitle(tenantCode);
    final home = ref.watch(customerPortalHomeProvider);

    return Title(
      title: portalTitle,
      color: Theme.of(context).colorScheme.primary,
      child: Scaffold(
        appBar: AppBar(
          title: Text(portalTitle),
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
        body: home.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _HomeError(
            error: error,
            onRetry: () => ref.invalidate(customerPortalHomeProvider),
          ),
          data: (snapshot) => _HomeContent(
            tenantCode: tenantCode,
            snapshot: snapshot,
            onRefresh: () async => ref.invalidate(customerPortalHomeProvider),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.tenantCode,
    required this.snapshot,
    required this.onRefresh,
  });

  final String tenantCode;
  final CustomerPortalHome snapshot;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Welcome to your customer portal',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.serviceLocation?.singleLine ??
                snapshot.account.displayName,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          _CommunityOverview(home: snapshot),
          const SizedBox(height: 16),
          _ScheduleSection(schedules: snapshot.schedules),
          const SizedBox(height: 16),
          _AnnouncementSection(announcements: snapshot.announcements),
          const SizedBox(height: 16),
          _DocumentSection(documents: snapshot.documents),
          const SizedBox(height: 16),
          _BoardSection(boardMembers: snapshot.boardMembers),
          const SizedBox(height: 16),
          _ServiceIssueSection(
            tenantCode: tenantCode,
            tickets: snapshot.recentTickets,
          ),
        ],
      ),
    );
  }
}

class _CommunityOverview extends StatelessWidget {
  const _CommunityOverview({required this.home});

  final CustomerPortalHome home;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              home.hasCommunityInfo ? 'Community' : 'Account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(home.account.displayName),
            if (home.account.accountNumber != null) ...[
              const SizedBox(height: 4),
              Text('Account ${home.account.accountNumber}'),
            ],
            if (home.hasCommunityInfo) ...[
              const SizedBox(height: 12),
              const Text(
                'Community-wide documents, announcements, schedules, and contacts are shown here because this service address belongs to a community account.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({required this.schedules});

  final List<CustomerPortalSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Service schedule',
      emptyText: 'No community service schedules are published yet.',
      children: schedules
          .map(
            (schedule) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_repeat_outlined),
              title: Text(schedule.serviceTypeLabel),
              subtitle: Text(
                [
                  schedule.scheduleRule ?? schedule.serviceDayLabel,
                  schedule.routeName,
                  schedule.notes,
                ]
                    .whereType<String>()
                    .where((part) => part.isNotEmpty)
                    .join(' · '),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AnnouncementSection extends StatelessWidget {
  const _AnnouncementSection({required this.announcements});

  final List<CustomerPortalAnnouncement> announcements;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Announcements',
      emptyText: 'No announcements are published right now.',
      children: announcements
          .map(
            (announcement) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.campaign_outlined),
              title: Text(announcement.title),
              subtitle: Text(announcement.body),
            ),
          )
          .toList(),
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({required this.documents});

  final List<CustomerPortalDocument> documents;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Documents',
      emptyText: 'No community documents are available yet.',
      children: documents
          .map(
            (document) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(document.title),
              subtitle: Text(document.category),
            ),
          )
          .toList(),
    );
  }
}

class _BoardSection extends StatelessWidget {
  const _BoardSection({required this.boardMembers});

  final List<CustomerPortalBoardMember> boardMembers;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Community contacts',
      emptyText: 'No board or community contacts have been published yet.',
      children: boardMembers
          .map(
            (member) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.groups_outlined),
              title: Text(member.name),
              subtitle: Text(
                [
                  member.roleName,
                  if (member.email != null) member.email,
                  if (member.phone != null) member.phone,
                ]
                    .whereType<String>()
                    .where((part) => part.isNotEmpty)
                    .join(' · '),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ServiceIssueSection extends StatelessWidget {
  const _ServiceIssueSection({
    required this.tenantCode,
    required this.tickets,
  });

  final String tenantCode;
  final List<CustomerPortalTicket> tickets;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Service issues',
      emptyText: 'No service issues have been submitted yet.',
      trailing: FilledButton.icon(
        onPressed: () => context.go('/portal/$tenantCode/service-issue'),
        icon: const Icon(Icons.add),
        label: const Text('Report issue'),
      ),
      children: tickets
          .map(
            (ticket) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_ticketIcon(ticket.type)),
              title: Text(ticket.subject),
              subtitle: Text(
                [
                  ticket.typeLabel,
                  ticket.statusLabel,
                  'Ticket ${ticket.shortId}',
                  _formatDate(ticket.createdAt),
                ].join(' · '),
              ),
              trailing: _TicketStatusChip(status: ticket.statusLabel),
              onTap: () => context.go(
                '/portal/$tenantCode/service-issues/${ticket.id}',
              ),
            ),
          )
          .toList(),
    );
  }

  IconData _ticketIcon(String type) {
    return switch (type) {
      'missed_pickup' => Icons.delete_sweep_outlined,
      'damaged_cart' => Icons.delete_outline,
      'complaint' => Icons.report_problem_outlined,
      _ => Icons.support_agent_outlined,
    };
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final month = switch (local.month) {
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
    return '$month ${local.day}';
  }
}

class _TicketStatusChip extends StatelessWidget {
  const _TicketStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(status),
      visualDensity: VisualDensity.compact,
      backgroundColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.emptyText,
    required this.children,
    this.trailing,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;
  final Widget? trailing;

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
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            if (children.isEmpty) Text(emptyText) else ...children,
          ],
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.error, required this.onRetry});

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
            Text('Unable to load customer portal: $error'),
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
