import 'service_schedule.dart';

class ServiceScheduleInput {
  const ServiceScheduleInput({
    required this.hoaId,
    this.addressId,
    required this.serviceType,
    required this.scheduleRule,
    required this.effectiveDate,
    this.endDate,
    required this.status,
    this.routeName,
    this.notes,
  });

  final String hoaId;
  final String? addressId;
  final ServiceScheduleType serviceType;
  final String scheduleRule;
  final DateTime effectiveDate;
  final DateTime? endDate;
  final ServiceScheduleStatus status;
  final String? routeName;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'hoa_id': hoaId,
      'address_id': addressId,
      'service_type': serviceType.databaseValue,
      'schedule_rule': scheduleRule.trim(),
      'route_name': _nullableText(routeName),
      'effective_date': _dateOnlyIso(effectiveDate),
      'end_date': endDate == null ? null : _dateOnlyIso(endDate!),
      'status': status.name,
      'notes': _nullableText(notes),
    };
  }
}

String? _nullableText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _dateOnlyIso(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
