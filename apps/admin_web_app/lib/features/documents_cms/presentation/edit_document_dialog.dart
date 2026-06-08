import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/hoa_document.dart';
import '../domain/hoa_document_inputs.dart';
import 'document_providers.dart';

class EditDocumentDialog extends ConsumerStatefulWidget {
  const EditDocumentDialog({
    required this.document,
    super.key,
  });

  final HoaDocument document;

  @override
  ConsumerState<EditDocumentDialog> createState() => _EditDocumentDialogState();
}

class _EditDocumentDialogState extends ConsumerState<EditDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late HoaDocumentVisibilityScope _visibilityScope;
  late HoaDocumentStatus _status;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.document.title);
    _categoryController = TextEditingController(text: widget.document.category);
    _visibilityScope = widget.document.visibilityScope;
    _status = widget.document.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commandState = ref.watch(documentCommandProvider);

    return AlertDialog(
      title: const Text('Edit Document'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              DropdownButtonFormField<HoaDocumentStatus>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: HoaDocumentStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(_label(status.name)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
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
              : const Icon(Icons.save_outlined),
          label: const Text('Save Changes'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final document = await ref.read(documentCommandProvider.notifier).updateDocument(
          id: widget.document.id,
          input: HoaDocumentEditInput(
            title: _titleController.text,
            category: _categoryController.text,
            visibilityScope: _visibilityScope,
            status: _status,
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

  static String _label(String value) {
    return value[0].toUpperCase() + value.substring(1);
  }
}
