import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ticket.dart';
import '../domain/ticket_inputs.dart';
import 'ticket_providers.dart';

class TicketCustomerUpdateDialog extends ConsumerStatefulWidget {
  const TicketCustomerUpdateDialog({required this.ticket, super.key});

  final ServiceTicket ticket;

  @override
  ConsumerState<TicketCustomerUpdateDialog> createState() =>
      _TicketCustomerUpdateDialogState();
}

class _TicketCustomerUpdateDialogState
    extends ConsumerState<TicketCustomerUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commandState = ref.watch(ticketCommandProvider);

    return AlertDialog(
      title: const Text('Add Customer Update'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _noteController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Customer Update',
                  helperText:
                      'Visible to the customer in their portal status history.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a customer update.';
                  }
                  return null;
                },
              ),
              if (commandState.hasError) ...[
                const SizedBox(height: 12),
                Text(
                  commandState.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              commandState.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: commandState.isLoading ? null : _submit,
          child: const Text('Post Update'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final didSave =
        await ref.read(ticketCommandProvider.notifier).addCustomerUpdate(
              TicketCustomerUpdateInput(
                ticket: widget.ticket,
                note: _noteController.text,
              ),
            );
    if (didSave && mounted) Navigator.of(context).pop();
  }
}
