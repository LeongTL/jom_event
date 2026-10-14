import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/config/app_config.dart';

void main() {
  test('reads_flavor_and_keys', () {
    final c = AppConfig.fromMap({
      'FLAVOR': 'staging',
      'SUPABASE_URL': 'https://x.supabase.co',
      'SUPABASE_ANON_KEY': 'anon',
    });
    expect(c.flavor, 'staging');
    expect(c.supabaseUrl, 'https://x.supabase.co');
    expect(c.supabaseAnonKey, 'anon');
  });

  test('throws_when_a_key_is_missing', () {
    expect(
      () => AppConfig.fromMap({'FLAVOR': 'dev', 'SUPABASE_ANON_KEY': 'anon'}),
      throwsStateError,
    );
  });
}
