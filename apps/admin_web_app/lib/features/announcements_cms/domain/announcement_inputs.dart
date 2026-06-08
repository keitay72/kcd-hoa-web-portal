import 'announcement.dart';

class AnnouncementInput {
  const AnnouncementInput({
    required this.hoaId,
    required this.title,
    required this.body,
    required this.publishAt,
    required this.status,
    this.expireAt,
  });

  final String hoaId;
  final String title;
  final String body;
  final DateTime publishAt;
  final DateTime? expireAt;
  final AnnouncementStatus status;

  Map<String, dynamic> toJson({String? createdBy}) {
    return {
      'hoa_id': hoaId,
      'title': title.trim(),
      'body': body.trim(),
      'publish_at': publishAt.toUtc().toIso8601String(),
      'expire_at': expireAt?.toUtc().toIso8601String(),
      'status': status.name,
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}
