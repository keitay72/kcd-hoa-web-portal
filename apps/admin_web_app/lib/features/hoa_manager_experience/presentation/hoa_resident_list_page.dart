import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/hoa_resident.dart';
import 'hoa_manager_providers.dart';
import 'hoa_scope_header.dart';

class HoaResidentListPage extends ConsumerStatefulWidget {
  const HoaResidentListPage({super.key});

  @override
  ConsumerState<HoaResidentListPage> createState() => _HoaResidentListPageState();
}

class _HoaResidentListPageState extends ConsumerState<HoaResidentListPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final residents = ref.watch(hoaResidentListProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HoaScopeHeader(
            title: 'HOA Residents',
            subtitle: 'Current resident-address memberships for your HOA.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search residents',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: residents.when(
              data: (items) => _ResidentTable(residents: _filter(items)),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Unable to load residents: $error')),
            ),
          ),
        ],
      ),
    );
  }

  List<HoaResident> _filter(List<HoaResident> items) {
    final search = _searchController.text.trim().toLowerCase();
    if (search.isEmpty) return items;

    return items.where((resident) {
      return resident.displayName.toLowerCase().contains(search) ||
          resident.email.toLowerCase().contains(search) ||
          resident.addressLabel.toLowerCase().contains(search);
    }).toList();
  }
}

class _ResidentTable extends StatelessWidget {
  const _ResidentTable({required this.residents});

  final List<HoaResident> residents;

  @override
  Widget build(BuildContext context) {
    if (residents.isEmpty) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No residents matched this HOA search.'),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: residents.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final resident = residents[index];
          return ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(resident.displayName),
            subtitle: Text('${resident.email} • ${resident.addressLabel}'),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(resident.occupancyLabel)),
                if (resident.isPrimary) const Chip(label: Text('Primary')),
                Chip(label: Text(resident.statusLabel)),
              ],
            ),
          );
        },
      ),
    );
  }
}
