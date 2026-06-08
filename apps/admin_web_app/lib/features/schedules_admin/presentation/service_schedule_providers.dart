import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../data/service_schedule_repository.dart';
import '../domain/service_schedule.dart';
import '../domain/service_schedule_inputs.dart';

export '../data/service_schedule_repository.dart' show ServiceScheduleListFilter;

final serviceScheduleRepositoryProvider = Provider<ServiceScheduleRepository>((ref) {
  return SupabaseServiceScheduleRepository(ref.watch(supabaseClientProvider));
});

final serviceScheduleListProvider = FutureProvider.autoDispose
    .family<List<ServiceSchedule>, ServiceScheduleListFilter>((ref, filter) {
  return ref.watch(serviceScheduleRepositoryProvider).list(filter);
});

final serviceScheduleDetailProvider =
    FutureProvider.autoDispose.family<ServiceSchedule, String>((ref, id) {
  return ref.watch(serviceScheduleRepositoryProvider).getById(id);
});

final serviceScheduleCommandProvider =
    AsyncNotifierProvider.autoDispose<ServiceScheduleCommandController, void>(
  ServiceScheduleCommandController.new,
);

class ServiceScheduleCommandController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<ServiceSchedule?> createSchedule(ServiceScheduleInput input) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(serviceScheduleRepositoryProvider).create(input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateScheduleViews(result.value?.id);
    return result.value;
  }

  Future<ServiceSchedule?> updateSchedule({
    required String id,
    required ServiceScheduleInput input,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(serviceScheduleRepositoryProvider).update(id: id, input: input);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateScheduleViews(id);
    return result.value;
  }

  Future<ServiceSchedule?> archiveSchedule(ServiceSchedule schedule) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() {
      return ref.read(serviceScheduleRepositoryProvider).archive(schedule);
    });

    if (result.hasError) {
      state = AsyncError<void>(result.error!, result.stackTrace!);
      return null;
    }

    state = const AsyncData(null);
    _invalidateScheduleViews(schedule.id);
    return result.value;
  }

  void _invalidateScheduleViews(String? scheduleId) {
    ref.invalidate(serviceScheduleListProvider);
    if (scheduleId != null) {
      ref.invalidate(serviceScheduleDetailProvider(scheduleId));
    }
  }
}
