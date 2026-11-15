import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/auth_repository.dart';

/// The app's sign-in, with Google done the way a website does it (a redirect), because the phone plugin cannot run in a browser.
class WebAuthRepository extends SupabaseAuthRepository {
  // ignore: use_super_parameters
  WebAuthRepository(SupabaseClient client) : _web = client, super(client);
  final SupabaseClient _web;

  @override
  Future<void> signInWithGoogle() => _web.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: Uri.base.origin,
  );
}
