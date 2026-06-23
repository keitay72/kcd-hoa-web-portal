// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../domain/customer_portal_home.dart';
import 'customer_portal_home_providers.dart';
import 'resident_portal_labels.dart';

final _customerPortalDocumentUrlProvider = FutureProvider.autoDispose
    .family<String, CustomerPortalDocument>((ref, document) {
  final storagePath = document.storagePath?.trim();
  if (storagePath == null || storagePath.isEmpty) {
    throw StateError('This document does not have a file attached.');
  }

  return ref
      .watch(supabaseClientProvider)
      .storage
      .from('hoa-documents')
      .createSignedUrl(storagePath, 60 * 10);
});

class CustomerDocumentViewPage extends ConsumerWidget {
  const CustomerDocumentViewPage({
    required this.tenantCode,
    required this.documentId,
    super.key,
  });

  final String tenantCode;
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portalTitle = customerPortalTitle(tenantCode);
    final home = ref.watch(customerPortalHomeProvider);

    return Title(
      title: portalTitle,
      color: Theme.of(context).colorScheme.primary,
      child: Scaffold(
        appBar: AppBar(
          title: Text(portalTitle),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => context.go('/portal/$tenantCode/home'),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: home.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _DocumentError(
            message: 'Unable to load document: $error',
            onBack: () => context.go('/portal/$tenantCode/home'),
          ),
          data: (snapshot) {
            final document = _findDocument(snapshot.documents, documentId);
            if (document == null) {
              return _DocumentError(
                message: 'This document is not available in your portal.',
                onBack: () => context.go('/portal/$tenantCode/home'),
              );
            }

            return _DocumentViewer(document: document);
          },
        ),
      ),
    );
  }

  CustomerPortalDocument? _findDocument(
    List<CustomerPortalDocument> documents,
    String id,
  ) {
    for (final document in documents) {
      if (document.id == id) return document;
    }
    return null;
  }
}

class _DocumentViewer extends ConsumerWidget {
  const _DocumentViewer({required this.document});

  final CustomerPortalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedUrl = ref.watch(_customerPortalDocumentUrlProvider(document));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labelize(document.category),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              signedUrl.maybeWhen(
                data: (url) => Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => html.window.open(url, '_blank'),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _download(url, document),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Download'),
                    ),
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: signedUrl.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _InlineDocumentError(
                message:
                    'We could not open this document. Please try again later.',
                detail: error.toString(),
              ),
              data: (url) {
                if (document.mimeType == 'application/pdf') {
                  return _PdfPreview(url: url, title: document.title);
                }

                return _InlineDocumentError(
                  message: 'Preview is not available for this file type.',
                  action: OutlinedButton.icon(
                    onPressed: () => html.window.open(url, '_blank'),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open document'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _download(String url, CustomerPortalDocument document) {
    final separator = url.contains('?') ? '&' : '?';
    final downloadUrl =
        '$url${separator}download=${Uri.encodeComponent(_fileName(document))}';
    html.AnchorElement(href: downloadUrl)
      ..download = _fileName(document)
      ..target = '_blank'
      ..click();
  }

  String _fileName(CustomerPortalDocument document) {
    final path = document.storagePath;
    if (path != null && path.trim().isNotEmpty) {
      final parts = path.split('/');
      final name = parts.isEmpty ? '' : parts.last.trim();
      if (name.isNotEmpty) return name;
    }

    final sanitized = document.title
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return sanitized.isEmpty ? 'document.pdf' : '$sanitized.pdf';
  }
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  static final Set<String> _registeredViewTypes = {};

  late String _viewType;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(covariant _PdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _registerView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }

  void _registerView() {
    _viewType = 'resident-document-preview-${widget.url.hashCode.abs()}';
    if (_registeredViewTypes.add(_viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
        return html.IFrameElement()
          ..src = widget.url
          ..title = widget.title
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%';
      });
    }
  }
}

class _InlineDocumentError extends StatelessWidget {
  const _InlineDocumentError({
    required this.message,
    this.detail,
    this.action,
  });

  final String message;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (detail != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 16),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentError extends StatelessWidget {
  const _DocumentError({
    required this.message,
    required this.onBack,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back to portal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _labelize(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
