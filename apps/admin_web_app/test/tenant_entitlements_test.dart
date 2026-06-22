import 'package:admin_web_app/core/subscriptions/tenant_entitlements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TenantSubscriptionEntitlements', () {
    test('customer portal plans unlock the full core feature set', () {
      for (final planCode in ['local', 'regional', 'metro', 'enterprise']) {
        final entitlements = TenantSubscriptionEntitlements(
          planCode: planCode,
          enabledAddonCodes: const {},
        );

        for (final feature
            in TenantSubscriptionEntitlements.customerPortalFeatures) {
          expect(
            entitlements.isEnabled(feature),
            isTrue,
            reason: '$planCode should include ${feature.label}',
          );
        }
      }
    });

    test('sms notifications remain add-on gated', () {
      const withoutSms = TenantSubscriptionEntitlements(
        planCode: 'metro',
        enabledAddonCodes: {},
      );

      const withSms = TenantSubscriptionEntitlements(
        planCode: 'metro',
        enabledAddonCodes: {'sms_notifications'},
      );

      expect(withoutSms.isEnabled(TenantFeature.smsNotifications), isFalse);
      expect(withSms.isEnabled(TenantFeature.smsNotifications), isTrue);
    });
  });
}
