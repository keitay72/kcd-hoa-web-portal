import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';
import 'tenant_management_providers.dart';

class TenantEmailSettingsDialog extends ConsumerStatefulWidget {
  const TenantEmailSettingsDialog({
    required this.tenantId,
    this.settings,
    super.key,
  });

  final String tenantId;
  final TenantEmailSettings? settings;

  @override
  ConsumerState<TenantEmailSettingsDialog> createState() => _TenantEmailSettingsDialogState();
}

class _TenantEmailSettingsDialogState extends ConsumerState<TenantEmailSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _provider;
  late String _verificationStatus;
  late final TextEditingController _senderDomain;
  late final TextEditingController _senderEmail;
  late final TextEditingController _replyToEmail;
  late final TextEditingController _providerDomainId;

  bool get _usesTenantManagedSender => _provider != 'platform_managed';

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _provider = settings?.provider ?? 'platform_managed';
    _verificationStatus = settings?.verificationStatus ?? 'not_configured';
    _senderDomain = TextEditingController(text: settings?.senderDomain ?? '');
    _senderEmail = TextEditingController(text: settings?.senderEmail ?? '');
    _replyToEmail = TextEditingController(text: settings?.replyToEmail ?? '');
    _providerDomainId = TextEditingController(text: settings?.providerDomainId ?? '');
  }

  @override
  void dispose() {
    _senderDomain.dispose();
    _senderEmail.dispose();
    _replyToEmail.dispose();
    _providerDomainId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantMutationControllerProvider);
    return AlertDialog(
      title: const Text('Email Configuration'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EmailSetupNotice(provider: _provider),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _provider,
                  decoration: const InputDecoration(
                    labelText: 'Email provider mode',
                    border: OutlineInputBorder(),
                    helperText: 'Choose how this tenant sends platform notification emails.',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'platform_managed',
                      child: Text('Platform Managed'),
                    ),
                    DropdownMenuItem(
                      value: 'resend',
                      child: Text('Tenant Domain - Resend'),
                    ),
                    DropdownMenuItem(
                      value: 'postmark',
                      child: Text('Tenant Domain - Postmark'),
                    ),
                    DropdownMenuItem(
                      value: 'sendgrid',
                      child: Text('Tenant Domain - SendGrid'),
                    ),
                    DropdownMenuItem(
                      value: 'custom_smtp',
                      child: Text('Custom SMTP / Future Provider'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _provider = value;
                      if (value == 'platform_managed') {
                        _verificationStatus = 'verified';
                      } else if (_verificationStatus == 'verified') {
                        _verificationStatus = 'pending';
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _verificationStatus,
                  decoration: const InputDecoration(
                    labelText: 'Verification status',
                    border: OutlineInputBorder(),
                    helperText: 'Use Verified only after DNS/provider setup has been confirmed.',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'not_configured', child: Text('Not Configured')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'verified', child: Text('Verified')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                    DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
                  ],
                  onChanged: (value) => setState(() => _verificationStatus = value ?? _verificationStatus),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senderDomain,
                  decoration: const InputDecoration(
                    labelText: 'Sender domain',
                    hintText: 'example-disposal.com',
                    border: OutlineInputBorder(),
                    helperText: 'Required for tenant-managed sending. Do not include https://.',
                  ),
                  validator: _senderDomainValidator,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senderEmail,
                  decoration: const InputDecoration(
                    labelText: 'Sender email',
                    hintText: 'notifications@example-disposal.com',
                    border: OutlineInputBorder(),
                    helperText: 'Required for tenant-managed sending.',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _senderEmailValidator,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _replyToEmail,
                  decoration: const InputDecoration(
                    labelText: 'Reply-to email',
                    hintText: 'support@example-disposal.com',
                    border: OutlineInputBorder(),
                    helperText: 'Optional. Tenant support inbox for customer replies.',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _optionalEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _providerDomainId,
                  decoration: const InputDecoration(
                    labelText: 'Provider domain ID',
                    border: OutlineInputBorder(),
                    helperText: 'Optional provider reference from Resend, Postmark, SendGrid, or SMTP vendor.',
                  ),
                ),
                if (_usesTenantManagedSender) ...[
                  const SizedBox(height: 16),
                  const _DnsChecklist(),
                ],
                if (state.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Unable to save email settings: ${state.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
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
          child: const Text('Save Email Settings'),
        ),
      ],
    );
  }

  String? _senderDomainValidator(String? value) {
    final text = value?.trim() ?? '';
    if (!_usesTenantManagedSender && text.isEmpty) return null;
    if (text.isEmpty) return 'Sender domain is required for tenant-managed email.';
    if (text.contains('://') || text.contains('/') || text.contains('@')) {
      return 'Enter a domain only, such as example-disposal.com.';
    }
    return RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$').hasMatch(text)
        ? null
        : 'Enter a valid sender domain.';
  }

  String? _senderEmailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (!_usesTenantManagedSender && text.isEmpty) return null;
    if (text.isEmpty) return 'Sender email is required for tenant-managed email.';
    final emailError = _optionalEmail(text);
    if (emailError != null) return emailError;

    final domain = _senderDomain.text.trim().toLowerCase();
    if (domain.isNotEmpty && !text.toLowerCase().endsWith('@$domain')) {
      return 'Sender email should use the sender domain.';
    }
    return null;
  }

  String? _optionalEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
        ? null
        : 'Enter a valid email.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(tenantMutationControllerProvider.notifier).updateEmailSettings(
          tenantId: widget.tenantId,
          input: TenantEmailSettingsInput(
            provider: _provider,
            verificationStatus: _verificationStatus,
            senderDomain: _senderDomain.text,
            senderEmail: _senderEmail.text,
            replyToEmail: _replyToEmail.text,
            providerDomainId: _providerDomainId.text,
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}

class _EmailSetupNotice extends StatelessWidget {
  const _EmailSetupNotice({required this.provider});

  final String provider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlatformManaged = provider == 'platform_managed';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isPlatformManaged
            ? colorScheme.primaryContainer.withOpacity(0.35)
            : colorScheme.tertiaryContainer.withOpacity(0.35),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPlatformManaged ? Icons.mark_email_read_outlined : Icons.dns_outlined,
            color: isPlatformManaged ? colorScheme.primary : colorScheme.tertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPlatformManaged
                  ? 'Platform Managed uses the platform sender. This is okay for early onboarding, but production tenants should usually move to their own verified sender domain.'
                  : 'Tenant-managed email requires sender domain verification before launch. Collect DNS access, sender address, reply-to inbox, and provider reference details.',
            ),
          ),
        ],
      ),
    );
  }
}

class _DnsChecklist extends StatelessWidget {
  const _DnsChecklist();

  @override
  Widget build(BuildContext context) {
    final items = [
      'Confirm tenant owns or controls the sender domain.',
      'Create provider domain in the email vendor.',
      'Add SPF/DKIM DNS records supplied by the provider.',
      'Verify domain before marking status as Verified.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Launch checklist', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
