import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/activation_code.dart';
import '../domain/activation_code_inputs.dart';
import 'activation_code_providers.dart';
import 'generated_code_result.dart';

class ResetActivationCodeDialog extends ConsumerStatefulWidget {
  const ResetActivationCodeDialog({
    required this.activationCode,
    super.key,
  });

  final ActivationCode activationCode;

  @override
  ConsumerState<ResetActivationCodeDialog> createState() =>
      _ResetActivationCodeDialogState();
}

class _ResetActivationCodeDialogState
    extends ConsumerState<ResetActivationCodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _daysController = TextEditingController(text: '30');
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(activationCodeCommandProvider.notifier).clearGeneratedCode();
    });
  }

  @override
  void dispose() {
    _daysController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commandState = ref.watch(activationCodeCommandProvider);

    return AlertDialog(
      title: const Text('Reset Activation Code'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.activationCode.addressLabel),
              const SizedBox(height: 14),
              TextFormField(
                controller: _daysController,
                decoration: const InputDecoration(
                  labelText: 'New Code Expires In Days',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: _validateDays,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason / Notes',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              if (commandState.hasError) ...[
                const SizedBox(height: 14),
                Text(
                  commandState.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (commandState.valueOrNull != null) ...[
                const SizedBox(height: 14),
                GeneratedCodeResult(result: commandState.valueOrNull!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: commandState.isLoading
              ? null
              : () => Navigator.of(context).pop(commandState.valueOrNull),
          child: Text(commandState.valueOrNull == null ? 'Cancel' : 'Close'),
        ),
        FilledButton.icon(
          onPressed: commandState.isLoading ? null : _reset,
          icon: commandState.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.restart_alt_outlined),
          label: const Text('Reset Code'),
        ),
      ],
    );
  }

  String? _validateDays(String? value) {
    final days = int.tryParse(value?.trim() ?? '');
    if (days == null || days < 1 || days > 365) {
      return 'Use 1 to 365 days';
    }
    return null;
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final days = int.parse(_daysController.text.trim());
    await ref.read(activationCodeCommandProvider.notifier).resetCode(
          ResetActivationCodeInput(
            activationCodeId: widget.activationCode.id,
            expiresAt: DateTime.now().toUtc().add(Duration(days: days)),
            reason: _reasonController.text,
          ),
        );
  }
}
