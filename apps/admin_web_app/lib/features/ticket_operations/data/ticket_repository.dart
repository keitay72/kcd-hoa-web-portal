import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ticket.dart';
import '../domain/ticket_inputs.dart';
import 'ticket_dtos.dart';

abstract interface class TicketRepository {
  Future<List<ServiceTicket>> list(TicketListFilter filter);
  Future<ServiceTicket> getById(String id);
  Future<List<TicketEvent>> eventsForTicket(String ticketId);
  Future<List<TicketAttachment>> attachmentsForTicket(String ticketId);
  Future<List<TicketAssigneeOption>> assigneeOptions();
  Future<TicketMetrics> metrics();
  Future<List<ServiceTicket>> queue(TicketQueue queue);
  Future<ServiceTicket> updateStatus(TicketStatusUpdateInput input);
  Future<ServiceTicket> assignTicket(TicketAssignmentInput input);
  Future<ServiceTicket> updatePriority(TicketPriorityUpdateInput input);
  Future<void> addInternalNote(TicketInternalNoteInput input);
  Future<ServiceTicket> runWorkflowAutomation(ServiceTicket ticket);
  Future<String> createAttachmentUrl(TicketAttachment attachment);
}

class TicketListFilter {
  const TicketListFilter({
    this.hoaId,
    this.status,
    this.priority,
    this.search,
  });

  final String? hoaId;
  final String? status;
  final String? priority;
  final String? search;

  @override
  bool operator ==(Object other) {
    return other is TicketListFilter &&
        other.hoaId == hoaId &&
        other.status == status &&
        other.priority == priority &&
        other.search == search;
  }

  @override
  int get hashCode => Object.hash(hoaId, status, priority, search);
}

class SupabaseTicketRepository implements TicketRepository {
  const SupabaseTicketRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'ticket-attachments';
  static const _ticketSelect = '''
    id,
    hoa_id,
    requester_user_id,
    address_id,
    type,
    priority,
    status,
    subject,
    description,
    created_at,
    updated_at,
    hoa_communities(name, code),
    profiles(full_name, email),
    hoa_addresses(line1, line2, city, state, postal_code)
  ''';

  @override
  Future<List<ServiceTicket>> list(TicketListFilter filter) async {
    var query = _client.from('tickets').select(_ticketSelect);

    if (filter.hoaId != null && filter.hoaId!.isNotEmpty) {
      query = query.eq('hoa_id', filter.hoaId!);
    }
    if (filter.status != null && filter.status!.isNotEmpty) {
      query = query.eq('status', filter.status!);
    }
    if (filter.priority != null && filter.priority!.isNotEmpty) {
      query = query.eq('priority', filter.priority!);
    }

    final rows = await query.order('created_at', ascending: false);
    final items = rows.map((row) => ServiceTicketDto.fromJson(row).toDomain()).toList();
    return _applySearch(items, filter.search);
  }

  @override
  Future<ServiceTicket> getById(String id) async {
    final row = await _client
        .from('tickets')
        .select(_ticketSelect)
        .eq('id', id)
        .single();

    return ServiceTicketDto.fromJson(row).toDomain();
  }

  @override
  Future<List<TicketEvent>> eventsForTicket(String ticketId) async {
    final rows = await _client
        .from('ticket_events')
        .select('id, ticket_id, actor_user_id, old_status, new_status, note, created_at, profiles(full_name, email)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: false);

    return rows.map((row) => TicketEventDto.fromJson(row).toDomain()).toList();
  }

  @override
  Future<List<TicketAttachment>> attachmentsForTicket(String ticketId) async {
    final rows = await _client
        .from('ticket_attachments')
        .select('id, ticket_id, uploaded_by, storage_path, mime_type, file_size, scan_status, created_at, profiles(full_name, email)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: false);

    return rows.map((row) => TicketAttachmentDto.fromJson(row).toDomain()).toList();
  }

  @override
  Future<List<TicketAssigneeOption>> assigneeOptions() async {
    final rows = await _client
        .from('user_tenant_roles')
        .select('user_id, role_id');

    final roleCodes = await _roleCodesById(
      rows.map((row) => row['role_id'] as int),
    );
    final eligibleUserIds = <String>{};
    final rolesByUser = <String, Set<String>>{};

    for (final row in rows) {
      final roleCode = roleCodes[row['role_id'] as int];
      if (!{'tenant_csr', 'tenant_dispatch', 'tenant_admin', 'tenant_manager'}.contains(roleCode)) {
        continue;
      }

      final userId = row['user_id'] as String;
      eligibleUserIds.add(userId);
      rolesByUser.putIfAbsent(userId, () => <String>{}).add(roleCode!);
    }

    final labels = await _profileLabelsById(eligibleUserIds);
    final options = rolesByUser.entries.map((entry) {
      return TicketAssigneeOption(
        userId: entry.key,
        label: labels[entry.key] ?? entry.key,
        roleCodes: entry.value,
      );
    }).toList();

    return options..sort((a, b) => a.label.compareTo(b.label));
  }

  Future<Map<int, String>> _roleCodesById(Iterable<int> roleIds) async {
    final ids = roleIds.toSet();
    if (ids.isEmpty) return const {};

    final rows = await _client
        .from('roles')
        .select('id, code')
        .filter('id', 'in', '(${ids.join(',')})');

    return {
      for (final row in rows)
        row['id'] as int: row['code'] as String? ?? 'unknown',
    };
  }

  Future<Map<String, String>> _profileLabelsById(Iterable<String> userIds) async {
    final ids = userIds.toSet();
    if (ids.isEmpty) return const {};

    final rows = await _client
        .from('profiles')
        .select('id, full_name, email')
        .filter('id', 'in', '(${ids.join(',')})');

    return {
      for (final row in rows)
        row['id'] as String: row['full_name'] as String? ??
            row['email'] as String? ??
            row['id'] as String,
    };
  }

  @override
  Future<TicketMetrics> metrics() async {
    final tickets = await list(const TicketListFilter());
    return TicketMetrics.fromTickets(tickets);
  }

  @override
  Future<List<ServiceTicket>> queue(TicketQueue queue) async {
    final tickets = await list(const TicketListFilter());
    return switch (queue) {
      TicketQueue.all => tickets,
      TicketQueue.csr => tickets.where((ticket) {
          return ticket.status == TicketStatus.newTicket ||
              ticket.status == TicketStatus.open ||
              ticket.status == TicketStatus.waitingOnCustomer;
        }).toList(),
      TicketQueue.dispatch => tickets.where((ticket) {
          return ticket.type == TicketType.missedPickup ||
              ticket.type == TicketType.damagedCart ||
              ticket.status == TicketStatus.assigned ||
              ticket.status == TicketStatus.inProgress;
        }).toList(),
      TicketQueue.urgent => tickets.where((ticket) {
          return ticket.priority == TicketPriority.urgent ||
              ticket.slaState == SlaState.breached;
        }).toList(),
      TicketQueue.aging => tickets.where((ticket) {
          return !ticket.status.isTerminal && ticket.age.inHours >= 48;
        }).toList(),
    };
  }

  @override
  Future<ServiceTicket> updateStatus(TicketStatusUpdateInput input) async {
    final newStatus = input.status.databaseValue;
    final oldStatus = input.ticket.status.databaseValue;

    final row = await _client
        .from('tickets')
        .update({'status': newStatus})
        .eq('id', input.ticket.id)
        .select(_ticketSelect)
        .single();

    await _client.from('ticket_events').insert({
      'ticket_id': input.ticket.id,
      'actor_user_id': _client.auth.currentUser?.id,
      'old_status': oldStatus,
      'new_status': newStatus,
      'note': _nullableText(input.note) ?? 'Status changed to ${input.status.label}',
    });

    return ServiceTicketDto.fromJson(row).toDomain();
  }

  @override
  Future<ServiceTicket> assignTicket(TicketAssignmentInput input) async {
    final assignedStatus = TicketStatus.assigned.databaseValue;
    final oldStatus = input.ticket.status.databaseValue;
    final row = await _client
        .from('tickets')
        .update({'status': assignedStatus})
        .eq('id', input.ticket.id)
        .select(_ticketSelect)
        .single();

    await _client.from('ticket_events').insert({
      'ticket_id': input.ticket.id,
      'actor_user_id': _client.auth.currentUser?.id,
      'old_status': oldStatus,
      'new_status': assignedStatus,
      'note': '[ASSIGNMENT] ${_nullableText(input.note) ?? 'Assigned to ${input.assignee.label}'}',
    });

    return ServiceTicketDto.fromJson(row).toDomain();
  }

  @override
  Future<ServiceTicket> updatePriority(TicketPriorityUpdateInput input) async {
    final row = await _client
        .from('tickets')
        .update({'priority': input.priority.name})
        .eq('id', input.ticket.id)
        .select(_ticketSelect)
        .single();

    await _client.from('ticket_events').insert({
      'ticket_id': input.ticket.id,
      'actor_user_id': _client.auth.currentUser?.id,
      'old_status': input.ticket.status.databaseValue,
      'new_status': input.ticket.status.databaseValue,
      'note': _nullableText(input.note) ??
          'Priority changed from ${input.ticket.priority.label} to ${input.priority.label}',
    });

    return ServiceTicketDto.fromJson(row).toDomain();
  }

  @override
  Future<void> addInternalNote(TicketInternalNoteInput input) async {
    await _client.from('ticket_events').insert({
      'ticket_id': input.ticket.id,
      'actor_user_id': _client.auth.currentUser?.id,
      'old_status': input.ticket.status.databaseValue,
      'new_status': input.ticket.status.databaseValue,
      'note': '[INTERNAL] ${input.note.trim()}',
    });
  }

  @override
  Future<ServiceTicket> runWorkflowAutomation(ServiceTicket ticket) async {
    var nextStatus = ticket.status;
    var nextPriority = ticket.priority;
    final notes = <String>[];

    if (ticket.status == TicketStatus.newTicket) {
      nextStatus = TicketStatus.open;
      notes.add('New ticket auto-opened for CSR triage');
    }

    if (!ticket.status.isTerminal && ticket.slaState == SlaState.breached) {
      nextPriority = TicketPriority.urgent;
      notes.add('SLA breach escalated priority to urgent');
    } else if (!ticket.status.isTerminal &&
        ticket.slaState == SlaState.dueSoon &&
        ticket.priority == TicketPriority.normal) {
      nextPriority = TicketPriority.high;
      notes.add('Ticket nearing SLA escalated priority to high');
    }

    final row = await _client
        .from('tickets')
        .update({
          'status': nextStatus.databaseValue,
          'priority': nextPriority.name,
        })
        .eq('id', ticket.id)
        .select(_ticketSelect)
        .single();

    if (notes.isNotEmpty) {
      await _client.from('ticket_events').insert({
        'ticket_id': ticket.id,
        'actor_user_id': _client.auth.currentUser?.id,
        'old_status': ticket.status.databaseValue,
        'new_status': nextStatus.databaseValue,
        'note': '[AUTOMATION] ${notes.join('; ')}',
      });
    }

    return ServiceTicketDto.fromJson(row).toDomain();
  }

  @override
  Future<String> createAttachmentUrl(TicketAttachment attachment) {
    return _client.storage.from(_bucket).createSignedUrl(
          attachment.storagePath,
          60 * 10,
        );
  }
}

String? _nullableText(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}


List<ServiceTicket> _applySearch(List<ServiceTicket> items, String? value) {
  final search = value?.trim().toLowerCase();

  if (search == null || search.isEmpty) return items;

  return items.where((ticket) {
    return ticket.subject.toLowerCase().contains(search) ||
        ticket.description.toLowerCase().contains(search) ||
        ticket.hoaLabel.toLowerCase().contains(search) ||
        ticket.requesterLabel.toLowerCase().contains(search) ||
        ticket.addressLabel.toLowerCase().contains(search);
  }).toList();
}
