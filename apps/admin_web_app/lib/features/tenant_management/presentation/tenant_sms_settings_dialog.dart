import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/tenant_management_inputs.dart';
import '../domain/tenant_management_models.dart';
import 'tenant_management_providers.dart';

class TenantSmsSettingsDialog extends ConsumerStatefulWidget {
  const TenantSmsSettingsDialog({
    required this.tenantId,
    this.settings,
    super.key,
  });

  final String tenantId;
  final TenantSmsSettings? settings;

  @override
  ConsumerState<TenantSmsSettingsDialog> createState() => _TenantSmsSettingsDialogState();
}

class _TenantSmsSettingsDialogState extends ConsumerState<TenantSmsSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _status;
  late final TextEditingController _subaccountSid;
  late final TextEditingController _messagingServiceSid;
  late final TextEditingController _sendingPhoneNumber;
  late final TextEditingController _monthlyLimit;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _status = settings?.status ?? 'disabled';
    _subaccountSid = TextEditingController(text: settings?.twilioSubaccountSid ?? '');
    _messagingServiceSid = TextEditingController(text: settings?.twilioMessagingServiceSid ?? '');
    _sendingPhoneNumber = TextEditingController(text: _formatPhone(settings?.sendingPhoneNumber ?? ''));
    _monthlyLimit = TextEditingController(text: settings?.monthlyMessageLimit?.toString() ?? '');
  }

  @override
  void dispose() {
    _subaccountSid.dispose();
    _messagingServiceSid.dispose();
    _sendingPhoneNumber.dispose();
    _monthlyLimit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantMutationControllerProvider);
    final isEnabledPath = _status == 'pending' || _status == 'active';
    final isActive = _status == 'active';

    return AlertDialog(
      title: const Text('SMS Add-On Setup'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record the tenant SMS decision and Twilio setup status. Do not store Twilio auth tokens here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'SMS add-on status',
                    border: OutlineInputBorder(),
                    helperText:
                        'Use Pending while waiting on Twilio number, sender registration, or customer approval.',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'disabled',
                      child: Text('Disabled - tenant declined or not offered'),
                    ),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Pending setup - tenant wants SMS'),
                    ),
                    DropdownMenuItem(
                      value: 'active',
                      child: Text('Active - ready to send messages'),
                    ),
                    DropdownMenuItem(
                      value: 'suspended',
                      child: Text('Suspended - temporarily unavailable'),
                    ),
                  ],
                  onChanged: state.isLoading ? null : (value) => setState(() => _status = value ?? _status),
                ),
                const SizedBox(height: 16),
                _SmsReadinessNotice(status: _status),
                const SizedBox(height: 16),
                Text('Twilio configuration', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _sendingPhoneNumber,
                  enabled: isEnabledPath && !state.isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Sending phone number',
                    border: OutlineInputBorder(),
                    helperText: 'US number assigned to this tenant. Stored as digits only.',
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_UsPhoneInputFormatter()],
                  validator: (value) {
                    if (!isActive && _digits(value).isEmpty) return null;
                    if (_digits(value).length != 10) return 'Enter a 10-digit US phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _monthlyLimit,
                  enabled: isEnabledPath && !state.isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Monthly message limit',
                    border: OutlineInputBorder(),
                    helperText: 'Optional cap for the tenant. Leave blank until pricing/plan is finalized.',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    final limit = int.tryParse(trimmed);
                    if (limit == null || limit < 0) return 'Enter zero or a positive number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subaccountSid,
                  enabled: isEnabledPath && !state.isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Twilio subaccount SID',
                    border: OutlineInputBorder(),
                    helperText: 'Optional Twilio subaccount identifier. Never paste auth tokens here.',
                  ),
                  validator: (value) => _optionalSidValidator(value, prefix: 'AC', label: 'Twilio subaccount SID'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messagingServiceSid,
                  enabled: isEnabledPath && !state.isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Twilio messaging service SID',
                    border: OutlineInputBorder(),
                    helperText: 'Required before marking SMS Active.',
                  ),
                  validator: (value) {
                    if (isActive && (value == null || value.trim().isEmpty)) {
                      return 'Messaging service SID is required for Active SMS';
                    }
                    return _optionalSidValidator(value, prefix: 'MG', label: 'Messaging service SID');
                  },
                ),
                const SizedBox(height: 16),
                _SmsChecklist(
                  status: _status,
                  hasPhone: _digits(_sendingPhoneNumber.text).length == 10,
                  hasMessagingService: _messagingServiceSid.text.trim().isNotEmpty,
                ),
                if (state.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Unable to save SMS settings: ${state.error}',
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
        FilledButton.icon(
          onPressed: state.isLoading ? null : _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save SMS Setup'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(tenantMutationControllerProvider.notifier).updateSmsSettings(
          tenantId: widget.tenantId,
          input: TenantSmsSettingsInput(
            status: _status,
            sendingPhoneNumber: _digits(_sendingPhoneNumber.text),
            monthlyMessageLimit: int.tryParse(_monthlyLimit.text.trim()),
            twilioSubaccountSid: _subaccountSid.text,
            twilioMessagingServiceSid: _messagingServiceSid.text,
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}

class _SmsReadinessNotice extends StatelessWidget {
  const _SmsReadinessNotice({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = switch (status) {
      'disabled' => 'SMS is disabled. This records that the tenant is not using the texting add-on yet.',
      'pending' => 'SMS is pending. Use this while Twilio setup, registration, billing, or tenant approval is incomplete.',
      'active' => 'SMS is active. Make sure Twilio sender, messaging service, and tenant billing/add-on approval are complete.',
      'suspended' => 'SMS is suspended. Keep settings for audit/history but do not send tenant SMS messages.',
      _ => 'Record the current SMS add-on state.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _SmsChecklist extends StatelessWidget {
  const _SmsChecklist({
    required this.status,
    required this.hasPhone,
    required this.hasMessagingService,
  });

  final String status;
  final bool hasPhone;
  final bool hasMessagingService;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ChecklistRow(label: 'Tenant SMS decision recorded', complete: status != 'disabled'),
      _ChecklistRow(label: 'Sending phone number assigned', complete: hasPhone),
      _ChecklistRow(label: 'Twilio messaging service connected', complete: hasMessagingService),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Launch checklist', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            size: 18,
            color: complete ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _UsPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = _digits(newValue.text);
    final limited = digits.length > 10 ? digits.substring(0, 10) : digits;
    final formatted = _formatPhone(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String? _optionalSidValidator(String? value, {required String prefix, required String label}) {
  final sid = value?.trim() ?? '';
  if (sid.isEmpty) return null;
  if (!sid.startsWith(prefix)) return '$label should start with $prefix';
  if (sid.length < 10) return '$label looks too short';
  return null;
}

String _digits(String? value) => (value ?? '').replaceAll(RegExp(r'\D'), '');

String _formatPhone(String value) {
  final digits = _digits(value);
  if (digits.isEmpty) return '';
  if (digits.length <= 3) return digits;
  if (digits.length <= 6) return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
  return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6, digits.length > 10 ? 10 : digits.length)}';
}
