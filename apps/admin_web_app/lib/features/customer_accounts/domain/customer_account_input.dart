import 'customer_account.dart';

class CustomerAccountInput {
  const CustomerAccountInput({
    required this.accountType,
    required this.status,
    this.accountNumber,
    this.name,
    this.externalAccountRef,
    this.metadata = const {},
  });

  final String? accountNumber;
  final CustomerAccountType accountType;
  final String? name;
  final CustomerAccountStatus status;
  final String? externalAccountRef;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toInsertJson({required String tenantId}) {
    return {
      'tenant_id': tenantId,
      ...toUpdateJson(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'account_number': _blankToNull(accountNumber),
      'account_type': accountType.databaseValue,
      'name': _blankToNull(name),
      'status': status.name,
      'external_account_ref': _blankToNull(externalAccountRef),
      'metadata': metadata,
    };
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
