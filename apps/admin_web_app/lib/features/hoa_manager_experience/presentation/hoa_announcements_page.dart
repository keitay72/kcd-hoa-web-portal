import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/rbac/admin_context.dart';
import '../../announcements_cms/domain/announcement.dart';
import '../../announcements_cms/presentation/announcement_form_dialog.dart';
import '../../announcements_cms/presentation/announcement_providers.dart';
import 'hoa_manager_providers.dart';
import 'hoa_scope_header.dart';

class HoaAnnouncementsPage extends ConsumerStatefulWidget {
  const HoaAnnouncementsPage({super.key});

  @override
  ConsumerState<HoaAnnouncementsPage> createState() =>
      _HoaAnnouncementsPageState();
}

class _HoaAnnouncementsPageState extends ConsumerState<HoaAnnouncementsPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(activeHoaScopeProvider);

    return scope.when(
      data: (item) {
        final hoaId = item?.hoaId;
        if (hoaId == null)
          return const Center(child: Text('No HOA scope assigned.'));
        final canManage = ref.watch(activeAdminAccessProvider).maybeWhen(
              data: (access) => access.can('announcements.manage'),
              orElse: () => false,
            );
        final announcements = ref.watch(
            announcementListProvider(AnnouncementListFilter(hoaId: hoaId)));

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const HoaScopeHeader(
                    title: 'HOA Announcements',
                    subtitle: 'Create and manage announcements for your HOA.',
                  ),
                  if (canManage)
                    FilledButton.icon(
                      onPressed: () => _openCreateDialog(context, ref, hoaId),
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Create Announcement'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search announcements',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: announcements.when(
                  data: (items) => _AnnouncementList(items: _filter(items)),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                      child: Text('Unable to load announcements: $error')),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Unable to load HOA scope: $error')),
    );
  }

  List<Announcement> _filter(List<Announcement> items) {
    final search = _searchController.text.trim().toLowerCase();
    if (search.isEmpty) return items;
    return items.where((announcement) {
      return announcement.title.toLowerCase().contains(search) ||
          announcement.statusLabel.toLowerCase().contains(search) ||
          announcement.createdByLabel.toLowerCase().contains(search);
    }).toList();
  }

  Future<void> _openCreateDialog(
      BuildContext context, WidgetRef ref, String hoaId) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AnnouncementFormDialog(
        initialHoaId: hoaId,
        lockHoaSelection: true,
      ),
    );

    if (result != null) ref.invalidate(announcementListProvider);
  }
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({required this.items});

  final List<Announcement> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No announcements matched this HOA search.'),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: Text(item.title),
            subtitle: Text(
                '${item.statusLabel} • Publishes ${_formatDate(item.publishAt)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/admin/announcements/${item.id}'),
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}/${local.year}';
}
