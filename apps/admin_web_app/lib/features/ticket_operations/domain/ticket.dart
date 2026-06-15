enum TicketStatus {
  newTicket,
  open,
  assigned,
  inProgress,
  waitingOnCustomer,
  resolved,
  closed;

  static TicketStatus fromDatabase(String value) {
    return switch (value) {
      'new' => TicketStatus.newTicket,
      'triaged' => TicketStatus.open,
      'assigned' => TicketStatus.assigned,
      'in_progress' => TicketStatus.inProgress,
      'resolved' => TicketStatus.resolved,
      'closed' => TicketStatus.closed,
      'reopened' => TicketStatus.open,
      _ => TicketStatus.newTicket,
    };
  }

  String get databaseValue {
    return switch (this) {
      TicketStatus.newTicket => 'new',
      TicketStatus.open => 'triaged',
      TicketStatus.assigned => 'assigned',
      TicketStatus.inProgress => 'in_progress',
      TicketStatus.waitingOnCustomer => 'assigned',
      TicketStatus.resolved => 'resolved',
      TicketStatus.closed => 'closed',
    };
  }

  String get label {
    return switch (this) {
      TicketStatus.newTicket => 'New',
      TicketStatus.open => 'Open',
      TicketStatus.assigned => 'Assigned',
      TicketStatus.inProgress => 'In Progress',
      TicketStatus.waitingOnCustomer => 'Waiting on Customer',
      TicketStatus.resolved => 'Resolved',
      TicketStatus.closed => 'Closed',
    };
  }

  bool get isTerminal => this == TicketStatus.resolved || this == TicketStatus.closed;
}

enum TicketPriority {
  low,
  normal,
  high,
  urgent;

  static TicketPriority fromDatabase(String value) {
    return TicketPriority.values.firstWhere(
      (priority) => priority.name == value,
      orElse: () => TicketPriority.normal,
    );
  }

  String get label => name[0].toUpperCase() + name.substring(1);

  int get slaHours {
    return switch (this) {
      TicketPriority.low => 96,
      TicketPriority.normal => 72,
      TicketPriority.high => 48,
      TicketPriority.urgent => 24,
    };
  }
}

enum TicketType {
  missedPickup,
  damagedCart,
  complaint,
  serviceIssue;

  static TicketType fromDatabase(String value) {
    return switch (value) {
      'missed_pickup' => TicketType.missedPickup,
      'damaged_cart' => TicketType.damagedCart,
      'complaint' => TicketType.complaint,
      'service_issue' => TicketType.serviceIssue,
      _ => TicketType.serviceIssue,
    };
  }

  String get label {
    return switch (this) {
      TicketType.missedPickup => 'Missed Pickup',
      TicketType.damagedCart => 'Damaged Cart',
      TicketType.complaint => 'Complaint',
      TicketType.serviceIssue => 'Service Issue',
    };
  }
}

enum TicketQueue {
  all,
  csr,
  dispatch,
  urgent,
  aging;

  String get label {
    return switch (this) {
      TicketQueue.all => 'All Tickets',
      TicketQueue.csr => 'CSR Queue',
      TicketQueue.dispatch => 'Dispatch Queue',
      TicketQueue.urgent => 'Urgent Queue',
      TicketQueue.aging => 'Aging Queue',
    };
  }
}

enum SlaState {
  onTrack,
  dueSoon,
  breached,
  complete;

  String get label {
    return switch (this) {
      SlaState.onTrack => 'On Track',
      SlaState.dueSoon => 'Due Soon',
      SlaState.breached => 'Breached',
      SlaState.complete => 'Complete',
    };
  }
}

class ServiceTicket {
  const ServiceTicket({
    required this.id,
    required this.hoaId,
    required this.requesterUserId,
    this.addressId,
    required this.type,
    required this.priority,
    required this.status,
    required this.subject,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.hoaName,
    this.hoaCode,
    this.requesterName,
    this.requesterEmail,
    this.addressLine1,
    this.addressLine2,
    this.addressCity,
    this.addressState,
    this.addressPostalCode,
  });

  final String id;
  final String hoaId;
  final String requesterUserId;
  final String? addressId;
  final TicketType type;
  final TicketPriority priority;
  final TicketStatus status;
  final String subject;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hoaName;
  final String? hoaCode;
  final String? requesterName;
  final String? requesterEmail;
  final String? addressLine1;
  final String? addressLine2;
  final String? addressCity;
  final String? addressState;
  final String? addressPostalCode;

  String get hoaLabel {
    if (hoaName != null && hoaCode != null) return '$hoaName ($hoaCode)';
    return hoaName ?? hoaCode ?? hoaId;
  }

  String get requesterLabel => requesterName ?? requesterEmail ?? requesterUserId;

  String get addressLabel {
    final parts = <String?>[
      addressLine1,
      addressLine2,
      addressCity,
      addressState,
      addressPostalCode,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Not set' : parts.join(', ');
  }

  DateTime get slaDueAt => createdAt.toUtc().add(Duration(hours: priority.slaHours));

  Duration get age => DateTime.now().toUtc().difference(createdAt.toUtc());

  Duration get slaRemaining => slaDueAt.difference(DateTime.now().toUtc());

  SlaState get slaState {
    if (status.isTerminal) return SlaState.complete;
    final remaining = slaRemaining;
    if (remaining.isNegative) return SlaState.breached;
    if (remaining.inHours <= 12) return SlaState.dueSoon;
    return SlaState.onTrack;
  }

  String get ageLabel => _durationLabel(age);

  String get slaLabel {
    if (slaState == SlaState.complete) return 'Complete';
    final remaining = slaRemaining;
    if (remaining.isNegative) return 'Overdue by ${_durationLabel(remaining.abs())}';
    return 'Due in ${_durationLabel(remaining)}';
  }
}

class TicketEvent {
  const TicketEvent({
    required this.id,
    required this.ticketId,
    this.actorUserId,
    this.oldStatus,
    this.newStatus,
    this.note,
    required this.createdAt,
    this.actorName,
    this.actorEmail,
  });

  final String id;
  final String ticketId;
  final String? actorUserId;
  final TicketStatus? oldStatus;
  final TicketStatus? newStatus;
  final String? note;
  final DateTime createdAt;
  final String? actorName;
  final String? actorEmail;

  String get actorLabel => actorName ?? actorEmail ?? actorUserId ?? 'System';

  bool get isInternalNote => note?.startsWith('[INTERNAL]') ?? false;
  bool get isAssignment => note?.startsWith('[ASSIGNMENT]') ?? false;
  bool get isAutomation => note?.startsWith('[AUTOMATION]') ?? false;

  String get displayNote {
    final value = note ?? '';
    return value
        .replaceFirst('[INTERNAL] ', '')
        .replaceFirst('[ASSIGNMENT] ', '')
        .replaceFirst('[AUTOMATION] ', '')
        .trim();
  }
}

class TicketAttachment {
  const TicketAttachment({
    required this.id,
    required this.ticketId,
    required this.uploadedBy,
    required this.storagePath,
    required this.mimeType,
    required this.fileSize,
    required this.scanStatus,
    required this.createdAt,
    this.uploadedByName,
    this.uploadedByEmail,
  });

  final String id;
  final String ticketId;
  final String uploadedBy;
  final String storagePath;
  final String mimeType;
  final int fileSize;
  final String scanStatus;
  final DateTime createdAt;
  final String? uploadedByName;
  final String? uploadedByEmail;

  String get uploadedByLabel => uploadedByName ?? uploadedByEmail ?? uploadedBy;

  String get fileName {
    final parts = storagePath.split('/');
    return parts.isEmpty ? storagePath : parts.last;
  }

  String get fileSizeLabel {
    if (fileSize >= 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (fileSize >= 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '$fileSize bytes';
  }
}

class TicketAssigneeOption {
  const TicketAssigneeOption({
    required this.userId,
    required this.label,
    required this.roleCodes,
  });

  final String userId;
  final String label;
  final Set<String> roleCodes;

  bool get canDispatch => roleCodes.contains('tenant_dispatch') || roleCodes.contains('tenant_admin');
  bool get canCsr => roleCodes.contains('tenant_csr') || roleCodes.contains('tenant_admin');
}

class TicketMetrics {
  const TicketMetrics({
    required this.totalOpen,
    required this.newTickets,
    required this.assigned,
    required this.inProgress,
    required this.waiting,
    required this.resolvedToday,
    required this.urgent,
    required this.slaBreached,
    required this.slaDueSoon,
  });

  final int totalOpen;
  final int newTickets;
  final int assigned;
  final int inProgress;
  final int waiting;
  final int resolvedToday;
  final int urgent;
  final int slaBreached;
  final int slaDueSoon;

  factory TicketMetrics.fromTickets(List<ServiceTicket> tickets) {
    final now = DateTime.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    return TicketMetrics(
      totalOpen: tickets.where((ticket) => !ticket.status.isTerminal).length,
      newTickets: tickets.where((ticket) => ticket.status == TicketStatus.newTicket).length,
      assigned: tickets.where((ticket) => ticket.status == TicketStatus.assigned).length,
      inProgress: tickets.where((ticket) => ticket.status == TicketStatus.inProgress).length,
      waiting: tickets.where((ticket) => ticket.status == TicketStatus.waitingOnCustomer).length,
      resolvedToday: tickets.where((ticket) {
        final updated = ticket.updatedAt.toLocal();
        return ticket.status == TicketStatus.resolved && !updated.isBefore(today);
      }).length,
      urgent: tickets.where((ticket) => ticket.priority == TicketPriority.urgent).length,
      slaBreached: tickets.where((ticket) => ticket.slaState == SlaState.breached).length,
      slaDueSoon: tickets.where((ticket) => ticket.slaState == SlaState.dueSoon).length,
    );
  }
}

String _durationLabel(Duration duration) {
  if (duration.inDays >= 1) return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
  if (duration.inHours >= 1) return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  return '${duration.inMinutes.clamp(0, 59)}m';
}
