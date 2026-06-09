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
    final isInviteOnly = user.id.startsWith('invite:');

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
                  onPressed: isInviteOnly ? null : () => _openEditDialog(context, ref),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit User'),
                ),
                OutlinedButton.icon(
                  onPressed: isInviteOnly ? null : () => _openAssignPlatformRoleDialog(context, ref),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Platform Role'),
                ),
                OutlinedButton.icon(
                  onPressed: isInviteOnly ? null : () => _openAssignHoaRoleDialog(context, ref),
                  icon: const Icon(Icons.domain_outlined),
                  label: const Text('HOA Role'),
                ),
                FilledButton.icon(
                  onPressed: !isInviteOnly && user.isActive && !commandState.isLoading
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
                  Expanded(
                    child: Column(
                      children: [
                        _ProfileCard(user: user),
                        const SizedBox(height: 20),
                        _InviteLifecycleCard(user: user),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: _RoleCards(user: user)),
                ],
              );
            }

            return Column(
              children: [
                _ProfileCard(user: user),
                const SizedBox(height: 20),
                _InviteLifecycleCard(user: user),
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
            _InfoRow(label: 'Status', value: user.statusLabel),
            _InfoRow(label: 'Created', value: _formatDate(user.createdAt)),
            _InfoRow(label: 'Updated', value: _formatDate(user.updatedAt)),
          ],
        ),
      ),
    );
  }
}


class _InviteLifecycleCard extends ConsumerWidget {
  const _InviteLifecycleCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invite = user.latestInvite;
    final commandState = ref.watch(userCommandProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Invite Lifecycle', style: Theme.of(context).textTheme.titleLarge)),
                if (invite != null) Chip(label: Text(invite.statusLabel)),
              ],
            ),
            const SizedBox(height: 16),
            if (invite == null)
              const Text('No invite record found for this user.')
            else ...[
              _InfoRow(label: 'Invite Status', value: invite.statusLabel),
              _InfoRow(label: 'Invited', value: _formatDateTime(invite.invitedAt)),
              _InfoRow(label: 'Expires', value: _formatDateTime(invite.expiresAt)),
              _InfoRow(label: 'Resent', value: invite.resentAt == null ? 'Never' : _formatDateTime(invite.resentAt!)),
              _InfoRow(label: 'Resend Count', value: invite.resendCount.toString()),
              if (invite.acceptedAt != null)
                _InfoRow(label: 'Accepted', value: _formatDateTime(invite.acceptedAt!)),
              if (invite.cancelledAt != null)
                _InfoRow(label: 'Cancelled', value: _formatDateTime(invite.cancelledAt!)),
              if (invite.failureReason != null && invite.failureReason!.trim().isNotEmpty)
                _InfoRow(label: 'Failure Reason', value: invite.failureReason!),
              if (invite.failureTimestamp != null)
                _InfoRow(label: 'Failed At', value: _formatDateTime(invite.failureTimestamp!)),
              if (invite.failureMessage != null && invite.failureMessage!.trim().isNotEmpty && invite.failureMessage != invite.failureReason)
                _InfoRow(label: 'Failure Message', value: invite.failureMessage!),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: invite.canResend && !commandState.isLoading
                        ? () => _resendInvite(context, ref, invite)
                        : null,
                    icon: const Icon(Icons.outgoing_mail),
                    label: const Text('Resend Invite'),
                  ),
                  OutlinedButton.icon(
                    onPressed: invite.canCancel && !commandState.isLoading
                        ? () => _confirmCancelInvite(context, ref, invite)
                        : null,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Invite'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _resendInvite(BuildContext context, WidgetRef ref, AdminUserInvite invite) async {
    final didResend = await ref.read(userCommandProvider.notifier).resendInvite(
          userId: user.id,
          inviteId: invite.id,
        );
    if (!context.mounted || !didResend) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite resent.')),
    );
  }

  Future<void> _confirmCancelInvite(BuildContext context, WidgetRef ref, AdminUserInvite invite) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Invite'),
        content: Text('Cancel the pending invite for ${user.email}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep Invite')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cancel Invite')),
        ],
      ),
    );

    if (didConfirm != true) return;
    final didCancel = await ref.read(userCommandProvider.notifier).cancelInvite(
          userId: user.id,
          inviteId: invite.id,
        );
    if (!context.mounted || !didCancel) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite cancelled.')),
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

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final date = _formatDate(local);
  final hour = local.hour > 12 ? local.hour - 12 : local.hour == 0 ? 12 : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$date $hour:$minute $period';
}
