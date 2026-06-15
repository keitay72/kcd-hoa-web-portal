import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';
import 'tenant_management_providers.dart';


class _BillingModeHelp extends StatelessWidget {
  const _BillingModeHelp({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, title, message) = switch (mode) {
      'free_beta' => (
          Icons.science_outlined,
          'Free beta',
          'No payment is collected. The selected plan still controls limits, features, and overage warnings.',
        ),
      'stripe' => (
          Icons.credit_card_outlined,
          'Stripe billing',
          'Use this when the Stripe customer and price IDs are ready for checkout and subscription sync.',
        ),
      _ => (
          Icons.receipt_long_outlined,
          'Manual billing',
          'Use this for offline billing or temporary subscriptions before Stripe automation is connected.',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPlanSummary extends StatelessWidget {
  const _SelectedPlanSummary({required this.plan});

  final SubscriptionPlanSummary plan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(plan.limitLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (plan.description != null) ...[
            const SizedBox(height: 6),
            Text(plan.description!),
          ],
          const SizedBox(height: 8),
          Text(
            'Stripe checkout can stay pending until the Stripe account and price IDs are ready.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class TenantSubscriptionDialog extends ConsumerStatefulWidget {
  const TenantSubscriptionDialog({
    required this.tenantId,
    required this.availablePlans,
    this.subscription,
    super.key,
  });

  final String tenantId;
  final List<SubscriptionPlanSummary> availablePlans;
  final TenantSubscriptionSummary? subscription;

  @override
  ConsumerState<TenantSubscriptionDialog> createState() => _TenantSubscriptionDialogState();
}

class _TenantSubscriptionDialogState extends ConsumerState<TenantSubscriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _planId;
  late String? _priceId;
  late String _status;
  late String _billingMode;
  late final TextEditingController _freeBetaEndsAt;
  late final TextEditingController _billingNotes;
  late final TextEditingController _periodStart;
  late final TextEditingController _periodEnd;
  late final TextEditingController _trialEndsAt;

  @override
  void initState() {
    super.initState();
    final subscription = widget.subscription;
    final existingPlanId = subscription?.planId;
    _planId = _isActivePlan(existingPlanId) ? existingPlanId : _firstPlanId();
    _priceId = subscription?.priceId ?? _firstPriceId(_planId);
    _billingMode = subscription?.billingMode ?? 'free_beta';
    _status = subscription?.status ?? (_billingMode == 'free_beta' ? 'active' : 'trialing');
    _freeBetaEndsAt = TextEditingController(text: _dateText(subscription?.freeBetaEndsAt));
    _billingNotes = TextEditingController(text: subscription?.billingNotes ?? '');
    _periodStart = TextEditingController(text: _dateText(subscription?.currentPeriodStart));
    _periodEnd = TextEditingController(text: _dateText(subscription?.currentPeriodEnd));
    _trialEndsAt = TextEditingController(text: _dateText(subscription?.trialEndsAt));
  }

  @override
  void dispose() {
    _freeBetaEndsAt.dispose();
    _billingNotes.dispose();
    _periodStart.dispose();
    _periodEnd.dispose();
    _trialEndsAt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantMutationControllerProvider);
    final selectedPlan = _selectedPlan;
    final activePlans = _activePlans;
    final prices = selectedPlan?.activePrices ?? const <SubscriptionPriceSummary>[];
    final isFreeBeta = _billingMode == 'free_beta';

    return AlertDialog(
      title: Text(widget.subscription == null ? 'Assign Subscription' : 'Change Subscription'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (activePlans.isEmpty)
                const Text('Create at least one active subscription plan before assigning a tenant subscription.')
              else ...[
                DropdownButtonFormField<String>(
                  value: _planId,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: activePlans
                      .map(
                        (plan) => DropdownMenuItem(
                          value: plan.id,
                          child: Text('${plan.name} - ${plan.limitLabel}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _planId = value;
                      _priceId = _firstPriceId(value);
                    });
                  },
                  validator: (value) => value == null ? 'Plan is required.' : null,
                ),
                if (selectedPlan != null) ...[
                  const SizedBox(height: 12),
                  _SelectedPlanSummary(plan: selectedPlan),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _billingMode,
                  decoration: const InputDecoration(labelText: 'Billing mode'),
                  items: const [
                    DropdownMenuItem(value: 'free_beta', child: Text('Free beta')),
                    DropdownMenuItem(value: 'manual', child: Text('Manual billing')),
                    DropdownMenuItem(value: 'stripe', child: Text('Stripe billing')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _billingMode = value ?? _billingMode;
                      if (_billingMode == 'free_beta') {
                        _status = 'active';
                      } else {
                        _priceId ??= _firstPriceId(_planId);
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                _BillingModeHelp(mode: _billingMode),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: prices.any((price) => price.id == _priceId) ? _priceId : null,
                  decoration: InputDecoration(
                    labelText: isFreeBeta ? 'Price / Rate (optional for beta)' : 'Price / Rate',
                  ),
                  items: prices
                      .map(
                        (price) => DropdownMenuItem(
                          value: price.id,
                          child: Text(
                            '${price.priceLabel} - ${price.hasStripePrice ? 'Stripe ready' : 'Stripe pending'}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _priceId = value),
                  validator: (value) {
                    if (isFreeBeta) return null;
                    return value == null ? 'Price is required unless this is a free beta.' : null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'trialing', child: Text('Trialing')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'past_due', child: Text('Past Due')),
                    DropdownMenuItem(value: 'paused', child: Text('Paused')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                    DropdownMenuItem(value: 'incomplete', child: Text('Incomplete')),
                  ],
                  onChanged: (value) => setState(() => _status = value ?? _status),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _dateField(_periodStart, 'Period start')),
                    const SizedBox(width: 12),
                    Expanded(child: _dateField(_periodEnd, 'Period end')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _dateField(_trialEndsAt, 'Trial ends')),
                    const SizedBox(width: 12),
                    Expanded(child: _dateField(_freeBetaEndsAt, 'Free beta ends')),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _billingNotes,
                  decoration: const InputDecoration(
                    labelText: 'Billing notes',
                    hintText: 'Example: Beta customer, no charge while validating limits.',
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 8),
                Text(
                  'Dates are optional and should use YYYY-MM-DD. Free beta keeps plan limits, feature gates, and overage warnings active without charging the tenant.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (state.hasError) ...[
                const SizedBox(height: 16),
                Text(
                  'Unable to save subscription: ${state.error}',
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
          onPressed: state.isLoading || _activePlans.isEmpty ? null : _submit,
          child: const Text('Save Subscription'),
        ),
      ],
    );
  }

  List<SubscriptionPlanSummary> get _activePlans =>
      widget.availablePlans.where((plan) => plan.isActive).toList(growable: false);

  bool _isActivePlan(String? planId) {
    if (planId == null) return false;
    return _activePlans.any((plan) => plan.id == planId);
  }

  SubscriptionPlanSummary? get _selectedPlan {
    for (final plan in _activePlans) {
      if (plan.id == _planId) return plan;
    }
    return null;
  }

  Widget _dateField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: 'YYYY-MM-DD'),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null;
        return _parseDate(text) == null ? 'Use YYYY-MM-DD.' : null;
      },
    );
  }

  String? _firstPlanId() {
    for (final plan in _activePlans) {
      return plan.id;
    }
    return null;
  }

  String? _firstPriceId(String? planId) {
    if (planId == null) return null;
    for (final plan in _activePlans) {
      final activePrices = plan.activePrices;
      if (plan.id == planId && activePrices.isNotEmpty) {
        return activePrices.first.id;
      }
    }
    return null;
  }

  String _dateText(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  DateTime? _parseDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    return DateTime.tryParse(
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(tenantMutationControllerProvider.notifier).saveSubscription(
          tenantId: widget.tenantId,
          subscriptionId: widget.subscription?.id,
          input: TenantSubscriptionInput(
            planId: _planId,
            priceId: _priceId,
            status: _status,
            billingMode: _billingMode,
            freeBetaEndsAt: _parseDate(_freeBetaEndsAt.text),
            billingNotes: _billingNotes.text,
            currentPeriodStart: _parseDate(_periodStart.text),
            currentPeriodEnd: _parseDate(_periodEnd.text),
            trialEndsAt: _parseDate(_trialEndsAt.text),
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}
