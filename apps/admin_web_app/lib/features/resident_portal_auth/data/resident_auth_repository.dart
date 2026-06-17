import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/resident_address.dart';
import '../domain/resident_registration.dart';
import 'resident_auth_dtos.dart';

abstract interface class ResidentPortalAuthRepository {
  Stream<AuthState> get authStateChanges;
  User? get currentUser;

  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<VerifiedResidentAddress> verifyAddress({
    required String tenantCode,
    required ResidentAddressInput input,
  });
  Future<ResidentRegistrationResult> register({
    required String tenantCode,
    required ResidentRegistrationInput input,
  });
  Future<bool> verifyActivationCode({
    required String verificationId,
    required String addressId,
    required String code,
  });
  Future<bool> verifyActivationCodeForCurrentUser(String code);
}

class SupabaseResidentPortalAuthRepository implements ResidentPortalAuthRepository {
  const SupabaseResidentPortalAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  @override
  Future<VerifiedResidentAddress> verifyAddress({
    required String tenantCode,
    required ResidentAddressInput input,
  }) async {
    final response = await _client.functions.invoke(
      'verify-address',
      body: {
        'tenantCode': tenantCode,
        ...input.toJson(),
      },
    );

    final data = response.data as Map<String, dynamic>;
    if (data['verified'] != true) {
      throw StateError(
        'We could not match that address to an active HOA address in this portal.',
      );
    }

    return VerifiedResidentAddressDto.fromJson(
      data['address'] as Map<String, dynamic>,
    ).toDomain();
  }

  @override
  Future<ResidentRegistrationResult> register({
    required String tenantCode,
    required ResidentRegistrationInput input,
  }) async {
    final address = await verifyAddress(tenantCode: tenantCode, input: input.address);
    final signUp = await _client.auth.signUp(
      email: input.email.trim(),
      password: input.password,
      emailRedirectTo: '${Uri.base.origin}/#/portal/$tenantCode/activation-code',
    );
    final user = signUp.user;

    if (user == null) {
      throw StateError('Unable to create resident account.');
    }

    final response = await _client.functions.invoke(
      'start-resident-registration',
      body: {
        'tenantCode': tenantCode,
        'userId': user.id,
        'fullName': input.fullName.trim(),
        'email': input.email.trim(),
        'addressId': address.id,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final verification = data['verification'] as Map<String, dynamic>;

    return ResidentRegistrationResult(
      userId: user.id,
      email: input.email.trim(),
      verificationId: verification['id'] as String,
      address: address,
      tenantCode: tenantCode,
    );
  }

  @override
  Future<bool> verifyActivationCodeForCurrentUser(String code) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in before entering your activation code.');
    }

    final row = await _client
        .from('residency_verifications')
        .select('id, address_id')
        .eq('user_id', user.id)
        .eq('status', 'pending')
        .limit(1)
        .maybeSingle();

    if (row == null) {
      throw StateError('No pending resident verification was found for this account.');
    }

    return verifyActivationCode(
      verificationId: row['id'] as String,
      addressId: row['address_id'] as String,
      code: code,
    );
  }

  @override
  Future<bool> verifyActivationCode({
    required String verificationId,
    required String addressId,
    required String code,
  }) async {
    final response = await _client.functions.invoke(
      'verify-activation-code',
      body: {
        'verificationId': verificationId,
        'addressId': addressId,
        'code': code.trim(),
      },
    );
    final data = response.data as Map<String, dynamic>;
    return data['verified'] == true;
  }
}
