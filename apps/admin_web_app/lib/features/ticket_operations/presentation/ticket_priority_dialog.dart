import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ticket.dart';
import '../domain/ticket_inputs.dart';
import 'ticket_providers.dart';

class TicketPriorityDialog extends ConsumerStatefulWidget {
  const TicketPriorityDialog({required this.ticket, super.key});

  final ServiceTicket ticket;

  @override
  ConsumerState<TicketPriorityDialog> createState() => _TicketPriorityDialogState();
}

class _TicketPriorityDialogState extends ConsumerState<TicketPriorityDialog> {
  final _noteController = TextEditingController();
  late TicketPriority _priority;

  @override
  void initState() {
    super.initState();
    _priority = widget.ticket.priority;
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
      title: const Text('Update Ticket Priority'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<TicketPriority>(
              value: _priority,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: TicketPriority.values
                  .map(
                    (priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(priority.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _priority = value);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Priority Note',
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
          onPressed: commandState.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: commandState.isLoading ? null : _submit,
          child: const Text('Save Priority'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final result = await ref.read(ticketCommandProvider.notifier).updatePriority(
          TicketPriorityUpdateInput(
            ticket: widget.ticket,
            priority: _priority,
            note: _noteController.text,
          ),
        );
    if (result != null && mounted) Navigator.of(context).pop(result);
  }
}
