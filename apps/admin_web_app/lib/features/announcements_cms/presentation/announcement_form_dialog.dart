import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../hoa_management/domain/hoa_community.dart';
import '../../hoa_management/presentation/hoa_providers.dart';
import '../domain/announcement.dart';
import '../domain/announcement_inputs.dart';
import 'announcement_providers.dart';

class AnnouncementFormDialog extends ConsumerStatefulWidget {
  const AnnouncementFormDialog({
    this.initialValue,
    super.key,
  });

  final Announcement? initialValue;

  @override
  ConsumerState<AnnouncementFormDialog> createState() => _AnnouncementFormDialogState();
}

class _AnnouncementFormDialogState extends ConsumerState<AnnouncementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  String? _hoaId;
  late AnnouncementStatus _status;
  late DateTime _publishAt;
  DateTime? _expireAt;

  bool get _isEditing => widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _bodyController = TextEditingController(text: initial?.body ?? '');
    _hoaId = initial?.hoaId;
    _status = initial?.status ?? AnnouncementStatus.draft;
    _publishAt = initial?.publishAt.toLocal() ?? DateTime.now();
    _expireAt = initial?.expireAt?.toLocal();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoas = ref.watch(hoaListProvider);
    final commandState = ref.watch(announcementCommandProvider);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Announcement' : 'Create Announcement'),
      content: SizedBox(
        width: 720,
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
                DropdownButtonFormField<AnnouncementStatus>(
                  value: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: AnnouncementStatus.values
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
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 620;
                    final publishField = _DateTimeField(
                      label: 'Publish Date',
                      value: _publishAt,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _publishAt = value);
                        }
                      },
                    );
                    final expireField = _DateTimeField(
                      label: 'Expiration Date',
                      value: _expireAt,
                      allowClear: true,
                      onChanged: (value) => setState(() => _expireAt = value),
                    );

                    if (compact) {
                      return Column(
                        children: [
                          publishField,
                          const SizedBox(height: 12),
                          expireField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: publishField),
                        const SizedBox(width: 12),
                        Expanded(child: expireField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Content',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                _FormattingToolbar(controller: _bodyController),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bodyController,
                  minLines: 10,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    labelText: 'Announcement body',
                    helperText: 'Supports basic Markdown-style formatting.',
                    border: OutlineInputBorder(),
                  ),
                  validator: _required,
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
    final expireAt = _expireAt;
    if (!_formKey.currentState!.validate() || _hoaId == null) {
      return;
    }

    if (expireAt != null && !expireAt.isAfter(_publishAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expiration date must be after the publish date.'),
        ),
      );
      return;
    }

    final input = AnnouncementInput(
      hoaId: _hoaId!,
      title: _titleController.text,
      body: _bodyController.text,
      publishAt: _publishAt,
      expireAt: expireAt,
      status: _status,
    );

    final controller = ref.read(announcementCommandProvider.notifier);
    final result = _isEditing
        ? await controller.updateAnnouncement(
            id: widget.initialValue!.id,
            input: input,
          )
        : await controller.createAnnouncement(input);

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

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
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
      onPressed: () => _pick(context),
      child: Row(
        children: [
          const Icon(Icons.event_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  value == null ? 'Not set' : _formatDateTime(value!),
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

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (date == null) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null) {
      return;
    }

    onChanged(
      DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }
}

class _FormattingToolbar extends StatelessWidget {
  const _FormattingToolbar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _wrapSelection('**', '**', 'Bold text'),
          icon: const Icon(Icons.format_bold),
          label: const Text('Bold'),
        ),
        OutlinedButton.icon(
          onPressed: () => _wrapSelection('_', '_', 'Italic text'),
          icon: const Icon(Icons.format_italic),
          label: const Text('Italic'),
        ),
        OutlinedButton.icon(
          onPressed: () => _insertAtLineStart('- '),
          icon: const Icon(Icons.format_list_bulleted),
          label: const Text('Bullet'),
        ),
        OutlinedButton.icon(
          onPressed: () => _wrapSelection('[', '](https://example.com)', 'Link text'),
          icon: const Icon(Icons.link),
          label: const Text('Link'),
        ),
      ],
    );
  }

  void _wrapSelection(String prefix, String suffix, String fallback) {
    final selection = controller.selection;
    final text = controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selectedText = start == end ? fallback : text.substring(start, end);
    final replacement = '$prefix$selectedText$suffix';

    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _insertAtLineStart(String prefix) {
    final selection = controller.selection;
    final text = controller.text;
    final offset = selection.isValid ? selection.start : text.length;
    final lineStart = text.lastIndexOf('\n', offset == 0 ? 0 : offset - 1) + 1;

    controller.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: offset + prefix.length),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

String _label(String value) {
  return value[0].toUpperCase() + value.substring(1);
}
