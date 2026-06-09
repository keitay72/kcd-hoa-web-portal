import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/resident_router.dart';

class ResidentApp extends ConsumerWidget {
  const ResidentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(residentRouterProvider);

    return MaterialApp.router(
      title: 'KC Disposal HOA Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xff1f6f43),
      ),
      routerConfig: router,
    );
  }
}
