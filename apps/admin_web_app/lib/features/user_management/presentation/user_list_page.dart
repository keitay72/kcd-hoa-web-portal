import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/admin_user.dart';
import 'invite_user_dialog.dart';
import 'user_management_providers.dart';

class UserListPage extends ConsumerStatefulWidget {
  const UserListPage({super.key});

  @override
  ConsumerState<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends ConsumerState<UserListPage> {
  final _searchController = TextEditingController();
  String? _status;

  UserListFilter get _filter => UserListFilter(
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        status: _status,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(userListProvider(_filter));
    final metrics = ref.watch(inviteMetricsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('User & Role Management', style: Theme.of(context).textTheme.headlineMedium),
              ),
              FilledButton.icon(
                onPressed: _openInviteDialog,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Invite User'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          metrics.when(
            data: (item) => _InviteMetricCards(metrics: item),
            loading: () => const SizedBox(height: 88, child: Center(child: LinearProgressIndicator())),
            error: (error, _) => Text('Unable to load invite counters: $error'),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final search = TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search users',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => setState(() {}),
                  );
                  final status = DropdownButtonFormField<String>(
                    value: _status ?? 'all',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'invite_pending', child: Text('Pending Invite')),
                      DropdownMenuItem(value: 'invite_expired', child: Text('Invite Expired')),
                      DropdownMenuItem(value: 'invite_failed', child: Text('Failed Invite')),
                      DropdownMenuItem(value: 'invite_cancelled', child: Text('Cancelled Invite')),
                      DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
                    ],
                    onChanged: (value) => setState(() => _status = value == 'all' ? null : value),
                  );
                  final actions = SizedBox(
                    height: 56,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.search),
                          label: const Text('Apply'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _status = null;
                              _searchController.clear();
                            });
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );

                  if (constraints.maxWidth >= 820) {
                    return Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 12),
                        SizedBox(width: 220, child: status),
                        const SizedBox(width: 12),
                        actions,
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(width: constraints.maxWidth, child: search),
                      SizedBox(width: constraints.maxWidth < 480 ? constraints.maxWidth : 220, child: status),
                      actions,
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: users.when(
              data: (items) => _UserTable(users: items),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Unable to load users: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInviteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const InviteUserDialog(),
    );

    if (result == true) ref.invalidate(userListProvider);
  }

}

class _InviteMetricCards extends StatelessWidget {
  const _InviteMetricCards({required this.metrics});

  final InviteMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetricCard(label: 'Pending Invites', value: metrics.pending, icon: Icons.schedule_send_outlined),
        _MetricCard(label: 'Failed Invites', value: metrics.failed, icon: Icons.error_outline),
        _MetricCard(label: 'Accepted Invites', value: metrics.accepted, icon: Icons.mark_email_read_outlined),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value.toString(), style: Theme.of(context).textTheme.headlineSmall),
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

class _UserTable extends StatelessWidget {
  const _UserTable({required this.users});

  final List<AdminUser> users;

  IconData _iconForUser(AdminUser user) {
    if (user.isPendingInvite) return Icons.mark_email_unread_outlined;
    if (!user.isActive) return Icons.person_off_outlined;
    return Icons.person_outline;
  }

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) return const Center(child: Text('No users found.'));

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            leading: Icon(_iconForUser(user)),
            title: Text(user.displayName),
            subtitle: Text('${user.email} - ${user.roleSummary}'),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(user.statusLabel)),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.go('/admin/users/${user.id}'),
          );
        },
      ),
    );
  }
}
