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
      title: const Text('Email Settings'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _provider,
                decoration: const InputDecoration(labelText: 'Provider'),
                items: const [
                  DropdownMenuItem(value: 'platform_managed', child: Text('Platform Managed')),
                  DropdownMenuItem(value: 'resend', child: Text('Resend')),
                  DropdownMenuItem(value: 'postmark', child: Text('Postmark')),
                  DropdownMenuItem(value: 'sendgrid', child: Text('SendGrid')),
                  DropdownMenuItem(value: 'custom_smtp', child: Text('Custom SMTP')),
                ],
                onChanged: (value) => setState(() => _provider = value ?? _provider),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _verificationStatus,
                decoration: const InputDecoration(labelText: 'Verification Status'),
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
                decoration: const InputDecoration(labelText: 'Sender domain'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senderEmail,
                decoration: const InputDecoration(labelText: 'Sender email'),
                validator: _optionalEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _replyToEmail,
                decoration: const InputDecoration(labelText: 'Reply-to email'),
                validator: _optionalEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _providerDomainId,
                decoration: const InputDecoration(labelText: 'Provider domain ID'),
              ),
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
