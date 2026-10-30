/// OpenStreetMap's own tile server: fine for development and staging, not for production traffic.
const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

class AppConfig {
  final String flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String mapTileUrl;

  /// Tells the tile server which app is asking (the bundle id).
  final String mapUserAgentPackage = 'com.jom.jom';

  const AppConfig({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.mapTileUrl = osmTileUrl,
  });

  factory AppConfig.fromMap(Map<String, String> env) {
    String need(String k) {
      final v = env[k];
      if (v == null || v.isEmpty) throw StateError('Missing config key $k');
      return v;
    }

    final flavor = need('FLAVOR');
    final tiles = env['MAP_TILE_URL'];
    return AppConfig(
      flavor: flavor,
      supabaseUrl: need('SUPABASE_URL'),
      supabaseAnonKey: need('SUPABASE_ANON_KEY'),
      mapTileUrl: tiles != null && tiles.isNotEmpty
          ? tiles
          : (flavor == 'prod' ? need('MAP_TILE_URL') : osmTileUrl),
    );
  }
}
