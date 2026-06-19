// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../address_registry/domain/hoa_address.dart';
import '../domain/ticket.dart';
import '../domain/ticket_inputs.dart';
import 'ticket_providers.dart';

class ResidentServiceIssuePage extends ConsumerStatefulWidget {
  const ResidentServiceIssuePage({super.key});

  @override
  ConsumerState<ResidentServiceIssuePage> createState() =>
      _ResidentServiceIssuePageState();
}

class _ResidentServiceIssuePageState
    extends ConsumerState<ResidentServiceIssuePage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _addressId;
  TicketType _type = TicketType.missedPickup;
  String? _fileName;
  String? _mimeType;
  Uint8List? _bytes;
  String? _fileError;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(residentTicketAddressesProvider);
    final commandState = ref.watch(ticketCommandProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Service Issue',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Submit a trash service issue for your registered address.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/hoa/tickets'),
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('My Tickets'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: addresses.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Text(
                    'No current resident address was found for this account.',
                  );
                }

                _addressId ??= items.first.id;
                return Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AddressSelect(
                        addresses: items,
                        selectedAddressId: _addressId,
                        onChanged: (value) =>
                            setState(() => _addressId = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<TicketType>(
                        value: _type,
                        decoration: const InputDecoration(
                          labelText: 'Issue Type',
                          border: OutlineInputBorder(),
                        ),
                        items: TicketType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _type = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Short Summary',
                          hintText: 'Example: Trash was not picked up',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: _required,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 5,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Details',
                          hintText:
                              'Tell us what happened, where the issue is, and anything the driver or office should know.',
                          border: OutlineInputBorder(),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: commandState.isLoading ? null : _pickFile,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            _fileName == null ? 'Add Photo' : 'Change Photo',
                          ),
                        ),
                      ),
                      if (_fileName != null) ...[
                        const SizedBox(height: 8),
                        Text('Selected: $_fileName'),
                      ],
                      if (_fileError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _fileError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (commandState.hasError) ...[
                        const SizedBox(height: 16),
                        Text(
                          commandState.error.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: commandState.isLoading
                            ? null
                            : () => _submit(items),
                        icon: commandState.isLoading
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        label: const Text('Submit Issue'),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Unable to load addresses: $error'),
            ),
          ),
        ),
      ],
    );
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

  Future<void> _submit(List<HoaAddress> addresses) async {
    HoaAddress? selectedAddress;
    for (final address in addresses) {
      if (address.id == _addressId) {
        selectedAddress = address;
        break;
      }
    }
    if (selectedAddress == null) return;
    if (!_formKey.currentState!.validate()) return;

    final bytes = _bytes;
    final fileName = _fileName;
    final mimeType = _mimeType;

    final ticket = await ref
        .read(ticketCommandProvider.notifier)
        .createResidentTicket(
          ResidentTicketCreateInput(
            hoaId: selectedAddress.hoaId,
            addressId: selectedAddress.id,
            type: _type,
            subject: _subjectController.text,
            description: _descriptionController.text,
            attachment: bytes == null || fileName == null || mimeType == null
                ? null
                : TicketAttachmentUploadInput(
                    fileName: fileName,
                    mimeType: mimeType,
                    bytes: bytes,
                  ),
          ),
        );

    if (!mounted || ticket == null) return;
    context.go('/admin/tickets/${ticket.id}');
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
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
      decoration: const InputDecoration(
        labelText: 'Service Address',
        border: OutlineInputBorder(),
      ),
      items: addresses
          .map(
            (address) => DropdownMenuItem(
              value: address.id,
              child: Text(address.singleLine),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
