import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../hoa_management/domain/hoa_community.dart';
import '../../hoa_management/presentation/hoa_providers.dart';
import '../domain/announcement.dart';
import 'announcement_form_dialog.dart';
import 'announcement_providers.dart';

class AnnouncementListPage extends ConsumerStatefulWidget {
  const AnnouncementListPage({super.key});

  @override
  ConsumerState<AnnouncementListPage> createState() => _AnnouncementListPageState();
}

class _AnnouncementListPageState extends ConsumerState<AnnouncementListPage> {
  final _searchController = TextEditingController();
  String? _hoaId;
  String? _status;
  DateTime? _publishFrom;
  DateTime? _publishTo;

  AnnouncementListFilter get _filter => AnnouncementListFilter(
        hoaId: _hoaId,
        status: _status,
        publishFrom: _publishFrom,
        publishTo: _publishTo == null ? null : _datePlusOneDay(_publishTo!),
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final announcements = ref.watch(announcementListProvider(_filter));
    final hoas = ref.watch(hoaListProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Announcements',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: _openCreateDialog,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Create Announcement'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _AnnouncementFilterBar(
                hoas: hoas,
                hoaId: _hoaId,
                status: _status,
                publishFrom: _publishFrom,
                publishTo: _publishTo,
                searchController: _searchController,
                onHoaChanged: (value) => setState(() => _hoaId = value),
                onStatusChanged: (value) => setState(() => _status = value),
                onPublishFromChanged: (value) => setState(() => _publishFrom = value),
                onPublishToChanged: (value) => setState(() => _publishTo = value),
                onApply: () => setState(() {}),
                onReset: () {
                  setState(() {
                    _hoaId = null;
                    _status = null;
                    _publishFrom = null;
                    _publishTo = null;
                    _searchController.clear();
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: announcements.when(
              data: (items) => _AnnouncementTable(announcements: items),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load announcements: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AnnouncementFormDialog(),
    );

    if (result != null) {
      ref.invalidate(announcementListProvider);
    }
  }
}

class _AnnouncementFilterBar extends StatelessWidget {
  const _AnnouncementFilterBar({
    required this.hoas,
    required this.hoaId,
    required this.status,
    required this.publishFrom,
    required this.publishTo,
    required this.searchController,
    required this.onHoaChanged,
    required this.onStatusChanged,
    required this.onPublishFromChanged,
    required this.onPublishToChanged,
    required this.onApply,
    required this.onReset,
  });

  final AsyncValue<List<HoaCommunity>> hoas;
  final String? hoaId;
  final String? status;
  final DateTime? publishFrom;
  final DateTime? publishTo;
  final TextEditingController searchController;
  final ValueChanged<String?> onHoaChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<DateTime?> onPublishFromChanged;
  final ValueChanged<DateTime?> onPublishToChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  static const _spacing = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hoaFilter = hoas.when(
          data: (items) => _HoaFilter(
            hoas: items,
            value: hoaId,
            onChanged: onHoaChanged,
          ),
          loading: () => const SizedBox(
            height: 56,
            child: Center(child: LinearProgressIndicator()),
          ),
          error: (error, _) => SizedBox(
            height: 56,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Unable to load HOAs: $error'),
            ),
          ),
        );
        final statusFilter = _StatusFilter(
          value: status,
          onChanged: onStatusChanged,
        );
        final searchFilter = TextField(
          controller: searchController,
          decoration: const InputDecoration(
            labelText: 'Search',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => onApply(),
        );
        final fromFilter = _DateFilterButton(
          label: 'Publish From',
          value: publishFrom,
          onChanged: onPublishFromChanged,
        );
        final toFilter = _DateFilterButton(
          label: 'Publish To',
          value: publishTo,
          onChanged: onPublishToChanged,
        );
        final actions = _FilterActions(
          onApply: onApply,
          onReset: onReset,
        );

        if (constraints.maxWidth >= 1200) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: hoaFilter),
              const SizedBox(width: _spacing),
              SizedBox(width: 170, child: statusFilter),
              const SizedBox(width: _spacing),
              SizedBox(width: 170, child: fromFilter),
              const SizedBox(width: _spacing),
              SizedBox(width: 170, child: toFilter),
              const SizedBox(width: _spacing),
              Expanded(flex: 3, child: searchFilter),
              const SizedBox(width: _spacing),
              actions,
            ],
          );
        }

        final fieldWidth = constraints.maxWidth < 560
            ? constraints.maxWidth
            : (constraints.maxWidth - _spacing) / 2;

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: fieldWidth, child: hoaFilter),
            SizedBox(width: fieldWidth, child: statusFilter),
            SizedBox(width: fieldWidth, child: fromFilter),
            SizedBox(width: fieldWidth, child: toFilter),
            SizedBox(width: fieldWidth, child: searchFilter),
            actions,
          ],
        );
      },
    );
  }
}

class _HoaFilter extends StatelessWidget {
  const _HoaFilter({
    required this.hoas,
    required this.value,
    required this.onChanged,
  });

  final List<HoaCommunity> hoas;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'HOA',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All HOAs'),
        ),
        ...hoas.map(
          (hoa) => DropdownMenuItem<String?>(
            value: hoa.id,
            child: Text(
              '${hoa.name} (${hoa.code})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      selectedItemBuilder: (context) {
        return [
          const Text('All HOAs', overflow: TextOverflow.ellipsis),
          ...hoas.map(
            (hoa) => Text(
              '${hoa.name} (${hoa.code})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ];
      },
      onChanged: onChanged,
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _allStatusesValue = '__all__';

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value ?? _allStatusesValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: _allStatusesValue,
          child: Text('All Statuses'),
        ),
        ...AnnouncementStatus.values.map(
          (status) => DropdownMenuItem<String>(
            value: status.name,
            child: Text(_label(status.name)),
          ),
        ),
      ],
      selectedItemBuilder: (context) {
        return [
          const Text('All Statuses', overflow: TextOverflow.ellipsis),
          ...AnnouncementStatus.values.map(
            (status) => Text(
              _label(status.name),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ];
      },
      onChanged: (nextValue) {
        onChanged(nextValue == _allStatusesValue ? null : nextValue);
      },
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: () => _pickDate(context),
      child: Row(
        children: [
          const Icon(Icons.date_range_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  value == null ? 'Any' : _formatDate(value!),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (value != null)
            IconButton(
              tooltip: 'Clear $label',
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (date != null) {
      onChanged(DateTime(date.year, date.month, date.day));
    }
  }
}

class _FilterActions extends StatelessWidget {
  const _FilterActions({
    required this.onApply,
    required this.onReset,
  });

  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.search),
            label: const Text('Apply'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onReset,
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementTable extends ConsumerWidget {
  const _AnnouncementTable({required this.announcements});

  final List<Announcement> announcements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (announcements.isEmpty) {
      return const Center(child: Text('No announcements found.'));
    }

    final commandState = ref.watch(announcementCommandProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: announcements.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final announcement = announcements[index];
          return ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: Text(announcement.title),
            subtitle: Text(
              '${announcement.hoaLabel} - Publish: ${_formatDateTime(announcement.publishAt)} - Updated: ${_formatDateTime(announcement.updatedAt)}',
            ),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(announcement.statusLabel)),
                if (!announcement.isArchived)
                  IconButton(
                    tooltip: announcement.isPublished ? 'Unpublish' : 'Publish',
                    onPressed: commandState.isLoading
                        ? null
                        : () => announcement.isPublished
                            ? ref
                                .read(announcementCommandProvider.notifier)
                                .unpublishAnnouncement(announcement.id)
                            : ref
                                .read(announcementCommandProvider.notifier)
                                .publishAnnouncement(announcement.id),
                    icon: Icon(
                      announcement.isPublished
                          ? Icons.visibility_off_outlined
                          : Icons.publish_outlined,
                    ),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.go('/admin/announcements/${announcement.id}'),
          );
        },
      ),
    );
  }
}

DateTime _datePlusOneDay(DateTime value) {
  return DateTime(value.year, value.month, value.day + 1);
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

String _label(String value) {
  return value[0].toUpperCase() + value.substring(1);
}
