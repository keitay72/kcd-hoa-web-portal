import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/admin_context.dart';
import 'hoa_form_dialog.dart';
import 'hoa_providers.dart';

class HoaListPage extends ConsumerWidget {
  const HoaListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hoas = ref.watch(hoaListProvider);
    final tenantId = ref.watch(activeAdminContextProvider).maybeWhen(
          data: (contextValue) =>
              contextValue?.isTenant == true ? contextValue?.scopeId : null,
          orElse: () => null,
        );

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Community Management',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(activeHoaIdsProvider);
                  ref.invalidate(hoaListProvider);
                },
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _openCreateDialog(
                  context,
                  ref,
                  tenantId: tenantId,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create Community'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: hoas.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(child: Text('No communities found.'));
                }

                return Card(
                  margin: EdgeInsets.zero,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final hoa = items[index];

                      return ListTile(
                        leading: Icon(
                          hoa.isActive
                              ? Icons.domain_outlined
                              : Icons.domain_disabled_outlined,
                        ),
                        title: Text(hoa.name),
                        subtitle: Text(
                          '${hoa.code} · ${hoa.status.name}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/admin/hoas/${hoa.id}'),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load communities: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog(
    BuildContext context,
    WidgetRef ref, {
    required String? tenantId,
  }) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => HoaFormDialog(tenantId: tenantId),
    );

    if (result != null) {
      ref.invalidate(hoaListProvider);
    }
  }
}
