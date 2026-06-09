import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_access.dart';
import 'hoa_manager_providers.dart';

class HoaScopeHeader extends ConsumerWidget {
  const HoaScopeHeader({
    required this.title,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(hoaManagerHoaRolesProvider);
    final active = ref.watch(activeHoaScopeProvider);

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            active.maybeWhen(
              data: (scope) => scope == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${scope.hoaName ?? scope.hoaId} - ${scope.name}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        roles.when(
          data: (items) => _HoaScopeSelect(items: items),
          loading: () => const SizedBox(width: 180, child: LinearProgressIndicator()),
          error: (error, _) => Text('Unable to load HOA scope: $error'),
        ),
      ],
    );
  }
}

class _HoaScopeSelect extends ConsumerWidget {
  const _HoaScopeSelect({required this.items});

  final List<AdminRoleAssignment> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.length <= 1) return const SizedBox.shrink();

    final selected = ref.watch(selectedHoaScopeProvider) ?? items.first.hoaId;

    return SizedBox(
      width: 280,
      child: DropdownButtonFormField<String>(
        value: selected,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'HOA Scope',
          border: OutlineInputBorder(),
        ),
        items: items
            .map(
              (role) => DropdownMenuItem(
                value: role.hoaId,
                child: Text(role.hoaName ?? role.hoaId ?? 'HOA'),
              ),
            )
            .toList(),
        onChanged: (value) {
          ref.read(selectedHoaScopeProvider.notifier).state = value;
          ref.invalidate(activeHoaScopeProvider);
          ref.invalidate(hoaManagerSummaryProvider);
          ref.invalidate(hoaResidentListProvider);
        },
      ),
    );
  }
}
