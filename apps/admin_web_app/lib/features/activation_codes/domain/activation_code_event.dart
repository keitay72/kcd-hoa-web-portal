enum ActivationCodeEventAction {
  created,
  reset,
  consumed,
  revoked,
  expired;

  static ActivationCodeEventAction fromDatabase(String value) {
    return ActivationCodeEventAction.values.firstWhere(
      (action) => action.name == value,
      orElse: () => ActivationCodeEventAction.created,
    );
  }
}

class ActivationCodeEvent {
  const ActivationCodeEvent({
    required this.id,
    required this.activationCodeId,
    required this.action,
    this.actorUserId,
    this.reason,
    required this.createdAt,
  });

  final String id;
  final String activationCodeId;
  final ActivationCodeEventAction action;
  final String? actorUserId;
  final String? reason;
  final DateTime createdAt;

  String get actionLabel => action.name[0].toUpperCase() + action.name.substring(1);
}
