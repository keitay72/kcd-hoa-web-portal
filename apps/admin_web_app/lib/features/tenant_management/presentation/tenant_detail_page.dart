import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/tenant_management_models.dart';
import 'billing_contact_dialog.dart';
import 'tenant_email_settings_dialog.dart';
import 'tenant_form_dialog.dart';
import 'tenant_management_providers.dart';
import 'tenant_onboarding_dialog.dart';
import 'tenant_settings_dialog.dart';
import 'tenant_sms_settings_dialog.dart';
import 'tenant_subscription_dialog.dart';

class TenantDetailPage extends ConsumerWidget {
  const TenantDetailPage({required this.tenantId, super.key});

  final String tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(tenantDetailProvider(tenantId));

    return detail.when(
      data: (tenantDetail) => _TenantDetailView(detail: tenantDetail),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Unable to load tenant: $error'),
      ),
    );
  }
}

class _TenantDetailView extends ConsumerWidget {
  const _TenantDetailView({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = detail.tenant;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to tenants',
                  onPressed: () => context.go('/admin/tenants'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.name,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(tenant.code)),
                          Chip(label: Text(tenant.statusLabel)),
                          if (tenant.isPrimary) const Chip(label: Text('Primary tenant')),
                        ],
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openTenantDialog(context, ref, tenant),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Tenant'),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList.list(
            children: [
              _OnboardingCard(detail: detail),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _SettingsCard(detail: detail),
                  _EmailSettingsCard(detail: detail),
                  _SmsSettingsCard(detail: detail),
                  _SubscriptionCard(detail: detail),
                ],
              ),
              const SizedBox(height: 16),
              _BillingContactsCard(detail: detail),
              const SizedBox(height: 16),
              _AddonsCard(detail: detail),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openTenantDialog(
    BuildContext context,
    WidgetRef ref,
    PlatformTenant tenant,
  ) async {
    await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TenantFormDialog(tenant: tenant),
    );
  }
}


class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context) {
    final status = detail.onboardingStatus;
    final progressPercent = (detail.onboardingProgress * 100).round();
    final checklist = detail.onboardingChecklist;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tenant Onboarding',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${detail.onboardingCompletedCount}/${detail.onboardingTotalCount} complete · $progressPercent%',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(label: Text(status?.statusLabel ?? 'Not Started')),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => showDialog<Object?>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => TenantOnboardingDialog(
                      tenantId: detail.tenant.id,
                      status: status,
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Update'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: detail.onboardingProgress),
            if (status?.blockedReason != null) ...[
              const SizedBox(height: 16),
              _WarningPanel(
                title: 'Blocked',
                message: status!.blockedReason!,
              ),
            ],
            if (status?.notes != null) ...[
              const SizedBox(height: 16),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(status!.notes!),
            ],
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth > 900
                    ? (constraints.maxWidth - 24) / 3
                    : constraints.maxWidth > 620
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: checklist
                      .map(
                        (item) => SizedBox(
                          width: cardWidth,
                          child: _ChecklistTile(item: item),
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
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.item});

  final OnboardingChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isComplete
              ? colorScheme.primary.withOpacity(0.35)
              : colorScheme.outlineVariant,
        ),
        color: item.isComplete
            ? colorScheme.primaryContainer.withOpacity(0.22)
            : colorScheme.surface,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: item.isComplete ? colorScheme.primary : colorScheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningPanel extends StatelessWidget {
  const _WarningPanel({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.errorContainer.withOpacity(0.45),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = detail.settings;
    return _TenantCard(
      title: 'Branding & Support',
      icon: Icons.tune_outlined,
      action: TextButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
      children: [
        _InfoLine(label: 'Support email', value: settings?.supportEmail ?? 'Not set'),
        _InfoLine(label: 'Support phone', value: settings?.supportPhone ?? 'Not set'),
        _InfoLine(label: 'Portal hostname', value: settings?.portalHostname ?? 'Not set'),
        _InfoLine(label: 'From name', value: settings?.emailFromName ?? 'Not set'),
        _InfoLine(label: 'Reply-to', value: settings?.emailReplyTo ?? 'Not set'),
        _InfoLine(label: 'Timezone', value: settings?.timezone ?? 'America/Chicago'),
      ],
    );
  }

  Future<void> _open(BuildContext context) {
    return showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TenantSettingsDialog(
        tenantId: detail.tenant.id,
        settings: detail.settings,
      ),
    );
  }
}

class _EmailSettingsCard extends StatelessWidget {
  const _EmailSettingsCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context) {
    final settings = detail.emailSettings;
    return _TenantCard(
      title: 'Email Configuration',
      icon: Icons.mark_email_read_outlined,
      action: TextButton.icon(
        onPressed: () => showDialog<Object?>(
          context: context,
          barrierDismissible: false,
          builder: (_) => TenantEmailSettingsDialog(
            tenantId: detail.tenant.id,
            settings: settings,
          ),
        ),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
      children: [
        _InfoLine(label: 'Provider', value: settings?.providerLabel ?? 'Platform Managed'),
        _InfoLine(label: 'Verification', value: settings?.verificationStatusLabel ?? 'Not Configured'),
        _InfoLine(label: 'Sender domain', value: settings?.senderDomain ?? 'Not set'),
        _InfoLine(label: 'Sender email', value: settings?.senderEmail ?? 'Not set'),
        _InfoLine(label: 'Reply-to', value: settings?.replyToEmail ?? 'Not set'),
      ],
    );
  }
}

class _SmsSettingsCard extends StatelessWidget {
  const _SmsSettingsCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context) {
    final settings = detail.smsSettings;
    return _TenantCard(
      title: 'SMS Add-On',
      icon: Icons.sms_outlined,
      action: TextButton.icon(
        onPressed: () => showDialog<Object?>(
          context: context,
          barrierDismissible: false,
          builder: (_) => TenantSmsSettingsDialog(
            tenantId: detail.tenant.id,
            settings: settings,
          ),
        ),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Edit'),
      ),
      children: [
        _InfoLine(label: 'Provider', value: settings?.provider ?? 'twilio'),
        _InfoLine(label: 'Status', value: settings?.statusLabel ?? 'Disabled'),
        _InfoLine(label: 'Phone number', value: settings?.sendingPhoneNumber ?? 'Not set'),
        _InfoLine(label: 'Message limit', value: settings?.monthlyMessageLimit?.toString() ?? 'Not set'),
        _InfoLine(label: 'Messaging service', value: settings?.twilioMessagingServiceSid ?? 'Not set'),
      ],
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = _currentSubscription(detail.subscriptions);
    return _TenantCard(
      title: 'Subscription',
      icon: Icons.credit_card_outlined,
      action: Wrap(
        spacing: 8,
        children: [
          TextButton.icon(
            onPressed: () => showDialog<Object?>(
              context: context,
              barrierDismissible: false,
              builder: (_) => TenantSubscriptionDialog(
                tenantId: detail.tenant.id,
                availablePlans: detail.availablePlans,
                subscription: current,
              ),
            ),
            icon: const Icon(Icons.edit_outlined),
            label: Text(current == null ? 'Assign' : 'Change'),
          ),
          TextButton.icon(
            onPressed: current == null
                ? null
                : () => _startCheckout(context, ref, current),
            icon: const Icon(Icons.open_in_new_outlined),
            label: const Text('Checkout'),
          ),
          TextButton.icon(
            onPressed: current == null
                ? null
                : () => _syncStripe(context, ref, current),
            icon: const Icon(Icons.sync_outlined),
            label: const Text('Sync'),
          ),
        ],
      ),
      children: [
        _InfoLine(label: 'Plan', value: current?.planName ?? 'No active plan'),
        _InfoLine(label: 'Status', value: current?.statusLabel ?? 'Not subscribed'),
        _InfoLine(label: 'Price', value: current?.priceLabel ?? 'Not set'),
        _InfoLine(label: 'Current period ends', value: _formatDate(current?.currentPeriodEnd)),
        _InfoLine(label: 'Trial ends', value: _formatDate(current?.trialEndsAt)),
      ],
    );
  }

  Future<void> _startCheckout(
    BuildContext context,
    WidgetRef ref,
    TenantSubscriptionSummary subscription,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(tenantMutationControllerProvider.notifier).createCheckoutSession(
          tenantId: detail.tenant.id,
          subscriptionId: subscription.id,
        );
    if (result == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Unable to start Stripe checkout.')));
      return;
    }
    if (!result.success || result.checkoutUrl == null) {
      messenger.showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }
    if (!context.mounted) return;
    await showDialog<Object?>(
      context: context,
      builder: (_) => _CheckoutUrlDialog(url: result.checkoutUrl!),
    );
  }

  Future<void> _syncStripe(
    BuildContext context,
    WidgetRef ref,
    TenantSubscriptionSummary subscription,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(tenantMutationControllerProvider.notifier).syncStripeSubscription(
          tenantId: detail.tenant.id,
          subscriptionId: subscription.id,
        );
    messenger.showSnackBar(
      SnackBar(content: Text(result?.message ?? 'Unable to sync Stripe status.')),
    );
  }
}

TenantSubscriptionSummary? _currentSubscription(
  List<TenantSubscriptionSummary> subscriptions,
) {
  const currentStatuses = {
    'trialing',
    'active',
    'past_due',
    'paused',
    'incomplete',
  };

  for (final subscription in subscriptions) {
    if (currentStatuses.contains(subscription.status)) {
      return subscription;
    }
  }

  return subscriptions.isEmpty ? null : subscriptions.first;
}

class _CheckoutUrlDialog extends StatelessWidget {
  const _CheckoutUrlDialog({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stripe Checkout URL'),
      content: SizedBox(
        width: 560,
        child: SelectableText(url),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checkout URL copied.')),
              );
            }
          },
          icon: const Icon(Icons.copy_outlined),
          label: const Text('Copy URL'),
        ),
      ],
    );
  }
}

class _BillingContactsCard extends StatelessWidget {
  const _BillingContactsCard({required this.detail});

  final TenantDetail detail;

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
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Billing Contacts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showDialog<Object?>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => BillingContactDialog(tenantId: detail.tenant.id),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Contact'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.billingContacts.isEmpty)
              const Text('No billing contacts configured yet.')
            else
              ...detail.billingContacts.map(
                (contact) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(contact.name),
                  subtitle: Text([
                    contact.email,
                    if (contact.phone != null) contact.phone!,
                  ].join(' · ')),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (contact.isPrimary) const Chip(label: Text('Primary')),
                      IconButton(
                        tooltip: 'Edit contact',
                        onPressed: () => showDialog<Object?>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => BillingContactDialog(
                            tenantId: detail.tenant.id,
                            contact: contact,
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddonsCard extends ConsumerWidget {
  const _AddonsCard({required this.detail});

  final TenantDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutation = ref.watch(tenantMutationControllerProvider);
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
                    'Add-On Management',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (detail.availableAddons.isEmpty)
              const Text('No add-ons are configured in the platform catalog yet.')
            else
              ...detail.availableAddons.map((addon) {
                final enabled = detail.addonFor(addon.id);
                final status = enabled?.status ?? 'disabled';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_circle_outline),
                  title: Text(addon.name),
                  subtitle: Text(addon.description ?? addon.code),
                  trailing: SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'requested', child: Text('Requested')),
                        DropdownMenuItem(value: 'enabled', child: Text('Enabled')),
                        DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
                        DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                      ],
                      onChanged: mutation.isLoading
                          ? null
                          : (value) {
                              if (value == null) return;
                              ref.read(tenantMutationControllerProvider.notifier).setAddonStatus(
                                    tenantId: detail.tenant.id,
                                    addonId: addon.id,
                                    status: value,
                                  );
                            },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.title,
    required this.icon,
    required this.children,
    this.action,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Tooltip(
              message: value,
              waitDuration: const Duration(milliseconds: 400),
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Not set';
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month/$day/${local.year}';
}
