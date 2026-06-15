import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/subscriptions/tenant_entitlements.dart';
import '../domain/commercial_catalog_models.dart';
import 'commercial_catalog_providers.dart';

class CommercialCatalogPage extends ConsumerWidget {
  const CommercialCatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(subscriptionPlansProvider);
    final addons = ref.watch(addonCatalogProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Plans & Add-Ons',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(subscriptionPlansProvider);
                  ref.invalidate(addonCatalogProvider);
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                _CatalogOverview(plans: plans, addons: addons),
                const SizedBox(height: 20),
                _FeatureMatrix(plans: plans, addons: addons),
                const SizedBox(height: 20),
                _PlansSection(plans: plans),
                const SizedBox(height: 20),
                _AddonsSection(addons: addons),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogOverview extends StatelessWidget {
  const _CatalogOverview({required this.plans, required this.addons});

  final AsyncValue<List<SubscriptionPlan>> plans;
  final AsyncValue<List<AddonCatalogItem>> addons;

  @override
  Widget build(BuildContext context) {
    final planItems = plans.valueOrNull ?? const <SubscriptionPlan>[];
    final addonItems = addons.valueOrNull ?? const <AddonCatalogItem>[];
    final activePlans = planItems.where((plan) => plan.isActive).length;
    final assignablePlans = planItems.where((plan) => plan.isAssignable).length;
    final stripeReadyPrices = planItems.fold<int>(
      0,
      (count, plan) => count + plan.prices.where((price) => price.isStripeReady).length,
    );
    final missingStripePrices = planItems.fold<int>(
      0,
      (count, plan) => count + plan.prices.where((price) => price.isActive && !price.isStripeReady).length,
    );
    final activeAddons = addonItems.where((addon) => addon.isActive).length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.dashboard_customize_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catalog Readiness',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use this catalog to define what tenants can subscribe to. Stripe IDs can be filled in once the Stripe account is ready.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 960
                    ? (constraints.maxWidth - 36) / 4
                    : constraints.maxWidth >= 620
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _CatalogMetricTile(
                      width: width,
                      label: 'Active Plans',
                      value: '$activePlans/${planItems.length}',
                      icon: Icons.workspace_premium_outlined,
                      isReady: activePlans > 0,
                    ),
                    _CatalogMetricTile(
                      width: width,
                      label: 'Assignable Plans',
                      value: '$assignablePlans',
                      icon: Icons.assignment_turned_in_outlined,
                      isReady: assignablePlans > 0,
                    ),
                    _CatalogMetricTile(
                      width: width,
                      label: 'Stripe Ready Prices',
                      value: '$stripeReadyPrices',
                      icon: Icons.credit_score_outlined,
                      isReady: missingStripePrices == 0 && stripeReadyPrices > 0,
                      warning: missingStripePrices > 0 ? '$missingStripePrices active price(s) missing Stripe ID' : null,
                    ),
                    _CatalogMetricTile(
                      width: width,
                      label: 'Active Add-Ons',
                      value: '$activeAddons/${addonItems.length}',
                      icon: Icons.extension_outlined,
                      isReady: activeAddons > 0,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogMetricTile extends StatelessWidget {
  const _CatalogMetricTile({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.isReady,
    this.warning,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final bool isReady;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasWarning = warning != null && warning!.trim().isNotEmpty;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasWarning
                ? colorScheme.error.withOpacity(0.45)
                : isReady
                    ? colorScheme.primary.withOpacity(0.35)
                    : colorScheme.outlineVariant,
          ),
          color: hasWarning
              ? colorScheme.errorContainer.withOpacity(0.25)
              : isReady
                  ? colorScheme.primaryContainer.withOpacity(0.20)
                  : colorScheme.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasWarning ? Icons.warning_amber_outlined : icon,
              color: hasWarning
                  ? colorScheme.error
                  : isReady
                      ? colorScheme.primary
                      : colorScheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                  if (hasWarning) ...[
                    const SizedBox(height: 4),
                    Text(warning!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureMatrix extends StatelessWidget {
  const _FeatureMatrix({required this.plans, required this.addons});

  final AsyncValue<List<SubscriptionPlan>> plans;
  final AsyncValue<List<AddonCatalogItem>> addons;

  @override
  Widget build(BuildContext context) {
    final planItems = [...(plans.valueOrNull ?? const <SubscriptionPlan>[])]..sort(_planSort);
    final addonItems = addons.valueOrNull ?? const <AddonCatalogItem>[];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.table_chart_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SaaS Tier Matrix',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quick reference for plan limits, prices, included capabilities, and optional add-ons.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (plans.isLoading || addons.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (plans.hasError)
              Text('Unable to load feature matrix: ${plans.error}')
            else if (planItems.isEmpty)
              const _EmptyCatalogState(
                icon: Icons.table_chart_outlined,
                title: 'No plans to compare yet',
                message: 'Seed or create subscription plans to populate the SaaS tier matrix.',
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth >= 1120
                      ? (constraints.maxWidth - 24) / 3
                      : constraints.maxWidth >= 760
                          ? (constraints.maxWidth - 12) / 2
                          : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: planItems
                        .map(
                          (plan) => SizedBox(
                            width: cardWidth,
                            child: _FeaturePlanCard(
                              plan: plan,
                              activeAddons: addonItems.where((addon) => addon.isActive).toList(),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  static int _planSort(SubscriptionPlan a, SubscriptionPlan b) {
    return _planRank(a.code).compareTo(_planRank(b.code));
  }
}

class _FeaturePlanCard extends StatelessWidget {
  const _FeaturePlanCard({required this.plan, required this.activeAddons});

  final SubscriptionPlan plan;
  final List<AddonCatalogItem> activeAddons;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monthly = plan.monthlyPrice;
    final annual = plan.annualPrice;
    final entitlements = TenantSubscriptionEntitlements(
      planCode: plan.code,
      enabledAddonCodes: const <String>{},
    );
    final includedFeatures = _includedFeatures(entitlements);
    final optionalAddons = activeAddons.where((addon) {
      final feature = _featureForAddon(addon.code);
      return feature == null || !entitlements.isEnabled(feature);
    });
    final enterpriseExtras = plan.code == 'enterprise'
        ? const ['Custom Integrations', 'Priority Support', 'Dedicated Onboarding']
        : const <String>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: plan.isAssignable
              ? colorScheme.primary.withOpacity(0.35)
              : colorScheme.outlineVariant,
        ),
        color: plan.isAssignable
            ? colorScheme.primaryContainer.withOpacity(0.12)
            : colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _SmallStatusChip(
                label: plan.isAssignable ? 'Assignable' : 'Setup Needed',
                isReady: plan.isAssignable,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(plan.description ?? plan.code),
          const SizedBox(height: 14),
          _MatrixLine(label: 'Monthly', value: monthly?.priceLabel ?? 'Not set'),
          _MatrixLine(label: 'Annual', value: annual?.priceLabel ?? 'Not set'),
          _MatrixLine(label: 'Limits', value: plan.limitLabel),
          _MatrixLine(
            label: 'Stripe',
            value: plan.hasStripeReadyPrice ? 'At least one price ready' : 'Price IDs pending',
            isWarning: !plan.hasStripeReadyPrice,
          ),
          const Divider(height: 24),
          Text('Included', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...includedFeatures.map((feature) => _FeatureBullet(label: feature.label, included: true)),
          ...enterpriseExtras.map((feature) => _FeatureBullet(label: feature, included: true)),
          if (optionalAddons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Optional add-ons', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...optionalAddons.map((addon) => _FeatureBullet(label: addon.name, included: false)),
          ],
        ],
      ),
    );
  }
}

class _MatrixLine extends StatelessWidget {
  const _MatrixLine({required this.label, required this.value, this.isWarning = false});

  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isWarning ? colorScheme.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.label, required this.included});

  final String label;
  final bool included;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            included ? Icons.check_circle_outline : Icons.add_circle_outline,
            size: 18,
            color: included ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

List<TenantFeature> _includedFeatures(TenantSubscriptionEntitlements entitlements) {
  const features = [
    ...TenantSubscriptionEntitlements.coreFeatures,
    TenantFeature.dispatchDashboard,
    TenantFeature.advancedTicketManagement,
    TenantFeature.analyticsDashboard,
    TenantFeature.roleManagement,
    TenantFeature.customBranding,
    TenantFeature.apiAccess,
  ];
  return features.where(entitlements.isEnabled).toList(growable: false);
}

TenantFeature? _featureForAddon(String addonCode) {
  return switch (addonCode) {
    'sms_notifications' => TenantFeature.smsNotifications,
    'white_label_branding' => TenantFeature.whiteLabelBranding,
    'custom_domain' => TenantFeature.customDomain,
    'advertising_platform' => TenantFeature.advertisingPlatform,
    'api_access' => TenantFeature.apiAccess,
    _ => null,
  };
}

int _planRank(String code) {
  return switch (code) {
    'starter' => 0,
    'professional' => 1,
    'enterprise' => 2,
    _ => 99,
  };
}

class _PlansSection extends StatelessWidget {
  const _PlansSection({required this.plans});

  final AsyncValue<List<SubscriptionPlan>> plans;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Subscription Plans',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showDialog<Object?>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const PlanDialog(),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Plan'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            plans.when(
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyCatalogState(
                    icon: Icons.workspace_premium_outlined,
                    title: 'No subscription plans yet',
                    message: 'Create your first plan so tenants can be assigned pricing during onboarding.',
                    actionLabel: 'Add Plan',
                    onPressed: () => showDialog<Object?>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const PlanDialog(),
                    ),
                  );
                }
                return Column(
                  children: items.map((plan) => _PlanTile(plan: plan)).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Unable to load plans: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          plan.isAssignable ? Icons.workspace_premium_outlined : Icons.pending_actions_outlined,
        ),
        title: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(plan.name),
            _SmallStatusChip(
              label: plan.isAssignable ? 'Assignable' : 'Needs Setup',
              isReady: plan.isAssignable,
            ),
            if (!plan.hasStripeReadyPrice)
              const _SmallStatusChip(
                label: 'Stripe Pending',
                isReady: false,
                icon: Icons.credit_card_off_outlined,
              ),
          ],
        ),
        subtitle: Text('${plan.code} · ${plan.statusLabel}'),
        trailing: Wrap(
          spacing: 8,
          children: [
            IconButton(
              tooltip: 'Edit plan',
              onPressed: () => showDialog<Object?>(
                context: context,
                barrierDismissible: false,
                builder: (_) => PlanDialog(plan: plan),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(plan.description ?? 'No description.'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Includes: ${plan.limitLabel}',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Prices',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => showDialog<Object?>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => PriceDialog(planId: plan.id),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Price'),
              ),
            ],
          ),
          if (plan.prices.isEmpty)
            _EmptyCatalogState(
              icon: Icons.sell_outlined,
              title: 'No prices configured',
              message: 'Add at least one active price before this plan can be assigned to a tenant.',
              actionLabel: 'Add Price',
              onPressed: () => showDialog<Object?>(
                context: context,
                barrierDismissible: false,
                builder: (_) => PriceDialog(planId: plan.id),
              ),
            )
          else
            ...plan.prices.map(
              (price) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sell_outlined),
                title: Text(price.priceLabel),
                subtitle: Text(
                  [
                    price.currency.toUpperCase(),
                    price.statusLabel,
                    price.isStripeReady ? 'Stripe ready' : 'Stripe ID missing',
                  ].join(' · '),
                ),
                trailing: IconButton(
                  tooltip: 'Edit price',
                  onPressed: () => showDialog<Object?>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => PriceDialog(planId: plan.id, price: price),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddonsSection extends StatelessWidget {
  const _AddonsSection({required this.addons});

  final AsyncValue<List<AddonCatalogItem>> addons;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.extension_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add-On Catalog',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showDialog<Object?>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const AddonDialog(),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Add-On'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            addons.when(
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyCatalogState(
                    icon: Icons.extension_outlined,
                    title: 'No add-ons yet',
                    message: 'Create optional add-ons like SMS notifications when tenants are ready for upgrades.',
                    actionLabel: 'Add Add-On',
                    onPressed: () => showDialog<Object?>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const AddonDialog(),
                    ),
                  );
                }
                return Column(
                  children: items
                      .map(
                        (addon) => ListTile(
                          leading: Icon(
                            addon.isActive ? Icons.add_circle_outline : Icons.extension_off_outlined,
                          ),
                          title: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(addon.name),
                              _SmallStatusChip(
                                label: addon.statusLabel,
                                isReady: addon.isActive,
                              ),
                            ],
                          ),
                          subtitle: Text(addon.description ?? addon.code),
                          trailing: IconButton(
                            tooltip: 'Edit add-on',
                            onPressed: () => showDialog<Object?>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => AddonDialog(addon: addon),
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Unable to load add-ons: $error'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallStatusChip extends StatelessWidget {
  const _SmallStatusChip({
    required this.label,
    required this.isReady,
    this.icon,
  });

  final String label;
  final bool isReady;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(
        icon ?? (isReady ? Icons.check_circle_outline : Icons.pending_outlined),
        size: 16,
        color: isReady ? colorScheme.primary : colorScheme.outline,
      ),
      label: Text(label),
      labelStyle: Theme.of(context).textTheme.bodySmall,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyCatalogState extends StatelessWidget {
  const _EmptyCatalogState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(message),
                if (actionLabel != null && onPressed != null) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.arrow_forward_outlined),
                    label: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlanDialog extends ConsumerStatefulWidget {
  const PlanDialog({this.plan, super.key});

  final SubscriptionPlan? plan;

  @override
  ConsumerState<PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends ConsumerState<PlanDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _hoaCount;
  late final TextEditingController _residentCount;
  late String _status;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _name = TextEditingController(text: plan?.name ?? '');
    _description = TextEditingController(text: plan?.description ?? '');
    _hoaCount = TextEditingController(text: plan?.includedHoaCount?.toString() ?? '');
    _residentCount = TextEditingController(text: plan?.includedResidentCount?.toString() ?? '');
    _status = plan?.status ?? 'draft';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _hoaCount.dispose();
    _residentCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commercialCatalogControllerProvider);
    return AlertDialog(
      title: Text(widget.plan == null ? 'Add Plan' : 'Edit Plan'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Plan name'),
                validator: _required,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _numberField(_hoaCount, 'Included HOAs')),
                  const SizedBox(width: 16),
                  Expanded(child: _numberField(_residentCount, 'Included residents')),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: (value) => setState(() => _status = value ?? _status),
              ),
              if (state.hasError) ...[
                const SizedBox(height: 16),
                Text(
                  'Unable to save plan: ${state.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: state.isLoading ? null : _submit,
          child: const Text('Save Plan'),
        ),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: 'Leave blank for unlimited.',
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required.' : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(commercialCatalogControllerProvider.notifier).savePlan(
          planId: widget.plan?.id,
          input: PlanInput(
            name: _name.text,
            description: _description.text,
            includedHoaCount: int.tryParse(_hoaCount.text),
            includedResidentCount: int.tryParse(_residentCount.text),
            status: _status,
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}

class PriceDialog extends ConsumerStatefulWidget {
  const PriceDialog({required this.planId, this.price, super.key});

  final String planId;
  final SubscriptionPlanPrice? price;

  @override
  ConsumerState<PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends ConsumerState<PriceDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _interval;
  late String _status;
  late final TextEditingController _amount;
  late final TextEditingController _currency;
  late final TextEditingController _stripePriceId;

  @override
  void initState() {
    super.initState();
    final price = widget.price;
    _interval = price?.billingInterval ?? 'monthly';
    _status = price?.status ?? 'active';
    _amount = TextEditingController(
      text: price == null ? '' : (price.unitAmountCents / 100).toStringAsFixed(2),
    );
    _currency = TextEditingController(text: price?.currency ?? 'usd');
    _stripePriceId = TextEditingController(text: price?.stripePriceId ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _currency.dispose();
    _stripePriceId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commercialCatalogControllerProvider);
    return AlertDialog(
      title: Text(widget.price == null ? 'Add Price' : 'Edit Price'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(labelText: 'Amount', prefixText: r'$'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => _amountToCents(value) == null ? 'Enter a valid amount.' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _interval,
                decoration: const InputDecoration(labelText: 'Billing interval'),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  DropdownMenuItem(value: 'annual', child: Text('Annual')),
                ],
                onChanged: (value) => setState(() => _interval = value ?? _interval),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stripePriceId,
                decoration: const InputDecoration(
                  labelText: 'Stripe price ID',
                  helperText: 'Optional until Stripe is connected. Required before live checkout.',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: (value) => setState(() => _status = value ?? _status),
              ),
              if (state.hasError) ...[
                const SizedBox(height: 16),
                Text(
                  'Unable to save price: ${state.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: state.isLoading ? null : _submit,
          child: const Text('Save Price'),
        ),
      ],
    );
  }

  int? _amountToCents(String? value) {
    final parsed = double.tryParse((value ?? '').trim());
    if (parsed == null || parsed < 0) return null;
    return (parsed * 100).round();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final cents = _amountToCents(_amount.text);
    if (cents == null) return;
    final ok = await ref.read(commercialCatalogControllerProvider.notifier).savePrice(
          planId: widget.planId,
          priceId: widget.price?.id,
          input: PriceInput(
            billingInterval: _interval,
            unitAmountCents: cents,
            status: _status,
            currency: _currency.text,
            stripePriceId: _stripePriceId.text,
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}

class AddonDialog extends ConsumerStatefulWidget {
  const AddonDialog({this.addon, super.key});

  final AddonCatalogItem? addon;

  @override
  ConsumerState<AddonDialog> createState() => _AddonDialogState();
}

class _AddonDialogState extends ConsumerState<AddonDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late String _status;

  @override
  void initState() {
    super.initState();
    final addon = widget.addon;
    _name = TextEditingController(text: addon?.name ?? '');
    _description = TextEditingController(text: addon?.description ?? '');
    _status = addon?.status ?? 'draft';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commercialCatalogControllerProvider);
    return AlertDialog(
      title: Text(widget.addon == null ? 'Add Add-On' : 'Edit Add-On'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Add-on name'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Required.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: (value) => setState(() => _status = value ?? _status),
              ),
              if (state.hasError) ...[
                const SizedBox(height: 16),
                Text(
                  'Unable to save add-on: ${state.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: state.isLoading ? null : _submit,
          child: const Text('Save Add-On'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(commercialCatalogControllerProvider.notifier).saveAddon(
          addonId: widget.addon?.id,
          input: AddonInput(
            name: _name.text,
            description: _description.text,
            status: _status,
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}
