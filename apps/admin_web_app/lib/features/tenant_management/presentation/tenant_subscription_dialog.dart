import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';
import 'tenant_management_providers.dart';

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
  late final TextEditingController _periodStart;
  late final TextEditingController _periodEnd;
  late final TextEditingController _trialEndsAt;

  @override
  void initState() {
    super.initState();
    final subscription = widget.subscription;
    _planId = subscription?.planId ?? _firstPlanId();
    _priceId = subscription?.priceId ?? _firstPriceId(_planId);
    _status = subscription?.status ?? 'trialing';
    _periodStart = TextEditingController(text: _dateText(subscription?.currentPeriodStart));
    _periodEnd = TextEditingController(text: _dateText(subscription?.currentPeriodEnd));
    _trialEndsAt = TextEditingController(text: _dateText(subscription?.trialEndsAt));
  }

  @override
  void dispose() {
    _periodStart.dispose();
    _periodEnd.dispose();
    _trialEndsAt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantMutationControllerProvider);
    final selectedPlan = _selectedPlan;
    final prices = selectedPlan?.prices ?? const <SubscriptionPriceSummary>[];

    return AlertDialog(
      title: Text(widget.subscription == null ? 'Assign Subscription' : 'Change Subscription'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.availablePlans.isEmpty)
                const Text('Create at least one active subscription plan before assigning a tenant subscription.')
              else ...[
                DropdownButtonFormField<String>(
                  value: _planId,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: widget.availablePlans
                      .map(
                        (plan) => DropdownMenuItem(
                          value: plan.id,
                          child: Text('${plan.name} (${plan.status})'),
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: prices.any((price) => price.id == _priceId) ? _priceId : null,
                  decoration: const InputDecoration(labelText: 'Price / Rate'),
                  items: prices
                      .map(
                        (price) => DropdownMenuItem(
                          value: price.id,
                          child: Text('${price.priceLabel} (${price.status})'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _priceId = value),
                  validator: (value) => value == null ? 'Price is required.' : null,
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
                _dateField(_trialEndsAt, 'Trial ends'),
                const SizedBox(height: 8),
                Text(
                  'Dates are optional and should use YYYY-MM-DD. Stripe will become the source of truth once billing automation is wired.',
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
          onPressed: state.isLoading || widget.availablePlans.isEmpty ? null : _submit,
          child: const Text('Save Subscription'),
        ),
      ],
    );
  }

  SubscriptionPlanSummary? get _selectedPlan {
    for (final plan in widget.availablePlans) {
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
    if (widget.availablePlans.isEmpty) return null;
    return widget.availablePlans.first.id;
  }

  String? _firstPriceId(String? planId) {
    if (planId == null) return null;
    for (final plan in widget.availablePlans) {
      if (plan.id == planId && plan.prices.isNotEmpty) {
        return plan.prices.first.id;
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
            currentPeriodStart: _parseDate(_periodStart.text),
            currentPeriodEnd: _parseDate(_periodEnd.text),
            trialEndsAt: _parseDate(_trialEndsAt.text),
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}
