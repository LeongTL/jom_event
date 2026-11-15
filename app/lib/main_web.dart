import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'backoffice/app.dart';
import 'backoffice/auth/web_auth_repository.dart';
import 'core/config/app_config.dart';
import 'core/supabase_client.dart';
import 'features/auth/data/auth_repository.dart';

/// The web back office: flutter run -d chrome -t lib/main_web.dart --dart-define-from-file=env/local.json
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = AppConfig.fromMap({
      'FLAVOR': const String.fromEnvironment('FLAVOR'),
      'SUPABASE_URL': const String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_ANON_KEY': const String.fromEnvironment('SUPABASE_ANON_KEY'),
      'MAP_TILE_URL': const String.fromEnvironment('MAP_TILE_URL'),
      'SHARE_BASE_URL': const String.fromEnvironment('SHARE_BASE_URL'),
      'PAYMENT_MODE': const String.fromEnvironment('PAYMENT_MODE'),
    });
    await initSupabase(config);
    runApp(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          authRepositoryProvider.overrideWith(
            (ref) => WebAuthRepository(ref.watch(supabaseClientProvider)),
          ),
        ],
        child: const BackOfficeApp(),
      ),
    );
  } on StateError catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('$e'))),
      ),
    );
  }
}
