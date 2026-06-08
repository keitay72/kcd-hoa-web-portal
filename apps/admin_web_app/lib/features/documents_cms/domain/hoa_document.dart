enum HoaDocumentStatus {
  active,
  archived;

  static HoaDocumentStatus fromDatabase(String value) {
    return HoaDocumentStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => HoaDocumentStatus.archived,
    );
  }
}

enum HoaDocumentVisibilityScope {
  resident,
  board,
  manager,
  admin;

  static HoaDocumentVisibilityScope fromDatabase(String value) {
    return HoaDocumentVisibilityScope.values.firstWhere(
      (scope) => scope.name == value,
      orElse: () => HoaDocumentVisibilityScope.resident,
    );
  }
}

class HoaDocument {
  const HoaDocument({
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
  final HoaDocumentVisibilityScope visibilityScope;
  final HoaDocumentStatus status;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? hoaName;
  final String? hoaCode;

  bool get isArchived => status == HoaDocumentStatus.archived;

  String get statusLabel => status.name[0].toUpperCase() + status.name.substring(1);

  String get visibilityLabel {
    return visibilityScope.name[0].toUpperCase() + visibilityScope.name.substring(1);
  }

  String get hoaLabel {
    if (hoaName != null && hoaCode != null) {
      return '$hoaName ($hoaCode)';
    }
    return hoaName ?? hoaCode ?? hoaId;
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
