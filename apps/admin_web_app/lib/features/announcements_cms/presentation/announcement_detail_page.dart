import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/announcement.dart';
import 'announcement_form_dialog.dart';
import 'announcement_providers.dart';

class AnnouncementDetailPage extends ConsumerWidget {
  const AnnouncementDetailPage({
    required this.announcementId,
    super.key,
  });

  final String announcementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcement = ref.watch(announcementDetailProvider(announcementId));
    final commandState = ref.watch(announcementCommandProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.go('/admin/announcements'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Announcement Detail',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              announcement.maybeWhen(
                data: (item) => _AnnouncementActions(
                  announcement: item,
                  isLoading: commandState.isLoading,
                  onEdit: () => _openEditDialog(context, ref, item),
                  onPublish: () => ref
                      .read(announcementCommandProvider.notifier)
                      .publishAnnouncement(item.id),
                  onUnpublish: () => ref
                      .read(announcementCommandProvider.notifier)
                      .unpublishAnnouncement(item.id),
                  onArchive: () => _archiveAnnouncement(context, ref, item),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          if (commandState.hasError) ...[
            const SizedBox(height: 12),
            Text(
              commandState.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Expanded(
            child: announcement.when(
              data: (item) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(label: Text(item.statusLabel)),
                                  if (item.isScheduled)
                                    const Chip(label: Text('Scheduled')),
                                  if (item.isExpired)
                                    const Chip(label: Text('Expired')),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Content',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              SelectableText(item.body),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Metadata',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              _DetailRow(label: 'ID', value: item.id),
                              _DetailRow(label: 'HOA', value: item.hoaLabel),
                              _DetailRow(label: 'HOA ID', value: item.hoaId),
                              _DetailRow(label: 'Status', value: item.statusLabel),
                              _DetailRow(
                                label: 'Publish Date',
                                value: _formatDateTime(item.publishAt),
                              ),
                              _DetailRow(
                                label: 'Expiration Date',
                                value: item.expireAt == null
                                    ? 'Not set'
                                    : _formatDateTime(item.expireAt!),
                              ),
                              _DetailRow(
                                label: 'Created By',
                                value: item.createdByLabel,
                              ),
                              _DetailRow(
                                label: 'Created',
                                value: _formatDateTime(item.createdAt),
                              ),
                              _DetailRow(
                                label: 'Updated',
                                value: _formatDateTime(item.updatedAt),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load announcement: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    Announcement announcement,
  ) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AnnouncementFormDialog(initialValue: announcement),
    );

    if (result != null) {
      ref.invalidate(announcementDetailProvider(announcement.id));
      ref.invalidate(announcementListProvider);
    }
  }

  Future<void> _archiveAnnouncement(
    BuildContext context,
    WidgetRef ref,
    Announcement announcement,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Announcement?'),
        content: Text(
          'Archive "${announcement.title}"? It will no longer be treated as active content.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(announcementCommandProvider.notifier)
          .archiveAnnouncement(announcement.id);
    }
  }
}

class _AnnouncementActions extends StatelessWidget {
  const _AnnouncementActions({
    required this.announcement,
    required this.isLoading,
    required this.onEdit,
    required this.onPublish,
    required this.onUnpublish,
    required this.onArchive,
  });

  final Announcement announcement;
  final bool isLoading;
  final VoidCallback onEdit;
  final VoidCallback onPublish;
  final VoidCallback onUnpublish;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: isLoading ? null : onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
        if (!announcement.isArchived)
          OutlinedButton.icon(
            onPressed: isLoading
                ? null
                : announcement.isPublished
                    ? onUnpublish
                    : onPublish,
            icon: Icon(
              announcement.isPublished
                  ? Icons.visibility_off_outlined
                  : Icons.publish_outlined,
            ),
            label: Text(announcement.isPublished ? 'Unpublish' : 'Publish'),
          ),
        FilledButton.icon(
          onPressed: announcement.isArchived || isLoading ? null : onArchive,
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.archive_outlined),
          label: const Text('Archive'),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value.isEmpty ? 'Not set' : value)),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
