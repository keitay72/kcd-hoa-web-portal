import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/customer_service_issue_repository.dart';
import 'customer_portal_home_providers.dart';
import 'customer_service_issue_providers.dart';
import 'resident_portal_scaffold.dart';

class CustomerServiceIssuePage extends ConsumerStatefulWidget {
  const CustomerServiceIssuePage({required this.tenantCode, super.key});

  final String tenantCode;

  @override
  ConsumerState<CustomerServiceIssuePage> createState() =>
      _CustomerServiceIssuePageState();
}

class _CustomerServiceIssuePageState
    extends ConsumerState<CustomerServiceIssuePage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _type = 'missed_pickup';

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerServiceIssueControllerProvider);

    return ResidentPortalScaffold(
      tenantCode: widget.tenantCode,
      title: 'Report a service issue',
      subtitle:
          'Tell us what happened at your verified service address. This creates a ticket for the service team.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Issue type'),
              items: const [
                DropdownMenuItem(
                  value: 'missed_pickup',
                  child: Text('Missed pickup'),
                ),
                DropdownMenuItem(
                  value: 'damaged_cart',
                  child: Text('Damaged cart'),
                ),
                DropdownMenuItem(
                  value: 'complaint',
                  child: Text('Complaint'),
                ),
                DropdownMenuItem(
                  value: 'service_issue',
                  child: Text('Other service issue'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Details',
                alignLabelWithHint: true,
              ),
              validator: _required,
            ),
            if (state.hasError) ...[
              const SizedBox(height: 12),
              Text(
                _errorText(state.error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: state.isLoading ? null : _submit,
              child: state.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit issue'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/portal/${widget.tenantCode}/home'),
              child: const Text('Back to portal'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ticketId =
        await ref.read(customerServiceIssueControllerProvider.notifier).submit(
              CustomerServiceIssueInput(
                type: _type,
                subject: _subjectController.text,
                description: _descriptionController.text,
              ),
            );
    if (ticketId == null || !mounted) return;
    ref.invalidate(customerPortalHomeProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Service issue submitted. Ticket $ticketId')),
    );
    context.go('/portal/${widget.tenantCode}/home');
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String _errorText(Object? error) {
    final message =
        error?.toString().replaceFirst('Bad state: ', '').trim() ?? '';
    if (message.isEmpty) return 'Unable to submit service issue.';
    return message;
  }
}
