import 'resident_address.dart';

class ResidentRegistrationInput {
  const ResidentRegistrationInput({
    required this.email,
    required this.address,
  });

  final String email;
  final ResidentAddressInput address;
}

class ResidentRegistrationResult {
  const ResidentRegistrationResult({
    required this.userId,
    required this.email,
    required this.verificationId,
    required this.address,
    required this.tenantCode,
  });

  final String userId;
  final String email;
  final String verificationId;
  final VerifiedResidentAddress address;
  final String tenantCode;
}

class ResidentEmailVerificationCompletion {
  const ResidentEmailVerificationCompletion({
    required this.verified,
  });

  final bool verified;
}
