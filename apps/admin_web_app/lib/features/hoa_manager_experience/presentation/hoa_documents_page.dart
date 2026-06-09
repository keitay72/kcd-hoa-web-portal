// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../documents_cms/domain/hoa_document.dart';
import '../../documents_cms/presentation/document_providers.dart';
import '../../documents_cms/presentation/upload_document_dialog.dart';
import 'hoa_manager_providers.dart';
import 'hoa_scope_header.dart';

class HoaDocumentsPage extends ConsumerWidget {
  const HoaDocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(activeHoaScopeProvider);

    return scope.when(
      data: (item) {
        final hoaId = item?.hoaId;
        if (hoaId == null) return const Center(child: Text('No HOA scope assigned.'));
        final documents = ref.watch(documentListProvider(DocumentListFilter(
          hoaId: hoaId,
          status: HoaDocumentStatus.active.name,
        )));

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: HoaScopeHeader(
                      title: 'HOA Documents',
                      subtitle: 'Manage documents visible to your HOA community.',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openUploadDialog(context, ref),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload Document'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: documents.when(
                  data: (items) => _DocumentList(documents: items),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Unable to load documents: $error')),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Unable to load HOA scope: $error')),
    );
  }

  Future<void> _openUploadDialog(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UploadDocumentDialog(),
    );

    if (result != null) ref.invalidate(documentListProvider);
  }
}

class _DocumentList extends ConsumerWidget {
  const _DocumentList({required this.documents});

  final List<HoaDocument> documents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (documents.isEmpty) return const Center(child: Text('No active documents found.'));

    return Card(
      margin: EdgeInsets.zero,
      child: ListView.separated(
        itemCount: documents.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final document = documents[index];
          return ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(document.title),
            subtitle: Text('${document.category} - ${document.visibilityLabel} - ${document.fileSizeLabel}'),
            trailing: Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: 'Download',
                  onPressed: () => _download(ref, document),
                  icon: const Icon(Icons.download_outlined),
                ),
                IconButton(
                  tooltip: 'Details',
                  onPressed: () => context.go('/admin/documents/${document.id}'),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _download(WidgetRef ref, HoaDocument document) async {
    final url = await ref.read(documentRepositoryProvider).createDownloadUrl(document);
    html.window.open(url, '_blank');
  }
}
