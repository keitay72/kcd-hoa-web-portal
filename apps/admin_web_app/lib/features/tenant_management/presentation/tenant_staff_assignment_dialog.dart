import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user_management/domain/role_catalog.dart';
import '../../user_management/presentation/user_management_providers.dart';
import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';
import 'tenant_management_providers.dart';

class TenantStaffAssignmentDialog extends ConsumerStatefulWidget {
  const TenantStaffAssignmentDialog({required this.detail, super.key});

  final TenantDetail detail;

  @override
  ConsumerState<TenantStaffAssignmentDialog> createState() =>
      _TenantStaffAssignmentDialogState();
}

class _TenantStaffAssignmentDialogState
    extends ConsumerState<TenantStaffAssignmentDialog> {
  String? _userId;
  int? _roleId;

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(roleCatalogProvider);
    final commandState = ref.watch(tenantMutationControllerProvider);
    final assignableUsers = widget.detail.assignableUsers;

    return AlertDialog(
      title: const Text('Assign Tenant Staff'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assignableUsers.isEmpty)
              const Text(
                  'No assignable active users were found. Invite the user first, then assign a tenant role.')
            else
              DropdownButtonFormField<String>(
                value: _userId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'User',
                  border: OutlineInputBorder(),
                ),
                items: assignableUsers
                    .map((user) => DropdownMenuItem(
                        value: user.id, child: Text(user.label)))
                    .toList(),
                onChanged: commandState.isLoading
                    ? null
                    : (value) => setState(() => _userId = value),
              ),
            const SizedBox(height: 16),
            roles.when(
              data: (items) {
                final tenantRoles =
                    items.where((role) => role.isTenantRole).toList();
                final selectedRoleId =
                    _roleId ?? _preferredTenantRoleId(tenantRoles);
                return DropdownButtonFormField<int>(
                  value: selectedRoleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Tenant Role',
                    border: OutlineInputBorder(),
                  ),
                  items: tenantRoles
                      .map((role) => DropdownMenuItem(
                          value: role.id, child: Text(role.name)))
                      .toList(),
                  onChanged: commandState.isLoading
                      ? null
                      : (value) => setState(() => _roleId = value),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Unable to load tenant roles: $error'),
            ),
            if (commandState.hasError) ...[
              const SizedBox(height: 12),
              Text(
                commandState.error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              commandState.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: commandState.isLoading ||
                  _userId == null ||
                  (_roleId == null &&
                      _preferredTenantRoleId(roles.valueOrNull ?? const []) ==
                          null)
              ? null
              : _submit,
          child: const Text('Assign Role'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final userId = _userId;
    final roleId = _roleId ??
        _preferredTenantRoleId(
            ref.read(roleCatalogProvider).valueOrNull ?? const []);
    if (userId == null || roleId == null) return;

    final didAssign = await ref
        .read(tenantMutationControllerProvider.notifier)
        .assignTenantStaff(
          tenantId: widget.detail.tenant.id,
          input: TenantStaffAssignmentInput(userId: userId, roleId: roleId),
        );

    if (didAssign && mounted) Navigator.of(context).pop(true);
  }
}

int? _preferredTenantRoleId(List<RoleCatalogEntry> roles) {
  for (final role in roles) {
    if (role.code == 'tenant_owner') return role.id;
  }
  for (final role in roles) {
    if (role.code == 'tenant_admin') return role.id;
  }
  return roles.isEmpty ? null : roles.first.id;
}
