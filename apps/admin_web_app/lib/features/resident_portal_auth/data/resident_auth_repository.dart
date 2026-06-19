// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/resident_address.dart';
import '../domain/resident_registration.dart';
import 'resident_auth_dtos.dart';

abstract interface class ResidentPortalAuthRepository {
  Stream<AuthState> get authStateChanges;
  User? get currentUser;

  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> completeEmailVerificationFromUri(Uri uri);
  Future<String> resolveTenantCodeForCurrentResident();
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

class SupabaseResidentPortalAuthRepository
    implements ResidentPortalAuthRepository {
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
  Future<void> completeEmailVerificationFromUri(Uri uri) async {
    final params = _combinedParams(uri);
    final urlError = params['error_description'] ?? params['error'];
    if (urlError != null && urlError.trim().isNotEmpty) {
      throw StateError(urlError.trim());
    }

    final code = params['code'];
    final tokenHash = params['token_hash'];
    final type = params['type'];
    final accessToken = params['access_token'];
    final refreshToken = params['refresh_token'];

    if (tokenHash != null && tokenHash.isNotEmpty) {
      final otpType = _residentOtpType(type);
      await _client.auth.verifyOTP(
        tokenHash: tokenHash,
        type: otpType,
      );
      await _waitForAuthenticatedSession();
      _clearResidentEmailCallbackPayload();
      return;
    }

    if (code != null && code.isNotEmpty) {
      await _client.auth.exchangeCodeForSession(code);
      await _waitForAuthenticatedSession();
      _clearResidentEmailCallbackPayload();
      return;
    }

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _client.auth.setSession(
        refreshToken,
        accessToken: accessToken,
      );
      await _waitForAuthenticatedSession();
      _clearResidentEmailCallbackPayload();
      return;
    }

    throw StateError(
      'This verification link is missing required information. Please request a new verification email.',
    );
  }

  Future<void> _waitForAuthenticatedSession() async {
    if (_client.auth.currentUser != null) {
      return;
    }

    final authState = await _client.auth.onAuthStateChange
        .firstWhere(
          (event) => event.session?.user != null,
        )
        .timeout(const Duration(seconds: 8));

    if (authState.session?.user == null && _client.auth.currentUser == null) {
      throw StateError(
        'We verified your email, but could not finish signing you in. Please try the email link again.',
      );
    }
  }

  @override
  Future<String> resolveTenantCodeForCurrentResident() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in again to continue your registration.');
    }

    final verification = await _client
        .from('residency_verifications')
        .select('hoa_id')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final hoaId = verification?['hoa_id']?.toString();
    if (hoaId == null || hoaId.isEmpty) {
      throw StateError(
        'We could not determine which HOA portal to finish registration in.',
      );
    }

    final hoa = await _client
        .from('hoa_communities')
        .select('tenant_id')
        .eq('id', hoaId)
        .maybeSingle();

    final tenantId = hoa?['tenant_id']?.toString();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError(
        'We could not determine which tenant this HOA belongs to.',
      );
    }

    final tenant = await _client
        .from('platform_tenants')
        .select('code')
        .eq('id', tenantId)
        .maybeSingle();

    final tenantCode = tenant?['code']?.toString().trim();
    if (tenantCode == null || tenantCode.isEmpty) {
      throw StateError(
        'We could not determine which resident portal to send you to.',
      );
    }

    return tenantCode;
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
    final address =
        await verifyAddress(tenantCode: tenantCode, input: input.address);
    final emailRedirectTo = await _resolveResidentEmailRedirectUrl(tenantCode);
    final signUp = await _client.auth.signUp(
      email: input.email.trim(),
      password: input.password,
      emailRedirectTo: emailRedirectTo,
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
      throw StateError(
          'No pending resident verification was found for this account.');
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

  Future<String> _resolveResidentEmailRedirectUrl(String tenantCode) async {
    final tenant = await _client
        .from('platform_tenants')
        .select('id')
        .eq('code', tenantCode)
        .maybeSingle();

    final tenantId = tenant?['id'] as String?;
    if (tenantId == null) {
      return _residentPortalRouteBase(Uri.base.origin, tenantCode);
    }

    final settings = await _client
        .from('tenant_settings')
        .select('portal_hostname')
        .eq('tenant_id', tenantId)
        .maybeSingle();

    final configuredHost = settings?['portal_hostname']?.toString().trim();
    if (configuredHost == null || configuredHost.isEmpty) {
      return _residentPortalRouteBase(Uri.base.origin, tenantCode);
    }

    final normalizedBase = _normalizePortalBaseUrl(configuredHost);
    return _residentPortalRouteBase(normalizedBase, tenantCode);
  }

  String _residentPortalRouteBase(String origin, String tenantCode) {
    final baseUri = Uri.parse(origin);
    return baseUri
        .replace(
          path: '/',
          queryParameters: {
            'portal_flow': 'resident_confirm',
            'tenant': tenantCode,
          },
          fragment: null,
        )
        .toString();
  }

  String _normalizePortalBaseUrl(String rawValue) {
    final trimmed = rawValue.trim();
    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
            ? trimmed
            : 'http://$trimmed';
    final uri = Uri.parse(withScheme);
    final normalized = uri.replace(
      path: '',
      query: null,
      fragment: null,
    );
    final origin = normalized.toString();
    return origin.endsWith('/')
        ? origin.substring(0, origin.length - 1)
        : origin;
  }

  Map<String, String> _combinedParams(Uri uri) {
    final params = <String, String>{...uri.queryParameters};
    final fragment = uri.fragment;
    if (fragment.isEmpty) return params;

    var normalizedFragment = fragment;
    final hashQueryStart = normalizedFragment.indexOf('?');
    if (hashQueryStart >= 0) {
      normalizedFragment = normalizedFragment.substring(hashQueryStart + 1);
    } else if (normalizedFragment.startsWith('?')) {
      normalizedFragment = normalizedFragment.substring(1);
    }

    if (normalizedFragment.isEmpty || !normalizedFragment.contains('=')) {
      return params;
    }

    try {
      params.addAll(Uri.splitQueryString(normalizedFragment));
    } on FormatException {
      return _mergeResidentStoredPayload(params);
    }

    return _mergeResidentStoredPayload(params);
  }

  Map<String, String> _mergeResidentStoredPayload(Map<String, String> params) {
    final storedPayload =
        html.window.localStorage['resident_email_callback_payload']?.trim();
    if (storedPayload == null || storedPayload.isEmpty) {
      return params;
    }

    final hasLiveAuthPayload = params.containsKey('access_token') ||
        params.containsKey('refresh_token') ||
        params.containsKey('token_hash') ||
        params.containsKey('code');
    if (hasLiveAuthPayload) {
      return params;
    }

    try {
      final merged = <String, String>{
        ...Uri.splitQueryString(storedPayload),
        ...params,
      };
      return merged;
    } on FormatException {
      return params;
    }
  }

  void _clearResidentEmailCallbackPayload() {
    html.window.localStorage.remove('resident_email_callback_payload');
  }

  OtpType _residentOtpType(String? type) {
    return switch (type) {
      'signup' => OtpType.signup,
      'magiclink' => OtpType.magiclink,
      'email' => OtpType.email,
      _ => OtpType.signup,
    };
  }
}
