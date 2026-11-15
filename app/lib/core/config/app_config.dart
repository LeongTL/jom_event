/// OpenStreetMap's own tile server: fine for development and staging, not for production traffic.
const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

class AppConfig {
  final String flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String mapTileUrl;

  /// The public address share links are built on (`<base>/e/<code>`). Empty until the domain exists: links then use
  /// the app's own `jom://` scheme.
  final String shareBaseUrl;

  /// 'manual' = guests pay the host by transfer and upload a receipt; 'gateway' = a payment provider (later).
  final String paymentMode;

  /// Tells the tile server which app is asking (the bundle id).
  final String mapUserAgentPackage = 'com.jom.jom';

  const AppConfig({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.mapTileUrl = osmTileUrl,
    this.shareBaseUrl = '',
    this.paymentMode = 'manual',
  });

  factory AppConfig.fromMap(Map<String, String> env) {
    String need(String k) {
      final v = env[k];
      if (v == null || v.isEmpty) throw StateError('Missing config key $k');
      return v;
    }

    final flavor = need('FLAVOR');
    final tiles = env['MAP_TILE_URL'];
    final mode = env['PAYMENT_MODE'];
    if (mode != null &&
        mode.isNotEmpty &&
        mode != 'manual' &&
        mode != 'gateway') {
      throw StateError('PAYMENT_MODE must be manual or gateway, not $mode');
    }
    return AppConfig(
      flavor: flavor,
      supabaseUrl: need('SUPABASE_URL'),
      supabaseAnonKey: need('SUPABASE_ANON_KEY'),
      shareBaseUrl: env['SHARE_BASE_URL'] ?? '',
      paymentMode: mode == null || mode.isEmpty ? 'manual' : mode,
      mapTileUrl: tiles != null && tiles.isNotEmpty
          ? tiles
          : (flavor == 'prod' ? need('MAP_TILE_URL') : osmTileUrl),
    );
  }
}
