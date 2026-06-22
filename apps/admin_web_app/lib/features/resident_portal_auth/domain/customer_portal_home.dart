class CustomerPortalHome {
  const CustomerPortalHome({
    required this.account,
    required this.serviceLocation,
    required this.announcements,
    required this.documents,
    required this.schedules,
    required this.recentTickets,
    required this.boardMembers,
  });

  final CustomerPortalAccount account;
  final CustomerPortalServiceLocation? serviceLocation;
  final List<CustomerPortalAnnouncement> announcements;
  final List<CustomerPortalDocument> documents;
  final List<CustomerPortalSchedule> schedules;
  final List<CustomerPortalTicket> recentTickets;
  final List<CustomerPortalBoardMember> boardMembers;

  bool get hasCommunityInfo => account.isCommunityAccount;
}

class CustomerPortalAccount {
  const CustomerPortalAccount({
    required this.id,
    required this.accountType,
    required this.isCommunityAccount,
    this.accountNumber,
    this.name,
  });

  final String id;
  final String accountType;
  final bool isCommunityAccount;
  final String? accountNumber;
  final String? name;

  String get displayName => name?.trim().isNotEmpty == true
      ? name!.trim()
      : accountNumber ?? 'Customer account';
}

class CustomerPortalServiceLocation {
  const CustomerPortalServiceLocation({
    required this.id,
    required this.line1,
    this.line2,
    required this.city,
    required this.state,
    required this.postalCode,
  });

  final String id;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String postalCode;

  String get singleLine {
    return <String?>[line1, line2, city, state, postalCode]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(', ');
  }
}

class CustomerPortalAnnouncement {
  const CustomerPortalAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    this.publishAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? publishAt;
}

class CustomerPortalDocument {
  const CustomerPortalDocument({
    required this.id,
    required this.title,
    required this.category,
    this.mimeType,
    this.storagePath,
  });

  final String id;
  final String title;
  final String category;
  final String? mimeType;
  final String? storagePath;
}

class CustomerPortalSchedule {
  const CustomerPortalSchedule({
    required this.id,
    required this.serviceType,
    required this.serviceDay,
    this.scheduleRule,
    this.routeName,
    this.notes,
  });

  final String id;
  final String serviceType;
  final int serviceDay;
  final String? scheduleRule;
  final String? routeName;
  final String? notes;

  String get serviceTypeLabel {
    return serviceType
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String get serviceDayLabel {
    return switch (serviceDay) {
      0 => 'Sunday',
      1 => 'Monday',
      2 => 'Tuesday',
      3 => 'Wednesday',
      4 => 'Thursday',
      5 => 'Friday',
      6 => 'Saturday',
      _ => 'Scheduled',
    };
  }
}

class CustomerPortalBoardMember {
  const CustomerPortalBoardMember({
    required this.id,
    required this.name,
    required this.roleName,
    required this.isPrimaryContact,
    this.email,
    this.phone,
  });

  final String id;
  final String name;
  final String roleName;
  final bool isPrimaryContact;
  final String? email;
  final String? phone;
}

class CustomerPortalTicket {
  const CustomerPortalTicket({
    required this.id,
    required this.type,
    required this.priority,
    required this.status,
    required this.subject,
    required this.description,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String type;
  final String priority;
  final String status;
  final String subject;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;

  String get typeLabel => _label(type);

  String get statusLabel => _label(status);

  String get priorityLabel => _label(priority);

  String get shortId => id.length <= 8 ? id : id.substring(0, 8);

  static String _label(String value) {
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}

class CustomerPortalTicketDetail {
  const CustomerPortalTicketDetail({
    required this.ticket,
    required this.events,
  });

  final CustomerPortalTicket ticket;
  final List<CustomerPortalTicketEvent> events;
}

class CustomerPortalTicketEvent {
  const CustomerPortalTicketEvent({
    required this.id,
    required this.ticketId,
    required this.createdAt,
    required this.actorLabel,
    this.oldStatus,
    this.newStatus,
    this.note,
  });

  final String id;
  final String ticketId;
  final DateTime createdAt;
  final String actorLabel;
  final String? oldStatus;
  final String? newStatus;
  final String? note;

  String get title {
    if (oldStatus != null && newStatus != null && oldStatus != newStatus) {
      return '${CustomerPortalTicket._label(oldStatus!)} to '
          '${CustomerPortalTicket._label(newStatus!)}';
    }
    if (newStatus != null) {
      return CustomerPortalTicket._label(newStatus!);
    }
    return 'Update';
  }

  String get displayNote => (note ?? '').trim();
}
