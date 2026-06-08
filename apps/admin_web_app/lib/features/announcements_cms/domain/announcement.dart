enum AnnouncementStatus {
  draft,
  published,
  archived;

  static AnnouncementStatus fromDatabase(String value) {
    return AnnouncementStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => AnnouncementStatus.draft,
    );
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.hoaId,
    required this.title,
    required this.body,
    required this.publishAt,
    this.expireAt,
    required this.status,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.hoaName,
    this.hoaCode,
    this.createdByEmail,
    this.createdByName,
  });

  final String id;
  final String hoaId;
  final String title;
  final String body;
  final DateTime publishAt;
  final DateTime? expireAt;
  final AnnouncementStatus status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hoaName;
  final String? hoaCode;
  final String? createdByEmail;
  final String? createdByName;

  bool get isArchived => status == AnnouncementStatus.archived;
  bool get isPublished => status == AnnouncementStatus.published;
  bool get isDraft => status == AnnouncementStatus.draft;

  String get statusLabel => _label(status.name);

  String get hoaLabel {
    if (hoaName != null && hoaCode != null) {
      return '$hoaName ($hoaCode)';
    }
    return hoaName ?? hoaCode ?? hoaId;
  }

  String get createdByLabel {
    return createdByName ?? createdByEmail ?? createdBy ?? 'Not set';
  }

  bool get isScheduled {
    return status == AnnouncementStatus.published && publishAt.isAfter(DateTime.now());
  }

  bool get isExpired {
    final expires = expireAt;
    return expires != null && expires.isBefore(DateTime.now());
  }
}

String _label(String value) {
  return value[0].toUpperCase() + value.substring(1);
}
