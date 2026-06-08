import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../address_registry/domain/hoa_address.dart';
import '../../address_registry/presentation/address_providers.dart';
import '../../hoa_management/domain/hoa_community.dart';
import '../../hoa_management/presentation/hoa_providers.dart';
import '../data/service_schedule_repository.dart';
import '../domain/service_schedule.dart';
import '../domain/service_schedule_inputs.dart';
import 'service_schedule_providers.dart';

class ServiceScheduleFormDialog extends ConsumerStatefulWidget {
  const ServiceScheduleFormDialog({
    this.initialValue,
    super.key,
  });

  final ServiceSchedule? initialValue;

  @override
  ConsumerState<ServiceScheduleFormDialog> createState() =>
      _ServiceScheduleFormDialogState();
}

class _ServiceScheduleFormDialogState extends ConsumerState<ServiceScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _scheduleRuleController;
  late final TextEditingController _routeNameController;
  late final TextEditingController _notesController;

  String? _hoaId;
  String? _addressId;
  ServiceScheduleScope _scope = ServiceScheduleScope.hoaWide;
  late ServiceScheduleType _serviceType;
  late DateTime _effectiveDate;
  DateTime? _endDate;
  late ServiceScheduleStatus _status;

  bool get _isEditing => widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _hoaId = initial?.hoaId;
    _addressId = initial?.addressId;
    _scope = initial?.isOverride == true
        ? ServiceScheduleScope.addressOverride
        : ServiceScheduleScope.hoaWide;
    _serviceType = initial?.serviceType ?? ServiceScheduleType.trash;
    _effectiveDate = initial?.effectiveDate ?? DateTime.now();
    _endDate = initial?.endDate;
    _status = initial?.status ?? ServiceScheduleStatus.active;
    _scheduleRuleController = TextEditingController(text: initial?.scheduleRule ?? '');
    _routeNameController = TextEditingController(text: initial?.routeName ?? '');
    _notesController = TextEditingController(text: initial?.notes ?? '');
  }

  @override
  void dispose() {
    _scheduleRuleController.dispose();
    _routeNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoas = ref.watch(hoaListProvider);
    final addresses = _hoaId == null
        ? const AsyncValue<List<HoaAddress>>.data([])
        : ref.watch(addressListProvider(_hoaId));
    final commandState = ref.watch(serviceScheduleCommandProvider);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Service Schedule' : 'Create Service Schedule'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HOA schedules are the default source of truth. Address schedules should only be used for exceptions.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                hoas.when(
                  data: (items) => _HoaSelect(
                    hoas: items,
                    selectedHoaId: _hoaId,
                    onChanged: (value) {
                      setState(() {
                        _hoaId = value;
                        _addressId = null;
                      });
                    },
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Unable to load HOAs: $error'),
                ),
                const SizedBox(height: 16),
                SegmentedButton<ServiceScheduleScope>(
                  segments: ServiceScheduleScope.values
                      .map(
                        (scope) => ButtonSegment(
                          value: scope,
                          label: Text(scope.label),
                        ),
                      )
                      .toList(),
                  selected: {_scope},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _scope = selection.first;
                      if (_scope == ServiceScheduleScope.hoaWide) {
                        _addressId = null;
                      }
                    });
                  },
                ),
                if (_scope == ServiceScheduleScope.addressOverride) ...[
                  const SizedBox(height: 16),
                  addresses.when(
                    data: (items) => _AddressSelect(
                      addresses: items.where((address) => address.isActive).toList(),
                      selectedAddressId: _addressId,
                      onChanged: (value) => setState(() => _addressId = value),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text('Unable to load addresses: $error'),
                  ),
                ],
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    final typeField = DropdownButtonFormField<ServiceScheduleType>(
                      value: _serviceType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Service Type',
                        border: OutlineInputBorder(),
                      ),
                      items: ServiceScheduleType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _serviceType = value);
                        }
                      },
                    );
                    final statusField = DropdownButtonFormField<ServiceScheduleStatus>(
                      value: _status,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: ServiceScheduleStatus.values
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _status = value);
                        }
                      },
                    );

                    if (compact) {
                      return Column(
                        children: [
                          typeField,
                          const SizedBox(height: 12),
                          statusField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: typeField),
                        const SizedBox(width: 12),
                        Expanded(child: statusField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _scheduleRuleController,
                  decoration: const InputDecoration(
                    labelText: 'Schedule Rule',
                    helperText: 'Examples: Tuesday, Thursday, First Saturday',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    final effectiveField = _DateField(
                      label: 'Effective Date',
                      value: _effectiveDate,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _effectiveDate = value);
                        }
                      },
                    );
                    final endField = _DateField(
                      label: 'End Date',
                      value: _endDate,
                      allowClear: true,
                      onChanged: (value) => setState(() => _endDate = value),
                    );

                    if (compact) {
                      return Column(
                        children: [
                          effectiveField,
                          const SizedBox(height: 12),
                          endField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: effectiveField),
                        const SizedBox(width: 12),
                        Expanded(child: endField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _routeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Route Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Holiday Overrides / Notes',
                    helperText: 'Example: Thanksgiving week shifts one day later.',
                    border: OutlineInputBorder(),
                  ),
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
          onPressed: commandState.isLoading ? null : _submit,
          icon: commandState.isLoading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isEditing ? 'Save Changes' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final endDate = _endDate;
    if (!_formKey.currentState!.validate() || _hoaId == null) {
      return;
    }

    if (_scope == ServiceScheduleScope.addressOverride && _addressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an address for the override.')),
      );
      return;
    }

    if (endDate != null && endDate.isBefore(_dateOnly(_effectiveDate))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be on or after effective date.')),
      );
      return;
    }

    final input = ServiceScheduleInput(
      hoaId: _hoaId!,
      addressId: _scope == ServiceScheduleScope.addressOverride ? _addressId : null,
      serviceType: _serviceType,
      scheduleRule: _scheduleRuleController.text,
      effectiveDate: _effectiveDate,
      endDate: endDate,
      status: _status,
      routeName: _routeNameController.text,
      notes: _notesController.text,
    );

    final controller = ref.read(serviceScheduleCommandProvider.notifier);
    final result = _isEditing
        ? await controller.updateSchedule(
            id: widget.initialValue!.id,
            input: input,
          )
        : await controller.createSchedule(input);

    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }
}

class _HoaSelect extends StatelessWidget {
  const _HoaSelect({
    required this.hoas,
    required this.selectedHoaId,
    required this.onChanged,
  });

  final List<HoaCommunity> hoas;
  final String? selectedHoaId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedHoaId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'HOA Community',
        border: OutlineInputBorder(),
      ),
      items: hoas
          .map(
            (hoa) => DropdownMenuItem(
              value: hoa.id,
              child: Text(
                '${hoa.name} (${hoa.code})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Choose an HOA' : null,
    );
  }
}

class _AddressSelect extends StatelessWidget {
  const _AddressSelect({
    required this.addresses,
    required this.selectedAddressId,
    required this.onChanged,
  });

  final List<HoaAddress> addresses;
  final String? selectedAddressId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedAddressId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Override Address',
        border: OutlineInputBorder(),
      ),
      items: addresses
          .map(
            (address) => DropdownMenuItem(
              value: address.id,
              child: Text(address.singleLine, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (_) => addresses.isEmpty ? 'No active addresses found' : null,
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: () => _pickDate(context),
      child: Row(
        children: [
          const Icon(Icons.date_range_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  value == null ? 'Not set' : _formatDate(value!),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (allowClear && value != null)
            IconButton(
              tooltip: 'Clear $label',
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (date != null) {
      onChanged(DateTime(date.year, date.month, date.day));
    }
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
