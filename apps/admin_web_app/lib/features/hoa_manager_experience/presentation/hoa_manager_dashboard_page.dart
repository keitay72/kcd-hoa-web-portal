import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'hoa_manager_providers.dart';
import 'hoa_scope_header.dart';

class HoaManagerDashboardPage extends ConsumerWidget {
  const HoaManagerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(hoaManagerSummaryProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const HoaScopeHeader(
          title: 'HOA Dashboard',
          subtitle: 'Community overview for HOA managers and board members.',
        ),
        const SizedBox(height: 20),
        summary.when(
          data: (item) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.hoaLabel, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(item.hoaCode)),
                    Chip(label: Text(item.hoaName)),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 1000
                        ? (constraints.maxWidth - 48) / 4
                        : constraints.maxWidth >= 640
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _MetricCard(
                          label: 'Residents',
                          value: item.residentCount.toString(),
                          icon: Icons.people_outline,
                          path: '/admin/hoa/residents',
                        ),
                        _MetricCard(
                          label: 'Documents',
                          value: item.activeDocumentCount.toString(),
                          icon: Icons.description_outlined,
                          path: '/admin/hoa/documents',
                        ),
                        _MetricCard(
                          label: 'Announcements',
                          value: item.activeAnnouncementCount.toString(),
                          icon: Icons.campaign_outlined,
                          path: '/admin/hoa/announcements',
                        ),
                        _MetricCard(
                          label: 'Open Tickets',
                          value: item.openTicketCount.toString(),
                          icon: Icons.confirmation_number_outlined,
                          path: '/admin/hoa/tickets',
                        ),
                        _MetricCard(
                          label: 'Active Schedules',
                          value: item.activeScheduleCount.toString(),
                          icon: Icons.event_repeat_outlined,
                          path: '/admin/hoa/service-schedules',
                        ),
                      ].map((card) => SizedBox(width: width, child: card)).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    const _QuickActionButton(
                      label: 'Residents',
                      icon: Icons.people_outline,
                      path: '/admin/hoa/residents',
                    ),
                    const _QuickActionButton(
                      label: 'HOA Staff',
                      icon: Icons.manage_accounts_outlined,
                      path: '/admin/hoa/staff',
                    ),
                    const _QuickActionButton(
                      label: 'Announcements',
                      icon: Icons.campaign_outlined,
                      path: '/admin/hoa/announcements',
                    ),
                    const _QuickActionButton(
                      label: 'Documents',
                      icon: Icons.description_outlined,
                      path: '/admin/hoa/documents',
                    ),
                    const _QuickActionButton(
                      label: 'Tickets',
                      icon: Icons.confirmation_number_outlined,
                      path: '/admin/hoa/tickets',
                    ),
                    const _QuickActionButton(
                      label: 'Schedules',
                      icon: Icons.event_repeat_outlined,
                      path: '/admin/hoa/service-schedules',
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Unable to load HOA dashboard: $error'),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.path,
  });

  final String label;
  final String value;
  final IconData icon;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(path),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 34),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => context.go(path),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
