import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/customer_account.dart';
import '../domain/customer_account_input.dart';
import '../domain/service_location.dart';
import '../domain/service_location_input.dart';
import 'customer_account_dto.dart';
import 'service_location_dto.dart';

class DuplicateServiceLocationException implements Exception {
  const DuplicateServiceLocationException(this.normalizedKey);

  final String normalizedKey;

  @override
  String toString() {
    return 'Service location already exists for this account: $normalizedKey';
  }
}

abstract interface class CustomerAccountRepository {
  Future<List<CustomerAccount>> listAccounts({
    String? tenantId,
    CustomerAccountType? accountType,
  });

  Future<CustomerAccount> getAccountById(String id);

  Future<CustomerAccount> createAccount(
    CustomerAccountInput input, {
    String? tenantId,
  });

  Future<CustomerAccount> updateAccount({
    required String id,
    required CustomerAccountInput input,
  });

  Future<List<ServiceLocation>> listServiceLocations({
    String? customerAccountId,
    String? tenantId,
  });

  Future<ServiceLocation> getServiceLocationById(String id);

  Future<ServiceLocation> createServiceLocation(
    ServiceLocationInput input, {
    String? tenantId,
  });

  Future<ServiceLocation> updateServiceLocation({
    required String id,
    required ServiceLocationInput input,
  });
}

class SupabaseCustomerAccountRepository implements CustomerAccountRepository {
  const SupabaseCustomerAccountRepository(this._client);

  final SupabaseClient _client;

  static const _accountSelectColumns = '''
    id,
    tenant_id,
    account_number,
    account_type,
    name,
    status,
    external_account_ref,
    metadata,
    created_at,
    updated_at
  ''';

  static const _locationSelectColumns = '''
    id,
    tenant_id,
    customer_account_id,
    line1,
    line2,
    city,
    state,
    postal_code,
    normalized_key,
    status,
    external_location_ref,
    metadata,
    created_at,
    updated_at,
    customer_accounts(name, account_number)
  ''';

  @override
  Future<List<CustomerAccount>> listAccounts({
    String? tenantId,
    CustomerAccountType? accountType,
  }) async {
    var query = _client.from('customer_accounts').select(_accountSelectColumns);

    if (tenantId != null && tenantId.isNotEmpty) {
      query = query.eq('tenant_id', tenantId);
    }

    if (accountType != null) {
      query = query.eq('account_type', accountType.databaseValue);
    }

    final rows = await query.order('name', ascending: true);
    return rows
        .map((row) => CustomerAccountDto.fromJson(row).toDomain())
        .toList();
  }

  @override
  Future<CustomerAccount> getAccountById(String id) async {
    final row = await _client
        .from('customer_accounts')
        .select(_accountSelectColumns)
        .eq('id', id)
        .single();

    return CustomerAccountDto.fromJson(row).toDomain();
  }

  @override
  Future<CustomerAccount> createAccount(
    CustomerAccountInput input, {
    String? tenantId,
  }) async {
    final targetTenantId = tenantId ?? await _primaryTenantId();
    final row = await _client
        .from('customer_accounts')
        .insert(input.toInsertJson(tenantId: targetTenantId))
        .select(_accountSelectColumns)
        .single();

    return CustomerAccountDto.fromJson(row).toDomain();
  }

  @override
  Future<CustomerAccount> updateAccount({
    required String id,
    required CustomerAccountInput input,
  }) async {
    final row = await _client
        .from('customer_accounts')
        .update(input.toUpdateJson())
        .eq('id', id)
        .select(_accountSelectColumns)
        .single();

    return CustomerAccountDto.fromJson(row).toDomain();
  }

  @override
  Future<List<ServiceLocation>> listServiceLocations({
    String? customerAccountId,
    String? tenantId,
  }) async {
    var query =
        _client.from('service_locations').select(_locationSelectColumns);

    if (customerAccountId != null && customerAccountId.isNotEmpty) {
      query = query.eq('customer_account_id', customerAccountId);
    }

    if (tenantId != null && tenantId.isNotEmpty) {
      query = query.eq('tenant_id', tenantId);
    }

    final rows = await query.order('line1', ascending: true);
    return rows
        .map((row) => ServiceLocationDto.fromJson(row).toDomain())
        .toList();
  }

  @override
  Future<ServiceLocation> getServiceLocationById(String id) async {
    final row = await _client
        .from('service_locations')
        .select(_locationSelectColumns)
        .eq('id', id)
        .single();

    return ServiceLocationDto.fromJson(row).toDomain();
  }

  @override
  Future<ServiceLocation> createServiceLocation(
    ServiceLocationInput input, {
    String? tenantId,
  }) async {
    await _ensureUniqueServiceLocation(input);
    final targetTenantId = tenantId ??
        await _tenantIdForAccount(
          input.customerAccountId,
        );
    final row = await _client
        .from('service_locations')
        .insert(input.toInsertJson(tenantId: targetTenantId))
        .select(_locationSelectColumns)
        .single();

    return ServiceLocationDto.fromJson(row).toDomain();
  }

  @override
  Future<ServiceLocation> updateServiceLocation({
    required String id,
    required ServiceLocationInput input,
  }) async {
    await _ensureUniqueServiceLocation(input, excludingLocationId: id);
    final row = await _client
        .from('service_locations')
        .update(input.toUpdateJson())
        .eq('id', id)
        .select(_locationSelectColumns)
        .single();

    return ServiceLocationDto.fromJson(row).toDomain();
  }

  Future<void> _ensureUniqueServiceLocation(
    ServiceLocationInput input, {
    String? excludingLocationId,
  }) async {
    var query = _client
        .from('service_locations')
        .select('id')
        .eq('customer_account_id', input.customerAccountId)
        .eq('normalized_key', input.normalizedKey);

    final rows = excludingLocationId == null
        ? await query.limit(1)
        : await query.neq('id', excludingLocationId).limit(1);

    if (rows.isNotEmpty) {
      throw DuplicateServiceLocationException(input.normalizedKey);
    }
  }

  Future<String> _tenantIdForAccount(String customerAccountId) async {
    final row = await _client
        .from('customer_accounts')
        .select('tenant_id')
        .eq('id', customerAccountId)
        .single();

    return row['tenant_id'] as String;
  }

  Future<String> _primaryTenantId() async {
    final primaryTenant = await _client
        .from('platform_tenants')
        .select('id')
        .eq('is_primary', true)
        .single();

    return primaryTenant['id'] as String;
  }
}
