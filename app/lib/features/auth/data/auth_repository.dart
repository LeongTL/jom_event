import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';

/// Google sign-in cannot run on this device yet (its client IDs are not set up).
class GoogleNotConfigured implements Exception {
  const GoogleNotConfigured();
  @override
  String toString() => 'Google sign-in is not set up on this device';
}

/// The person closed the Google window. Not an error.
class GoogleCancelled implements Exception {
  const GoogleCancelled();
  @override
  String toString() => 'Google sign-in was cancelled';
}

/// Everything the app does about who the user is. Screens only ever see this, so tests swap it for a fake.
abstract class AuthRepository {
  /// The current session first (null when signed out), then every change.
  Stream<Session?> get session;
  Future<void> signInWithGoogle();

  /// [phone] is in the +60... form (see normalizeMyPhone).
  Future<void> sendOtp(String phone);
  Future<void> verifyOtp(String phone, String code);

  /// Saves the display name on the account and on the profile row.
  Future<void> setName(String name);
  Future<void> signOut();
}

// Compile-time settings (--dart-define-from-file). The web client ID is what Supabase checks the Google token
// against; iOS also needs its own client ID. Both are public identifiers, not secrets.
const _googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
const _googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, {this.googleWebClientId = '', this.googleIosClientId = ''});

  final SupabaseClient _client;
  final String googleWebClientId;
  final String googleIosClientId;
  var _googleReady = false;

  GoTrueClient get _auth => _client.auth;

  @override
  Stream<Session?> get session async* {
    yield _auth.currentSession;
    yield* _auth.onAuthStateChange.map((change) => change.session);
  }

  @override
  Future<void> signInWithGoogle() async {
    // Calling the Google plugin on iOS without its client ID can crash the app, so check first.
    if (googleWebClientId.isEmpty || (Platform.isIOS && googleIosClientId.isEmpty)) throw const GoogleNotConfigured();
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(clientId: Platform.isIOS ? googleIosClientId : null, serverClientId: googleWebClientId);
      _googleReady = true;
    }
    try {
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const GoogleNotConfigured();
      await _auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const GoogleCancelled();
      rethrow;
    }
  }

  @override
  Future<void> sendOtp(String phone) => _auth.signInWithOtp(phone: phone);

  @override
  Future<void> verifyOtp(String phone, String code) =>
      _auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);

  @override
  Future<void> setName(String name) async {
    await _auth.updateUser(UserAttributes(data: {'full_name': name}));
    // the profile row is what other people see; it is changed by a database function, never directly
    await _client.schema('identity').rpc('update_profile', params: {'name': name, 'phone': _auth.currentUser?.phone});
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(
    ref.watch(supabaseClientProvider),
    googleWebClientId: _googleWebClientId,
    googleIosClientId: _googleIosClientId,
  ),
);

/// Who is signed in right now (null: nobody). Loading only for an instant at start-up.
final sessionProvider = StreamProvider<Session?>((ref) => ref.watch(authRepositoryProvider).session);
