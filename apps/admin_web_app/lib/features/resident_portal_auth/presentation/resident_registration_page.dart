// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/resident_address.dart';
import '../domain/resident_registration.dart';
import 'resident_auth_providers.dart';
import 'resident_portal_scaffold.dart';

class ResidentRegistrationPage extends ConsumerStatefulWidget {
  const ResidentRegistrationPage({required this.tenantCode, super.key});

  final String tenantCode;

  @override
  ConsumerState<ResidentRegistrationPage> createState() =>
      _ResidentRegistrationPageState();
}

class _ResidentRegistrationPageState
    extends ConsumerState<ResidentRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _line1Controller = TextEditingController();
  final _line2Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController(text: 'MO');
  final _postalCodeController = TextEditingController();
  bool _preparedSession = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparedSession) return;
    _preparedSession = true;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _prepareResidentSession());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(residentPortalAuthControllerProvider);

    return ResidentPortalScaffold(
      tenantCode: widget.tenantCode,
      title: 'Create your resident account',
      subtitle:
          'Enter your HOA service address. We will match you to the correct HOA automatically.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: _email,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: _password,
            ),
            const SizedBox(height: 24),
            Text(
              'Service Address',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _line1Controller,
              decoration: const InputDecoration(labelText: 'Street Address'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _line2Controller,
              decoration:
                  const InputDecoration(labelText: 'Unit / Apt (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City'),
              validator: _required,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(labelText: 'State'),
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _postalCodeController,
                    decoration: const InputDecoration(labelText: 'ZIP Code'),
                    validator: _required,
                  ),
                ),
              ],
            ),
            if (state.hasError) ...[
              const SizedBox(height: 12),
              Text(
                state.error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: state.isLoading ? null : _submit,
              child: state.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  context.go('/portal/${widget.tenantCode}/sign-in'),
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prepareResidentSession() async {
    final repository = ref.read(residentPortalAuthRepositoryProvider);
    if (repository.currentUser == null) return;
    await repository.signOut();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    html.window.localStorage['resident_pending_tenant_code'] =
        widget.tenantCode;
    final result =
        await ref.read(residentPortalAuthControllerProvider.notifier).register(
              tenantCode: widget.tenantCode,
              input: ResidentRegistrationInput(
                fullName: _nameController.text,
                email: _emailController.text,
                password: _passwordController.text,
                address: ResidentAddressInput(
                  line1: _line1Controller.text,
                  line2: _line2Controller.text,
                  city: _cityController.text,
                  state: _stateController.text,
                  postalCode: _postalCodeController.text,
                ),
              ),
            );
    if (result != null && mounted) {
      context.go('/portal/${widget.tenantCode}/email-verification-pending');
      return;
    }
    html.window.localStorage.remove('resident_pending_tenant_code');
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Required';
    if (!input.contains('@') || !input.contains('.'))
      return 'Enter a valid email';
    return null;
  }

  String? _password(String? value) {
    if (value == null || value.length < 8) return 'Use at least 8 characters';
    return null;
  }
}
