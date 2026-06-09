import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_access.dart';
import 'permission_rules.dart';
import 'rbac_providers.dart';
import 'unauthorized_page.dart';

class ProtectedAdminPage extends ConsumerWidget {
  const ProtectedAdminPage({
    required this.rule,
    required this.child,
    super.key,
  });

  final AdminPermissionRule rule;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rule.isOpen) return child;

    final access = ref.watch(adminAccessProvider);
    return access.when(
      data: (value) {
        if (_isAllowed(value)) return child;
        return UnauthorizedPage(requiredPermissions: rule.permissions);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => UnauthorizedPage(
        requiredPermissions: rule.permissions,
        message: 'Unable to verify your permissions: $error',
      ),
    );
  }

  bool _isAllowed(AdminAccess access) {
    final hasPermissions = rule.permissions.isEmpty || access.canAny(rule.permissions);
    final hasRoles = rule.roleCodes.isEmpty || access.hasAnyRoleCode(rule.roleCodes);
    return hasPermissions && hasRoles;
  }
}

extension ProtectedGoRoute on Widget {
  Widget protectedBy(AdminPermissionRule rule) {
    return ProtectedAdminPage(rule: rule, child: this);
  }
}

void goToUnauthorized(BuildContext context) {
  context.go('/admin/unauthorized');
}
