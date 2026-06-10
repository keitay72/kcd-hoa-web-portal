import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';
import 'tenant_management_providers.dart';

class TenantSettingsDialog extends ConsumerStatefulWidget {
  const TenantSettingsDialog({
    required this.tenantId,
    this.settings,
    super.key,
  });

  final String tenantId;
  final TenantSettings? settings;

  @override
  ConsumerState<TenantSettingsDialog> createState() => _TenantSettingsDialogState();
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

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _supportEmail = TextEditingController(text: settings?.supportEmail ?? '');
    _supportPhone = TextEditingController(text: settings?.supportPhone ?? '');
    _portalHostname = TextEditingController(text: settings?.portalHostname ?? '');
    _logoUrl = TextEditingController(text: settings?.logoUrl ?? '');
    _emailFromName = TextEditingController(text: settings?.emailFromName ?? '');
    _emailReplyTo = TextEditingController(text: settings?.emailReplyTo ?? '');
    _primaryColor = TextEditingController(text: settings?.primaryColor ?? '');
    _secondaryColor = TextEditingController(text: settings?.secondaryColor ?? '');
    _timezone = TextEditingController(text: settings?.timezone ?? 'America/Chicago');
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
                _field(_supportEmail, 'Support email', validator: _optionalEmail),
                _field(_supportPhone, 'Support phone'),
                _field(_portalHostname, 'Portal hostname'),
                _field(_logoUrl, 'Logo URL'),
                _field(_emailFromName, 'Email from name'),
                _field(_emailReplyTo, 'Reply-to email', validator: _optionalEmail),
                _field(_primaryColor, 'Primary color', helper: '#1F7A4D', validator: _optionalHexColor),
                _field(_secondaryColor, 'Secondary color', helper: '#F4B942', validator: _optionalHexColor),
                _field(_timezone, 'Timezone'),
                if (state.hasError)
                  SizedBox(
                    width: 640,
                    child: Text(
                      'Unable to save settings: ${state.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
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
  }) {
    return SizedBox(
      width: 312,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, helperText: helper),
        validator: validator,
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
    final ok = await ref.read(tenantMutationControllerProvider.notifier).updateSettings(
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
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}
