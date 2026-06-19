import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_context.dart';

class UnauthorizedPage extends ConsumerWidget {
  const UnauthorizedPage({
    this.requiredPermissions = const {},
    this.message,
    super.key,
  });

  final Set<String> requiredPermissions;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homePath = ref.watch(activeAdminAccessProvider).maybeWhen(
          data: (access) => access.isHoaScopedOnly ? '/admin/hoa' : '/admin',
          orElse: () => '/admin',
        );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 44,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Access Restricted',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message ??
                        'Your account does not have permission to access this admin area.',
                  ),
                  if (requiredPermissions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Required permission:',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: requiredPermissions
                          .map((permission) => Chip(label: Text(permission)))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go(homePath),
                    icon: const Icon(Icons.dashboard_outlined),
                    label: const Text('Back to Dashboard'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
