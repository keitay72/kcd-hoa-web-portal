import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_context.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/document_repository.dart';
import '../domain/hoa_document.dart';
import '../domain/hoa_document_inputs.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return SupabaseDocumentRepository(ref.watch(supabaseClientProvider));
});

final documentListProvider = FutureProvider.autoDispose
    .family<List<HoaDocument>, DocumentListFilter>((ref, filter) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final items = await ref.watch(documentRepositoryProvider).list(
        hoaId: filter.hoaId,
        status: filter.status,
        category: filter.category,
      );
  if (allowedHoaIds == null) return items;
  return items.where((item) => allowedHoaIds.contains(item.hoaId)).toList();
});

final documentDetailProvider =
    FutureProvider.autoDispose.family<HoaDocument, String>((ref, id) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final item = await ref.watch(documentRepositoryProvider).getById(id);
  if (allowedHoaIds != null && !allowedHoaIds.contains(item.hoaId)) {
    throw StateError('Document is outside the active view.');
  }
  return item;
});

final documentCommandProvider =
    AsyncNotifierProvider.autoDispose<DocumentCommandController, void>(
  DocumentCommandController.new,
);

class DocumentListFilter {
  const DocumentListFilter({
    this.hoaId,
    this.status,
    this.category,
  });

  final String? hoaId;
  final String? status;
  final String? category;

  @override
  bool operator ==(Object other) {
    return other is DocumentListFilter &&
        other.hoaId == hoaId &&
        other.status == status &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(hoaId, status, category);
}

class DocumentCommandController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<HoaDocument?> uploadDocument(HoaDocumentUploadInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(documentRepositoryProvider).upload(input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateDocumentViews(result.value?.id);
    return result.value;
  }

  Future<HoaDocument?> updateDocument({
    required String id,
    required HoaDocumentEditInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(documentRepositoryProvider).update(id: id, input: input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateDocumentViews(id);
    return result.value;
  }

  Future<HoaDocument?> archiveDocument(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(documentRepositoryProvider).archive(id);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateDocumentViews(id);
    return result.value;
  }

  void _invalidateDocumentViews(String? documentId) {
    ref.invalidate(documentListProvider);
    if (documentId != null) {
      ref.invalidate(documentDetailProvider(documentId));
    }
  }
}
