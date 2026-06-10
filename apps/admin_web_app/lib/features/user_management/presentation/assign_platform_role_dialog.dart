import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/admin_user.dart';
import '../domain/user_management_inputs.dart';
import 'user_management_providers.dart';

class AssignPlatformRoleDialog extends ConsumerStatefulWidget {
  const AssignPlatformRoleDialog({required this.user, super.key});

  final AdminUser user;

  @override
  ConsumerState<AssignPlatformRoleDialog> createState() => _AssignPlatformRoleDialogState();
}

class _AssignPlatformRoleDialogState extends ConsumerState<AssignPlatformRoleDialog> {
  int? _roleId;
  String? _tenantId;

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(roleCatalogProvider);
    final tenants = ref.watch(platformTenantOptionsProvider);
    final commandState = ref.watch(userCommandProvider);

    return AlertDialog(
      title: const Text('Assign Tenant Role'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            roles.when(
              data: (items) => DropdownButtonFormField<int>(
                value: _roleId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: items
                    .where((role) => role.isPlatformRole)
                    .map((role) => DropdownMenuItem(value: role.id, child: Text(role.name)))
                    .toList(),
                onChanged: (value) => setState(() => _roleId = value),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Unable to load roles: $error'),
            ),
            const SizedBox(height: 16),
            tenants.when(
              data: (items) {
                final value = _tenantId ?? (items.isEmpty ? null : items.first.id);
                return DropdownButtonFormField<String>(
                  value: value,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tenant', border: OutlineInputBorder()),
                  items: items
                      .map((tenant) => DropdownMenuItem(value: tenant.id, child: Text(tenant.name)))
                      .toList(),
                  onChanged: (value) => setState(() => _tenantId = value),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Unable to load tenants: $error'),
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
          onPressed: commandState.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: commandState.isLoading ? null : _submit,
          child: const Text('Assign Tenant Role'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final tenantOptions = ref.read(platformTenantOptionsProvider).valueOrNull ?? [];
    final tenantId = _tenantId ?? (tenantOptions.isEmpty ? null : tenantOptions.first.id);
    final roleId = _roleId;
    if (tenantId == null || roleId == null) return;

    final didAssign = await ref.read(userCommandProvider.notifier).assignPlatformRole(
          AssignPlatformRoleInput(
            userId: widget.user.id,
            tenantId: tenantId,
            roleId: roleId,
          ),
        );

    if (didAssign && mounted) Navigator.of(context).pop(true);
  }
}
