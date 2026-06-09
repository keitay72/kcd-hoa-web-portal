class HoaManagerSummary {
  const HoaManagerSummary({
    required this.hoaId,
    required this.hoaName,
    required this.hoaCode,
    required this.residentCount,
    required this.activeDocumentCount,
    required this.activeAnnouncementCount,
    required this.openTicketCount,
    required this.activeScheduleCount,
  });

  final String hoaId;
  final String hoaName;
  final String hoaCode;
  final int residentCount;
  final int activeDocumentCount;
  final int activeAnnouncementCount;
  final int openTicketCount;
  final int activeScheduleCount;

  String get hoaLabel => '$hoaName ($hoaCode)';
}
