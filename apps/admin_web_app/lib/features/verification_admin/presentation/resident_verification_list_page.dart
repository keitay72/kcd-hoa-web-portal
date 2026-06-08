import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/resident_verification.dart';
import 'resident_verification_providers.dart';

class ResidentVerificationListPage extends ConsumerStatefulWidget {
  const ResidentVerificationListPage({super.key});

  @override
  ConsumerState<ResidentVerificationListPage> createState() =>
      _ResidentVerificationListPageState();
}

class _ResidentVerificationListPageState
    extends ConsumerState<ResidentVerificationListPage> {
  final _searchController = TextEditingController();
  String? _status;
  String _search = '';

  ResidentVerificationListFilter get _filter {
    return ResidentVerificationListFilter(
      status: _status,
      search: _search,
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final verifications = ref.watch(residentVerificationListProvider(_filter));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Resident Verification',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(
                  residentVerificationListProvider(_filter),
                ),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<String?>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Status',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    ...ResidentVerificationStatus.values.map(
                      (status) => DropdownMenuItem<String?>(
                        value: status.name,
                        child: Text(status.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search resident, email, HOA, or address',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: verifications.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No resident verifications found.'),
                  );
                }

                return Card(
                  margin: EdgeInsets.zero,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return ListTile(
                        leading: Icon(_statusIcon(item.status)),
                        title: Text(item.residentLabel),
                        subtitle: Text(
                          '${item.residentEmail ?? 'No email'} · ${item.hoaLabel} · ${item.addressLabel.isEmpty ? 'No address' : item.addressLabel}',
                        ),
                        trailing: Text(item.statusLabel),
                        onTap: () => context.go(
                          '/admin/resident-verification/${item.id}',
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load resident verifications: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(ResidentVerificationStatus status) {
    return switch (status) {
      ResidentVerificationStatus.pending => Icons.hourglass_empty_outlined,
      ResidentVerificationStatus.verified => Icons.verified_user_outlined,
      ResidentVerificationStatus.failed => Icons.error_outline,
    };
  }
}
