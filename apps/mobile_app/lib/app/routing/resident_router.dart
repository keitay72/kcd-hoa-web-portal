import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/supabase_provider.dart';
import '../../features/authentication/presentation/activation_code_verification_page.dart';
import '../../features/authentication/presentation/address_verification_page.dart';
import '../../features/authentication/presentation/email_verification_pending_page.dart';
import '../../features/authentication/presentation/registration_success_page.dart';
import '../../features/authentication/presentation/resident_login_page.dart';
import '../../features/authentication/presentation/resident_registration_page.dart';

final residentRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final path = state.uri.path;
      final publicRoutes = {
        '/login',
        '/register',
        '/verify-address',
        '/email-verification-pending',
      };

      if (user == null && !publicRoutes.contains(path)) {
        return '/login';
      }

      if (user != null && path == '/login') {
        return '/activation-code';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'residentLogin',
        builder: (context, state) => const ResidentLoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'residentRegistration',
        builder: (context, state) => const ResidentRegistrationPage(),
      ),
      GoRoute(
        path: '/verify-address',
        name: 'addressVerification',
        builder: (context, state) => const AddressVerificationPage(),
      ),
      GoRoute(
        path: '/email-verification-pending',
        name: 'emailVerificationPending',
        builder: (context, state) => const EmailVerificationPendingPage(),
      ),
      GoRoute(
        path: '/activation-code',
        name: 'activationCodeVerification',
        builder: (context, state) => const ActivationCodeVerificationPage(),
      ),
      GoRoute(
        path: '/registration-success',
        name: 'registrationSuccess',
        builder: (context, state) => const RegistrationSuccessPage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text(state.error?.toString() ?? 'Route not found')),
    ),
  );
});
