import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/rbac/admin_access.dart';
import '../../../core/rbac/admin_context.dart';
import '../domain/role_catalog.dart';
import '../domain/user_management_inputs.dart';
import 'user_form_fields.dart';
import 'user_management_providers.dart';

class InviteUserDialog extends ConsumerStatefulWidget {
  const InviteUserDialog({
    this.title = 'Invite User',
    this.initialCategory,
    this.initialRoleCode,
    this.initialTenantId,
    this.initialHoaId,
    this.allowedRoleCodes,
    this.lockScope = false,
    super.key,
  });

  final String title;
  final String? initialCategory;
  final String? initialRoleCode;
  final String? initialTenantId;
  final String? initialHoaId;
  final Set<String>? allowedRoleCodes;
  final bool lockScope;

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

  late String _category;
  String? _roleCode;
  String? _tenantId;
  String? _hoaId;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _category = _initialCategory();
    _roleCode = widget.initialRoleCode;
    _tenantId = widget.initialTenantId;
    _hoaId = widget.initialHoaId;
    final allowedRoleCodes = widget.allowedRoleCodes;
    if (allowedRoleCodes != null && allowedRoleCodes.length == 1) {
      _roleCode = allowedRoleCodes.first;
    }
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

  String _initialCategory() {
    final category = widget.initialCategory;
    if (category == 'hoa') return 'community';
    if (category == 'platform' && widget.initialTenantId != null) {
      return 'tenant';
    }
    return category ?? 'platform';
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
    final access = ref.watch(activeAdminAccessProvider).valueOrNull;
    final includeCommunityCategory = hoas.maybeWhen(
      data: (items) => items.isNotEmpty,
      orElse: () => true,
    );
    final availableCategories = _availableCategories(
      access,
      includeCommunity: includeCommunityCategory,
    );
    final selectedCategory = availableCategories.contains(_category)
        ? _category
        : availableCategories.first;
    final shouldChooseTenant =
        selectedCategory == 'tenant' && access?.isPlatformOperator == true;
    if (!availableCategories.contains(_category) &&
        availableCategories.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _category = availableCategories.first;
          _roleCode = null;
          _tenantId = null;
          _hoaId = null;
        });
        _refreshFormState();
      });
    }
    final canSubmit = _hasValidFieldValues() && _hasRequiredSelections(access);

    return AlertDialog(
      title: Text(widget.title),
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
                if (!widget.lockScope && availableCategories.length > 1) ...[
                  SegmentedButton<String>(
                    segments: availableCategories
                        .map(
                          (category) => ButtonSegment(
                            value: category,
                            label: Text(_categoryLabel(category)),
                          ),
                        )
                        .toList(),
                    selected: {selectedCategory},
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
                ],
                roles.when(
                  data: (items) {
                    final availableRoles = switch (selectedCategory) {
                      'platform' => items.where((role) =>
                          role.canBeInvitedAsPlatformStaff &&
                          _canInvitePlatformRole(role.code, access)),
                      'tenant' => items.where((role) =>
                          role.canBeInvitedAsTenantStaff &&
                          _canInviteTenantRole(role.code, access)),
                      _ => items
                          .where((role) => role.canBeInvitedAsCommunityContact),
                    }
                        .where((role) =>
                            widget.allowedRoleCodes == null ||
                            widget.allowedRoleCodes!.contains(role.code))
                        .toList()
                      ..sort(_compareRolePermission);

                    final selectedRoleCode =
                        availableRoles.any((role) => role.code == _roleCode)
                            ? _roleCode
                            : null;

                    if (availableRoles.length == 1 &&
                        _roleCode != availableRoles.first.code) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _roleCode = availableRoles.first.code);
                        _refreshFormState();
                      });
                    } else if (_roleCode != null && selectedRoleCode == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _roleCode = null);
                        _refreshFormState();
                      });
                    }

                    if (availableRoles.isEmpty) {
                      return const Text(
                        'No roles are available for your current access level.',
                      );
                    }

                    if (availableRoles.length == 1) {
                      return _LockedRoleField(
                        role: availableRoles.first,
                        label: _roleLabel(availableRoles.first),
                      );
                    }

                    return _RoleSelect(
                      roles: availableRoles,
                      value: selectedRoleCode,
                      labelForRole: _roleLabel,
                      onChanged: (value) {
                        setState(() => _roleCode = value);
                        _refreshFormState();
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Unable to load roles: $error'),
                ),
                const SizedBox(height: 16),
                if (shouldChooseTenant)
                  tenants.when(
                    data: (items) {
                      final tenantId = _tenantId ?? _primaryTenantId(items);
                      final selectedTenantId =
                          items.any((tenant) => tenant.id == tenantId)
                              ? tenantId
                              : null;
                      return _TenantSelect(
                        tenants: items,
                        value: selectedTenantId,
                        onChanged: widget.lockScope
                            ? null
                            : (value) {
                                setState(() => _tenantId = value);
                                _refreshFormState();
                              },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Unable to load tenants: $error'),
                  )
                else if (selectedCategory == 'community' && !widget.lockScope)
                  hoas.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return const Text(
                          'No communities are available for this tenant.',
                        );
                      }
                      final selectedHoaId =
                          items.any((hoa) => hoa.id == _hoaId) ? _hoaId : null;
                      return _HoaSelect(
                        hoas: items,
                        value: selectedHoaId,
                        onChanged: (value) {
                          setState(() => _hoaId = value);
                          _refreshFormState();
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) =>
                        Text('Unable to load communities: $error'),
                  ),
                if (commandState.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    commandState.error.toString(),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              commandState.isLoading ? null : () => Navigator.of(context).pop(),
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

  bool _canInvitePlatformRole(String roleCode, AdminAccess? access) {
    if (roleCode == 'platform_owner') return false;
    if (access?.isPlatformOwner == true) return true;
    if (access?.isPlatformAdmin == true) {
      return const {'platform_support', 'platform_sales'}.contains(roleCode);
    }
    return false;
  }

  bool _canInviteTenantRole(String roleCode, AdminAccess? access) {
    if (access?.isPlatformOperator == true) return true;
    if (access == null || !access.isTenantStaff) return false;

    if (access.hasAnyRoleCode({'tenant_owner', 'tenant_admin'})) {
      return const {
        'tenant_admin',
        'tenant_manager',
        'tenant_csr',
      }.contains(roleCode);
    }

    if (access.hasTenantRole('tenant_manager')) {
      return roleCode == 'tenant_csr';
    }

    return false;
  }

  List<String> _availableCategories(
    AdminAccess? access, {
    required bool includeCommunity,
  }) {
    if (access == null) return [_category];

    final isPlatformOperator = access.isPlatformOperator;
    final isTenantOperator = access.isTenantStaff;
    final isCommunityOperator = access.hoaRoles.isNotEmpty;

    if (widget.lockScope) return [_category];
    if (isPlatformOperator) {
      return [
        'platform',
        'tenant',
        if (includeCommunity) 'community',
      ];
    }
    if (isTenantOperator) {
      return [
        'tenant',
        if (includeCommunity) 'community',
      ];
    }
    if (isCommunityOperator) return const ['community'];
    return includeCommunity ? const ['community'] : const ['tenant'];
  }

  String _categoryLabel(String category) {
    return switch (category) {
      'platform' => 'Platform Staff',
      'tenant' => 'Tenant Staff',
      _ => 'Community Contact',
    };
  }

  int _compareRolePermission(RoleCatalogEntry a, RoleCatalogEntry b) {
    final rankCompare = _rolePermissionRank(b.code).compareTo(
      _rolePermissionRank(a.code),
    );
    if (rankCompare != 0) return rankCompare;
    return a.name.compareTo(b.name);
  }

  int _rolePermissionRank(String roleCode) {
    return switch (roleCode) {
      'platform_owner' => 1000,
      'platform_admin' => 900,
      'platform_support' => 800,
      'platform_sales' => 700,
      'tenant_owner' => 600,
      'tenant_admin' => 500,
      'tenant_manager' => 400,
      'tenant_csr' => 300,
      'community_admin' => 100,
      _ => 0,
    };
  }

  String _roleLabel(RoleCatalogEntry role) {
    return switch (role.code) {
      'tenant_owner' => 'Owner',
      'tenant_admin' => 'Admin',
      'tenant_manager' => 'Manager',
      'tenant_csr' => 'Customer Service',
      'community_admin' => 'Community Contact',
      _ => role.name,
    };
  }

  Future<void> _submit() async {
    final roleCode = _roleCode;
    final access = ref.read(activeAdminAccessProvider).valueOrNull;
    final tenantId = _effectiveTenantId(access);
    if (!_validateForm(access) || roleCode == null) return;
    if (_category == 'tenant' && tenantId == null) return;
    if (_category == 'community' && _hoaId == null) return;

    final middleName = _middleNameController.text.trim();

    final didInvite = await ref.read(userCommandProvider.notifier).inviteUser(
          InviteAdminUserInput(
            email: _emailController.text.trim(),
            firstName: _firstNameController.text.trim(),
            middleName: middleName.isEmpty ? null : middleName,
            lastName: _lastNameController.text.trim(),
            phone: UserFormValidators.phoneDigits(_phoneController.text),
            roleCode: roleCode,
            tenantId: _category == 'tenant' ? tenantId : null,
            hoaId: _category == 'community' ? _hoaId : null,
          ),
        );

    if (didInvite && mounted) Navigator.of(context).pop(true);
  }

  String? _primaryTenantId(List<PlatformTenantOption> tenants) {
    if (tenants.isEmpty) return null;
    return tenants
        .firstWhere((tenant) => tenant.isPrimary, orElse: () => tenants.first)
        .id;
  }

  bool _validateForm(AdminAccess? access) {
    return _formKey.currentState?.validate() == true &&
        _hasRequiredSelections(access);
  }

  bool _hasRequiredSelections(AdminAccess? access) {
    final tenantId = _effectiveTenantId(access);
    return _roleCode != null &&
        switch (_category) {
          'platform' => true,
          'tenant' => tenantId != null,
          _ => _hoaId != null,
        };
  }

  String? _effectiveTenantId(AdminAccess? access) {
    if (_tenantId != null) return _tenantId;
    if (access != null &&
        !access.isPlatformOperator &&
        access.tenantScopeIds.isNotEmpty) {
      return access.tenantScopeIds.first;
    }
    return _primaryTenantId(
      ref.read(platformTenantOptionsProvider).valueOrNull ?? [],
    );
  }

  bool _hasValidFieldValues() {
    return UserFormValidators.email(_emailController.text) == null &&
        UserFormValidators.requiredName(
                _firstNameController.text, 'First Name') ==
            null &&
        UserFormValidators.optionalName(
                _middleNameController.text, 'Middle Name') ==
            null &&
        UserFormValidators.requiredName(
                _lastNameController.text, 'Last Name') ==
            null &&
        UserFormValidators.phone(_phoneController.text) == null;
  }

  void _refreshFormState() {
    final access = ref.read(activeAdminAccessProvider).valueOrNull;
    final isValid = _hasValidFieldValues() && _hasRequiredSelections(access);
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
  const _RoleSelect({
    required this.roles,
    required this.value,
    required this.labelForRole,
    required this.onChanged,
  });

  final List<RoleCatalogEntry> roles;
  final String? value;
  final String Function(RoleCatalogEntry role) labelForRole;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
          labelText: 'Role', border: OutlineInputBorder()),
      items: roles
          .map((role) => DropdownMenuItem(
              value: role.code, child: Text(labelForRole(role))))
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Select a role.' : null,
    );
  }
}

class _LockedRoleField extends StatelessWidget {
  const _LockedRoleField({required this.role, this.label});

  final RoleCatalogEntry role;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: label ?? role.name,
      readOnly: true,
      decoration: const InputDecoration(
        labelText: 'Role',
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _TenantSelect extends StatelessWidget {
  const _TenantSelect(
      {required this.tenants, required this.value, required this.onChanged});

  final List<PlatformTenantOption> tenants;
  final String? value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
          labelText: 'Platform Tenant', border: OutlineInputBorder()),
      items: tenants
          .map((tenant) =>
              DropdownMenuItem(value: tenant.id, child: Text(tenant.name)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _HoaSelect extends StatelessWidget {
  const _HoaSelect(
      {required this.hoas, required this.value, required this.onChanged});

  final List<HoaScopeOption> hoas;
  final String? value;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
          labelText: 'Community', border: OutlineInputBorder()),
      items: hoas
          .map((hoa) => DropdownMenuItem(value: hoa.id, child: Text(hoa.label)))
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Select an HOA.' : null,
    );
  }
}
