import 'resident_address.dart';

class ResidentRegistrationInput {
  const ResidentRegistrationInput({
    required this.fullName,
    required this.email,
    required this.password,
    required this.address,
  });

  final String fullName;
  final String email;
  final String password;
  final ResidentAddressInput address;
}

class ResidentRegistrationResult {
  const ResidentRegistrationResult({
    required this.userId,
    required this.email,
    required this.verificationId,
    required this.address,
    required this.tenantCode,
    required this.activationCodeRequired,
  });

  final String userId;
  final String email;
  final String verificationId;
  final VerifiedResidentAddress address;
  final String tenantCode;
  final bool activationCodeRequired;
}

class ResidentEmailVerificationCompletion {
  const ResidentEmailVerificationCompletion({
    required this.verified,
    required this.activationCodeRequired,
  });

  final bool verified;
  final bool activationCodeRequired;
}
