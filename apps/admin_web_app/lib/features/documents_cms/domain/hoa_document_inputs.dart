import 'dart:typed_data';

import 'hoa_document.dart';

class HoaDocumentUploadInput {
  const HoaDocumentUploadInput({
    required this.hoaId,
    required this.title,
    required this.category,
    required this.visibilityScope,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String hoaId;
  final String title;
  final String category;
  final HoaDocumentVisibilityScope visibilityScope;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  int get fileSize => bytes.length;
}

class HoaDocumentEditInput {
  const HoaDocumentEditInput({
    required this.title,
    required this.category,
    required this.visibilityScope,
    required this.status,
  });

  final String title;
  final String category;
  final HoaDocumentVisibilityScope visibilityScope;
  final HoaDocumentStatus status;
}
