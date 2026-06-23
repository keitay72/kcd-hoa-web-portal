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
      child: ColoredBox(
        color: const Color(0xFFF7FAF6),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          children: [
            _PortalOverview(
              home: snapshot,
            ),
            const SizedBox(height: 18),
            _CommunityOverview(home: snapshot),
            const SizedBox(height: 16),
            _ScheduleSection(schedules: snapshot.schedules),
            const SizedBox(height: 16),
            _AnnouncementSection(announcements: snapshot.announcements),
            const SizedBox(height: 16),
            _DocumentSection(
              tenantCode: tenantCode,
              documents: snapshot.documents,
            ),
            const SizedBox(height: 16),
            _BoardSection(boardMembers: snapshot.boardMembers),
            const SizedBox(height: 16),
            _ServiceIssueSection(
              tenantCode: tenantCode,
              tickets: snapshot.recentTickets,
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalOverview extends StatelessWidget {
  const _PortalOverview({
    required this.home,
  });

  final CustomerPortalHome home;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final serviceAddress = home.serviceLocation?.singleLine;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE9F4EF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1E3D9)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 16,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (serviceAddress != null)
                      _InfoPill(
                        icon: Icons.location_on_outlined,
                        label: serviceAddress,
                      )
                    else
                      Text(
                        home.account.displayName,
                        style: textTheme.bodyLarge,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _OverviewStat(
                icon: Icons.event_repeat_outlined,
                label: 'Schedules',
                value: home.schedules.length.toString(),
                color: const Color(0xFF2F6F9F),
              ),
              _OverviewStat(
                icon: Icons.description_outlined,
                label: 'Documents',
                value: home.documents.length.toString(),
                color: const Color(0xFF6F4AA8),
              ),
              _OverviewStat(
                icon: Icons.confirmation_number_outlined,
                label: 'Service issues',
                value: home.recentTickets.length.toString(),
                color: const Color(0xFF8A5A00),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC8DBD0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF256D46)),
          const SizedBox(width: 8),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E5DD)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _IconBubble(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(label),
              ],
            ),
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
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBubble(
                  icon: home.hasCommunityInfo
                      ? Icons.apartment_outlined
                      : Icons.account_circle_outlined,
                  color: const Color(0xFF00897B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    home.hasCommunityInfo ? 'Community' : 'Account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              home.account.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
      icon: Icons.event_repeat_outlined,
      accentColor: const Color(0xFF2F6F9F),
      emptyText: 'No community service schedules are published yet.',
      children: schedules
          .map(
            (schedule) => _PortalListTile(
              icon: Icons.event_repeat_outlined,
              iconColor: const Color(0xFF2F6F9F),
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
      icon: Icons.campaign_outlined,
      accentColor: const Color(0xFFA43D62),
      emptyText: 'No announcements are published right now.',
      children: announcements
          .map(
            (announcement) => _PortalListTile(
              icon: Icons.campaign_outlined,
              iconColor: const Color(0xFFA43D62),
              title: Text(announcement.title),
              subtitle: Text(announcement.body),
            ),
          )
          .toList(),
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.tenantCode,
    required this.documents,
  });

  final String tenantCode;
  final List<CustomerPortalDocument> documents;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Documents',
      icon: Icons.description_outlined,
      accentColor: const Color(0xFF6F4AA8),
      emptyText: 'No community documents are available yet.',
      children: documents
          .map(
            (document) => _PortalListTile(
              icon: Icons.description_outlined,
              iconColor: const Color(0xFF6F4AA8),
              title: Text(document.title),
              subtitle: Text(document.category),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => context.go(
                '/portal/$tenantCode/documents/${document.id}',
              ),
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
      icon: Icons.groups_outlined,
      accentColor: const Color(0xFF4E6E2E),
      emptyText: 'No board or community contacts have been published yet.',
      children: boardMembers
          .map(
            (member) => _PortalListTile(
              icon: Icons.groups_outlined,
              iconColor: const Color(0xFF4E6E2E),
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
      icon: Icons.confirmation_number_outlined,
      accentColor: const Color(0xFF8A5A00),
      emptyText: 'No service issues have been submitted yet.',
      trailing: FilledButton.icon(
        onPressed: () => context.go('/portal/$tenantCode/service-issue'),
        icon: const Icon(Icons.add),
        label: const Text('Report issue'),
      ),
      children: tickets
          .map(
            (ticket) => _PortalListTile(
              icon: _ticketIcon(ticket.type),
              iconColor: const Color(0xFF8A5A00),
              title: Text(ticket.subject),
              subtitle: Text(
                [
                  ticket.typeLabel,
                  'Ticket ${ticket.shortId}',
                  _formatDate(ticket.createdAt),
                ].join(' · '),
              ),
              trailing: _TicketStatusChip(
                status: ticket.status,
                label: ticket.statusLabel,
              ),
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
  const _TicketStatusChip({
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
      visualDensity: VisualDensity.compact,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.emptyText,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final String emptyText;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBubble(icon: icon, color: accentColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            if (children.isEmpty) Text(emptyText) else ...children,
          ],
        ),
      ),
    );
  }
}

class _PortalListTile extends StatelessWidget {
  const _PortalListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: const Color(0xFFF7FAF6),
        borderRadius: BorderRadius.circular(8),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          leading: _IconBubble(icon: icon, color: iconColor),
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 22),
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
