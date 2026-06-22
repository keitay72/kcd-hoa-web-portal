import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/admin_context.dart';
import '../domain/analytics_dashboard.dart';
import 'analytics_dashboard_providers.dart';

int _tenantVisibleAttentionCount(TenantLaunchReadinessMetrics metrics) {
  final visibleCount = metrics.setupAttentionTotal - metrics.stripePending;
  return visibleCount < 0 ? 0 : visibleCount;
}

class AnalyticsDashboardPage extends ConsumerWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(analyticsDashboardProvider);
    final access = ref.watch(activeAdminAccessProvider);

    return access.when(
      data: (resolvedAccess) {
        final isTenantScoped = resolvedAccess.hasTenantRoleAssignment &&
            !resolvedAccess.hasGlobalRoleAssignment;
        return dashboard.when(
          data: (snapshot) => _AnalyticsDashboardContent(
            snapshot: snapshot,
            isTenantScoped: isTenantScoped,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _DashboardError(error: error),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _DashboardError(error: error),
    );
  }
}

class _AnalyticsDashboardContent extends ConsumerWidget {
  const _AnalyticsDashboardContent({
    required this.snapshot,
    required this.isTenantScoped,
  });

  final AnalyticsDashboardSnapshot snapshot;
  final bool isTenantScoped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(analyticsDashboardProvider);
        await ref.read(analyticsDashboardProvider.future);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pagePadding = constraints.maxWidth < 600 ? 16.0 : 24.0;

          return ListView(
            padding: EdgeInsets.all(pagePadding),
            children: [
              _DashboardHeader(
                loadedAt: snapshot.loadedAt,
                isTenantScoped: isTenantScoped,
              ),
              const SizedBox(height: 20),
              _SectionHeader(
                title: isTenantScoped ? 'Portal Metrics' : 'Platform Metrics',
                subtitle: isTenantScoped
                    ? 'Current customer portal activity for your organization.'
                    : 'Current customer portal health across tenant operations.',
              ),
              const SizedBox(height: 12),
              _MetricGrid(
                cards: [
                  _MetricCardData(
                    label:
                        isTenantScoped ? 'Community Accounts' : 'Communities',
                    value: snapshot.platformMetrics.totalHoas,
                    icon: Icons.domain_outlined,
                    color: Colors.teal,
                    onTapPath: '/admin/hoas',
                  ),
                  _MetricCardData(
                    label: isTenantScoped
                        ? 'Active Customer Users'
                        : 'Active Customers',
                    value: snapshot.platformMetrics.activeResidents,
                    icon: Icons.people_outline,
                    color: Colors.green,
                    onTapPath: '/admin/resident-verification',
                  ),
                  _MetricCardData(
                    label: 'Pending Customer Verifications',
                    value:
                        snapshot.platformMetrics.pendingResidentVerifications,
                    icon: Icons.verified_user_outlined,
                    color: Colors.orange,
                    onTapPath: '/admin/resident-verification',
                  ),
                  if (!isTenantScoped)
                    _MetricCardData(
                      label: 'Active Activation Codes',
                      value: snapshot.platformMetrics.activeActivationCodes,
                      icon: Icons.password_outlined,
                      color: Colors.indigo,
                      onTapPath: '/admin/activation-codes',
                    ),
                  _MetricCardData(
                    label: 'Documents',
                    value: snapshot.platformMetrics.documentsCount,
                    icon: Icons.description_outlined,
                    color: Colors.blue,
                    onTapPath: '/admin/documents',
                  ),
                  _MetricCardData(
                    label: 'Announcements',
                    value: snapshot.platformMetrics.announcementsCount,
                    icon: Icons.campaign_outlined,
                    color: Colors.pink,
                    onTapPath: '/admin/announcements',
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (!isTenantScoped ||
                  _tenantVisibleAttentionCount(
                          snapshot.launchReadinessMetrics) >
                      0) ...[
                _SectionHeader(
                  title: isTenantScoped
                      ? 'Portal Readiness'
                      : 'Tenant Launch Readiness',
                  subtitle: isTenantScoped
                      ? 'Billing, staffing, and onboarding items for this portal.'
                      : 'Subscription, billing, staffing, and onboarding blockers across SaaS tenants.',
                ),
                const SizedBox(height: 12),
                _TenantLaunchReadinessPanel(
                  metrics: snapshot.launchReadinessMetrics,
                  isTenantScoped: isTenantScoped,
                ),
                const SizedBox(height: 28),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1080;
                  final ticketPanel = _TicketMetricsPanel(
                    metrics: snapshot.ticketMetrics,
                  );
                  final operationsPanel = _OperationalMetricsPanel(
                    metrics: snapshot.operationalMetrics,
                  );

                  if (!isWide) {
                    return Column(
                      children: [
                        ticketPanel,
                        const SizedBox(height: 20),
                        operationsPanel,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: ticketPanel),
                      const SizedBox(width: 20),
                      Expanded(child: operationsPanel),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              _SectionHeader(
                title: 'Recent Activity',
                subtitle: isTenantScoped
                    ? 'Latest activity for this management portal.'
                    : 'Latest operational events from the live Supabase data set.',
              ),
              const SizedBox(height: 12),
              _RecentActivityGrid(snapshot: snapshot),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.loadedAt,
    required this.isTenantScoped,
  });

  final DateTime loadedAt;
  final bool isTenantScoped;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isTenantScoped
                  ? 'Management Dashboard'
                  : 'Analytics & Operations Dashboard',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              isTenantScoped
                  ? 'Customer accounts, tickets, content, and readiness for your organization.'
                  : 'Platform, ticket, staffing, and activity metrics across tenant portal operations.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
        Chip(
          avatar: const Icon(Icons.sync_outlined, size: 18),
          label: Text('Loaded ${_formatDateTime(loadedAt)}'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.cards});

  final List<_MetricCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1280
            ? 3
            : width >= 820
                ? 2
                : 1;
        final cardWidth = (width - ((columns - 1) * 12)) / columns;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((card) =>
                  SizedBox(width: cardWidth, child: _MetricCard(data: card)))
              .toList(),
        );
      },
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTapPath,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String? onTapPath;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: data.color.withOpacity(0.12),
              foregroundColor: data.color,
              child: Icon(data.icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.value.toString(),
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(data.label,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (data.onTapPath != null) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );

    if (data.onTapPath == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go(data.onTapPath!),
      child: card,
    );
  }
}

class _TenantLaunchReadinessPanel extends StatelessWidget {
  const _TenantLaunchReadinessPanel({
    required this.metrics,
    required this.isTenantScoped,
  });

  final TenantLaunchReadinessMetrics metrics;
  final bool isTenantScoped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent = (metrics.launchProgress * 100).round();
    final blockers = [
      _ReadinessCounterData(
        label: 'Missing Plan',
        value: metrics.missingSubscription,
        icon: Icons.credit_card_off_outlined,
        color: Colors.orange,
      ),
      _ReadinessCounterData(
        label: 'Missing Billing Contact',
        value: metrics.missingBillingContact,
        icon: Icons.contact_mail_outlined,
        color: Colors.deepOrange,
      ),
      _ReadinessCounterData(
        label: 'Missing Tenant Owner',
        value: metrics.missingTenantAdmin,
        icon: Icons.admin_panel_settings_outlined,
        color: Colors.indigo,
      ),
      _ReadinessCounterData(
        label: 'Missing Community',
        value: metrics.missingHoa,
        icon: Icons.domain_disabled_outlined,
        color: Colors.blueGrey,
      ),
      if (!isTenantScoped)
        _ReadinessCounterData(
          label: 'Stripe Pending',
          value: metrics.stripePending,
          icon: Icons.sync_problem_outlined,
          color: Colors.purple,
        ),
      _ReadinessCounterData(
        label: 'Over Included Limits',
        value: metrics.overIncludedLimits,
        icon: Icons.trending_up_outlined,
        color: Colors.red,
      ),
      _ReadinessCounterData(
        label: 'Blocked',
        value: metrics.blocked,
        icon: Icons.block_outlined,
        color: Colors.redAccent,
      ),
    ];

    final tenantVisibleAttentionCount = isTenantScoped
        ? _tenantVisibleAttentionCount(metrics)
        : metrics.setupAttentionTotal;
    final readinessLabel = isTenantScoped
        ? _tenantReadinessLabel(metrics)
        : '$progressPercent% launch ready';
    final readinessSubtitle = isTenantScoped
        ? _tenantReadinessSubtitle(metrics, tenantVisibleAttentionCount)
        : '${metrics.readyToLaunch} ready, ${metrics.launched} launched, ${metrics.totalTenants} total tenants';

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.12),
                      foregroundColor: Colors.green.shade700,
                      child: const Icon(Icons.rocket_launch_outlined),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          readinessLabel,
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(readinessSubtitle),
                      ],
                    ),
                  ],
                ),
                Chip(
                  avatar: Icon(
                    tenantVisibleAttentionCount == 0
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_outlined,
                    size: 18,
                  ),
                  label: Text(
                    tenantVisibleAttentionCount == 0
                        ? 'No onboarding blockers'
                        : '$tenantVisibleAttentionCount onboarding item(s) need attention',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: metrics.launchProgress,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 1100
                    ? 4
                    : width >= 760
                        ? 3
                        : width >= 520
                            ? 2
                            : 1;
                final itemWidth = (width - ((columns - 1) * 10)) / columns;

                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: blockers
                      .map(
                        (item) => SizedBox(
                          width: itemWidth,
                          child: _ReadinessCounter(data: item),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );

    if (isTenantScoped) {
      return card;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go('/admin/tenants'),
      child: card,
    );
  }

  String _tenantReadinessLabel(TenantLaunchReadinessMetrics metrics) {
    if (metrics.launched > 0) return 'Launched';
    if (metrics.readyToLaunch > 0) return 'Ready to launch';
    if (metrics.blocked > 0) return 'Launch blocked';
    if (_tenantVisibleAttentionCount(metrics) > 0) {
      return 'Onboarding needs attention';
    }
    return 'Onboarding in progress';
  }

  String _tenantReadinessSubtitle(
    TenantLaunchReadinessMetrics metrics,
    int attentionCount,
  ) {
    if (metrics.totalTenants == 0) {
      return 'No tenant record is available for this account.';
    }
    if (attentionCount == 0) {
      return metrics.launched > 0
          ? 'No visible operational blockers for this tenant.'
          : 'No readiness blockers detected for this tenant.';
    }
    if (attentionCount == 1) {
      return metrics.launched > 0
          ? '1 operational item needs attention.'
          : '1 onboarding item needs attention before launch.';
    }
    return metrics.launched > 0
        ? '$attentionCount operational items need attention.'
        : '$attentionCount onboarding items need attention before launch.';
  }
}

class _ReadinessCounterData {
  const _ReadinessCounterData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _ReadinessCounter extends StatelessWidget {
  const _ReadinessCounter({required this.data});

  final _ReadinessCounterData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: data.color.withOpacity(data.value == 0 ? 0.06 : 0.11),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: data.color.withOpacity(data.value == 0 ? 0.12 : 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(data.icon, color: data.color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              data.value.toString(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketMetricsPanel extends StatelessWidget {
  const _TicketMetricsPanel({required this.metrics});

  final TicketMetricsBreakdown metrics;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('New', metrics.newTickets, Colors.blue),
      ('Open', metrics.open, Colors.cyan),
      ('Assigned', metrics.assigned, Colors.indigo),
      ('In Progress', metrics.inProgress, Colors.orange),
      ('Resolved', metrics.resolved, Colors.green),
      ('Closed', metrics.closed, Colors.grey),
    ];
    final maxValue = rows
        .map((row) => row.$2)
        .fold<int>(1, (max, value) => value > max ? value : max);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ticket Metrics',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
                '${metrics.activeTotal} active, ${metrics.completedTotal} completed'),
            const SizedBox(height: 18),
            ...rows.map((row) {
              return _MetricBarRow(
                label: row.$1,
                value: row.$2,
                maxValue: maxValue,
                color: row.$3,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _OperationalMetricsPanel extends StatelessWidget {
  const _OperationalMetricsPanel({required this.metrics});

  final OperationalMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Team Coverage',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Assigned tenant staff and community contacts.'),
            const SizedBox(height: 18),
            _CompactMetric(
                label: 'Community Managers',
                value: metrics.hoaManagers,
                icon: Icons.supervisor_account_outlined),
            _CompactMetric(
                label: 'Board Contacts',
                value: metrics.hoaBoardMembers,
                icon: Icons.groups_outlined),
            _CompactMetric(
                label: 'Tenant Staff',
                value: metrics.tenantStaff,
                icon: Icons.badge_outlined),
            _CompactMetric(
                label: 'Dispatch Users',
                value: metrics.dispatchUsers,
                icon: Icons.local_shipping_outlined),
            _CompactMetric(
                label: 'CSR Users',
                value: metrics.csrUsers,
                icon: Icons.support_agent_outlined),
          ],
        ),
      ),
    );
  }
}

class _MetricBarRow extends StatelessWidget {
  const _MetricBarRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  final String label;
  final int value;
  final int maxValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(width: 112, child: Text(label)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: maxValue == 0 ? 0 : value / maxValue,
                minHeight: 10,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 42,
            child: Text(
              value.toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric(
      {required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(label),
      trailing:
          Text(value.toString(), style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _RecentActivityGrid extends StatelessWidget {
  const _RecentActivityGrid({required this.snapshot});

  final AnalyticsDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1180;
        final cards = [
          _RecentActivityCard(
            title: 'Recent Tickets',
            icon: Icons.confirmation_number_outlined,
            emptyText: 'No recent tickets.',
            children: snapshot.recentTickets.map((ticket) {
              return _ActivityTile(
                title: ticket.subject,
                subtitle: '${_labelize(ticket.status)} • ${ticket.hoaName}',
                meta: _formatDateTime(ticket.createdAt),
                onTap: () => context.go('/admin/tickets/${ticket.id}'),
              );
            }).toList(),
          ),
          _RecentActivityCard(
            title: 'Recent Customer Registrations',
            icon: Icons.person_add_alt_outlined,
            emptyText: 'No recent customer registrations.',
            children: snapshot.recentResidentRegistrations.map((registration) {
              return _ActivityTile(
                title: registration.residentName,
                subtitle: '${registration.email} • ${registration.hoaName}',
                meta: _labelize(registration.status),
                onTap: () => context
                    .go('/admin/resident-verification/${registration.id}'),
              );
            }).toList(),
          ),
          _RecentActivityCard(
            title: 'Recent Community Creation',
            icon: Icons.domain_add_outlined,
            emptyText: 'No recent communities.',
            children: snapshot.recentHoaCreations.map((hoa) {
              return _ActivityTile(
                title: hoa.name,
                subtitle: '${hoa.code} • ${_labelize(hoa.status)}',
                meta: _formatDate(hoa.createdAt),
                onTap: () => context.go('/admin/hoas/${hoa.id}'),
              );
            }).toList(),
          ),
          _RecentActivityCard(
            title: 'Recent Document Uploads',
            icon: Icons.upload_file_outlined,
            emptyText: 'No recent document uploads.',
            children: snapshot.recentDocumentUploads.map((document) {
              return _ActivityTile(
                title: document.title,
                subtitle: '${document.category} • ${document.hoaName}',
                meta: _labelize(document.status),
                onTap: () => context.go('/admin/documents/${document.id}'),
              );
            }).toList(),
          ),
        ];

        if (!isWide) {
          return Column(
            children: cards
                .map((card) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: card,
                    ))
                .toList(),
          );
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map((card) => SizedBox(
                    width: (constraints.maxWidth - 16) / 2,
                    child: card,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.title,
    required this.icon,
    required this.emptyText,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(emptyText),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: SizedBox(
        width: 96,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}

class _DashboardError extends ConsumerWidget {
  const _DashboardError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Unable to load analytics dashboard.',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(analyticsDashboardProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}/${local.year}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour > 12
      ? local.hour - 12
      : local.hour == 0
          ? 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${_formatDate(local)} $hour:$minute $period';
}

String _labelize(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
