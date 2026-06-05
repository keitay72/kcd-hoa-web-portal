class GenerateActivationCodeInput {
  const GenerateActivationCodeInput({
    required this.addressId,
    required this.expiresAt,
    this.reason,
  });

  final String addressId;
  final DateTime expiresAt;
  final String? reason;
}

class ResetActivationCodeInput {
  const ResetActivationCodeInput({
    required this.activationCodeId,
    required this.expiresAt,
    this.reason,
  });

  final String activationCodeId;
  final DateTime expiresAt;
  final String? reason;
}

class RevokeActivationCodeInput {
  const RevokeActivationCodeInput({
    required this.activationCodeId,
    this.reason,
  });

  final String activationCodeId;
  final String? reason;
}
