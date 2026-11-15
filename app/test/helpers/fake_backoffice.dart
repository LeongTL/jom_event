import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/backoffice/access/access.dart';
import 'package:jom/backoffice/admin/admin_repository.dart';
import 'package:jom/backoffice/app.dart';
import 'package:jom/backoffice/auth/backoffice_auth.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/host/data/host_repository.dart';
import 'package:jom/features/host/domain/host_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_auth.dart';
import 'fake_host.dart';

/// Whether the signed-in person is an admin and has given the second factor. Changed by [FakeBackOfficeAuth].
class FakeAccess implements AccessRepository {
  FakeAccess({this.isAdmin = false, this.aal2 = false});
  bool isAdmin;
  bool aal2;

  @override
  Future<AdminAccess> me() async => AdminAccess(isAdmin: isAdmin, aal2: aal2);
}

/// Email and password sign-in and the authenticator code. The password is `secret-pass`, the code `123456`.
class FakeBackOfficeAuth implements BackOfficeAuth {
  FakeBackOfficeAuth(this.auth, this.access, {this.factorId});
  final FakeAuthRepository auth;
  final FakeAccess access;
  String? factorId;
  final passwordSignIns = <String>[];
  final enrolments = <String>[];
  final verifies = <(String, String)>[];

  @override
  Future<void> signInWithPassword(String email, String password) async {
    passwordSignIns.add(email);
    if (password != 'secret-pass') {
      throw const AuthException('Invalid login credentials');
    }
    auth.signInAs(fakeSession(phone: null, email: email, name: 'Ada Admin'));
  }

  @override
  Future<String?> verifiedFactorId() async => factorId;

  @override
  Future<TotpEnrollment> enrollTotp() async {
    enrolments.add('totp');
    return const TotpEnrollment(
      factorId: 'f1',
      uri: 'otpauth://totp/Jom:ada?secret=JBSWY3DPEHPK3PXP&issuer=Jom',
      secret: 'JBSWY3DPEHPK3PXP',
    );
  }

  @override
  Future<void> verifyTotp(String factorId, String code) async {
    verifies.add((factorId, code));
    if (code != '123456') {
      throw const AuthException('Invalid TOTP code entered');
    }
    this.factorId = factorId;
    access.aal2 = true;
    auth.signInAs(fakeSession(phone: null, email: 'ada@example.com'));
  }
}

class BoWorld {
  BoWorld({
    bool isAdmin = false,
    bool aal2 = false,
    HostState host = HostState.none,
    String? factorId,
    Session? signedIn,
    FakeAdmin? admin,
  }) : admin = admin ?? FakeAdmin(),
       auth = FakeAuthRepository(initial: signedIn),
       access = FakeAccess(isAdmin: isAdmin, aal2: aal2),
       hosts = FakeHost()..status = HostStatus(host) {
    boAuth = FakeBackOfficeAuth(auth, access, factorId: factorId);
  }
  final FakeAuthRepository auth;
  final FakeAccess access;
  final FakeHost hosts;
  final FakeAdmin admin;
  late final FakeBackOfficeAuth boAuth;

  List<Override> get overrides => [
    authRepositoryProvider.overrideWithValue(auth),
    accessRepositoryProvider.overrideWithValue(access),
    backOfficeAuthProvider.overrideWithValue(boAuth),
    hostRepositoryProvider.overrideWithValue(hosts),
    adminRepositoryProvider.overrideWithValue(admin),
  ];
}

/// The back office on fakes at [width] x [height].
Future<void> pumpBackOffice(
  WidgetTester t,
  BoWorld world, {
  double width = 1280,
  double height = 900,
  List<Override> extra = const [],
}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [...world.overrides, ...extra],
      child: const BackOfficeApp(),
    ),
  );
  await t.pumpAndSettle();
}

class FakeAdmin implements AdminRepository {
  FakeAdmin({List<PendingApplication>? pending, Map<String, Application>? full})
    : pending = pending ?? [],
      full = full ?? {};
  final List<PendingApplication> pending;
  final Map<String, Application> full;
  final reviews = <(String, String, String?)>[];
  Object? reviewError;

  @override
  Future<List<PendingApplication>> pendingHosts() async => [...pending];

  @override
  Future<Application> application(String userId) async => full[userId]!;

  @override
  Future<void> review(String userId, String decision, {String? reason}) async {
    reviews.add((userId, decision, reason));
    if (reviewError != null) throw reviewError!;
    pending.removeWhere((p) => p.userId == userId);
  }

  @override
  Future<String?> qrUrl(String path) async => 'http://localhost/qr.png';
}
