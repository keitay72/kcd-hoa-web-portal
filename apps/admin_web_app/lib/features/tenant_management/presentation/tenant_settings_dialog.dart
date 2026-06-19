import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';
import 'tenant_management_providers.dart';

class TenantSettingsDialog extends ConsumerStatefulWidget {
  const TenantSettingsDialog({
    required this.tenantId,
    this.settings,
    this.canManageBranding = true,
    this.canManageCustomDomain = true,
    this.brandingLockReason,
    this.customDomainLockReason,
    super.key,
  });

  final String tenantId;
  final TenantSettings? settings;
  final bool canManageBranding;
  final bool canManageCustomDomain;
  final String? brandingLockReason;
  final String? customDomainLockReason;

  @override
  ConsumerState<TenantSettingsDialog> createState() =>
      _TenantSettingsDialogState();
}

class _TenantSettingsDialogState extends ConsumerState<TenantSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _supportEmail;
  late final TextEditingController _supportPhone;
  late final TextEditingController _portalHostname;
  late final TextEditingController _logoUrl;
  late final TextEditingController _emailFromName;
  late final TextEditingController _emailReplyTo;
  late final TextEditingController _primaryColor;
  late final TextEditingController _secondaryColor;
  late final TextEditingController _timezone;
  late bool _residentActivationCodesRequired;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _supportEmail = TextEditingController(text: settings?.supportEmail ?? '');
    _supportPhone = TextEditingController(text: settings?.supportPhone ?? '');
    _portalHostname =
        TextEditingController(text: settings?.portalHostname ?? '');
    _logoUrl = TextEditingController(text: settings?.logoUrl ?? '');
    _emailFromName = TextEditingController(text: settings?.emailFromName ?? '');
    _emailReplyTo = TextEditingController(text: settings?.emailReplyTo ?? '');
    _primaryColor = TextEditingController(text: settings?.primaryColor ?? '');
    _secondaryColor =
        TextEditingController(text: settings?.secondaryColor ?? '');
    _timezone =
        TextEditingController(text: settings?.timezone ?? 'America/Chicago');
    _residentActivationCodesRequired =
        settings?.residentActivationCodesRequired ?? true;
  }

  @override
  void dispose() {
    _supportEmail.dispose();
    _supportPhone.dispose();
    _portalHostname.dispose();
    _logoUrl.dispose();
    _emailFromName.dispose();
    _emailReplyTo.dispose();
    _primaryColor.dispose();
    _secondaryColor.dispose();
    _timezone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantMutationControllerProvider);
    return AlertDialog(
      title: const Text('Tenant Settings'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                if (!widget.canManageBranding)
                  _lockedNotice(
                    context,
                    title: 'Branding fields locked',
                    message: widget.brandingLockReason ?? 'Upgrade required',
                  ),
                if (!widget.canManageCustomDomain)
                  _lockedNotice(
                    context,
                    title: 'Custom domain locked',
                    message:
                        widget.customDomainLockReason ?? 'Add-on not enabled',
                  ),
                _field(_supportEmail, 'Support email',
                    validator: _optionalEmail),
                _field(_supportPhone, 'Support phone'),
                _field(
                  _portalHostname,
                  'Portal hostname',
                  enabled: widget.canManageCustomDomain,
                ),
                _field(
                  _logoUrl,
                  'Logo URL',
                  enabled: widget.canManageBranding,
                ),
                _field(_emailFromName, 'Email from name'),
                _field(_emailReplyTo, 'Reply-to email',
                    validator: _optionalEmail),
                _field(
                  _primaryColor,
                  'Primary color',
                  helper: '#1F7A4D',
                  validator: _optionalHexColor,
                  enabled: widget.canManageBranding,
                ),
                _field(
                  _secondaryColor,
                  'Secondary color',
                  helper: '#F4B942',
                  validator: _optionalHexColor,
                  enabled: widget.canManageBranding,
                ),
                _field(_timezone, 'Timezone'),
                SizedBox(
                  width: 640,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Require resident activation codes'),
                    subtitle: const Text(
                      'When off, residents only verify their email and service address during self-registration.',
                    ),
                    value: _residentActivationCodesRequired,
                    onChanged: (value) {
                      setState(() => _residentActivationCodesRequired = value);
                    },
                  ),
                ),
                if (state.hasError)
                  SizedBox(
                    width: 640,
                    child: Text(
                      'Unable to save settings: ${state.error}',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
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
          child: const Text('Save Settings'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? helper,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 312,
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(labelText: label, helperText: helper),
        validator: validator,
      ),
    );
  }

  Widget _lockedNotice(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 640,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surfaceContainerHighest.withOpacity(0.55),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$title: $message.'),
            ),
          ],
        ),
      ),
    );
  }

  String? _optionalEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text);
    return valid ? null : 'Enter a valid email.';
  }

  String? _optionalHexColor(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(text)
        ? null
        : 'Use #RRGGBB format.';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(tenantMutationControllerProvider.notifier)
        .updateSettings(
          tenantId: widget.tenantId,
          input: TenantSettingsInput(
            supportEmail: _supportEmail.text,
            supportPhone: _supportPhone.text,
            portalHostname: _portalHostname.text,
            logoUrl: _logoUrl.text,
            emailFromName: _emailFromName.text,
            emailReplyTo: _emailReplyTo.text,
            primaryColor: _primaryColor.text,
            secondaryColor: _secondaryColor.text,
            timezone: _timezone.text,
            residentActivationCodesRequired: _residentActivationCodesRequired,
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}
