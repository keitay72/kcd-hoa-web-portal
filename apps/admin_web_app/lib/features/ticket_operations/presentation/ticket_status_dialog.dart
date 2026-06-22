import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ticket.dart';
import '../domain/ticket_inputs.dart';
import 'ticket_providers.dart';

class TicketStatusDialog extends ConsumerStatefulWidget {
  const TicketStatusDialog({required this.ticket, super.key});

  final ServiceTicket ticket;

  @override
  ConsumerState<TicketStatusDialog> createState() => _TicketStatusDialogState();
}

class _TicketStatusDialogState extends ConsumerState<TicketStatusDialog> {
  final _noteController = TextEditingController();
  late TicketStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.ticket.status;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commandState = ref.watch(ticketCommandProvider);

    return AlertDialog(
      title: const Text('Update Ticket Status'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<TicketStatus>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: TicketStatus.values
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Customer-visible timeline note',
                helperText:
                    'Shown to the customer with this status change. Leave blank to use the default note.',
                border: OutlineInputBorder(),
              ),
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
      actions: [
        TextButton(
          onPressed:
              commandState.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: commandState.isLoading ? null : _submit,
          child: const Text('Save Status'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final result = await ref.read(ticketCommandProvider.notifier).updateStatus(
          TicketStatusUpdateInput(
            ticket: widget.ticket,
            status: _status,
            note: _noteController.text,
          ),
        );
    if (result != null && mounted) Navigator.of(context).pop(result);
  }
}
