import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/service_schedule.dart';
import '../domain/service_schedule_inputs.dart';
import 'service_schedule_dto.dart';

abstract interface class ServiceScheduleRepository {
  Future<List<ServiceSchedule>> list(ServiceScheduleListFilter filter);

  Future<ServiceSchedule> getById(String id);

  Future<ServiceSchedule> create(ServiceScheduleInput input);

  Future<ServiceSchedule> update({
    required String id,
    required ServiceScheduleInput input,
  });

  Future<ServiceSchedule> archive(ServiceSchedule schedule);
}

class ServiceScheduleListFilter {
  const ServiceScheduleListFilter({
    this.hoaId,
    this.serviceType,
    this.status,
    this.scope,
    this.search,
  });

  final String? hoaId;
  final String? serviceType;
  final String? status;
  final String? scope;
  final String? search;

  @override
  bool operator ==(Object other) {
    return other is ServiceScheduleListFilter &&
        other.hoaId == hoaId &&
        other.serviceType == serviceType &&
        other.status == status &&
        other.scope == scope &&
        other.search == search;
  }

  @override
  int get hashCode => Object.hash(hoaId, serviceType, status, scope, search);
}

class SupabaseServiceScheduleRepository implements ServiceScheduleRepository {
  const SupabaseServiceScheduleRepository(this._client);

  final SupabaseClient _client;

  static const _selectColumns = '''
    id,
    hoa_id,
    address_id,
    service_type,
    schedule_rule,
    route_name,
    effective_date,
    end_date,
    status,
    notes,
    created_at,
    updated_at,
    hoa_communities(name, code),
    hoa_addresses(line1, line2, city, state, postal_code)
  ''';

  @override
  Future<List<ServiceSchedule>> list(ServiceScheduleListFilter filter) async {
    var query = _client.from('service_schedules').select(_selectColumns);

    if (filter.hoaId != null && filter.hoaId!.isNotEmpty) {
      query = query.eq('hoa_id', filter.hoaId!);
    }
    if (filter.serviceType != null && filter.serviceType!.isNotEmpty) {
      query = query.eq('service_type', filter.serviceType!);
    }
    if (filter.status != null && filter.status!.isNotEmpty) {
      query = query.eq('status', filter.status!);
    }
    final rows = await query.order('service_type', ascending: true);
    var items = rows.map((row) => ServiceScheduleDto.fromJson(row).toDomain()).toList();

    if (filter.scope == ServiceScheduleScope.hoaWide.value) {
      items = items.where((item) => item.isHoaWide).toList();
    } else if (filter.scope == ServiceScheduleScope.addressOverride.value) {
      items = items.where((item) => item.isOverride).toList();
    }

    final search = filter.search?.trim().toLowerCase();

    if (search == null || search.isEmpty) {
      return items;
    }

    return items.where((item) {
      return item.hoaLabel.toLowerCase().contains(search) ||
          item.serviceTypeLabel.toLowerCase().contains(search) ||
          item.scheduleRule.toLowerCase().contains(search) ||
          item.routeNameLabel.toLowerCase().contains(search) ||
          item.addressLabel.toLowerCase().contains(search) ||
          (item.notes ?? '').toLowerCase().contains(search);
    }).toList();
  }

  @override
  Future<ServiceSchedule> getById(String id) async {
    final row = await _client
        .from('service_schedules')
        .select(_selectColumns)
        .eq('id', id)
        .single();

    return ServiceScheduleDto.fromJson(row).toDomain();
  }

  @override
  Future<ServiceSchedule> create(ServiceScheduleInput input) async {
    final row = await _client
        .from('service_schedules')
        .insert(input.toJson())
        .select(_selectColumns)
        .single();

    return ServiceScheduleDto.fromJson(row).toDomain();
  }

  @override
  Future<ServiceSchedule> update({
    required String id,
    required ServiceScheduleInput input,
  }) async {
    final row = await _client
        .from('service_schedules')
        .update(input.toJson())
        .eq('id', id)
        .select(_selectColumns)
        .single();

    return ServiceScheduleDto.fromJson(row).toDomain();
  }

  @override
  Future<ServiceSchedule> archive(ServiceSchedule schedule) async {
    final today = _dateOnly(DateTime.now());
    final row = await _client
        .from('service_schedules')
        .update({
          'status': ServiceScheduleStatus.archived.name,
          'end_date': _dateOnlyIso(today),
        })
        .eq('id', schedule.id)
        .select(_selectColumns)
        .single();

    return ServiceScheduleDto.fromJson(row).toDomain();
  }
}

enum ServiceScheduleScope {
  hoaWide,
  addressOverride;

  String get value {
    return switch (this) {
      ServiceScheduleScope.hoaWide => 'hoa_wide',
      ServiceScheduleScope.addressOverride => 'address_override',
    };
  }

  String get label {
    return switch (this) {
      ServiceScheduleScope.hoaWide => 'HOA Defaults',
      ServiceScheduleScope.addressOverride => 'Address Overrides',
    };
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _dateOnlyIso(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
