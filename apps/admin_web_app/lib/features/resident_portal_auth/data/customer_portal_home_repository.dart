import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/customer_portal_home.dart';

abstract interface class CustomerPortalHomeRepository {
  Future<CustomerPortalHome> loadHome();
  Future<CustomerPortalTicketDetail> loadTicketDetail(String ticketId);
}

class SupabaseCustomerPortalHomeRepository
    implements CustomerPortalHomeRepository {
  const SupabaseCustomerPortalHomeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CustomerPortalHome> loadHome() async {
    final response = await _client.functions.invoke('customer-portal-home');
    final data = response.data as Map<String, dynamic>;
    return CustomerPortalHome(
      account: _account(data['account'] as Map<String, dynamic>),
      serviceLocation: _optionalLocation(data['serviceLocation']),
      announcements: _list(data['announcements'], _announcement),
      documents: _list(data['documents'], _document),
      schedules: _list(data['schedules'], _schedule),
      recentTickets: _list(data['recentTickets'], _ticket),
      boardMembers: _list(data['boardMembers'], _boardMember),
    );
  }

  @override
  Future<CustomerPortalTicketDetail> loadTicketDetail(String ticketId) async {
    final response = await _client.functions.invoke(
      'customer-ticket-detail',
      body: {'ticketId': ticketId},
    );
    final data = response.data as Map<String, dynamic>;
    return CustomerPortalTicketDetail(
      ticket: _ticket(data['ticket'] as Map<String, dynamic>),
      events: _list(data['events'], _ticketEvent),
    );
  }

  CustomerPortalAccount _account(Map<String, dynamic> json) {
    return CustomerPortalAccount(
      id: json['id'] as String,
      accountType: json['accountType'] as String? ?? 'residential',
      isCommunityAccount: json['isCommunityAccount'] == true,
      accountNumber: json['accountNumber'] as String?,
      name: json['name'] as String?,
    );
  }

  CustomerPortalServiceLocation? _optionalLocation(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return CustomerPortalServiceLocation(
      id: value['id'] as String,
      line1: value['line1'] as String,
      line2: value['line2'] as String?,
      city: value['city'] as String,
      state: value['state'] as String,
      postalCode: value['postal_code'] as String? ??
          value['postalCode'] as String? ??
          '',
    );
  }

  CustomerPortalAnnouncement _announcement(Map<String, dynamic> json) {
    return CustomerPortalAnnouncement(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Announcement',
      body: json['body'] as String? ?? '',
      publishAt: _date(json['publish_at']),
    );
  }

  CustomerPortalDocument _document(Map<String, dynamic> json) {
    return CustomerPortalDocument(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Document',
      category: json['category'] as String? ?? 'general',
      mimeType: json['mime_type'] as String?,
      storagePath: json['storage_path'] as String?,
    );
  }

  CustomerPortalSchedule _schedule(Map<String, dynamic> json) {
    return CustomerPortalSchedule(
      id: json['id'] as String,
      serviceType: json['service_type'] as String? ?? 'service',
      serviceDay: json['service_day'] as int? ?? -1,
      scheduleRule: json['schedule_rule'] as String?,
      routeName: json['route_name'] as String?,
      notes: json['notes'] as String?,
    );
  }

  CustomerPortalBoardMember _boardMember(Map<String, dynamic> json) {
    return CustomerPortalBoardMember(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Community contact',
      roleName: json['roleName'] as String? ?? 'Community contact',
      isPrimaryContact: json['isPrimaryContact'] == true,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  CustomerPortalTicket _ticket(Map<String, dynamic> json) {
    return CustomerPortalTicket(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'service_issue',
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'new',
      subject: json['subject'] as String? ?? 'Service issue',
      description: json['description'] as String? ?? '',
      createdAt:
          _date(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      updatedAt: _date(json['updated_at'] ?? json['updatedAt']),
    );
  }

  CustomerPortalTicketEvent _ticketEvent(Map<String, dynamic> json) {
    return CustomerPortalTicketEvent(
      id: json['id'] as String,
      ticketId: json['ticketId'] as String? ?? json['ticket_id'] as String,
      actorLabel: json['actorLabel'] as String? ?? 'Service team',
      oldStatus: json['oldStatus'] as String? ?? json['old_status'] as String?,
      newStatus: json['newStatus'] as String? ?? json['new_status'] as String?,
      note: json['note'] as String?,
      createdAt:
          _date(json['createdAt'] ?? json['created_at']) ?? DateTime.now(),
    );
  }

  List<T> _list<T>(
    Object? value,
    T Function(Map<String, dynamic> json) mapper,
  ) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(mapper)
        .toList(growable: false);
  }

  DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
