import '../domain/ticket.dart';

class ServiceTicketDto {
  const ServiceTicketDto({
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
  final String type;
  final String priority;
  final String status;
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

  factory ServiceTicketDto.fromJson(Map<String, dynamic> json) {
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;
    final requester = json['profiles'] as Map<String, dynamic>?;
    final address = json['hoa_addresses'] as Map<String, dynamic>?;

    return ServiceTicketDto(
      id: json['id'] as String,
      hoaId: json['hoa_id'] as String,
      requesterUserId: json['requester_user_id'] as String,
      addressId: json['address_id'] as String?,
      type: json['type'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      hoaName: hoa?['name'] as String?,
      hoaCode: hoa?['code'] as String?,
      requesterName: requester?['full_name'] as String?,
      requesterEmail: requester?['email'] as String?,
      addressLine1: address?['line1'] as String?,
      addressLine2: address?['line2'] as String?,
      addressCity: address?['city'] as String?,
      addressState: address?['state'] as String?,
      addressPostalCode: address?['postal_code'] as String?,
    );
  }

  ServiceTicket toDomain() {
    return ServiceTicket(
      id: id,
      hoaId: hoaId,
      requesterUserId: requesterUserId,
      addressId: addressId,
      type: TicketType.fromDatabase(type),
      priority: TicketPriority.fromDatabase(priority),
      status: TicketStatus.fromDatabase(status),
      subject: subject,
      description: description,
      createdAt: createdAt,
      updatedAt: updatedAt,
      hoaName: hoaName,
      hoaCode: hoaCode,
      requesterName: requesterName,
      requesterEmail: requesterEmail,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      addressCity: addressCity,
      addressState: addressState,
      addressPostalCode: addressPostalCode,
    );
  }
}

class TicketEventDto {
  const TicketEventDto({
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
  final String? oldStatus;
  final String? newStatus;
  final String? note;
  final DateTime createdAt;
  final String? actorName;
  final String? actorEmail;

  factory TicketEventDto.fromJson(Map<String, dynamic> json) {
    final actor = json['profiles'] as Map<String, dynamic>?;

    return TicketEventDto(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String,
      actorUserId: json['actor_user_id'] as String?,
      oldStatus: json['old_status'] as String?,
      newStatus: json['new_status'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      actorName: actor?['full_name'] as String?,
      actorEmail: actor?['email'] as String?,
    );
  }

  TicketEvent toDomain() {
    return TicketEvent(
      id: id,
      ticketId: ticketId,
      actorUserId: actorUserId,
      oldStatus: oldStatus == null ? null : TicketStatus.fromDatabase(oldStatus!),
      newStatus: newStatus == null ? null : TicketStatus.fromDatabase(newStatus!),
      note: note,
      createdAt: createdAt,
      actorName: actorName,
      actorEmail: actorEmail,
    );
  }
}

class TicketAttachmentDto {
  const TicketAttachmentDto({
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

  factory TicketAttachmentDto.fromJson(Map<String, dynamic> json) {
    final uploader = json['profiles'] as Map<String, dynamic>?;

    return TicketAttachmentDto(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String,
      uploadedBy: json['uploaded_by'] as String,
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String,
      fileSize: json['file_size'] as int,
      scanStatus: json['scan_status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      uploadedByName: uploader?['full_name'] as String?,
      uploadedByEmail: uploader?['email'] as String?,
    );
  }

  TicketAttachment toDomain() {
    return TicketAttachment(
      id: id,
      ticketId: ticketId,
      uploadedBy: uploadedBy,
      storagePath: storagePath,
      mimeType: mimeType,
      fileSize: fileSize,
      scanStatus: scanStatus,
      createdAt: createdAt,
      uploadedByName: uploadedByName,
      uploadedByEmail: uploadedByEmail,
    );
  }
}
