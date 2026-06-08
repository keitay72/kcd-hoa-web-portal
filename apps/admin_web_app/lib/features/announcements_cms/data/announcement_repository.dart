import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/announcement.dart';
import '../domain/announcement_inputs.dart';
import 'announcement_dto.dart';

abstract interface class AnnouncementRepository {
  Future<List<Announcement>> list(AnnouncementListFilter filter);

  Future<Announcement> getById(String id);

  Future<Announcement> create(AnnouncementInput input);

  Future<Announcement> update({
    required String id,
    required AnnouncementInput input,
  });

  Future<Announcement> setStatus({
    required String id,
    required AnnouncementStatus status,
  });

  Future<Announcement> archive(String id);
}

class AnnouncementListFilter {
  const AnnouncementListFilter({
    this.hoaId,
    this.status,
    this.publishFrom,
    this.publishTo,
    this.search,
  });

  final String? hoaId;
  final String? status;
  final DateTime? publishFrom;
  final DateTime? publishTo;
  final String? search;

  @override
  bool operator ==(Object other) {
    return other is AnnouncementListFilter &&
        other.hoaId == hoaId &&
        other.status == status &&
        other.publishFrom == publishFrom &&
        other.publishTo == publishTo &&
        other.search == search;
  }

  @override
  int get hashCode => Object.hash(
        hoaId,
        status,
        publishFrom,
        publishTo,
        search,
      );
}

class SupabaseAnnouncementRepository implements AnnouncementRepository {
  const SupabaseAnnouncementRepository(this._client);

  final SupabaseClient _client;

  static const _selectColumns = '''
    id,
    hoa_id,
    title,
    body,
    publish_at,
    expire_at,
    status,
    created_by,
    created_at,
    updated_at,
    hoa_communities(name, code),
    profiles(email, full_name)
  ''';

  @override
  Future<List<Announcement>> list(AnnouncementListFilter filter) async {
    var query = _client.from('announcements').select(_selectColumns);

    if (filter.hoaId != null && filter.hoaId!.isNotEmpty) {
      query = query.eq('hoa_id', filter.hoaId!);
    }
    if (filter.status != null && filter.status!.isNotEmpty) {
      query = query.eq('status', filter.status!);
    }
    if (filter.publishFrom != null) {
      query = query.gte('publish_at', filter.publishFrom!.toUtc().toIso8601String());
    }
    if (filter.publishTo != null) {
      query = query.lt('publish_at', filter.publishTo!.toUtc().toIso8601String());
    }

    final rows = await query.order('publish_at', ascending: false);
    final items = rows.map((row) => AnnouncementDto.fromJson(row).toDomain()).toList();
    final search = filter.search?.trim().toLowerCase();

    if (search == null || search.isEmpty) {
      return items;
    }

    return items.where((item) {
      return item.title.toLowerCase().contains(search) ||
          item.body.toLowerCase().contains(search) ||
          item.hoaLabel.toLowerCase().contains(search) ||
          item.createdByLabel.toLowerCase().contains(search);
    }).toList();
  }

  @override
  Future<Announcement> getById(String id) async {
    final row = await _client
        .from('announcements')
        .select(_selectColumns)
        .eq('id', id)
        .single();

    return AnnouncementDto.fromJson(row).toDomain();
  }

  @override
  Future<Announcement> create(AnnouncementInput input) async {
    final row = await _client
        .from('announcements')
        .insert(input.toJson(createdBy: _client.auth.currentUser?.id))
        .select(_selectColumns)
        .single();

    return AnnouncementDto.fromJson(row).toDomain();
  }

  @override
  Future<Announcement> update({
    required String id,
    required AnnouncementInput input,
  }) async {
    final row = await _client
        .from('announcements')
        .update(input.toJson())
        .eq('id', id)
        .select(_selectColumns)
        .single();

    return AnnouncementDto.fromJson(row).toDomain();
  }

  @override
  Future<Announcement> setStatus({
    required String id,
    required AnnouncementStatus status,
  }) async {
    final row = await _client
        .from('announcements')
        .update({'status': status.name})
        .eq('id', id)
        .select(_selectColumns)
        .single();

    return AnnouncementDto.fromJson(row).toDomain();
  }

  @override
  Future<Announcement> archive(String id) {
    return setStatus(id: id, status: AnnouncementStatus.archived);
  }
}
