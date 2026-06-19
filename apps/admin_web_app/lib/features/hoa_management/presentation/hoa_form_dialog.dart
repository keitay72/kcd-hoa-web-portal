import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/hoa_code_generator.dart';
import '../domain/hoa_community.dart';
import '../domain/hoa_community_input.dart';
import 'hoa_providers.dart';

class HoaFormDialog extends ConsumerStatefulWidget {
  const HoaFormDialog({
    this.initialValue,
    this.tenantId,
    this.title,
    super.key,
  });

  final HoaCommunity? initialValue;
  final String? tenantId;
  final String? title;

  @override
  ConsumerState<HoaFormDialog> createState() => _HoaFormDialogState();
}

class _HoaFormDialogState extends ConsumerState<HoaFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  HoaCommunityStatus _status = HoaCommunityStatus.active;
  bool? _residentActivationCodesRequiredOverride;

  bool get _isEditing => widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.initialValue;
    if (initialValue != null) {
      _nameController.text = initialValue.name;
      _status = initialValue.status;
      _residentActivationCodesRequiredOverride =
          initialValue.residentActivationCodesRequiredOverride;
    }
    _nameController.addListener(_refreshCodePreview);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshCodePreview);
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(hoaFormControllerProvider);
    final codePreview = ref.watch(
      hoaCodePreviewProvider(
        HoaCodePreviewRequest(
          name: _nameController.text,
          excludingHoaId: widget.initialValue?.id,
        ),
      ),
    );
    final fallbackCode = _nameController.text.trim().isEmpty
        ? ''
        : HoaCodeGenerator.baseCodeFromName(_nameController.text);
    final displayedCode = codePreview.maybeWhen(
      data: (value) => value,
      orElse: () => fallbackCode,
    );

    return AlertDialog(
      title: Text(widget.title ?? (_isEditing ? 'Edit HOA' : 'Create HOA')),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'HOA Name',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: ValueKey('hoa-code-$displayedCode'),
                initialValue: displayedCode,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'HOA Code',
                  helperText: codePreview.isLoading
                      ? 'Checking existing HOA codes...'
                      : 'Generated from HOA name. Duplicate codes get a numeric suffix.',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<HoaCommunityStatus>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: HoaCommunityStatus.active,
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: HoaCommunityStatus.inactive,
                    child: Text('Inactive'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<bool?>(
                value: _residentActivationCodesRequiredOverride,
                decoration: const InputDecoration(
                  labelText: 'Resident activation codes',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<bool?>(
                    value: null,
                    child: Text('Use tenant default'),
                  ),
                  DropdownMenuItem<bool?>(
                    value: true,
                    child: Text('Require codes'),
                  ),
                  DropdownMenuItem<bool?>(
                    value: false,
                    child: Text('Bypass codes'),
                  ),
                ],
                onChanged: (value) {
                  setState(
                    () => _residentActivationCodesRequiredOverride = value,
                  );
                },
              ),
              if (formState.hasError) ...[
                const SizedBox(height: 14),
                Text(
                  formState.error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              formState.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: formState.isLoading ? null : _submit,
          icon: formState.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isEditing ? 'Save changes' : 'Create HOA'),
        ),
      ],
    );
  }

  void _refreshCodePreview() {
    setState(() {});
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final input = HoaCommunityInput(
      name: _nameController.text.trim(),
      status: _status,
      residentActivationCodesRequiredOverride:
          _residentActivationCodesRequiredOverride,
    );

    final controller = ref.read(hoaFormControllerProvider.notifier);
    final result = _isEditing
        ? await controller.updateHoa(id: widget.initialValue!.id, input: input)
        : await controller.create(input, tenantId: widget.tenantId);

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }
}
