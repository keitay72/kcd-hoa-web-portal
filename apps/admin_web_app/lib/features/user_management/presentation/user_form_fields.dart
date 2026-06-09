import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NameParts {
  const NameParts({
    required this.firstName,
    this.middleName,
    required this.lastName,
  });

  final String firstName;
  final String? middleName;
  final String lastName;

  String get fullName {
    return [firstName, middleName, lastName]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
  }
}

class UserFormValidators {
  static final RegExp _nameRegExp = RegExp(r"^[A-Za-z][A-Za-z .'-]*$");
  static final RegExp _emailRegExp = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? requiredName(String? value, String label) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$label is required.';
    return optionalName(value, label);
  }

  static String? optionalName(String? value, String label) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (!_nameRegExp.hasMatch(trimmed)) {
      return '$label may only include letters, spaces, apostrophes, hyphens, and periods.';
    }
    return null;
  }

  static String? email(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required.';
    if (!_emailRegExp.hasMatch(trimmed)) return 'Enter a valid email address.';
    return null;
  }

  static String? phone(String? value) {
    final digits = phoneDigits(value ?? '');
    if (digits.isEmpty) return 'Phone is required.';
    if (digits.length != 10) return 'Enter a 10-digit US phone number.';
    return null;
  }

  static String phoneDigits(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  static bool shouldWarnCapitalization(String value) {
    final letters = value.replaceAll(RegExp(r"[^A-Za-z]"), '');
    if (letters.length < 2) return false;
    return letters == letters.toUpperCase() || letters == letters.toLowerCase();
  }
}

class UsPhoneTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = UserFormValidators.phoneDigits(newValue.text);
    final limited = digits.length > 10 ? digits.substring(0, 10) : digits;
    final formatted = _format(limited);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String digits) {
    if (digits.isEmpty) return '';
    if (digits.length <= 3) return '($digits';
    if (digits.length <= 6) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3)}';
    }
    return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
  }
}

NameParts splitName(String? fullName) {
  final parts = (fullName ?? '').trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return const NameParts(firstName: '', lastName: '');
  if (parts.length == 1) return NameParts(firstName: parts.first, lastName: '');
  return NameParts(
    firstName: parts.first,
    middleName: parts.length > 2 ? parts.sublist(1, parts.length - 1).join(' ') : null,
    lastName: parts.last,
  );
}

String formatPhoneForDisplay(String? value) {
  final digits = UserFormValidators.phoneDigits(value ?? '');
  if (digits.length != 10) return value ?? '';
  return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
}

class CapitalizationWarning extends StatelessWidget {
  const CapitalizationWarning({required this.show, super.key});

  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          const Expanded(child: Text('Consider using proper capitalization.')),
        ],
      ),
    );
  }
}
