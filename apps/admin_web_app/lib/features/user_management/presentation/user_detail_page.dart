import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/admin_access.dart';
import '../../../core/rbac/admin_context.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../domain/admin_user.dart';
import 'assign_hoa_role_dialog.dart';
import 'assign_platform_role_dialog.dart';
import 'change_password_dialog.dart';
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
    final access = ref.watch(activeAdminAccessProvider).valueOrNull;
    final isInviteOnly = user.id.startsWith('invite:');
    final isCurrentUser = ref.watch(currentUserProvider)?.id == user.id;
    final canManageTarget = _canManageTargetUser(access, user);
    final canDeactivate =
        !isInviteOnly && user.isActive && canManageTarget && !isCurrentUser;
    final canReactivate =
        !isInviteOnly && user.status == 'disabled' && canManageTarget;
    final canAssignScopedRoles = !isInviteOnly &&
        !user.hasGlobalRoles &&
        access?.can('roles.manage') == true;
    final showAccountActivity = user.latestInvite != null || !isInviteOnly;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/admin/users'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Users'),
                  ),
                  const SizedBox(height: 8),
                  Text(user.displayName,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text(user.email),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: isInviteOnly || !canManageTarget
                      ? null
                      : () => _openEditDialog(context, ref),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit User'),
                ),
                if (canAssignScopedRoles)
                  OutlinedButton.icon(
                    onPressed: () =>
                        _openAssignPlatformRoleDialog(context, ref),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Tenant Role'),
                  ),
                if (canAssignScopedRoles)
                  OutlinedButton.icon(
                    onPressed: () => _openAssignHoaRoleDialog(context, ref),
                    icon: const Icon(Icons.domain_outlined),
                    label: const Text('Community Role'),
                  ),
                if (isCurrentUser)
                  OutlinedButton.icon(
                    onPressed: commandState.isLoading
                        ? null
                        : () => _openChangePasswordDialog(context),
                    icon: const Icon(Icons.lock_reset_outlined),
                    label: const Text('Change Password'),
                  ),
                if (canDeactivate)
                  FilledButton.icon(
                    onPressed: commandState.isLoading
                        ? null
                        : () => _confirmDeactivate(context, ref),
                    icon: const Icon(Icons.person_off_outlined),
                    label: const Text('Deactivate'),
                  ),
                if (canReactivate)
                  FilledButton.icon(
                    onPressed: commandState.isLoading
                        ? null
                        : () => _confirmReactivate(context, ref),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Reactivate'),
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
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileCard(user: user),
                        if (showAccountActivity) ...[
                          const SizedBox(height: 20),
                          _AccountActivityCard(user: user),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AccessSummaryCard(user: user),
                        const SizedBox(height: 20),
                        _RoleCards(user: user),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileCard(user: user),
                if (showAccountActivity) ...[
                  const SizedBox(height: 20),
                  _AccountActivityCard(user: user),
                ],
                const SizedBox(height: 20),
                _AccessSummaryCard(user: user),
                const SizedBox(height: 20),
                _RoleCards(user: user),
              ],
            );
          },
        ),
      ],
    );
  }

  bool _canManageTargetUser(AdminAccess? access, AdminUser target) {
    if (target.isPlatformOwner) return false;
    if (access?.isPlatformOwner == true) return true;
    if (access?.isPlatformAdmin == true) return !target.isPlatformAdmin;
    if (access == null || !access.isTenantStaff) return false;

    for (final targetRole in target.platformRoles) {
      final actorRoles = access.tenantRoles
          .where((role) => role.tenantId == targetRole.tenantId)
          .map((role) => role.code)
          .toSet();

      if (actorRoles.contains('tenant_owner')) {
        return targetRole.roleCode != 'tenant_owner';
      }

      if (actorRoles.contains('tenant_admin') ||
          actorRoles.contains('sys_admin')) {
        return const {
          'tenant_manager',
          'tenant_csr',
        }.contains(targetRole.roleCode);
      }

      if (actorRoles.contains('tenant_manager') ||
          actorRoles.contains('mgmt')) {
        return targetRole.roleCode == 'tenant_csr';
      }
    }

    return false;
  }

  Future<void> _openEditDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<AdminUser>(
      context: context,
      builder: (_) => EditUserDialog(user: user),
    );
    if (result != null) ref.invalidate(userDetailProvider(user.id));
  }

  Future<void> _openAssignPlatformRoleDialog(
      BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AssignPlatformRoleDialog(user: user),
    );
    if (result == true) ref.invalidate(userDetailProvider(user.id));
  }

  Future<void> _openAssignHoaRoleDialog(
      BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AssignHoaRoleDialog(user: user),
    );
    if (result == true) ref.invalidate(userDetailProvider(user.id));
  }

  Future<void> _openChangePasswordDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => ChangePasswordDialog(user: user),
    );
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate User'),
        content: const Text(
          "This will deactivate this user's access. Are you sure you want to continue?",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Deactivate')),
        ],
      ),
    );

    if (didConfirm != true) return;
    await ref.read(userCommandProvider.notifier).deactivateUser(user.id);
  }

  Future<void> _confirmReactivate(BuildContext context, WidgetRef ref) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reactivate User'),
        content: const Text(
          "This will restore this user's access. Are you sure you want to continue?",
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reactivate')),
        ],
      ),
    );

    if (didConfirm != true) return;
    await ref.read(userCommandProvider.notifier).reactivateUser(user.id);
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

class _AccountActivityCard extends ConsumerWidget {
  const _AccountActivityCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invite = user.latestInvite;
    final commandState = ref.watch(userCommandProvider);
    final activity = ref.watch(userAccountActivityProvider(user.id));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('Account Activity',
                        style: Theme.of(context).textTheme.titleLarge)),
                if (invite != null) Chip(label: Text(invite.statusLabel)),
              ],
            ),
            const SizedBox(height: 16),
            if (invite != null) ...[
              _InviteActivitySection(
                invite: invite,
                commandState: commandState,
                onResend: () => _resendInvite(context, ref, invite),
                onCancel: () => _confirmCancelInvite(context, ref, invite),
              ),
              const SizedBox(height: 20),
            ],
            activity.when(
              data: (items) => _AuditActivitySection(items: items),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => Text('Unable to load activity: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resendInvite(
      BuildContext context, WidgetRef ref, AdminUserInvite invite) async {
    final didResend = await ref.read(userCommandProvider.notifier).resendInvite(
          userId: user.id,
          inviteId: invite.id,
        );
    if (!context.mounted || !didResend) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite resent.')),
    );
  }

  Future<void> _confirmCancelInvite(
      BuildContext context, WidgetRef ref, AdminUserInvite invite) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Invite'),
        content: Text('Cancel the pending invite for ${user.email}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep Invite')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel Invite')),
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

class _InviteActivitySection extends StatelessWidget {
  const _InviteActivitySection({
    required this.invite,
    required this.commandState,
    required this.onResend,
    required this.onCancel,
  });

  final AdminUserInvite invite;
  final AsyncValue<void> commandState;
  final VoidCallback onResend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Invite', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _InfoRow(label: 'Status', value: invite.statusLabel),
        _InfoRow(label: 'Invited', value: _formatDateTime(invite.invitedAt)),
        _InfoRow(label: 'Expires', value: _formatDateTime(invite.expiresAt)),
        _InfoRow(
          label: 'Resent',
          value: invite.resentAt == null
              ? 'Never'
              : _formatDateTime(invite.resentAt!),
        ),
        _InfoRow(label: 'Resend Count', value: invite.resendCount.toString()),
        if (invite.acceptedAt != null)
          _InfoRow(
              label: 'Accepted', value: _formatDateTime(invite.acceptedAt!)),
        if (invite.cancelledAt != null)
          _InfoRow(
              label: 'Cancelled', value: _formatDateTime(invite.cancelledAt!)),
        if (invite.failureReason != null &&
            invite.failureReason!.trim().isNotEmpty)
          _InfoRow(label: 'Failure Reason', value: invite.failureReason!),
        if (invite.failureTimestamp != null)
          _InfoRow(
              label: 'Failed At',
              value: _formatDateTime(invite.failureTimestamp!)),
        if (invite.failureMessage != null &&
            invite.failureMessage!.trim().isNotEmpty &&
            invite.failureMessage != invite.failureReason)
          _InfoRow(label: 'Failure Message', value: invite.failureMessage!),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed:
                  invite.canResend && !commandState.isLoading ? onResend : null,
              icon: const Icon(Icons.outgoing_mail),
              label: const Text('Resend Invite'),
            ),
            OutlinedButton.icon(
              onPressed:
                  invite.canCancel && !commandState.isLoading ? onCancel : null,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Invite'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AuditActivitySection extends StatelessWidget {
  const _AuditActivitySection({required this.items});

  final List<UserAccountActivity> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('No account changes have been recorded yet.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Changes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...items.map((item) => _ActivityTile(item: item)),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item});

  final UserAccountActivity item;

  @override
  Widget build(BuildContext context) {
    final statusChange = item.statusChange;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.history),
      title: Text(item.actionLabel),
      subtitle: Text(
        [
          'By ${item.actorLabel}',
          _formatDateTime(item.createdAt),
          if (statusChange != null) 'Status: $statusChange',
        ].join('\n'),
      ),
      isThreeLine: statusChange != null,
    );
  }
}

class _AccessSummaryCard extends StatelessWidget {
  const _AccessSummaryCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (user.globalRoles.isNotEmpty)
        _CountChip(label: 'Platform', value: user.globalRoles.length),
      if (user.platformRoles.isNotEmpty || !user.hasGlobalRoles)
        _CountChip(label: 'Tenant', value: user.platformRoles.length),
      if (user.hoaRoles.isNotEmpty || !user.hasGlobalRoles)
        _CountChip(label: 'Community', value: user.hoaRoles.length),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Access Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(user.statusLabel)),
              ],
            ),
            const SizedBox(height: 12),
            Text(user.roleSummary),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  chips.isEmpty ? [const Chip(label: Text('No roles'))] : chips,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(child: Text(value.toString())),
      label: Text(label),
    );
  }
}

class _RoleCards extends ConsumerWidget {
  const _RoleCards({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = <Widget>[
      _GlobalRolesCard(user: user),
      if (user.platformRoles.isNotEmpty || !user.hasGlobalRoles)
        _TenantRolesCard(user: user),
      if (user.hoaRoles.isNotEmpty || !user.hasGlobalRoles)
        _HoaRolesCard(user: user),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          if (index > 0) const SizedBox(height: 20),
          cards[index],
        ],
      ],
    );
  }
}

class _GlobalRolesCard extends StatelessWidget {
  const _GlobalRolesCard({required this.user});

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
            Text('Platform Roles',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (user.globalRoles.isEmpty)
              const Text('No platform roles assigned.')
            else
              ...user.globalRoles.map(
                (role) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(role.roleName),
                  subtitle: const Text('Global platform access'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TenantRolesCard extends ConsumerWidget {
  const _TenantRolesCard({required this.user});

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
            Text('Tenant Staff Roles',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (user.platformRoles.isEmpty)
              const Text('No tenant staff roles assigned.')
            else
              ...user.platformRoles.map(
                (role) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(role.roleName),
                  subtitle: Text(role.tenantName),
                  trailing: IconButton(
                    tooltip: 'Remove role',
                    onPressed: () => ref
                        .read(userCommandProvider.notifier)
                        .removePlatformRole(role),
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
            Text('Community Roles',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (user.hoaRoles.isEmpty)
              const Text('No community roles assigned.')
            else
              ...user.hoaRoles.map(
                (role) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(role.roleName),
                  subtitle: Text('${role.hoaName} - ${role.status}'),
                  trailing: role.status == 'active'
                      ? IconButton(
                          tooltip: 'Deactivate role',
                          onPressed: () => ref
                              .read(userCommandProvider.notifier)
                              .removeHoaRole(role),
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
  final hour = local.hour > 12
      ? local.hour - 12
      : local.hour == 0
          ? 12
          : local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$date $hour:$minute $period';
}
