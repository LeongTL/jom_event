import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/config/app_config.dart';

void main() {
  paymentModeTests();
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

  test('prod_config_requires_map_tile_url_and_dev_staging_default_to_osm', () {
    const base = {
      'SUPABASE_URL': 'https://x.supabase.co',
      'SUPABASE_ANON_KEY': 'anon',
    };
    expect(
      AppConfig.fromMap({...base, 'FLAVOR': 'dev'}).mapTileUrl,
      osmTileUrl,
    );
    expect(
      AppConfig.fromMap({...base, 'FLAVOR': 'staging', 'MAP_TILE_URL': ''})
          .mapTileUrl,
      osmTileUrl,
    );
    expect(
      () => AppConfig.fromMap({...base, 'FLAVOR': 'prod', 'MAP_TILE_URL': ''}),
      throwsStateError,
    );
    expect(
      AppConfig.fromMap({
        ...base,
        'FLAVOR': 'prod',
        'MAP_TILE_URL': 'https://t.example/{z}/{x}/{y}.png',
      }).mapTileUrl,
      'https://t.example/{z}/{x}/{y}.png',
    );
  });
}

void paymentModeTests() {
  const base = {
    'FLAVOR': 'dev',
    'SUPABASE_URL': 'https://x.supabase.co',
    'SUPABASE_ANON_KEY': 'anon',
  };
  test('payment_mode_defaults_to_manual', () {
    expect(AppConfig.fromMap(base).paymentMode, 'manual');
  });
  test('payment_mode_gateway_is_read', () {
    expect(
      AppConfig.fromMap({...base, 'PAYMENT_MODE': 'gateway'}).paymentMode,
      'gateway',
    );
  });
  test('unknown_payment_mode_throws', () {
    expect(
      () => AppConfig.fromMap({...base, 'PAYMENT_MODE': 'cash'}),
      throwsStateError,
    );
  });
}
