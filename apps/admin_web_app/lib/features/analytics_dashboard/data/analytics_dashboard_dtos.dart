import '../domain/analytics_dashboard.dart';

class RecentTicketActivityDto {
  const RecentTicketActivityDto({
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

  factory RecentTicketActivityDto.fromJson(Map<String, dynamic> json) {
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;
    final requester = json['profiles'] as Map<String, dynamic>?;

    return RecentTicketActivityDto(
      id: json['id'] as String,
      subject: json['subject'] as String? ?? 'Untitled ticket',
      status: json['status'] as String? ?? 'new',
      priority: json['priority'] as String? ?? 'normal',
      hoaName: hoa?['name'] as String? ?? 'Unknown HOA',
      requesterName: requester?['full_name'] as String? ??
          requester?['email'] as String? ??
          'Unknown resident',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  RecentTicketActivity toDomain() {
    return RecentTicketActivity(
      id: id,
      subject: subject,
      status: status,
      priority: priority,
      hoaName: hoaName,
      requesterName: requesterName,
      createdAt: createdAt,
    );
  }
}

class RecentResidentRegistrationDto {
  const RecentResidentRegistrationDto({
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

  factory RecentResidentRegistrationDto.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;

    return RecentResidentRegistrationDto(
      id: json['id'] as String,
      residentName: profile?['full_name'] as String? ?? 'Unknown resident',
      email: profile?['email'] as String? ?? 'No email',
      hoaName: hoa?['name'] as String? ?? 'Unknown HOA',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  RecentResidentRegistration toDomain() {
    return RecentResidentRegistration(
      id: id,
      residentName: residentName,
      email: email,
      hoaName: hoaName,
      status: status,
      createdAt: createdAt,
    );
  }
}

class RecentHoaCreationDto {
  const RecentHoaCreationDto({
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

  factory RecentHoaCreationDto.fromJson(Map<String, dynamic> json) {
    return RecentHoaCreationDto(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unnamed HOA',
      code: json['code'] as String? ?? 'NO_CODE',
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  RecentHoaCreation toDomain() {
    return RecentHoaCreation(
      id: id,
      name: name,
      code: code,
      status: status,
      createdAt: createdAt,
    );
  }
}

class RecentDocumentUploadDto {
  const RecentDocumentUploadDto({
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

  factory RecentDocumentUploadDto.fromJson(Map<String, dynamic> json) {
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;

    return RecentDocumentUploadDto(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled document',
      category: json['category'] as String? ?? 'General',
      hoaName: hoa?['name'] as String? ?? 'Unknown HOA',
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  RecentDocumentUpload toDomain() {
    return RecentDocumentUpload(
      id: id,
      title: title,
      category: category,
      hoaName: hoaName,
      status: status,
      createdAt: createdAt,
    );
  }
}
