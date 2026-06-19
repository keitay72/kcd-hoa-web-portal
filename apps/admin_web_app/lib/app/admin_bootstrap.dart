// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_app.dart';

Future<void> bootstrapAdminApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  _clearStaleAdminInviteCallback();
  _normalizeResidentEmailCallback();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Missing Supabase config. Provide SUPABASE_URL and SUPABASE_ANON_KEY '
      'with --dart-define.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
      detectSessionInUri: false,
    ),
  );

  runApp(const ProviderScope(child: AdminApp()));
}

void _clearStaleAdminInviteCallback() {
  final uri = Uri.base;
  final normalizedFragment = _normalizedRouteFragment(uri.fragment);
  if (!normalizedFragment.startsWith('/accept-invite')) return;
  if (_extractAuthPayloadSegment(_fragmentPayload(uri.fragment) ?? '') !=
      null) {
    return;
  }

  html.window.history.replaceState(
    null,
    'HOA Portal Admin',
    '${uri.origin}/#/',
  );
}

void _normalizeResidentEmailCallback() {
  final uri = Uri.base;
  final normalizedFragment = _normalizedRouteFragment(uri.fragment);

  if (normalizedFragment.startsWith('/portal/')) return;
  if (normalizedFragment.startsWith('/accept-invite')) return;

  final authPayload = _extractResidentAuthPayload(uri);
  if (authPayload == null) return;

  html.window.localStorage['resident_email_callback_payload'] = authPayload;

  final tenantFromQuery =
      uri.queryParameters['portal_flow'] == 'resident_confirm' &&
              (uri.queryParameters['tenant']?.trim().isNotEmpty ?? false)
          ? uri.queryParameters['tenant']!.trim()
          : null;
  final pendingTenantCode = tenantFromQuery ??
      html.window.localStorage['resident_pending_tenant_code'];
  final callbackFragment =
      pendingTenantCode == null || pendingTenantCode.trim().isEmpty
          ? '/portal/confirm-email?$authPayload'
          : '/portal/$pendingTenantCode/confirm-email?$authPayload';
  html.window.history.replaceState(
    null,
    'Resident Email Confirmation',
    '${uri.origin}/#$callbackFragment',
  );
}

String? _extractResidentAuthPayload(Uri uri) {
  final queryPayload = _extractAuthPayloadSegment(uri.query);
  if (queryPayload != null) {
    return queryPayload;
  }

  return _extractAuthPayloadSegment(_fragmentPayload(uri.fragment) ?? '');
}

String _normalizedRouteFragment(String fragment) {
  if (fragment.startsWith('/')) return fragment;
  if (fragment.startsWith('?')) return fragment.substring(1);
  return fragment;
}

String? _fragmentPayload(String fragment) {
  if (fragment.isEmpty) return null;

  final fragmentQueryStart = fragment.indexOf('?');
  if (fragmentQueryStart >= 0) {
    return fragment.substring(fragmentQueryStart + 1);
  }

  if (fragment.startsWith('?')) {
    return fragment.substring(1);
  }

  return fragment;
}

String? _extractAuthPayloadSegment(String candidate) {
  final trimmed = candidate.trim();
  if (trimmed.isEmpty) return null;
  if (!_looksLikeAuthPayload(trimmed)) return null;
  return trimmed;
}

bool _looksLikeAuthPayload(String value) {
  return value.contains('access_token=') ||
      value.contains('refresh_token=') ||
      value.contains('token_hash=') ||
      value.contains('code=') ||
      value.contains('type=signup') ||
      value.contains('type=email') ||
      value.contains('error_description=');
}
