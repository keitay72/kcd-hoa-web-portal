import '../domain/activation_code_event.dart';

class ActivationCodeEventDto {
  const ActivationCodeEventDto({
    required this.id,
    required this.activationCodeId,
    required this.action,
    this.actorUserId,
    this.reason,
    required this.createdAt,
  });

  final String id;
  final String activationCodeId;
  final String action;
  final String? actorUserId;
  final String? reason;
  final DateTime createdAt;

  factory ActivationCodeEventDto.fromJson(Map<String, dynamic> json) {
    return ActivationCodeEventDto(
      id: json['id'] as String,
      activationCodeId: json['activation_code_id'] as String,
      action: json['action'] as String,
      actorUserId: json['actor_user_id'] as String?,
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  ActivationCodeEvent toDomain() {
    return ActivationCodeEvent(
      id: id,
      activationCodeId: activationCodeId,
      action: ActivationCodeEventAction.fromDatabase(action),
      actorUserId: actorUserId,
      reason: reason,
      createdAt: createdAt,
    );
  }
}
