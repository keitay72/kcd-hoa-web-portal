import 'package:supabase_flutter/supabase_flutter.dart';

import '../../announcements_cms/data/announcement_repository.dart';
import '../../documents_cms/data/document_repository.dart';
import '../../schedules_admin/data/service_schedule_repository.dart';
import '../../ticket_operations/data/ticket_repository.dart';
import '../../ticket_operations/domain/ticket.dart';
import '../domain/hoa_manager_summary.dart';
import '../domain/hoa_resident.dart';
import 'hoa_resident_dto.dart';

abstract interface class HoaManagerRepository {
  Future<List<HoaResident>> residents(String hoaId);
  Future<HoaManagerSummary> summary(String hoaId);
}

class SupabaseHoaManagerRepository implements HoaManagerRepository {
  const SupabaseHoaManagerRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<HoaResident>> residents(String hoaId) async {
    final rows = await _client
        .from('user_address_memberships')
        .select('''
          user_id,
          hoa_id,
          address_id,
          occupancy_type,
          is_primary,
          start_date,
          profile:profiles!user_address_memberships_user_id_fkey(email, full_name, phone, status),
          hoa_addresses(line1, line2, city, state, postal_code)
        ''')
        .eq('hoa_id', hoaId)
        .eq('is_current', true)
        .order('start_date', ascending: false);

    return rows.map((row) => HoaResidentDto.fromJson(row).toDomain()).toList();
  }

  @override
  Future<HoaManagerSummary> summary(String hoaId) async {
    final hoaRow = await _client
        .from('hoa_communities')
        .select('id, name, code')
        .eq('id', hoaId)
        .single();

    final residents = await this.residents(hoaId);
    final documents = await SupabaseDocumentRepository(_client).list(
      hoaId: hoaId,
      status: 'active',
    );
    final announcements = await SupabaseAnnouncementRepository(_client).list(
      AnnouncementListFilter(
        hoaId: hoaId,
        status: 'published',
      ),
    );
    final tickets = await SupabaseTicketRepository(_client).list(
      TicketListFilter(hoaId: hoaId),
    );
    final schedules = await SupabaseServiceScheduleRepository(_client).list(
      ServiceScheduleListFilter(
        hoaId: hoaId,
        status: 'active',
        scope: ServiceScheduleScope.hoaWide.value,
      ),
    );

    return HoaManagerSummary(
      hoaId: hoaId,
      hoaName: hoaRow['name'] as String? ?? 'HOA',
      hoaCode: hoaRow['code'] as String? ?? hoaId,
      residentCount: residents.length,
      activeDocumentCount: documents.length,
      activeAnnouncementCount: announcements.length,
      openTicketCount: tickets.where((ticket) => !ticket.status.isTerminal).length,
      activeScheduleCount: schedules.length,
    );
  }
}
