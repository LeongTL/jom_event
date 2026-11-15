import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

/// A new authenticator-app factor: the address the QR code holds and the same secret as text for typing in by hand.
class TotpEnrollment {
  const TotpEnrollment({
    required this.factorId,
    required this.uri,
    required this.secret,
  });
  final String factorId;
  final String uri;
  final String secret;
}

/// What an admin does to sign in: email and password, then the authenticator code. (Hosts use AuthRepository.)
abstract class BackOfficeAuth {
  Future<void> signInWithPassword(String email, String password);

  /// The id of the admin's confirmed authenticator, or null when they have not set one up yet.
  Future<String?> verifiedFactorId();

  /// Starts setting up an authenticator; it counts only after [verifyTotp] accepts a code from it.
  Future<TotpEnrollment> enrollTotp();

  /// Checks [code] for [factorId]; on success the session reaches the second factor (aal2).
  Future<void> verifyTotp(String factorId, String code);
}

class SupabaseBackOfficeAuth implements BackOfficeAuth {
  SupabaseBackOfficeAuth(this._client);
  final SupabaseClient _client;

  GoTrueMFAApi get _mfa => _client.auth.mfa;

  @override
  Future<void> signInWithPassword(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  @override
  Future<String?> verifiedFactorId() async {
    final factors = await _mfa.listFactors();
    return factors.totp.isEmpty ? null : factors.totp.first.id;
  }

  @override
  Future<TotpEnrollment> enrollTotp() async {
    // a setup that was abandoned half way would block a new one with the same name
    for (final f in (await _mfa.listFactors()).all) {
      if (f.status == FactorStatus.unverified) await _mfa.unenroll(f.id);
    }
    final r = await _mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'Jom',
      friendlyName: 'Jom admin',
    );
    return TotpEnrollment(
      factorId: r.id,
      uri: r.totp!.uri,
      secret: r.totp!.secret,
    );
  }

  @override
  Future<void> verifyTotp(String factorId, String code) async {
    await _mfa.challengeAndVerify(factorId: factorId, code: code);
  }
}

final backOfficeAuthProvider = Provider<BackOfficeAuth>(
  (ref) => SupabaseBackOfficeAuth(ref.watch(supabaseClientProvider)),
);
