import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                if (items.isEmpty) return const Text('No subscription plans configured yet.');
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
        leading: const Icon(Icons.workspace_premium_outlined),
        title: Text(plan.name),
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
              'Includes: ${plan.includedHoaCount ?? 0} HOAs · ${plan.includedResidentCount ?? 0} residents',
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
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No prices configured.'),
            )
          else
            ...plan.prices.map(
              (price) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sell_outlined),
                title: Text(price.priceLabel),
                subtitle: Text('${price.currency.toUpperCase()} · ${price.statusLabel}'),
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
                if (items.isEmpty) return const Text('No add-ons configured yet.');
                return Column(
                  children: items
                      .map(
                        (addon) => ListTile(
                          leading: const Icon(Icons.add_circle_outline),
                          title: Text(addon.name),
                          subtitle: Text('${addon.code} · ${addon.statusLabel}'),
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
      decoration: InputDecoration(labelText: label),
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
                decoration: const InputDecoration(labelText: 'Stripe price ID'),
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
