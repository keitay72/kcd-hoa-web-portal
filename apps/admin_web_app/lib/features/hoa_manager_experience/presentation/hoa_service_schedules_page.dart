import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../schedules_admin/domain/service_schedule.dart';
import '../../schedules_admin/presentation/service_schedule_providers.dart';
import 'hoa_manager_providers.dart';
import 'hoa_scope_header.dart';

class HoaServiceSchedulesPage extends ConsumerStatefulWidget {
  const HoaServiceSchedulesPage({super.key});

  @override
  ConsumerState<HoaServiceSchedulesPage> createState() => _HoaServiceSchedulesPageState();
}

class _HoaServiceSchedulesPageState extends ConsumerState<HoaServiceSchedulesPage> {
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
        if (hoaId == null) return const Center(child: Text('No HOA scope assigned.'));
        final schedules = ref.watch(serviceScheduleListProvider(ServiceScheduleListFilter(
          hoaId: hoaId,
          status: ServiceScheduleStatus.active.name,
        )));

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HoaScopeHeader(
                title: 'HOA Service Schedules',
                subtitle: 'HOA-wide schedules and address overrides for your community.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search schedules',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: schedules.when(
                  data: (items) => _ScheduleList(schedules: _filter(items)),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Unable to load schedules: $error')),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Unable to load HOA scope: $error')),
    );
  }

  List<ServiceSchedule> _filter(List<ServiceSchedule> items) {
    final search = _searchController.text.trim().toLowerCase();
    if (search.isEmpty) return items;
    return items.where((schedule) {
      return schedule.serviceTypeLabel.toLowerCase().contains(search) ||
          schedule.scheduleRule.toLowerCase().contains(search) ||
          schedule.routeNameLabel.toLowerCase().contains(search) ||
          schedule.addressLabel.toLowerCase().contains(search) ||
          schedule.scheduleScopeLabel.toLowerCase().contains(search);
    }).toList();
  }
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.schedules});

  final List<ServiceSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No active schedules matched this HOA search.'),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: schedules.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final schedule = schedules[index];
          return ListTile(
            leading: const Icon(Icons.event_repeat_outlined),
            title: Text('${schedule.serviceTypeLabel}: ${schedule.scheduleRule}'),
            subtitle: Text('${schedule.scheduleScopeLabel} • ${schedule.routeNameLabel} • ${schedule.addressLabel}'),
            trailing: Chip(label: Text(schedule.statusLabel)),
          );
        },
      ),
    );
  }
}
