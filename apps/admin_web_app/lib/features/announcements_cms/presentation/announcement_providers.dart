import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_context.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../data/announcement_repository.dart';
import '../domain/announcement.dart';
import '../domain/announcement_inputs.dart';

export '../data/announcement_repository.dart' show AnnouncementListFilter;

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return SupabaseAnnouncementRepository(ref.watch(supabaseClientProvider));
});

final announcementListProvider = FutureProvider.autoDispose
    .family<List<Announcement>, AnnouncementListFilter>((ref, filter) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final items = await ref.watch(announcementRepositoryProvider).list(filter);
  if (allowedHoaIds == null) return items;
  return items.where((item) => allowedHoaIds.contains(item.hoaId)).toList();
});

final announcementDetailProvider =
    FutureProvider.autoDispose.family<Announcement, String>((ref, id) async {
  final allowedHoaIds = await ref.watch(activeHoaIdsProvider.future);
  final item = await ref.watch(announcementRepositoryProvider).getById(id);
  if (allowedHoaIds != null && !allowedHoaIds.contains(item.hoaId)) {
    throw StateError('Announcement is outside the active view.');
  }
  return item;
});

final announcementCommandProvider =
    AsyncNotifierProvider.autoDispose<AnnouncementCommandController, void>(
  AnnouncementCommandController.new,
);

class AnnouncementCommandController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<Announcement?> createAnnouncement(AnnouncementInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(announcementRepositoryProvider).create(input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateAnnouncementViews(result.value?.id);
    return result.value;
  }

  Future<Announcement?> updateAnnouncement({
    required String id,
    required AnnouncementInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref
          .read(announcementRepositoryProvider)
          .update(id: id, input: input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateAnnouncementViews(id);
    return result.value;
  }

  Future<Announcement?> publishAnnouncement(String id) {
    return _setStatus(id: id, status: AnnouncementStatus.published);
  }

  Future<Announcement?> unpublishAnnouncement(String id) {
    return _setStatus(id: id, status: AnnouncementStatus.draft);
  }

  Future<Announcement?> archiveAnnouncement(String id) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(announcementRepositoryProvider).archive(id);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateAnnouncementViews(id);
    return result.value;
  }

  Future<Announcement?> _setStatus({
    required String id,
    required AnnouncementStatus status,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(announcementRepositoryProvider).setStatus(
            id: id,
            status: status,
          );
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateAnnouncementViews(id);
    return result.value;
  }

  void _invalidateAnnouncementViews(String? announcementId) {
    ref.invalidate(announcementListProvider);
    if (announcementId != null) {
      ref.invalidate(announcementDetailProvider(announcementId));
    }
  }
}
