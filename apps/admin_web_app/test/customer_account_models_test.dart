import 'package:admin_web_app/features/customer_accounts/data/customer_account_dto.dart';
import 'package:admin_web_app/features/customer_accounts/data/service_location_dto.dart';
import 'package:admin_web_app/features/customer_accounts/domain/customer_account.dart';
import 'package:admin_web_app/features/customer_accounts/domain/customer_account_input.dart';
import 'package:admin_web_app/features/customer_accounts/domain/service_location.dart';
import 'package:admin_web_app/features/customer_accounts/domain/service_location_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomerAccount', () {
    test('maps roll off database value and display fallback', () {
      final account = CustomerAccountDto.fromJson({
        'id': 'account-1',
        'tenant_id': 'tenant-1',
        'account_number': '1001',
        'account_type': 'roll_off',
        'name': null,
        'status': 'active',
        'external_account_ref': null,
        'metadata': {'source': 'test'},
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      }).toDomain();

      expect(account.accountType, CustomerAccountType.rollOff);
      expect(account.displayName, 'Account 1001');
      expect(account.metadata, {'source': 'test'});
    });

    test('input trims optional strings and writes database enum values', () {
      const input = CustomerAccountInput(
        accountNumber: ' 2002 ',
        accountType: CustomerAccountType.rollOff,
        name: '  Roll Off Customer ',
        status: CustomerAccountStatus.suspended,
        externalAccountRef: ' ',
      );

      expect(input.toInsertJson(tenantId: 'tenant-1'), {
        'tenant_id': 'tenant-1',
        'account_number': '2002',
        'account_type': 'roll_off',
        'name': 'Roll Off Customer',
        'status': 'suspended',
        'external_account_ref': null,
        'metadata': {},
      });
    });
  });

  group('ServiceLocation', () {
    test('maps joined account fields and address label', () {
      final location = ServiceLocationDto.fromJson({
        'id': 'location-1',
        'tenant_id': 'tenant-1',
        'customer_account_id': 'account-1',
        'line1': '123 Main St',
        'line2': 'Unit B',
        'city': 'Olathe',
        'state': 'KS',
        'postal_code': '66061',
        'normalized_key': '123 MAIN ST|UNIT B|OLATHE|KS|66061',
        'status': 'active',
        'external_location_ref': 'LOC-1',
        'metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
        'customer_accounts': {
          'name': 'Cedar Creek HOA',
          'account_number': 'A-100',
        },
      }).toDomain();

      expect(location.status, ServiceLocationStatus.active);
      expect(location.customerAccountName, 'Cedar Creek HOA');
      expect(location.singleLine, '123 Main St, Unit B, Olathe, KS, 66061');
    });

    test('input normalizes address values for the database', () {
      const input = ServiceLocationInput(
        customerAccountId: 'account-1',
        line1: ' 123 Main St ',
        line2: ' ',
        city: ' Olathe ',
        state: 'ks',
        postalCode: '66061-1234',
        status: ServiceLocationStatus.active,
      );

      expect(input.toInsertJson(tenantId: 'tenant-1'), {
        'tenant_id': 'tenant-1',
        'customer_account_id': 'account-1',
        'line1': '123 Main St',
        'line2': null,
        'city': 'Olathe',
        'state': 'KS',
        'postal_code': '66061-1234',
        'normalized_key': '123MAINST|OLATHE|KS|660611234',
        'status': 'active',
        'external_location_ref': null,
        'metadata': {},
      });
    });
  });
}
