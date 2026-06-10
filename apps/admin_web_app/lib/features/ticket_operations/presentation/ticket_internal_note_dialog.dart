import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ticket.dart';
import '../domain/ticket_inputs.dart';
import 'ticket_providers.dart';

class TicketInternalNoteDialog extends ConsumerStatefulWidget {
  const TicketInternalNoteDialog({required this.ticket, super.key});

  final ServiceTicket ticket;

  @override
  ConsumerState<TicketInternalNoteDialog> createState() => _TicketInternalNoteDialogState();
}

class _TicketInternalNoteDialogState extends ConsumerState<TicketInternalNoteDialog> {
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
      title: const Text('Add Internal Note'),
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
                  labelText: 'Internal Note',
                  helperText: 'Visible to tenant staff only through the admin timeline.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter an internal note.';
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
          onPressed: commandState.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: commandState.isLoading ? null : _submit,
          child: const Text('Add Note'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final didSave = await ref.read(ticketCommandProvider.notifier).addInternalNote(
          TicketInternalNoteInput(
            ticket: widget.ticket,
            note: _noteController.text,
          ),
        );
    if (didSave && mounted) Navigator.of(context).pop();
  }
}
