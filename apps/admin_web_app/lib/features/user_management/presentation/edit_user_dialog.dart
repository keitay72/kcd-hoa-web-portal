import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/admin_user.dart';
import '../domain/user_management_inputs.dart';
import 'user_form_fields.dart';
import 'user_management_providers.dart';

class EditUserDialog extends ConsumerStatefulWidget {
  const EditUserDialog({required this.user, super.key});

  final AdminUser user;

  @override
  ConsumerState<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends ConsumerState<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late String _status;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    final nameParts = splitName(widget.user.fullName);
    _firstNameController = TextEditingController(text: nameParts.firstName);
    _middleNameController = TextEditingController(text: nameParts.middleName ?? '');
    _lastNameController = TextEditingController(text: nameParts.lastName);
    _phoneController = TextEditingController(text: formatPhoneForDisplay(widget.user.phone));
    _status = widget.user.status;

    for (final controller in [
      _firstNameController,
      _middleNameController,
      _lastNameController,
      _phoneController,
    ]) {
      controller.addListener(_refreshFormState);
    }
    _isFormValid = _hasValidFieldValues();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commandState = ref.watch(userCommandProvider);

    return AlertDialog(
      title: const Text('Edit User'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: widget.user.email,
                  enabled: false,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                _NameField(
                  controller: _firstNameController,
                  label: 'First Name',
                  required: true,
                ),
                const SizedBox(height: 16),
                _NameField(
                  controller: _middleNameController,
                  label: 'Middle Name',
                  required: false,
                ),
                const SizedBox(height: 16),
                _NameField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  required: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    hintText: '(816) 406-4118',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [UsPhoneTextInputFormatter()],
                  validator: UserFormValidators.phone,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'disabled', child: Text('Disabled')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                    _refreshFormState();
                  },
                ),
                if (commandState.hasError) ...[
                  const SizedBox(height: 12),
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
        FilledButton(
          onPressed: commandState.isLoading || !_isFormValid ? null : _submit,
          child: const Text('Save User'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    final name = NameParts(
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
    );

    final result = await ref.read(userCommandProvider.notifier).updateUser(
          id: widget.user.id,
          input: UpdateAdminUserInput(
            fullName: name.fullName,
            phone: UserFormValidators.phoneDigits(_phoneController.text),
            status: _status,
          ),
        );

    if (result != null && mounted) Navigator.of(context).pop(result);
  }

  bool _hasValidFieldValues() {
    return UserFormValidators.requiredName(_firstNameController.text, 'First Name') == null &&
        UserFormValidators.optionalName(_middleNameController.text, 'Middle Name') == null &&
        UserFormValidators.requiredName(_lastNameController.text, 'Last Name') == null &&
        UserFormValidators.phone(_phoneController.text) == null;
  }

  void _refreshFormState() {
    final isValid = _hasValidFieldValues();
    if (isValid != _isFormValid && mounted) {
      setState(() => _isFormValid = isValid);
    }
  }
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.label,
    required this.required,
  });

  final TextEditingController controller;
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.text.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => required
                  ? UserFormValidators.requiredName(value, label)
                  : UserFormValidators.optionalName(value, label),
            ),
            CapitalizationWarning(
              show: UserFormValidators.optionalName(value, label) == null &&
                  UserFormValidators.shouldWarnCapitalization(value),
            ),
          ],
        );
      },
    );
  }
}
