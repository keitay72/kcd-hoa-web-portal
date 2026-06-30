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
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  HoaCommunityStatus _status = HoaCommunityStatus.active;
  CommunityType _communityType = CommunityType.hoa;

  bool get _isEditing => widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.initialValue;
    if (initialValue != null) {
      _nameController.text = initialValue.name;
      _cityController.text = initialValue.city ?? '';
      _stateController.text = initialValue.state ?? '';
      _status = initialValue.status;
      _communityType = initialValue.communityType;
    }
    _nameController.addListener(_refreshCodePreview);
    _cityController.addListener(_syncCityDisplayName);
    _stateController.addListener(_syncCityDisplayName);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshCodePreview);
    _cityController.removeListener(_syncCityDisplayName);
    _stateController.removeListener(_syncCityDisplayName);
    _nameController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(hoaFormControllerProvider);
    final codePreview = ref.watch(
      hoaCodePreviewProvider(
        HoaCodePreviewRequest(
          name: _nameController.text,
          communityType: _communityType,
          excludingHoaId: widget.initialValue?.id,
        ),
      ),
    );
    final fallbackCode = _nameController.text.trim().isEmpty
        ? ''
        : HoaCodeGenerator.baseCodeFromName(
            _nameController.text,
            communityType: _communityType,
          );
    final displayedCode = codePreview.maybeWhen(
      data: (value) => value,
      orElse: () => fallbackCode,
    );

    return AlertDialog(
      title: Text(
        widget.title ?? (_isEditing ? 'Edit Community' : 'Create Community'),
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<CommunityType>(
                segments: const [
                  ButtonSegment(
                    value: CommunityType.hoa,
                    icon: Icon(Icons.apartment_outlined),
                    label: Text('HOA'),
                  ),
                  ButtonSegment(
                    value: CommunityType.city,
                    icon: Icon(Icons.location_city_outlined),
                    label: Text('City'),
                  ),
                ],
                selected: {_communityType},
                onSelectionChanged: formState.isLoading
                    ? null
                    : (selection) {
                        setState(() {
                          _communityType = selection.first;
                          _syncCityDisplayName();
                        });
                      },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _communityType == CommunityType.city
                      ? 'Display Name'
                      : 'Community Name',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              if (_communityType == CommunityType.city) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                        ),
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'State',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: _validateState,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                key: ValueKey('hoa-code-$displayedCode'),
                initialValue: displayedCode,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Community Code',
                  helperText: codePreview.isLoading
                      ? 'Checking existing community codes...'
                      : 'Generated from community name. Duplicate codes get a numeric suffix.',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<HoaCommunityStatus>(
                initialValue: _status,
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
          label: Text(_isEditing ? 'Save changes' : 'Create Community'),
        ),
      ],
    );
  }

  void _refreshCodePreview() {
    setState(() {});
  }

  void _syncCityDisplayName() {
    if (_communityType != CommunityType.city) return;
    final city = _cityController.text.trim();
    final state = _stateController.text.trim().toUpperCase();
    if (city.isEmpty && state.isEmpty) return;
    final displayName =
        [city, state].where((part) => part.isNotEmpty).join(', ');
    if (_nameController.text != displayName) {
      _nameController.text = displayName;
      _nameController.selection = TextSelection.collapsed(
        offset: _nameController.text.length,
      );
    } else {
      _refreshCodePreview();
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _validateState(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(value!.trim())) {
      return 'Use 2 letters';
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
      communityType: _communityType,
      city: _communityType == CommunityType.city
          ? _titleCase(_cityController.text.trim())
          : null,
      state: _communityType == CommunityType.city
          ? _stateController.text.trim().toUpperCase()
          : null,
      residentActivationCodesRequiredOverride: false,
    );

    final controller = ref.read(hoaFormControllerProvider.notifier);
    final result = _isEditing
        ? await controller.updateHoa(id: widget.initialValue!.id, input: input)
        : await controller.create(input, tenantId: widget.tenantId);

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  String _titleCase(String value) {
    return value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
      if (part.length == 1) return part.toUpperCase();
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join(' ');
  }
}
