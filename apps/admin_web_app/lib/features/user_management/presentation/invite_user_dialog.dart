import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/role_catalog.dart';
import '../domain/user_management_inputs.dart';
import 'user_form_fields.dart';
import 'user_management_providers.dart';

class InviteUserDialog extends ConsumerStatefulWidget {
  const InviteUserDialog({super.key});

  @override
  ConsumerState<InviteUserDialog> createState() => _InviteUserDialogState();
}

class _InviteUserDialogState extends ConsumerState<InviteUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _category = 'platform';
  String? _roleCode;
  String? _tenantId;
  String? _hoaId;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _emailController,
      _firstNameController,
      _middleNameController,
      _lastNameController,
      _phoneController,
    ]) {
      controller.addListener(_refreshFormState);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(roleCatalogProvider);
    final tenants = ref.watch(platformTenantOptionsProvider);
    final hoas = ref.watch(hoaScopeOptionsProvider);
    final commandState = ref.watch(userCommandProvider);
    final canSubmit = _hasValidFieldValues() && _hasRequiredSelections();

    return AlertDialog(
      title: const Text('Invite User'),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: UserFormValidators.email,
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
                    hintText: '(913) 555-1234',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [UsPhoneTextInputFormatter()],
                  validator: UserFormValidators.phone,
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'platform', label: Text('Tenant Staff')),
                    ButtonSegment(value: 'hoa', label: Text('HOA User')),
                  ],
                  selected: {_category},
                  onSelectionChanged: (value) {
                    setState(() {
                      _category = value.first;
                      _roleCode = null;
                      _tenantId = null;
                      _hoaId = null;
                    });
                    _refreshFormState();
                  },
                ),
                const SizedBox(height: 16),
                roles.when(
                  data: (items) => _RoleSelect(
                    roles: _category == 'platform'
                        ? items.where((role) => role.isPlatformRole).toList()
                        : items.where((role) => role.isHoaRole).toList(),
                    value: _roleCode,
                    onChanged: (value) {
                      setState(() => _roleCode = value);
                      _refreshFormState();
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Unable to load roles: $error'),
                ),
                const SizedBox(height: 16),
                if (_category == 'platform')
                  tenants.when(
                    data: (items) => _TenantSelect(
                      tenants: items,
                      value: _tenantId ?? _primaryTenantId(items),
                      onChanged: (value) {
                        setState(() => _tenantId = value);
                        _refreshFormState();
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Unable to load tenants: $error'),
                  )
                else
                  hoas.when(
                    data: (items) => _HoaSelect(
                      hoas: items,
                      value: _hoaId,
                      onChanged: (value) {
                        setState(() => _hoaId = value);
                        _refreshFormState();
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Unable to load HOAs: $error'),
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
      ),
      actions: [
        TextButton(
          onPressed: commandState.isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: commandState.isLoading || !canSubmit ? null : _submit,
          icon: const Icon(Icons.mail_outline),
          label: const Text('Invite User'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final roleCode = _roleCode;
    final tenantId = _tenantId ?? _primaryTenantId(ref.read(platformTenantOptionsProvider).valueOrNull ?? []);
    if (!_validateForm() || roleCode == null) return;
    if (_category == 'platform' && tenantId == null) return;
    if (_category == 'hoa' && _hoaId == null) return;

    final middleName = _middleNameController.text.trim();

    final didInvite = await ref.read(userCommandProvider.notifier).inviteUser(
          InviteAdminUserInput(
            email: _emailController.text.trim(),
            firstName: _firstNameController.text.trim(),
            middleName: middleName.isEmpty ? null : middleName,
            lastName: _lastNameController.text.trim(),
            phone: UserFormValidators.phoneDigits(_phoneController.text),
            roleCode: roleCode,
            tenantId: _category == 'platform' ? tenantId : null,
            hoaId: _category == 'hoa' ? _hoaId : null,
          ),
        );

    if (didInvite && mounted) Navigator.of(context).pop(true);
  }

  String? _primaryTenantId(List<PlatformTenantOption> tenants) {
    if (tenants.isEmpty) return null;
    return tenants.firstWhere((tenant) => tenant.isPrimary, orElse: () => tenants.first).id;
  }

  bool _validateForm() {
    return _formKey.currentState?.validate() == true && _hasRequiredSelections();
  }

  bool _hasRequiredSelections() {
    final tenantId = _tenantId ?? _primaryTenantId(ref.read(platformTenantOptionsProvider).valueOrNull ?? []);
    return _roleCode != null && (_category == 'platform' ? tenantId != null : _hoaId != null);
  }

  bool _hasValidFieldValues() {
    return UserFormValidators.email(_emailController.text) == null &&
        UserFormValidators.requiredName(_firstNameController.text, 'First Name') == null &&
        UserFormValidators.optionalName(_middleNameController.text, 'Middle Name') == null &&
        UserFormValidators.requiredName(_lastNameController.text, 'Last Name') == null &&
        UserFormValidators.phone(_phoneController.text) == null;
  }

  void _refreshFormState() {
    final isValid = _hasValidFieldValues() && _hasRequiredSelections();
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

class _RoleSelect extends StatelessWidget {
  const _RoleSelect({required this.roles, required this.value, required this.onChanged});

  final List<RoleCatalogEntry> roles;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
      items: roles.map((role) => DropdownMenuItem(value: role.code, child: Text(role.name))).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Select a role.' : null,
    );
  }
}

class _TenantSelect extends StatelessWidget {
  const _TenantSelect({required this.tenants, required this.value, required this.onChanged});

  final List<PlatformTenantOption> tenants;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Platform Tenant', border: OutlineInputBorder()),
      items: tenants.map((tenant) => DropdownMenuItem(value: tenant.id, child: Text(tenant.name))).toList(),
      onChanged: onChanged,
    );
  }
}

class _HoaSelect extends StatelessWidget {
  const _HoaSelect({required this.hoas, required this.value, required this.onChanged});

  final List<HoaScopeOption> hoas;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'HOA Scope', border: OutlineInputBorder()),
      items: hoas.map((hoa) => DropdownMenuItem(value: hoa.id, child: Text(hoa.label))).toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Select an HOA.' : null,
    );
  }
}
