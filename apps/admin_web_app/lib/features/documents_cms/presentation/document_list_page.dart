// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../hoa_management/domain/hoa_community.dart';
import '../../hoa_management/presentation/hoa_providers.dart';
import '../domain/hoa_document.dart';
import 'document_providers.dart';
import 'upload_document_dialog.dart';

class DocumentListPage extends ConsumerStatefulWidget {
  const DocumentListPage({super.key});

  @override
  ConsumerState<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends ConsumerState<DocumentListPage> {
  final _categoryController = TextEditingController();
  String? _hoaId;
  String? _status = HoaDocumentStatus.active.name;

  DocumentListFilter get _filter => DocumentListFilter(
        hoaId: _hoaId,
        status: _status,
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
      );

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(documentListProvider(_filter));
    final hoas = ref.watch(hoaListProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Documents',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: _openUploadDialog,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Upload Document'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _DocumentFilterBar(
                hoas: hoas,
                hoaId: _hoaId,
                status: _status,
                categoryController: _categoryController,
                onHoaChanged: (value) => setState(() => _hoaId = value),
                onStatusChanged: (value) => setState(() => _status = value),
                onApply: () => setState(() {}),
                onReset: () {
                  setState(() {
                    _hoaId = null;
                    _status = HoaDocumentStatus.active.name;
                    _categoryController.clear();
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: documents.when(
              data: (items) => _DocumentTable(
                documents: items,
                onDownload: _downloadDocument,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load documents: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUploadDialog() async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UploadDocumentDialog(),
    );

    if (result != null) {
      ref.invalidate(documentListProvider);
    }
  }

  Future<void> _downloadDocument(HoaDocument document) async {
    final url = await ref.read(documentRepositoryProvider).createDownloadUrl(document);
    html.window.open(url, '_blank');
  }
}

String _documentLabel(String value) {
  return value[0].toUpperCase() + value.substring(1);
}

class _DocumentFilterBar extends StatelessWidget {
  const _DocumentFilterBar({
    required this.hoas,
    required this.hoaId,
    required this.status,
    required this.categoryController,
    required this.onHoaChanged,
    required this.onStatusChanged,
    required this.onApply,
    required this.onReset,
  });

  final AsyncValue<List<HoaCommunity>> hoas;
  final String? hoaId;
  final String? status;
  final TextEditingController categoryController;
  final ValueChanged<String?> onHoaChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  static const _spacing = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleRow = constraints.maxWidth >= 980;
        final hoaFilter = hoas.when(
          data: (items) => _HoaFilter(
            hoas: items,
            value: hoaId,
            onChanged: onHoaChanged,
          ),
          loading: () => const SizedBox(
            height: 56,
            child: Center(child: LinearProgressIndicator()),
          ),
          error: (error, _) => SizedBox(
            height: 56,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Unable to load HOAs: $error'),
            ),
          ),
        );
        final statusFilter = _StatusFilter(
          value: status,
          onChanged: onStatusChanged,
        );
        final categoryFilter = TextField(
          controller: categoryController,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => onApply(),
        );
        final actions = _FilterActions(
          onApply: onApply,
          onReset: onReset,
        );

        if (useSingleRow) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 4, child: hoaFilter),
              const SizedBox(width: _spacing),
              SizedBox(width: 180, child: statusFilter),
              const SizedBox(width: _spacing),
              Expanded(flex: 3, child: categoryFilter),
              const SizedBox(width: _spacing),
              actions,
            ],
          );
        }

        final fieldWidth = constraints.maxWidth < 520
            ? constraints.maxWidth
            : (constraints.maxWidth - _spacing) / 2;

        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: fieldWidth, child: hoaFilter),
            SizedBox(width: fieldWidth, child: statusFilter),
            SizedBox(width: fieldWidth, child: categoryFilter),
            actions,
          ],
        );
      },
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _allStatusesValue = '__all__';

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value ?? _allStatusesValue,
      isExpanded: true,
      icon: const Icon(Icons.expand_more),
      decoration: const InputDecoration(
        labelText: 'Status',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: _allStatusesValue,
          child: Text('All Statuses'),
        ),
        ...HoaDocumentStatus.values.map(
          (status) => DropdownMenuItem<String>(
            value: status.name,
            child: Text(_documentLabel(status.name)),
          ),
        ),
      ],
      selectedItemBuilder: (context) {
        return [
          const Text('All Statuses', overflow: TextOverflow.ellipsis),
          ...HoaDocumentStatus.values.map(
            (status) => Text(
              _documentLabel(status.name),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ];
      },
      onChanged: (nextValue) {
        onChanged(nextValue == _allStatusesValue ? null : nextValue);
      },
    );
  }
}

class _FilterActions extends StatelessWidget {
  const _FilterActions({
    required this.onApply,
    required this.onReset,
  });

  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: onApply,
            icon: const Icon(Icons.search),
            label: const Text('Apply'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onReset,
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _HoaFilter extends StatelessWidget {
  const _HoaFilter({
    required this.hoas,
    required this.value,
    required this.onChanged,
  });

  final List<HoaCommunity> hoas;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      value: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more),
      decoration: const InputDecoration(
        labelText: 'HOA',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('All HOAs'),
        ),
        ...hoas.map(
          (hoa) => DropdownMenuItem<String?>(
            value: hoa.id,
            child: Text(
              '${hoa.name} (${hoa.code})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      selectedItemBuilder: (context) {
        return [
          const Text('All HOAs', overflow: TextOverflow.ellipsis),
          ...hoas.map(
            (hoa) => Text(
              '${hoa.name} (${hoa.code})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ];
      },
      onChanged: onChanged,
    );
  }
}

class _DocumentTable extends StatelessWidget {
  const _DocumentTable({
    required this.documents,
    required this.onDownload,
  });

  final List<HoaDocument> documents;
  final ValueChanged<HoaDocument> onDownload;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const Center(child: Text('No documents found.'));
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: documents.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final document = documents[index];
          return ListTile(
            leading: Icon(
              document.mimeType == 'application/pdf'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined,
            ),
            title: Text(document.title),
            subtitle: Text(
              '${document.hoaLabel} - ${document.category} - ${document.visibilityLabel} - ${document.fileSizeLabel}',
            ),
            trailing: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(document.statusLabel)),
                IconButton(
                  tooltip: 'Download',
                  onPressed: () => onDownload(document),
                  icon: const Icon(Icons.download_outlined),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => context.go('/admin/documents/${document.id}'),
          );
        },
      ),
    );
  }
}
