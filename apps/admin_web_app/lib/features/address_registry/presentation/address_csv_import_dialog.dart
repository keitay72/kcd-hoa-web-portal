// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../domain/address_import_result.dart';

import '../../hoa_management/domain/hoa_community.dart';
import '../../hoa_management/presentation/hoa_providers.dart';
import '../domain/hoa_address_input.dart';
import 'address_providers.dart';

class AddressCsvImportDialog extends ConsumerStatefulWidget {
  const AddressCsvImportDialog({super.key});

  @override
  ConsumerState<AddressCsvImportDialog> createState() =>
      _AddressCsvImportDialogState();
}

class _AddressCsvImportDialogState
    extends ConsumerState<AddressCsvImportDialog> {
  static const _sampleHeaderRow =
      'hoa_code,line1,line2,city,state,postal_code,is_active';
  static const _spreadsheetHeaderRow =
      'hoa_code\tline1\tline2\tcity\tstate\tpostal_code\tis_active';
  static const _sampleDataRow =
      'HOA_LAKESIDE_ESTATES,101 Main St,,Kansas City,MO,64101,true';

  final _csvController = TextEditingController();
  String? _parseError;

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hoas = ref.watch(hoaListProvider);
    final importState = ref.watch(addressImportControllerProvider);

    return AlertDialog(
      title: const Text('Bulk CSV Import'),
      content: SizedBox(
        width: 760,
        child: hoas.when(
          data: (items) => _buildContent(context, importState, items),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('Unable to load HOA communities: $error'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: importState.isLoading
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: importState.isLoading || hoas.valueOrNull == null
              ? null
              : () => _import(hoas.valueOrNull!),
          icon: importState.isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file_outlined),
          label: const Text('Import CSV'),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    AsyncValue<AddressImportResult?> importState,
    List<HoaCommunity> hoas,
  ) {
    final result = importState.valueOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload a CSV of service addresses for one or more HOA communities.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Required columns: hoa_code or hoa_id, line1, city, state, postal_code',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Optional columns: line2, is_active',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: using hoa_code is usually easier than hoa_id. Example: hoa_code,line1,city,state,postal_code',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Copy this header row into a blank spreadsheet:',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: _spreadsheetHeaderRow),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Spreadsheet headers copied to clipboard.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy Headers'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _sampleHeaderRow,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The button copies a spreadsheet-friendly version so each header pastes into its own column.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Example row:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _sampleDataRow,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Example meaning: this creates an active address at 101 Main St in Lakeside Estates.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: importState.isLoading ? null : _pickCsvFile,
              icon: const Icon(Icons.attach_file_outlined),
              label: const Text('Choose CSV file'),
            ),
            const SizedBox(width: 12),
            Text('${hoas.length} HOA communities available'),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _csvController,
          minLines: 10,
          maxLines: 14,
          decoration: const InputDecoration(
            labelText: 'CSV Content',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        if (_parseError != null) ...[
          const SizedBox(height: 12),
          Text(
            _parseError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (importState.hasError) ...[
          const SizedBox(height: 12),
          Text(
            importState.error.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (result != null) ...[
          const SizedBox(height: 12),
          Text('Created ${result.createdCount} addresses.'),
          if (result.hasFailures) ...[
            const SizedBox(height: 8),
            Text('${result.failedRows.length} rows failed:'),
            const SizedBox(height: 6),
            SizedBox(
              height: 120,
              child: ListView.builder(
                itemCount: result.failedRows.length,
                itemBuilder: (context, index) {
                  final failure = result.failedRows[index];
                  return Text('Row ${failure.rowNumber}: ${failure.reason}');
                },
              ),
            ),
          ],
        ],
      ],
    );
  }

  void _pickCsvFile() {
    final input = html.FileUploadInputElement()..accept = '.csv,text/csv';
    input.click();
    input.onChange.listen((_) {
      final files = input.files;
      final file = files == null || files.isEmpty ? null : files[0];
      if (file == null) {
        return;
      }

      final reader = html.FileReader();
      reader.onLoad.listen((_) {
        setState(() {
          _csvController.text = reader.result as String? ?? '';
          _parseError = null;
        });
      });
      reader.readAsText(file);
    });
  }

  Future<void> _import(List<HoaCommunity> hoas) async {
    setState(() => _parseError = null);

    try {
      final rows = _parseCsv(_csvController.text, hoas);
      if (rows.isEmpty) {
        setState(() => _parseError = 'CSV contains no address rows.');
        return;
      }

      await ref.read(addressImportControllerProvider.notifier).importRows(rows);
    } catch (error) {
      setState(() => _parseError = error.toString());
    }
  }

  List<HoaAddressInput> _parseCsv(String csv, List<HoaCommunity> hoas) {
    final records = _readCsvRecords(csv);
    if (records.length < 2) {
      return const [];
    }

    final headers = records.first.map((value) => value.trim().toLowerCase()).toList();
    final hoaByCode = {for (final hoa in hoas) hoa.code.toUpperCase(): hoa.id};
    final hoaIds = hoas.map((hoa) => hoa.id).toSet();
    final rows = <HoaAddressInput>[];

    for (var index = 1; index < records.length; index += 1) {
      final record = records[index];
      if (record.every((value) => value.trim().isEmpty)) {
        continue;
      }

      final row = <String, String>{};
      for (var column = 0; column < headers.length; column += 1) {
        row[headers[column]] = column < record.length ? record[column].trim() : '';
      }

      final hoaId = _resolveHoaId(row, hoaByCode, hoaIds, index + 1);
      final line1 = _required(row, 'line1', index + 1);
      final city = _required(row, 'city', index + 1);
      final state = _required(row, 'state', index + 1);
      final postalCode = _required(row, 'postal_code', index + 1);
      final isActiveValue = row['is_active'];

      rows.add(
        HoaAddressInput(
          hoaId: hoaId,
          line1: line1,
          line2: row['line2'],
          city: city,
          state: state,
          postalCode: postalCode,
          isActive: isActiveValue == null ||
              isActiveValue.isEmpty ||
              ['true', 't', 'yes', 'y', '1', 'active']
                  .contains(isActiveValue.toLowerCase()),
        ),
      );
    }

    return rows;
  }

  String _resolveHoaId(
    Map<String, String> row,
    Map<String, String> hoaByCode,
    Set<String> hoaIds,
    int rowNumber,
  ) {
    final explicitHoaId = row['hoa_id'];
    if (explicitHoaId != null && explicitHoaId.isNotEmpty) {
      if (!hoaIds.contains(explicitHoaId)) {
        throw FormatException('Row $rowNumber references an unknown hoa_id.');
      }
      return explicitHoaId;
    }

    final hoaCode = row['hoa_code']?.toUpperCase();
    if (hoaCode == null || hoaCode.isEmpty) {
      throw FormatException('Row $rowNumber must include hoa_code or hoa_id.');
    }

    final hoaId = hoaByCode[hoaCode];
    if (hoaId == null) {
      throw FormatException('Row $rowNumber references unknown hoa_code $hoaCode.');
    }

    return hoaId;
  }

  String _required(Map<String, String> row, String key, int rowNumber) {
    final value = row[key];
    if (value == null || value.trim().isEmpty) {
      throw FormatException('Row $rowNumber missing required column $key.');
    }
    return value.trim();
  }

  List<List<String>> _readCsvRecords(String csv) {
    final records = <List<String>>[];
    final currentRecord = <String>[];
    final currentField = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < csv.length; index += 1) {
      final char = csv[index];
      final next = index + 1 < csv.length ? csv[index + 1] : null;

      if (char == '"') {
        if (inQuotes && next == '"') {
          currentField.write('"');
          index += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (char == ',' && !inQuotes) {
        currentRecord.add(currentField.toString());
        currentField.clear();
        continue;
      }

      if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && next == '\n') {
          index += 1;
        }
        currentRecord.add(currentField.toString());
        currentField.clear();
        records.add(List<String>.from(currentRecord));
        currentRecord.clear();
        continue;
      }

      currentField.write(char);
    }

    currentRecord.add(currentField.toString());
    if (currentRecord.any((value) => value.trim().isNotEmpty)) {
      records.add(currentRecord);
    }

    return records;
  }
}
