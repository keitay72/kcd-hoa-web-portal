import '../domain/service_schedule.dart';

class ServiceScheduleDto {
  const ServiceScheduleDto({
    required this.id,
    required this.hoaId,
    this.addressId,
    required this.serviceType,
    required this.scheduleRule,
    this.routeName,
    required this.effectiveDate,
    this.endDate,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.hoaName,
    this.hoaCode,
    this.addressLine1,
    this.addressLine2,
    this.addressCity,
    this.addressState,
    this.addressPostalCode,
  });

  final String id;
  final String hoaId;
  final String? addressId;
  final String serviceType;
  final String scheduleRule;
  final String? routeName;
  final DateTime effectiveDate;
  final DateTime? endDate;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hoaName;
  final String? hoaCode;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressCity;
  final String? addressState;
  final String? addressPostalCode;

  factory ServiceScheduleDto.fromJson(Map<String, dynamic> json) {
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;
    final address = json['hoa_addresses'] as Map<String, dynamic>?;

    return ServiceScheduleDto(
      id: json['id'] as String,
      hoaId: json['hoa_id'] as String,
      addressId: json['address_id'] as String?,
      serviceType: json['service_type'] as String,
      scheduleRule: json['schedule_rule'] as String,
      routeName: json['route_name'] as String?,
      effectiveDate: DateTime.parse(json['effective_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      status: json['status'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      hoaName: hoa?['name'] as String?,
      hoaCode: hoa?['code'] as String?,
      addressLine1: address?['line1'] as String?,
      addressLine2: address?['line2'] as String?,
      addressCity: address?['city'] as String?,
      addressState: address?['state'] as String?,
      addressPostalCode: address?['postal_code'] as String?,
    );
  }

  ServiceSchedule toDomain() {
    return ServiceSchedule(
      id: id,
      hoaId: hoaId,
      addressId: addressId,
      serviceType: ServiceScheduleType.fromDatabase(serviceType),
      scheduleRule: scheduleRule,
      routeName: routeName,
      effectiveDate: effectiveDate,
      endDate: endDate,
      status: ServiceScheduleStatus.fromDatabase(status),
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      hoaName: hoaName,
      hoaCode: hoaCode,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      addressCity: addressCity,
      addressState: addressState,
      addressPostalCode: addressPostalCode,
    );
  }
}
