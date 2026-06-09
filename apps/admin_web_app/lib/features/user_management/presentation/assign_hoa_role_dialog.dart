import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/admin_user.dart';
import '../domain/user_management_inputs.dart';
import 'user_management_providers.dart';

class AssignHoaRoleDialog extends ConsumerStatefulWidget {
  const AssignHoaRoleDialog({required this.user, super.key});

  final AdminUser user;

  @override
  ConsumerState<AssignHoaRoleDialog> createState() => _AssignHoaRoleDialogState();
}

class _AssignHoaRoleDialogState extends ConsumerState<AssignHoaRoleDialog> {
  int? _roleId;
  String? _hoaId;

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(roleCatalogProvider);
    final hoas = ref.watch(hoaScopeOptionsProvider);
    final commandState = ref.watch(userCommandProvider);

    return AlertDialog(
      title: const Text('Assign HOA Role'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            roles.when(
              data: (items) => DropdownButtonFormField<int>(
                value: _roleId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: items
                    .where((role) => role.isHoaRole)
                    .map((role) => DropdownMenuItem(value: role.id, child: Text(role.name)))
                    .toList(),
                onChanged: (value) => setState(() => _roleId = value),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Unable to load roles: $error'),
            ),
            const SizedBox(height: 16),
            hoas.when(
              data: (items) => DropdownButtonFormField<String>(
                value: _hoaId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'HOA', border: OutlineInputBorder()),
                items: items
                    .map((hoa) => DropdownMenuItem(value: hoa.id, child: Text(hoa.label)))
                    .toList(),
                onChanged: (value) => setState(() => _hoaId = value),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Unable to load HOAs: $error'),
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
          child: const Text('Assign Role'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final hoaId = _hoaId;
    final roleId = _roleId;
    if (hoaId == null || roleId == null) return;

    final didAssign = await ref.read(userCommandProvider.notifier).assignHoaRole(
          AssignHoaRoleInput(
            userId: widget.user.id,
            hoaId: hoaId,
            roleId: roleId,
          ),
        );

    if (didAssign && mounted) Navigator.of(context).pop(true);
  }
}
