import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/service_schedule.dart';
import 'service_schedule_form_dialog.dart';
import 'service_schedule_providers.dart';

class ServiceScheduleDetailPage extends ConsumerWidget {
  const ServiceScheduleDetailPage({
    required this.scheduleId,
    super.key,
  });

  final String scheduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedule = ref.watch(serviceScheduleDetailProvider(scheduleId));
    final commandState = ref.watch(serviceScheduleCommandProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.go('/admin/service-schedules'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Service Schedule Detail',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              schedule.maybeWhen(
                data: (item) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: commandState.isLoading
                          ? null
                          : () => _openEditDialog(context, ref, item),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    FilledButton.icon(
                      onPressed: item.isArchived || commandState.isLoading
                          ? null
                          : () => _archiveSchedule(context, ref, item),
                      icon: commandState.isLoading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.archive_outlined),
                      label: const Text('Archive'),
                    ),
                  ],
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
            child: schedule.when(
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
                                '${item.serviceTypeLabel}: ${item.scheduleRule}',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(label: Text(item.statusLabel)),
                                  Chip(label: Text(item.scheduleScopeLabel)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _DetailRow(label: 'HOA', value: item.hoaLabel),
                              _DetailRow(label: 'Scope', value: item.scheduleScopeLabel),
                              _DetailRow(label: 'Address', value: item.addressLabel),
                              _DetailRow(label: 'Service Type', value: item.serviceTypeLabel),
                              _DetailRow(label: 'Schedule Rule', value: item.scheduleRule),
                              _DetailRow(label: 'Route Name', value: item.routeNameLabel),
                              _DetailRow(label: 'Effective Date', value: _formatDate(item.effectiveDate)),
                              _DetailRow(
                                label: 'End Date',
                                value: item.endDate == null
                                    ? 'Not set'
                                    : _formatDate(item.endDate!),
                              ),
                              _DetailRow(label: 'Status', value: item.statusLabel),
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
                                'Schedule Details',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 16),
                              _DetailRow(label: 'ID', value: item.id),
                              _DetailRow(label: 'HOA ID', value: item.hoaId),
                              _DetailRow(label: 'Address ID', value: item.addressId ?? 'Not set'),
                              _DetailRow(label: 'Holiday Overrides / Notes', value: item.notes ?? 'Not set'),
                              _DetailRow(label: 'Created', value: _formatDateTime(item.createdAt)),
                              _DetailRow(label: 'Updated', value: _formatDateTime(item.updatedAt)),
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
                child: Text('Unable to load service schedule: $error'),
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
    ServiceSchedule schedule,
  ) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ServiceScheduleFormDialog(initialValue: schedule),
    );

    if (result != null) {
      ref.invalidate(serviceScheduleDetailProvider(schedule.id));
      ref.invalidate(serviceScheduleListProvider);
    }
  }

  Future<void> _archiveSchedule(
    BuildContext context,
    WidgetRef ref,
    ServiceSchedule schedule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Service Schedule?'),
        content: Text(
          'Archive ${schedule.serviceTypeLabel} for ${schedule.hoaLabel}? This will retain it historically.',
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
      await ref.read(serviceScheduleCommandProvider.notifier).archiveSchedule(schedule);
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
            width: 155,
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

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${_formatDate(local)} $hour:$minute';
}
