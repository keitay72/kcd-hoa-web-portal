import '../domain/customer_account.dart';

class CustomerAccountDto {
  const CustomerAccountDto({
    required this.id,
    required this.tenantId,
    required this.accountType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.accountNumber,
    this.name,
    this.externalAccountRef,
    this.metadata = const {},
    this.serviceLocationCount,
  });

  final String id;
  final String tenantId;
  final String? accountNumber;
  final String accountType;
  final String? name;
  final String status;
  final String? externalAccountRef;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? serviceLocationCount;

  factory CustomerAccountDto.fromJson(Map<String, dynamic> json) {
    return CustomerAccountDto(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      accountNumber: json['account_number'] as String?,
      accountType: json['account_type'] as String,
      name: json['name'] as String?,
      status: json['status'] as String,
      externalAccountRef: json['external_account_ref'] as String?,
      metadata: _jsonObject(json['metadata']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      serviceLocationCount: json['service_location_count'] as int?,
    );
  }

  CustomerAccount toDomain() {
    return CustomerAccount(
      id: id,
      tenantId: tenantId,
      accountNumber: accountNumber,
      accountType: CustomerAccountType.fromDatabase(accountType),
      name: name,
      status: CustomerAccountStatus.fromDatabase(status),
      externalAccountRef: externalAccountRef,
      metadata: metadata,
      createdAt: createdAt,
      updatedAt: updatedAt,
      serviceLocationCount: serviceLocationCount,
    );
  }

  static Map<String, dynamic> _jsonObject(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    return const {};
  }
}
