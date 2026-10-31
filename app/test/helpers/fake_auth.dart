import 'dart:async';

import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A signed-in (or half signed-in) session for tests. [name] ends up in the user metadata, like Google or setName do.
Session fakeSession({
  String? phone = '60123456789',
  String? name,
  String? email,
}) => Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: User(
    id: 'u1',
    appMetadata: const {},
    userMetadata: name == null ? const {} : {'full_name': name},
    aud: 'authenticated',
    createdAt: '2026-10-15T00:00:00Z',
    phone: phone,
    email: email,
  ),
);

/// Stands in for Supabase: the test OTP +60123456789 / 123456 works, anything else is refused.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({Session? initial, this.newUserHasName = false})
    : _current = initial;

  Session? _current;
  final _changes = StreamController<Session?>.broadcast();

  /// Does a brand-new phone user already have a name (as a Google user would)?
  final bool newUserHasName;

  final sentTo = <String>[];
  final verified = <(String, String)>[];
  final names = <String>[];
  var googleCalls = 0;
  var signOutCalls = 0;
  var deleteCalls = 0;
  Object? deleteError;
  Object? googleError;
  Object? sendError;

  void _set(Session? s) {
    _current = s;
    _changes.add(s);
  }

  @override
  Stream<Session?> get session async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
    if (googleError != null) throw googleError!;
    _set(fakeSession(phone: null, name: 'Leong TL'));
  }

  @override
  Future<void> sendOtp(String phone) async {
    if (sendError != null) throw sendError!;
    sentTo.add(phone);
  }

  @override
  Future<void> verifyOtp(String phone, String code) async {
    verified.add((phone, code));
    if (code != '123456') {
      throw const AuthException('Token has expired or is invalid');
    }
    _set(
      fakeSession(
        phone: phone.substring(1),
        name: newUserHasName ? 'Mei' : null,
      ),
    );
  }

  @override
  Future<void> setName(String name) async {
    names.add(name);
    _set(fakeSession(phone: _current?.user.phone, name: name));
  }

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    if (deleteError != null) throw deleteError!;
    _set(null);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _set(null);
  }
}
