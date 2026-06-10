class AnalyticsDashboardSnapshot {
  const AnalyticsDashboardSnapshot({
    required this.platformMetrics,
    required this.ticketMetrics,
    required this.operationalMetrics,
    required this.recentTickets,
    required this.recentResidentRegistrations,
    required this.recentHoaCreations,
    required this.recentDocumentUploads,
    required this.loadedAt,
  });

  final PlatformMetrics platformMetrics;
  final TicketMetricsBreakdown ticketMetrics;
  final OperationalMetrics operationalMetrics;
  final List<RecentTicketActivity> recentTickets;
  final List<RecentResidentRegistration> recentResidentRegistrations;
  final List<RecentHoaCreation> recentHoaCreations;
  final List<RecentDocumentUpload> recentDocumentUploads;
  final DateTime loadedAt;
}

class PlatformMetrics {
  const PlatformMetrics({
    required this.totalHoas,
    required this.activeResidents,
    required this.pendingResidentVerifications,
    required this.activeActivationCodes,
    required this.documentsCount,
    required this.announcementsCount,
  });

  final int totalHoas;
  final int activeResidents;
  final int pendingResidentVerifications;
  final int activeActivationCodes;
  final int documentsCount;
  final int announcementsCount;
}

class TicketMetricsBreakdown {
  const TicketMetricsBreakdown({
    required this.newTickets,
    required this.open,
    required this.assigned,
    required this.inProgress,
    required this.resolved,
    required this.closed,
  });

  final int newTickets;
  final int open;
  final int assigned;
  final int inProgress;
  final int resolved;
  final int closed;

  int get activeTotal => newTickets + open + assigned + inProgress;
  int get completedTotal => resolved + closed;
}

class OperationalMetrics {
  const OperationalMetrics({
    required this.hoaManagers,
    required this.hoaBoardMembers,
    required this.kcStaff,
    required this.dispatchUsers,
    required this.csrUsers,
  });

  final int hoaManagers;
  final int hoaBoardMembers;
  final int kcStaff;
  final int dispatchUsers;
  final int csrUsers;
}

class RecentTicketActivity {
  const RecentTicketActivity({
    required this.id,
    required this.subject,
    required this.status,
    required this.priority,
    required this.hoaName,
    required this.requesterName,
    required this.createdAt,
  });

  final String id;
  final String subject;
  final String status;
  final String priority;
  final String hoaName;
  final String requesterName;
  final DateTime createdAt;
}

class RecentResidentRegistration {
  const RecentResidentRegistration({
    required this.id,
    required this.residentName,
    required this.email,
    required this.hoaName,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String residentName;
  final String email;
  final String hoaName;
  final String status;
  final DateTime createdAt;
}

class RecentHoaCreation {
  const RecentHoaCreation({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String code;
  final String status;
  final DateTime createdAt;
}

class RecentDocumentUpload {
  const RecentDocumentUpload({
    required this.id,
    required this.title,
    required this.category,
    required this.hoaName,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final String hoaName;
  final String status;
  final DateTime createdAt;
}
