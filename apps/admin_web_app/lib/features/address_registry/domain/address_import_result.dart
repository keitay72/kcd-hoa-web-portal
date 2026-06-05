class AddressImportResult {
  const AddressImportResult({
    required this.createdCount,
    required this.failedRows,
  });

  final int createdCount;
  final List<AddressImportFailure> failedRows;

  bool get hasFailures => failedRows.isNotEmpty;
}

class AddressImportFailure {
  const AddressImportFailure({
    required this.rowNumber,
    required this.reason,
  });

  final int rowNumber;
  final String reason;
}
