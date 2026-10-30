import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/config/app_config.dart';
import 'package:jom/core/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('the app config comes from main, and nothing silently assumes one', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(() => c.read(appConfigProvider), throwsA(anything));

    const config = AppConfig(
      flavor: 'staging',
      supabaseUrl: 'https://x.supabase.co',
      supabaseAnonKey: 'anon',
    );
    final withConfig = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(config)],
    );
    addTearDown(withConfig.dispose);
    expect(withConfig.read(appConfigProvider).flavor, 'staging');
  });

  test('screens ask for the Supabase client through one provider, so tests can swap it', () {
    final fake = SupabaseClient('https://x.supabase.co', 'anon');
    final c = ProviderContainer(
      overrides: [supabaseClientProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    expect(identical(c.read(supabaseClientProvider), fake), isTrue);
  });
}
