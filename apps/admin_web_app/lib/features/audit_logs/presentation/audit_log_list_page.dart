import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audit_log.dart';
import 'audit_log_providers.dart';

class AuditLogListPage extends ConsumerStatefulWidget {
  const AuditLogListPage({super.key});

  @override
  ConsumerState<AuditLogListPage> createState() => _AuditLogListPageState();
}

class _AuditLogListPageState extends ConsumerState<AuditLogListPage> {
  final _searchController = TextEditingController();
  final _actionController = TextEditingController();
  final _entityTypeController = TextEditingController();
  String? _hoaId;
  AuditLogFilters _filters = const AuditLogFilters();

  @override
  void dispose() {
    _searchController.dispose();
    _actionController.dispose();
    _entityTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(auditLogListProvider(_filters));
    final hoaOptions = ref.watch(auditHoaOptionsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audit Logs',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review privileged activity, tenant operations, role changes, and HOA-scoped events.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh audit logs',
                onPressed: () => ref.invalidate(auditLogListProvider(_filters)),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _AuditFilterBar(
            searchController: _searchController,
            actionController: _actionController,
            entityTypeController: _entityTypeController,
            hoaId: _hoaId,
            hoaOptions: hoaOptions,
            onHoaChanged: (value) => setState(() => _hoaId = value),
            onApply: _applyFilters,
            onReset: _resetFilters,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: logs.when(
              data: (items) => _AuditLogResults(
                items: items,
                filters: _filters,
                onSelected: (entry) => _showAuditDetail(context, entry),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load audit logs: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _filters = AuditLogFilters(
        search: _emptyToNull(_searchController.text),
        action: _emptyToNull(_actionController.text),
        entityType: _emptyToNull(_entityTypeController.text),
        hoaId: _hoaId,
      );
    });
  }

  void _resetFilters() {
    _searchController.clear();
    _actionController.clear();
    _entityTypeController.clear();
    setState(() {
      _hoaId = null;
      _filters = const AuditLogFilters();
    });
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _showAuditDetail(BuildContext context, AuditLogEntry entry) {
    return showDialog<void>(
      context: context,
      builder: (_) => _AuditLogDetailDialog(entry: entry),
    );
  }
}

class _AuditFilterBar extends StatelessWidget {
  const _AuditFilterBar({
    required this.searchController,
    required this.actionController,
    required this.entityTypeController,
    required this.hoaId,
    required this.hoaOptions,
    required this.onHoaChanged,
    required this.onApply,
    required this.onReset,
  });

  final TextEditingController searchController;
  final TextEditingController actionController;
  final TextEditingController entityTypeController;
  final String? hoaId;
  final AsyncValue<List<AuditHoaOption>> hoaOptions;
  final ValueChanged<String?> onHoaChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final singleColumn = availableWidth < 680;
            final twoColumn = availableWidth >= 680 && availableWidth < 1100;
            final fieldWidth = singleColumn
                ? availableWidth
                : twoColumn
                    ? (availableWidth - 12) / 2
                    : null;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: fieldWidth ?? 280,
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search audit logs',
                      hintText: 'Actor, entity, action, IP',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onApply(),
                  ),
                ),
                SizedBox(
                  width: fieldWidth ?? 180,
                  child: TextField(
                    controller: actionController,
                    decoration: const InputDecoration(
                      labelText: 'Action',
                      hintText: 'created, updated...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onApply(),
                  ),
                ),
                SizedBox(
                  width: fieldWidth ?? 180,
                  child: TextField(
                    controller: entityTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Entity Type',
                      hintText: 'tenant, ticket...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onApply(),
                  ),
                ),
                SizedBox(
                  width: fieldWidth ?? 240,
                  child: hoaOptions.when(
                    data: (items) => DropdownButtonFormField<String?>(
                      value: hoaId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'HOA',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'All HOA communities',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...items.map(
                          (hoa) => DropdownMenuItem<String?>(
                            value: hoa.id,
                            child: Text(
                              hoa.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: onHoaChanged,
                    ),
                    loading: () => const TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'HOA',
                        hintText: 'Loading...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    error: (_, __) => const TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'HOA',
                        hintText: 'Unable to load HOA list',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: singleColumn ? availableWidth : null,
                  child: FilledButton.icon(
                    onPressed: onApply,
                    icon: const Icon(Icons.filter_alt_outlined),
                    label: const Text('Apply'),
                  ),
                ),
                SizedBox(
                  width: singleColumn ? availableWidth : null,
                  child: TextButton(
                    onPressed: onReset,
                    child: const Text('Reset'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AuditLogResults extends StatelessWidget {
  const _AuditLogResults({
    required this.items,
    required this.filters,
    required this.onSelected,
  });

  final List<AuditLogEntry> items;
  final AuditLogFilters filters;
  final ValueChanged<AuditLogEntry> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          filters.hasFilters
              ? 'No audit logs match these filters.'
              : 'No audit logs found.',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        return Card(
          margin: EdgeInsets.zero,
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = items[index];
              if (compact) {
                return _CompactAuditTile(entry: entry, onTap: () => onSelected(entry));
              }
              return _AuditTile(entry: entry, onTap: () => onSelected(entry));
            },
          ),
        );
      },
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry, required this.onTap});

  final AuditLogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(_iconForEntity(entry.entityType)),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: _AuditTextColumn(
                title: _titleCase(entry.action),
                subtitle: entry.createdAt.toLocal().toString(),
              ),
            ),
            Expanded(
              flex: 3,
              child: _AuditTextColumn(
                title: entry.entityType,
                subtitle: entry.entityId,
              ),
            ),
            Expanded(
              flex: 3,
              child: _AuditTextColumn(
                title: entry.actorLabel,
                subtitle: entry.hoaLabel,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _CompactAuditTile extends StatelessWidget {
  const _CompactAuditTile({required this.entry, required this.onTap});

  final AuditLogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(child: Icon(_iconForEntity(entry.entityType))),
      title: Text('${_titleCase(entry.action)} · ${entry.entityType}'),
      subtitle: Text(
        '${entry.actorLabel}\n${entry.hoaLabel}\n${entry.createdAt.toLocal()}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _AuditTextColumn extends StatelessWidget {
  const _AuditTextColumn({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _AuditLogDetailDialog extends StatelessWidget {
  const _AuditLogDetailDialog({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${_titleCase(entry.action)} Audit Event'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow(label: 'Created', value: entry.createdAt.toLocal().toString()),
              _DetailRow(label: 'Actor', value: entry.actorLabel),
              _DetailRow(label: 'HOA', value: entry.hoaLabel),
              _DetailRow(label: 'Action', value: entry.action),
              _DetailRow(label: 'Entity Type', value: entry.entityType),
              _DetailRow(label: 'Entity ID', value: entry.entityId),
              _DetailRow(label: 'IP Address', value: entry.ip ?? 'Not captured'),
              _DetailRow(label: 'User Agent', value: entry.userAgent ?? 'Not captured'),
              const SizedBox(height: 18),
              _JsonPanel(title: 'Before', value: entry.beforeJson),
              const SizedBox(height: 12),
              _JsonPanel(title: 'After', value: entry.afterJson),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _JsonPanel extends StatelessWidget {
  const _JsonPanel({required this.title, required this.value});

  final String title;
  final Map<String, dynamic>? value;

  @override
  Widget build(BuildContext context) {
    final formatted = value == null
        ? 'No data captured.'
        : const JsonEncoder.withIndent('  ').convert(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 260),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.45),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              formatted,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
      ],
    );
  }
}

IconData _iconForEntity(String entityType) {
  final normalized = entityType.toLowerCase();
  if (normalized.contains('tenant')) return Icons.business_center_outlined;
  if (normalized.contains('user') || normalized.contains('role')) return Icons.manage_accounts_outlined;
  if (normalized.contains('ticket')) return Icons.confirmation_number_outlined;
  if (normalized.contains('document')) return Icons.description_outlined;
  if (normalized.contains('announcement')) return Icons.campaign_outlined;
  if (normalized.contains('schedule')) return Icons.event_repeat_outlined;
  if (normalized.contains('hoa')) return Icons.domain_outlined;
  return Icons.fact_check_outlined;
}

String _titleCase(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map(
        (word) => word.length == 1
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
