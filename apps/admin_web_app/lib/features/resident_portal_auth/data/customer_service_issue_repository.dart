import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerServiceIssueInput {
  const CustomerServiceIssueInput({
    required this.type,
    required this.subject,
    required this.description,
  });

  final String type;
  final String subject;
  final String description;
}

abstract interface class CustomerServiceIssueRepository {
  Future<String> submit(CustomerServiceIssueInput input);
}

class SupabaseCustomerServiceIssueRepository
    implements CustomerServiceIssueRepository {
  const SupabaseCustomerServiceIssueRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> submit(CustomerServiceIssueInput input) async {
    final response = await _client.functions.invoke(
      'submit-customer-service-issue',
      body: {
        'type': input.type,
        'subject': input.subject.trim(),
        'description': input.description.trim(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data['ticketId'] as String;
  }
}
