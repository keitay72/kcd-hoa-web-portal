import 'ticket.dart';

class TicketStatusUpdateInput {
  const TicketStatusUpdateInput({
    required this.ticket,
    required this.status,
    this.note,
  });

  final ServiceTicket ticket;
  final TicketStatus status;
  final String? note;
}

class TicketAssignmentInput {
  const TicketAssignmentInput({
    required this.ticket,
    required this.assignee,
    this.note,
  });

  final ServiceTicket ticket;
  final TicketAssigneeOption assignee;
  final String? note;
}

class TicketPriorityUpdateInput {
  const TicketPriorityUpdateInput({
    required this.ticket,
    required this.priority,
    this.note,
  });

  final ServiceTicket ticket;
  final TicketPriority priority;
  final String? note;
}

class TicketInternalNoteInput {
  const TicketInternalNoteInput({
    required this.ticket,
    required this.note,
  });

  final ServiceTicket ticket;
  final String note;
}
