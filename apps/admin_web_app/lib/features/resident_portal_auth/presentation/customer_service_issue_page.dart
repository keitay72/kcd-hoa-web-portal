// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

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
  String? _fileName;
  String? _mimeType;
  Uint8List? _bytes;
  String? _fileError;

  static const _maxImageBytes = 10 * 1024 * 1024;

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
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: state.isLoading ? null : _pickFile,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_fileName == null ? 'Add photo' : 'Change photo'),
              ),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.image_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _fileName!,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: state.isLoading ? null : _removeFile,
                    child: const Text('Remove'),
                  ),
                ],
              ),
            ],
            if (_fileError != null) ...[
              const SizedBox(height: 8),
              Text(
                _fileError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
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
    final ticketId = await ref
        .read(customerServiceIssueControllerProvider.notifier)
        .submit(
          CustomerServiceIssueInput(
            type: _type,
            subject: _subjectController.text,
            description: _descriptionController.text,
            attachment: _bytes == null || _fileName == null || _mimeType == null
                ? null
                : CustomerServiceIssueAttachmentInput(
                    fileName: _fileName!,
                    mimeType: _mimeType!,
                    bytes: _bytes!,
                  ),
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

  Future<void> _pickFile() async {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = false;

    input.click();
    await input.onChange.first;

    final files = input.files;
    if (files == null || files.isEmpty) return;

    final file = files.first;
    final mimeType = file.type.isEmpty ? _inferMimeType(file.name) : file.type;
    if (!mimeType.startsWith('image/')) {
      setState(() {
        _fileName = null;
        _mimeType = null;
        _bytes = null;
        _fileError = 'Only image uploads are supported for issue photos.';
      });
      return;
    }

    if (file.size > _maxImageBytes) {
      setState(() {
        _fileName = null;
        _mimeType = null;
        _bytes = null;
        _fileError = 'Photos must be 10 MB or smaller.';
      });
      return;
    }

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final bytes = await _bytesFromReaderResult(reader.result, file);
    if (bytes == null) {
      setState(() => _fileError = 'Unable to read the selected image.');
      return;
    }

    setState(() {
      _fileName = file.name;
      _mimeType = mimeType;
      _bytes = bytes;
      _fileError = null;
    });
  }

  Future<Uint8List?> _bytesFromReaderResult(
    Object? result,
    html.File file,
  ) async {
    if (result is ByteBuffer) {
      return Uint8List.view(result);
    }
    if (result is Uint8List) {
      return result;
    }
    if (result is List<int>) {
      return Uint8List.fromList(result);
    }

    final fallbackReader = html.FileReader();
    fallbackReader.readAsDataUrl(file);
    await fallbackReader.onLoad.first;

    final dataUrl = fallbackReader.result;
    if (dataUrl is! String) return null;
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex < 0) return null;

    return Uint8List.fromList(
      html.window.atob(dataUrl.substring(commaIndex + 1)).codeUnits,
    );
  }

  void _removeFile() {
    setState(() {
      _fileName = null;
      _mimeType = null;
      _bytes = null;
      _fileError = null;
    });
  }

  String _inferMimeType(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.gif')) return 'image/gif';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  String _errorText(Object? error) {
    final message =
        error?.toString().replaceFirst('Bad state: ', '').trim() ?? '';
    if (message.isEmpty) return 'Unable to submit service issue.';
    return message;
  }
}
