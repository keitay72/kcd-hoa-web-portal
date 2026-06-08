import '../domain/hoa_document.dart';

class HoaDocumentDto {
  const HoaDocumentDto({
    required this.id,
    required this.hoaId,
    required this.title,
    required this.category,
    required this.storagePath,
    required this.mimeType,
    required this.fileSize,
    required this.visibilityScope,
    required this.status,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.hoaName,
    this.hoaCode,
  });

  final String id;
  final String hoaId;
  final String title;
  final String category;
  final String storagePath;
  final String mimeType;
  final int fileSize;
  final String visibilityScope;
  final String status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hoaName;
  final String? hoaCode;

  factory HoaDocumentDto.fromJson(Map<String, dynamic> json) {
    final hoa = json['hoa_communities'] as Map<String, dynamic>?;

    return HoaDocumentDto(
      id: json['id'] as String,
      hoaId: json['hoa_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      storagePath: json['storage_path'] as String,
      mimeType: json['mime_type'] as String,
      fileSize: json['file_size'] as int,
      visibilityScope: json['visibility_scope'] as String,
      status: json['status'] as String,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      hoaName: hoa?['name'] as String?,
      hoaCode: hoa?['code'] as String?,
    );
  }

  HoaDocument toDomain() {
    return HoaDocument(
      id: id,
      hoaId: hoaId,
      title: title,
      category: category,
      storagePath: storagePath,
      mimeType: mimeType,
      fileSize: fileSize,
      visibilityScope: HoaDocumentVisibilityScope.fromDatabase(visibilityScope),
      status: HoaDocumentStatus.fromDatabase(status),
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      hoaName: hoaName,
      hoaCode: hoaCode,
    );
  }
}
