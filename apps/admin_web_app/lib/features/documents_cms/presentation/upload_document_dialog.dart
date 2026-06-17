// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../hoa_management/domain/hoa_community.dart';
import '../../hoa_management/presentation/hoa_providers.dart';
import '../domain/hoa_document.dart';
import '../domain/hoa_document_inputs.dart';
import 'document_providers.dart';

class UploadDocumentDialog extends ConsumerStatefulWidget {
  const UploadDocumentDialog({
    this.initialHoaId,
    this.lockHoaSelection = false,
    super.key,
  });

  final String? initialHoaId;
  final bool lockHoaSelection;

  @override
  ConsumerState<UploadDocumentDialog> createState() => _UploadDocumentDialogState();
}

class _UploadDocumentDialogState extends ConsumerState<UploadDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController(text: 'General');

  late String? _hoaId;
  HoaDocumentVisibilityScope _visibilityScope = HoaDocumentVisibilityScope.resident;
  String? _fileName;
  String? _mimeType;
  Uint8List? _bytes;
  String? _fileError;

  @override
  void initState() {
    super.initState();
    _hoaId = widget.initialHoaId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoas = ref.watch(hoaListProvider);
    final commandState = ref.watch(documentCommandProvider);

    return AlertDialog(
      title: const Text('Upload Document'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                hoas.when(
                  data: (items) => _HoaSelect(
                    hoas: items,
                    selectedHoaId: _hoaId,
                    lockSelection: widget.lockHoaSelection,
                    onChanged: (value) => setState(() => _hoaId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Unable to load HOAs: $error'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    helperText: 'Examples: Rules, Trash Service, Maps, Notices',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<HoaDocumentVisibilityScope>(
                  value: _visibilityScope,
                  decoration: const InputDecoration(
                    labelText: 'Visibility Scope',
                    border: OutlineInputBorder(),
                  ),
                  items: HoaDocumentVisibilityScope.values
                      .map(
                        (scope) => DropdownMenuItem(
                          value: scope,
                          child: Text(_label(scope.name)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _visibilityScope = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(_fileName == null ? 'Choose PDF or Image' : 'Change File'),
                ),
                if (_fileName != null) ...[
                  const SizedBox(height: 8),
                  Text('Selected: $_fileName'),
                ],
                if (_fileError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _fileError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (commandState.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    commandState.error.toString(),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: commandState.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: commandState.isLoading ? null : _submit,
          icon: commandState.isLoading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_outlined),
          label: const Text('Upload'),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    final input = html.FileUploadInputElement()
      ..accept = 'application/pdf,image/*'
      ..multiple = false;

    input.click();
    await input.onChange.first;

    final files = input.files;
    if (files == null || files.isEmpty) {
      return;
    }

    final file = files.first;

    final mimeType = file.type.isEmpty ? _inferMimeType(file.name) : file.type;
    if (!_isAllowedFile(file.name, mimeType)) {
      setState(() {
        _fileName = null;
        _mimeType = null;
        _bytes = null;
        _fileError = 'Only PDF and image uploads are supported.';
      });
      return;
    }

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final result = reader.result;
    if (result is! ByteBuffer) {
      setState(() => _fileError = 'Unable to read the selected file.');
      return;
    }

    setState(() {
      _fileName = file.name;
      _mimeType = mimeType;
      _bytes = Uint8List.view(result);
      _fileError = null;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = _titleFromFileName(file.name);
      }
    });
  }

  Future<void> _submit() async {
    final bytes = _bytes;
    final fileName = _fileName;
    final mimeType = _mimeType;

    setState(() {
      _fileError = bytes == null ? 'Choose a PDF or image before uploading.' : null;
    });

    if (!_formKey.currentState!.validate() ||
        _hoaId == null ||
        bytes == null ||
        fileName == null ||
        mimeType == null) {
      return;
    }

    final document = await ref.read(documentCommandProvider.notifier).uploadDocument(
          HoaDocumentUploadInput(
            hoaId: _hoaId!,
            title: _titleController.text,
            category: _categoryController.text,
            visibilityScope: _visibilityScope,
            fileName: fileName,
            mimeType: mimeType,
            bytes: bytes,
          ),
        );

    if (document != null && mounted) {
      Navigator.of(context).pop(document);
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  bool _isAllowedFile(String fileName, String mimeType) {
    final lowerName = fileName.toLowerCase();
    return mimeType == 'application/pdf' ||
        mimeType.startsWith('image/') ||
        lowerName.endsWith('.pdf') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.webp');
  }

  String _inferMimeType(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.pdf')) return 'application/pdf';
    if (lowerName.endsWith('.png')) return 'image/png';
    if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerName.endsWith('.gif')) return 'image/gif';
    if (lowerName.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  String _titleFromFileName(String fileName) {
    final name = fileName.split('/').last.split('\\').last;
    final dotIndex = name.lastIndexOf('.');
    final withoutExtension = dotIndex > 0 ? name.substring(0, dotIndex) : name;
    return withoutExtension.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  }

  static String _label(String value) {
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _HoaSelect extends StatelessWidget {
  const _HoaSelect({
    required this.hoas,
    required this.selectedHoaId,
    required this.onChanged,
    this.lockSelection = false,
  });

  final List<HoaCommunity> hoas;
  final String? selectedHoaId;
  final ValueChanged<String?> onChanged;
  final bool lockSelection;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedHoaId,
      decoration: const InputDecoration(
        labelText: 'HOA Community',
        border: OutlineInputBorder(),
      ),
      items: hoas
          .map(
            (hoa) => DropdownMenuItem(
              value: hoa.id,
              child: Text('${hoa.name} (${hoa.code})'),
            ),
          )
          .toList(),
      onChanged: lockSelection ? null : onChanged,
      validator: (value) => value == null ? 'Choose an HOA' : null,
    );
  }
}
