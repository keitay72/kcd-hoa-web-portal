import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_access.dart';
import '../../../core/rbac/rbac_providers.dart';
import '../../user_management/domain/admin_user.dart';
import '../../user_management/presentation/invite_user_dialog.dart';
import '../../user_management/presentation/user_management_providers.dart';
import 'hoa_manager_providers.dart';
import 'hoa_scope_header.dart';

class HoaStaffPage extends ConsumerWidget {
  const HoaStaffPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(activeHoaScopeProvider);
    final access = ref.watch(adminAccessProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const HoaScopeHeader(
          title: 'HOA Staff',
          subtitle: 'Community staff and leadership.',
        ),
        const SizedBox(height: 20),
        scope.when(
          data: (activeScope) {
            if (activeScope?.hoaId == null) {
              return const _EmptyHoaScopeState();
            }

            final hoaId = activeScope!.hoaId!;
            final hoaName = activeScope.hoaName ?? 'HOA';
            final staff = ref.watch(hoaStaffProvider(hoaId));
            final canInvite = access.maybeWhen(
              data: (value) => _canInviteHoaStaff(value, hoaId),
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
                                hoaName,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                        ),
                        if (canInvite) ...[
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _openInviteDialog(context, ref, hoaId: hoaId, hoaName: hoaName),
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: const Text('Add HOA User'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    staff.when(
                      data: (users) {
                        if (users.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Theme.of(context).colorScheme.surfaceContainerLowest,
                            ),
                            child: const Text(
                              'No HOA staff have been assigned yet. Invite an HOA manager or board member to get started.',
                            ),
                          );
                        }

                        final sortedUsers = [...users]..sort(
                            (a, b) => _compareHoaStaffForDisplay(a, b, hoaId),
                          );

                        return Column(
                          children: sortedUsers
                              .map(
                                (user) => _HoaStaffTile(
                                  hoaId: hoaId,
                                  user: user,
                                  canManage: canInvite,
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
                        child: Text('Unable to load HOA staff: $error'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Unable to load HOA scope: $error'),
        ),
      ],
    );
  }

  static bool _canInviteHoaStaff(AdminAccess access, String hoaId) {
    return access.hoaRoles.any((role) => role.hoaId == hoaId && role.code == 'hoa_manager');
  }

  static Future<void> _openInviteDialog(
    BuildContext context,
    WidgetRef ref, {
    required String hoaId,
    required String hoaName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => InviteUserDialog(
        title: 'Add HOA User - $hoaName',
        initialCategory: 'hoa',
        initialRoleCode: 'hoa_board',
        initialHoaId: hoaId,
        allowedRoleCodes: const {'hoa_board'},
        lockScope: true,
      ),
    );

    if (result == true) {
      ref.invalidate(hoaStaffProvider(hoaId));
    }
  }

  static int _compareHoaStaffForDisplay(AdminUser a, AdminUser b, String hoaId) {
    final aPriority = _hoaRolePriority(a, hoaId);
    final bPriority = _hoaRolePriority(b, hoaId);
    if (aPriority != bPriority) return aPriority.compareTo(bPriority);

    if (a.isPendingInvite != b.isPendingInvite) {
      return a.isPendingInvite ? 1 : -1;
    }

    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }

  static int _hoaRolePriority(AdminUser user, String hoaId) {
    final roleCodes = user.hoaRoles
        .where((role) => role.hoaId == hoaId && role.status == 'active')
        .map((role) => role.roleCode)
        .toSet();

    if (roleCodes.contains('hoa_manager')) return 0;
    if (roleCodes.contains('hoa_board')) return 1;
    return 2;
  }
}

class _HoaStaffTile extends ConsumerWidget {
  const _HoaStaffTile({
    required this.hoaId,
    required this.user,
    required this.canManage,
  });

  final String hoaId;
  final AdminUser user;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final commandState = ref.watch(userCommandProvider);
    final currentHoaRoles = user.hoaRoles
        .where((role) => role.hoaId == hoaId && role.status == 'active')
        .toList();
    final subtitleParts = <String>[
      user.email,
      if (user.isPendingInvite) user.latestInvite?.statusLabel ?? user.statusLabel,
    ];
    final isManager = currentHoaRoles.any((role) => role.roleCode == 'hoa_manager');
    final isBoardMember = currentHoaRoles.any((role) => role.roleCode == 'hoa_board');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: user.isPendingInvite
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.primaryContainer,
        child: Icon(
          user.isPendingInvite ? Icons.mark_email_unread_outlined : Icons.person_outline,
          color: user.isPendingInvite
              ? theme.colorScheme.onSecondaryContainer
              : theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(user.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitleParts.where((part) => part.trim().isNotEmpty).join(' • ')),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isManager)
                Chip(
                  avatar: Icon(
                    Icons.workspace_premium_outlined,
                    size: 18,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  label: Text(
                    'Manager',
                    style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
                  ),
                  side: BorderSide(color: theme.colorScheme.tertiaryContainer),
                ),
              if (!isManager && isBoardMember)
                Chip(
                  avatar: Icon(
                    Icons.groups_2_outlined,
                    size: 18,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  label: Text(
                    'Board Member',
                    style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                  ),
                  side: BorderSide(color: theme.colorScheme.secondaryContainer),
                ),
            ],
          ),
        ],
      ),
      trailing: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (user.isPendingInvite)
            Chip(label: Text(user.latestInvite?.statusLabel ?? user.statusLabel))
          else
            const Chip(label: Text('Active')),
          if (canManage && user.latestInvite?.canResend == true)
            IconButton(
              tooltip: 'Resend invite',
              onPressed: commandState.isLoading
                  ? null
                  : () async {
                      final invite = user.latestInvite;
                      if (invite == null) return;
                      final didResend = await ref.read(userCommandProvider.notifier).resendInvite(
                            userId: user.id,
                            inviteId: invite.id,
                          );
                      if (didResend) ref.invalidate(hoaStaffProvider(hoaId));
                    },
              icon: const Icon(Icons.outgoing_mail),
            ),
          if (canManage && user.latestInvite?.canCancel == true)
            IconButton(
              tooltip: 'Cancel invite',
              onPressed: commandState.isLoading
                  ? null
                  : () async {
                      final invite = user.latestInvite;
                      if (invite == null) return;
                      final didCancel = await ref.read(userCommandProvider.notifier).cancelInvite(
                            userId: user.id,
                            inviteId: invite.id,
                          );
                      if (didCancel) ref.invalidate(hoaStaffProvider(hoaId));
                    },
              icon: const Icon(Icons.cancel_outlined),
            ),
          if (canManage && currentHoaRoles.isNotEmpty)
            PopupMenuButton<UserHoaRoleAssignment>(
              tooltip: 'Manage role',
              onSelected: (assignment) async {
                final didRemove = await ref.read(userCommandProvider.notifier).removeHoaRole(assignment);
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

class _EmptyHoaScopeState extends StatelessWidget {
  const _EmptyHoaScopeState();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'This account is not currently assigned to an HOA scope.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
