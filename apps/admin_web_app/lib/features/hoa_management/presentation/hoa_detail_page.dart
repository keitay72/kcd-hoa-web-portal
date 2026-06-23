import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/admin_access.dart';
import '../../../core/rbac/admin_context.dart';
import '../../user_management/domain/admin_user.dart';
import '../../user_management/presentation/invite_user_dialog.dart';
import '../../user_management/presentation/user_management_providers.dart';
import 'hoa_form_dialog.dart';
import 'hoa_providers.dart';

class HoaDetailPage extends ConsumerWidget {
  const HoaDetailPage({
    required this.hoaId,
    super.key,
  });

  final String hoaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoa = ref.watch(hoaDetailProvider(hoaId));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: hoa.when(
        data: (item) => ListView(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.go('/admin/hoas'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Community Detail',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showDialog<Object?>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => HoaFormDialog(initialValue: item),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Community'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    _DetailRow(label: 'ID', value: item.id),
                    _DetailRow(label: 'Tenant ID', value: item.tenantId),
                    _DetailRow(label: 'Community Code', value: item.code),
                    _DetailRow(label: 'Name', value: item.name),
                    _DetailRow(label: 'Status', value: item.status.name),
                    _DetailRow(
                      label: 'Customer verification',
                      value: item.residentActivationCodeSettingLabel
                          .replaceFirst('Activation codes: ', ''),
                    ),
                    _DetailRow(
                      label: 'Created',
                      value: item.createdAt.toLocal().toString(),
                    ),
                    _DetailRow(
                      label: 'Updated',
                      value: item.updatedAt.toLocal().toString(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _HoaStaffSection(hoaId: item.id, hoaName: item.name),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Unable to load community: $error'),
        ),
      ),
    );
  }
}

class _HoaStaffSection extends ConsumerWidget {
  const _HoaStaffSection({
    required this.hoaId,
    required this.hoaName,
  });

  final String hoaId;
  final String hoaName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(hoaStaffProvider(hoaId));
    final access = ref.watch(activeAdminAccessProvider);
    final canInvite = access.maybeWhen(
      data: _canInviteHoaStaff,
      orElse: () => false,
    );

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community Contacts',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Invite and manage community contacts for $hoaName.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed:
                      canInvite ? () => _openInviteDialog(context, ref) : null,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add Community User'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            staff.when(
              data: (users) {
                if (users.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color:
                          Theme.of(context).colorScheme.surfaceContainerLowest,
                    ),
                    child: const Text(
                      'No community contacts have been assigned yet. Add a community manager or board member to get started.',
                    ),
                  );
                }

                return Column(
                  children: users
                      .map(
                        (user) => _HoaStaffTile(
                          hoaId: hoaId,
                          user: user,
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Unable to load community contacts: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canInviteHoaStaff(AdminAccess access) {
    if (access.isPlatformOperator ||
        access.isTenantAdmin ||
        access.isTenantManager) {
      return true;
    }

    return access.hoaRoles.any(
      (role) => role.hoaId == hoaId && role.code == 'hoa_manager',
    );
  }

  Set<String> _allowedInviteRoleCodes(AdminAccess access) {
    if (access.isPlatformOperator ||
        access.isTenantAdmin ||
        access.isTenantManager) {
      return const {'hoa_manager', 'hoa_board'};
    }

    if (access.hoaRoles
        .any((role) => role.hoaId == hoaId && role.code == 'hoa_manager')) {
      return const {'hoa_board'};
    }

    return const {};
  }

  Future<void> _openInviteDialog(BuildContext context, WidgetRef ref) async {
    final access = await ref.read(activeAdminAccessProvider.future);
    final allowedRoleCodes = _allowedInviteRoleCodes(access);
    if (allowedRoleCodes.isEmpty) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => InviteUserDialog(
        title: 'Add Community User - $hoaName',
        initialCategory: 'hoa',
        initialRoleCode: allowedRoleCodes.length == 1
            ? allowedRoleCodes.first
            : 'hoa_manager',
        initialHoaId: hoaId,
        allowedRoleCodes: allowedRoleCodes,
        lockScope: true,
      ),
    );

    if (result == true) {
      ref.invalidate(hoaStaffProvider(hoaId));
    }
  }
}

class _HoaStaffTile extends ConsumerWidget {
  const _HoaStaffTile({
    required this.hoaId,
    required this.user,
  });

  final String hoaId;
  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final commandState = ref.watch(userCommandProvider);
    final currentHoaRoles = user.hoaRoles
        .where((role) => role.hoaId == hoaId && role.status == 'active')
        .toList();
    final subtitleParts = <String>[
      user.email,
      if (currentHoaRoles.isNotEmpty)
        currentHoaRoles.map((role) => role.roleName).join(', '),
      if (user.isPendingInvite)
        user.latestInvite?.statusLabel ?? user.statusLabel,
    ];

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: user.isPendingInvite
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.primaryContainer,
        child: Icon(
          user.isPendingInvite
              ? Icons.mark_email_unread_outlined
              : Icons.person_outline,
          color: user.isPendingInvite
              ? theme.colorScheme.onSecondaryContainer
              : theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(user.displayName),
      subtitle: Text(
        subtitleParts.where((part) => part.trim().isNotEmpty).join(' • '),
      ),
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (user.isPendingInvite)
            Chip(
                label: Text(user.latestInvite?.statusLabel ?? user.statusLabel))
          else
            const Chip(label: Text('Active')),
          if (user.latestInvite?.canResend == true)
            IconButton(
              tooltip: 'Resend invite',
              onPressed: commandState.isLoading
                  ? null
                  : () async {
                      final invite = user.latestInvite;
                      if (invite == null) return;
                      final didResend = await ref
                          .read(userCommandProvider.notifier)
                          .resendInvite(
                            userId: user.id,
                            inviteId: invite.id,
                          );
                      if (didResend) ref.invalidate(hoaStaffProvider(hoaId));
                    },
              icon: const Icon(Icons.outgoing_mail),
            ),
          if (user.latestInvite?.canCancel == true)
            IconButton(
              tooltip: 'Cancel invite',
              onPressed: commandState.isLoading
                  ? null
                  : () async {
                      final invite = user.latestInvite;
                      if (invite == null) return;
                      final didCancel = await ref
                          .read(userCommandProvider.notifier)
                          .cancelInvite(
                            userId: user.id,
                            inviteId: invite.id,
                          );
                      if (didCancel) ref.invalidate(hoaStaffProvider(hoaId));
                    },
              icon: const Icon(Icons.cancel_outlined),
            ),
          if (currentHoaRoles.isNotEmpty)
            PopupMenuButton<UserHoaRoleAssignment>(
              tooltip: 'Manage role',
              onSelected: (assignment) async {
                final didRemove = await ref
                    .read(userCommandProvider.notifier)
                    .removeHoaRole(assignment);
                if (didRemove) ref.invalidate(hoaStaffProvider(hoaId));
              },
              itemBuilder: (context) => currentHoaRoles
                  .map(
                    (role) => PopupMenuItem<UserHoaRoleAssignment>(
                      value: role,
                      child: Text('Remove ${role.roleName}'),
                    ),
                  )
                  .toList(),
              child: const Icon(Icons.more_vert),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
