import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/supabase_client.dart';

/// [overrides] let the end-to-end tests swap native pieces (the photo picker); `flutter run` passes none.
Future<void> main({List<Override> overrides = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // These come from the build: flutter run --dart-define-from-file=env/staging.json
    final config = AppConfig.fromMap({
      'FLAVOR': const String.fromEnvironment('FLAVOR'),
      'SUPABASE_URL': const String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_ANON_KEY': const String.fromEnvironment('SUPABASE_ANON_KEY'),
      'MAP_TILE_URL': const String.fromEnvironment('MAP_TILE_URL'),
      'PAYMENT_MODE': const String.fromEnvironment('PAYMENT_MODE'),
    });
    await initSupabase(config);
    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          paymentModeProvider.overrideWithValue(config.paymentMode),
          ...overrides,
        ],
        child: const JomApp(),
      ),
    );
  } on StateError catch (e) {
    runApp(_ConfigError('$e'));
  }
}

/// Shown instead of a crash when the app was started without its settings.
class _ConfigError extends StatelessWidget {
  const _ConfigError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Jom was started without its settings.\n\n$message\n\nRun it with:\nflutter run --dart-define-from-file=env/staging.json',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
