import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dev/dev_security_bypass.dart';

class CurrentAdminProfile {
  const CurrentAdminProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.passwordSetAt,
  });

  final String id;
  final String email;
  final String? fullName;
  final DateTime? passwordSetAt;

  bool get requiresPasswordSetup => passwordSetAt == null;

  String get displayName {
    final name = fullName?.trim();
    return name == null || name.isEmpty ? email : name;
  }
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});

final currentAdminProfileProvider =
    FutureProvider.autoDispose<CurrentAdminProfile?>((ref) async {
  if (devSecurityBypassEnabled) {
    return CurrentAdminProfile(
      id: devUserId,
      email: devUserEmail,
      fullName: devUserName,
      passwordSetAt: DateTime.utc(2026),
    );
  }

  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final row = await ref
      .watch(supabaseClientProvider)
      .from('profiles')
      .select('id, email, full_name, password_set_at')
      .eq('id', user.id)
      .maybeSingle();

  if (row == null) {
    return CurrentAdminProfile(
      id: user.id,
      email: user.email ?? user.id,
    );
  }

  return CurrentAdminProfile(
    id: row['id'] as String? ?? user.id,
    email: row['email'] as String? ?? user.email ?? user.id,
    fullName: row['full_name'] as String?,
    passwordSetAt: _optionalDateTime(row['password_set_at']),
  );
});

DateTime? _optionalDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
