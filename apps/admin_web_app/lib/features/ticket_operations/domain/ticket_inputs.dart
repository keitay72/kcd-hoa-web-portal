import 'ticket.dart';

class TicketAttachmentUploadInput {
  const TicketAttachmentUploadInput({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final List<int> bytes;

  int get fileSize => bytes.length;
}

class ResidentTicketCreateInput {
  const ResidentTicketCreateInput({
    required this.hoaId,
    required this.addressId,
    required this.type,
    required this.subject,
    required this.description,
    this.attachment,
  });

  final String hoaId;
  final String addressId;
  final TicketType type;
  final String subject;
  final String description;
  final TicketAttachmentUploadInput? attachment;
}

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

class TicketCustomerUpdateInput {
  const TicketCustomerUpdateInput({
    required this.ticket,
    required this.note,
  });

  final ServiceTicket ticket;
  final String note;
}
