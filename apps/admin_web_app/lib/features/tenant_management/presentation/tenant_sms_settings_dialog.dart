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
    _sendingPhoneNumber = TextEditingController(text: settings?.sendingPhoneNumber ?? '');
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
    return AlertDialog(
      title: const Text('SMS Add-On Settings'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'SMS Status'),
                items: const [
                  DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                ],
                onChanged: (value) => setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sendingPhoneNumber,
                decoration: const InputDecoration(labelText: 'Sending phone number'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _monthlyLimit,
                decoration: const InputDecoration(labelText: 'Monthly message limit'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subaccountSid,
                decoration: const InputDecoration(labelText: 'Twilio subaccount SID'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messagingServiceSid,
                decoration: const InputDecoration(labelText: 'Twilio messaging service SID'),
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
      actions: [
        TextButton(
          onPressed: state.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: state.isLoading ? null : _submit,
          child: const Text('Save SMS Settings'),
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
            sendingPhoneNumber: _sendingPhoneNumber.text,
            monthlyMessageLimit: int.tryParse(_monthlyLimit.text),
            twilioSubaccountSid: _subaccountSid.text,
            twilioMessagingServiceSid: _messagingServiceSid.text,
          ),
        );
    if (ok && mounted) Navigator.of(context).pop(true);
  }
}
