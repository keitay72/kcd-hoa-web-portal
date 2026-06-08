// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/hoa_document.dart';
import 'document_providers.dart';
import 'edit_document_dialog.dart';

class DocumentDetailPage extends ConsumerWidget {
  const DocumentDetailPage({
    required this.documentId,
    super.key,
  });

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(documentDetailProvider(documentId));
    final commandState = ref.watch(documentCommandProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => context.go('/admin/documents'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Document Detail',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              document.maybeWhen(
                data: (item) => Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _downloadDocument(ref, item),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openEditDialog(context, ref, item),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                    FilledButton.icon(
                      onPressed: item.isArchived || commandState.isLoading
                          ? null
                          : () => _archiveDocument(context, ref, item),
                      icon: commandState.isLoading
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.archive_outlined),
                      label: const Text('Archive'),
                    ),
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          if (commandState.hasError) ...[
            const SizedBox(height: 12),
            Text(
              commandState.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Expanded(
            child: document.when(
              data: (item) => Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              item.mimeType == 'application/pdf'
                                  ? Icons.picture_as_pdf_outlined
                                  : Icons.image_outlined,
                              size: 44,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Chip(label: Text(item.statusLabel)),
                                      Chip(label: Text(item.visibilityLabel)),
                                      Chip(label: Text(item.category)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _DetailRow(label: 'ID', value: item.id),
                        _DetailRow(label: 'HOA', value: item.hoaLabel),
                        _DetailRow(label: 'HOA ID', value: item.hoaId),
                        _DetailRow(label: 'Category', value: item.category),
                        _DetailRow(label: 'Visibility Scope', value: item.visibilityLabel),
                        _DetailRow(label: 'Status', value: item.statusLabel),
                        _DetailRow(label: 'Storage Path', value: item.storagePath),
                        _DetailRow(label: 'MIME Type', value: item.mimeType),
                        _DetailRow(label: 'File Size', value: item.fileSizeLabel),
                        _DetailRow(label: 'Created By', value: item.createdBy ?? ''),
                        _DetailRow(
                          label: 'Created',
                          value: item.createdAt.toLocal().toString(),
                        ),
                        _DetailRow(
                          label: 'Updated',
                          value: item.updatedAt.toLocal().toString(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Unable to load document: $error'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    HoaDocument document,
  ) async {
    final result = await showDialog<Object?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditDocumentDialog(document: document),
    );

    if (result != null) {
      ref.invalidate(documentDetailProvider(document.id));
      ref.invalidate(documentListProvider);
    }
  }

  Future<void> _archiveDocument(
    BuildContext context,
    WidgetRef ref,
    HoaDocument document,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Document?'),
        content: Text(
          'Archive "${document.title}"? Residents will no longer see it as an active document.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(documentCommandProvider.notifier).archiveDocument(document.id);
  }

  Future<void> _downloadDocument(WidgetRef ref, HoaDocument document) async {
    final url = await ref.read(documentRepositoryProvider).createDownloadUrl(document);
    html.window.open(url, '_blank');
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value.isEmpty ? 'Not set' : value)),
        ],
      ),
    );
  }
}
