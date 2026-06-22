import 'package:flutter/material.dart';

import 'resident_portal_labels.dart';

class ResidentPortalScaffold extends StatelessWidget {
  const ResidentPortalScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.tenantCode,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? tenantCode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final portalTitle = customerPortalTitle(tenantCode);

    return Title(
      title: portalTitle,
      color: Theme.of(context).colorScheme.primary,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        portalTitle,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
