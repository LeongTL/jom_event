import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/flags/flags_repository.dart';
import 'core/router/app_router.dart';
import 'core/theme/calm.dart';
import 'features/host/data/host_repository.dart';

class JomApp extends ConsumerStatefulWidget {
  const JomApp({super.key});

  @override
  ConsumerState<JomApp> createState() => _JomAppState();
}

class _JomAppState extends ConsumerState<JomApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The host entrance flag and my application are read at start and again when the app comes back, so an
  // approval or a switched-off flag shows without a restart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref.invalidate(hostEntryEnabledProvider);
    ref.invalidate(hostStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Jom',
      debugShowCheckedModeBanner: false,
      theme: calmTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
