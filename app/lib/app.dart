import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/tokens.dart';

class JomApp extends ConsumerWidget {
  const JomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Jom',
      debugShowCheckedModeBanner: false,
      theme: jomThemeData(ref.watch(jomThemeProvider)),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
