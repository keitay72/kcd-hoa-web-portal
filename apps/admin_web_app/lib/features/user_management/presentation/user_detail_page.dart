import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/admin_user.dart';
import 'assign_hoa_role_dialog.dart';
import 'assign_platform_role_dialog.dart';
import 'edit_user_dialog.dart';
import 'user_management_providers.dart';

class UserDetailPage extends ConsumerWidget {
  const UserDetailPage({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDetailProvider(userId));

    return user.when(
      data: (item) => _UserDetailContent(user: item),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () => context.go('/admin/users'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Users'),
            ),
            const SizedBox(height: 16),
            Text('Unable to load user: $error'),
          ],
        ),
      ),
    );
  }
}

class _UserDetailContent extends ConsumerWidget {
  const _UserDetailContent({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commandState = ref.watch(userCommandProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/admin/users'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to Users'),
                ),
                const SizedBox(height: 8),
                Text(user.displayName, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(user.email),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openEditDialog(context, ref),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit User'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openAssignPlatformRoleDialog(context, ref),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Platform Role'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openAssignHoaRoleDialog(context, ref),
                  icon: const Icon(Icons.domain_outlined),
                  label: const Text('HOA Role'),
                ),
                FilledButton.icon(
                  onPressed: user.isActive && !commandState.isLoading
                      ? () => _confirmDeactivate(context, ref)
                      : null,
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Deactivate'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (commandState.hasError) ...[
          Text(
            commandState.error.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 960) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ProfileCard(user: user)),
                  const SizedBox(width: 20),
                  Expanded(child: _RoleCards(user: user)),
                ],
              );
            }

            return Column(
              children: [
                _ProfileCard(user: user),
                const SizedBox(height: 20),
                _RoleCards(user: user),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openEditDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<AdminUser>(
      context: context,
      builder: (_) => EditUserDialog(user: user),
    );
    if (result != null) ref.invalidate(userDetailProvider(user.id));
  }

  Future<void> _openAssignPlatformRoleDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AssignPlatformRoleDialog(user: user),
    );
    if (result == true) ref.invalidate(userDetailProvider(user.id));
  }

  Future<void> _openAssignHoaRoleDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AssignHoaRoleDialog(user: user),
    );
    if (result == true) ref.invalidate(userDetailProvider(user.id));
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text('Deactivate ${user.displayName}? This disables the profile and inactivates HOA role assignments.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Deactivate')),
        ],
      ),
    );

    if (didConfirm != true) return;
    await ref.read(userCommandProvider.notifier).deactivateUser(user.id);
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _InfoRow(label: 'Name', value: user.displayName),
            _InfoRow(label: 'Email', value: user.email),
            _InfoRow(label: 'Phone', value: user.phone ?? 'Not set'),
            _InfoRow(label: 'Status', value: user.status),
            _InfoRow(label: 'Created', value: _formatDate(user.createdAt)),
            _InfoRow(label: 'Updated', value: _formatDate(user.updatedAt)),
          ],
        ),
      ),
    );
  }
}

class _RoleCards extends ConsumerWidget {
  const _RoleCards({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _PlatformRolesCard(user: user),
        const SizedBox(height: 20),
        _HoaRolesCard(user: user),
      ],
    );
  }
}

class _PlatformRolesCard extends ConsumerWidget {
  const _PlatformRolesCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KC Disposal Staff Roles', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (user.platformRoles.isEmpty)
              const Text('No platform roles assigned.')
            else
              ...user.platformRoles.map(
                (role) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(role.roleName),
                  subtitle: Text(role.tenantName),
                  trailing: IconButton(
                    tooltip: 'Remove role',
                    onPressed: () => ref.read(userCommandProvider.notifier).removePlatformRole(role),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HoaRolesCard extends ConsumerWidget {
  const _HoaRolesCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HOA Roles', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (user.hoaRoles.isEmpty)
              const Text('No HOA roles assigned.')
            else
              ...user.hoaRoles.map(
                (role) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(role.roleName),
                  subtitle: Text('${role.hoaName} - ${role.status}'),
                  trailing: role.status == 'active'
                      ? IconButton(
                          tooltip: 'Deactivate role',
                          onPressed: () => ref.read(userCommandProvider.notifier).removeHoaRole(role),
                          icon: const Icon(Icons.remove_circle_outline),
                        )
                      : const Chip(label: Text('Inactive')),
                ),
              ),
          ],
        ),
      ),
    );
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
          SelectableText(value),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}/${local.year}';
}
