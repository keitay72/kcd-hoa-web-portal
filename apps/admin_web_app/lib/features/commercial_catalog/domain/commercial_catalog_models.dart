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
  bool get isActive => status == 'active';
  bool get hasActivePrice => prices.any((price) => price.isActive);
  bool get hasStripeReadyPrice => prices.any((price) => price.isStripeReady);
  bool get isAssignable => isActive && hasActivePrice;
  String get hoaLimitLabel =>
      includedHoaCount == null ? 'Unlimited HOAs' : '${_formatCount(includedHoaCount!)} HOAs';
  String get residentLimitLabel => includedResidentCount == null
      ? 'Unlimited residents'
      : '${_formatCount(includedResidentCount!)} residents';
  String get limitLabel => '$hoaLimitLabel · $residentLimitLabel';

  SubscriptionPlanPrice? get monthlyPrice => _priceForInterval('monthly');
  SubscriptionPlanPrice? get annualPrice => _priceForInterval('annual');

  SubscriptionPlanPrice? _priceForInterval(String interval) {
    for (final price in prices) {
      if (price.billingInterval == interval && price.isActive) return price;
    }
    return null;
  }
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
  bool get isActive => status == 'active';
  bool get isStripeReady => stripePriceId != null && stripePriceId!.trim().isNotEmpty;
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
  bool get isActive => status == 'active';
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

String _formatCount(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
