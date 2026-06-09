import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ticket.dart';
import '../domain/ticket_inputs.dart';
import 'ticket_providers.dart';

class TicketAssignmentDialog extends ConsumerStatefulWidget {
  const TicketAssignmentDialog({required this.ticket, super.key});

  final ServiceTicket ticket;

  @override
  ConsumerState<TicketAssignmentDialog> createState() => _TicketAssignmentDialogState();
}

class _TicketAssignmentDialogState extends ConsumerState<TicketAssignmentDialog> {
  final _noteController = TextEditingController();
  String? _assigneeUserId;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assignees = ref.watch(ticketAssigneeOptionsProvider);
    final commandState = ref.watch(ticketCommandProvider);

    return AlertDialog(
      title: const Text('Assign Ticket'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            assignees.when(
              data: (items) => DropdownButtonFormField<String>(
                value: _assigneeUserId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Assignee',
                  border: OutlineInputBorder(),
                ),
                items: items
                    .map(
                      (assignee) => DropdownMenuItem(
                        value: assignee.userId,
                        child: Text(assignee.label, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _assigneeUserId = value),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Unable to load assignees: $error'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Assignment Note',
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
          child: const Text('Assign'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final assigneeId = _assigneeUserId;
    if (assigneeId == null) return;
    final assignees = await ref.read(ticketRepositoryProvider).assigneeOptions();
    final assignee = assignees.firstWhere((item) => item.userId == assigneeId);

    final result = await ref.read(ticketCommandProvider.notifier).assignTicket(
          TicketAssignmentInput(
            ticket: widget.ticket,
            assignee: assignee,
            note: _noteController.text,
          ),
        );
    if (result != null && mounted) Navigator.of(context).pop(result);
  }
}
