class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    required this.prices,
    this.description,
    this.includedHoaCount,
    this.includedResidentCount,
  });

  final String id;
  final String code;
  final String name;
  final String status;
  final String? description;
  final int? includedHoaCount;
  final int? includedResidentCount;
  final List<SubscriptionPlanPrice> prices;

  String get statusLabel => _titleCase(status);
}

class SubscriptionPlanPrice {
  const SubscriptionPlanPrice({
    required this.id,
    required this.planId,
    required this.billingInterval,
    required this.currency,
    required this.unitAmountCents,
    required this.status,
    this.stripePriceId,
  });

  final String id;
  final String planId;
  final String billingInterval;
  final String currency;
  final int unitAmountCents;
  final String status;
  final String? stripePriceId;

  String get priceLabel {
    final amount = (unitAmountCents / 100).toStringAsFixed(2);
    return '\$$amount/${billingInterval.toLowerCase()}';
  }

  String get statusLabel => _titleCase(status);
}

class AddonCatalogItem {
  const AddonCatalogItem({
    required this.id,
    required this.code,
    required this.name,
    required this.status,
    this.description,
  });

  final String id;
  final String code;
  final String name;
  final String status;
  final String? description;

  String get statusLabel => _titleCase(status);
}

class PlanInput {
  const PlanInput({
    required this.name,
    required this.status,
    this.description,
    this.includedHoaCount,
    this.includedResidentCount,
  });

  final String name;
  final String status;
  final String? description;
  final int? includedHoaCount;
  final int? includedResidentCount;
}

class PriceInput {
  const PriceInput({
    required this.billingInterval,
    required this.unitAmountCents,
    required this.status,
    this.currency = 'usd',
    this.stripePriceId,
  });

  final String billingInterval;
  final String currency;
  final int unitAmountCents;
  final String status;
  final String? stripePriceId;
}

class AddonInput {
  const AddonInput({
    required this.name,
    required this.status,
    this.description,
  });

  final String name;
  final String status;
  final String? description;
}

String _titleCase(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
