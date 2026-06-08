import '../domain/announcement.dart';

class AnnouncementDto {
  const AnnouncementDto({
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
  final String status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hoaName;
  final String? hoaCode;
  final String? createdByEmail;
  final String? createdByName;

  factory AnnouncementDto.fromJson(Map<String, dynamic> json) {
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;
    final profile = json['profiles'] as Map<String, dynamic>?;

    return AnnouncementDto(
      id: json['id'] as String,
      hoaId: json['hoa_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      publishAt: DateTime.parse(json['publish_at'] as String),
      expireAt: json['expire_at'] == null
          ? null
          : DateTime.parse(json['expire_at'] as String),
      status: json['status'] as String,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      hoaName: hoa?['name'] as String?,
      hoaCode: hoa?['code'] as String?,
      createdByEmail: profile?['email'] as String?,
      createdByName: profile?['full_name'] as String?,
    );
  }

  Announcement toDomain() {
    return Announcement(
      id: id,
      hoaId: hoaId,
      title: title,
      body: body,
      publishAt: publishAt,
      expireAt: expireAt,
      status: AnnouncementStatus.fromDatabase(status),
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      hoaName: hoaName,
      hoaCode: hoaCode,
      createdByEmail: createdByEmail,
      createdByName: createdByName,
    );
  }
}
