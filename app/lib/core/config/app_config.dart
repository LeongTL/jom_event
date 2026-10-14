class AppConfig {
  final String flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;

  const AppConfig({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory AppConfig.fromMap(Map<String, String> env) {
    String need(String k) {
      final v = env[k];
      if (v == null || v.isEmpty) throw StateError('Missing config key $k');
      return v;
    }

    return AppConfig(
      flavor: need('FLAVOR'),
      supabaseUrl: need('SUPABASE_URL'),
      supabaseAnonKey: need('SUPABASE_ANON_KEY'),
    );
  }
}
