import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';

/// Set once in main() from the build's --dart-define-from-file; tests override it.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw StateError(
    'appConfigProvider must be overridden with the app config (see main.dart)',
  ),
);

/// The one way screens reach Supabase. Always the public (anon) key: the app never holds a secret key.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

Future<void> initSupabase(AppConfig config) => Supabase.initialize(
  url: config.supabaseUrl,
  publishableKey: config.supabaseAnonKey,
);
