import '../domain/service_location.dart';

class ServiceLocationDto {
  const ServiceLocationDto({
    required this.id,
    required this.tenantId,
    required this.customerAccountId,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.normalizedKey,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.externalLocationRef,
    this.metadata = const {},
    this.customerAccountName,
    this.customerAccountNumber,
  });

  final String id;
  final String tenantId;
  final String customerAccountId;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;
  final String normalizedKey;
  final String status;
  final String? externalLocationRef;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? customerAccountName;
  final String? customerAccountNumber;

  factory ServiceLocationDto.fromJson(Map<String, dynamic> json) {
    final account = json['customer_accounts'] as Map<String, dynamic>?;

    return ServiceLocationDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      customerAccountId: json['customer_account_id'] as String,
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postal_code'] as String,
      normalizedKey: json['normalized_key'] as String,
      status: json['status'] as String,
      externalLocationRef: json['external_location_ref'] as String?,
      metadata: _jsonObject(json['metadata']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      customerAccountName: account?['name'] as String?,
      customerAccountNumber: account?['account_number'] as String?,
    );
  }

  ServiceLocation toDomain() {
    return ServiceLocation(
      id: id,
      tenantId: tenantId,
      customerAccountId: customerAccountId,
      line1: line1,
      line2: line2,
      city: city,
      state: state,
      postalCode: postalCode,
      normalizedKey: normalizedKey,
      status: ServiceLocationStatus.fromDatabase(status),
      externalLocationRef: externalLocationRef,
      metadata: metadata,
      createdAt: createdAt,
      updatedAt: updatedAt,
      customerAccountName: customerAccountName,
      customerAccountNumber: customerAccountNumber,
    );
  }

  static Map<String, dynamic> _jsonObject(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    return const {};
  }
}
