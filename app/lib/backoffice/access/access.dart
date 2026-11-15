import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/host/data/host_repository.dart';

/// What the back office shows after sign-in.
enum Shell { signIn, mfa, admin, host, notAuthorised }

/// The one rule for who sees what. An admin sees the admin shell only after the second factor (aal2); an approved host
/// sees the host shell; a person who is both starts in the admin shell and may switch ([chosen]). Everyone else is refused.
Shell decideShell({
  required bool signedIn,
  required bool isAdmin,
  required bool aal2,
  required String hostStatus,
  Shell? chosen,
}) {
  if (!signedIn) return Shell.signIn;
  final host = hostStatus == 'approved';
  if (isAdmin) {
    if (!aal2) return Shell.mfa;
    return chosen == Shell.host && host ? Shell.host : Shell.admin;
  }
  return host ? Shell.host : Shell.notAuthorised;
}

/// Who the signed-in person is to the back office. [aal2] is true once they have given the authenticator code.
class AdminAccess {
  const AdminAccess({required this.isAdmin, required this.aal2});
  final bool isAdmin;
  final bool aal2;
  static const none = AdminAccess(isAdmin: false, aal2: false);
}

abstract class AccessRepository {
  Future<AdminAccess> me();
}

class SupabaseAccessRepository implements AccessRepository {
  SupabaseAccessRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<AdminAccess> me() async {
    final admin =
        await _client.schema('identity').rpc('is_admin') as bool? ?? false;
    final level = _client.auth.mfa.getAuthenticatorAssuranceLevel();
    return AdminAccess(
      isAdmin: admin,
      aal2: level.currentLevel == AuthenticatorAssuranceLevels.aal2,
    );
  }
}

final accessRepositoryProvider = Provider<AccessRepository>(
  (ref) => SupabaseAccessRepository(ref.watch(supabaseClientProvider)),
);

/// Read again whenever the session changes (sign-in, the second factor, a refresh), so the shell follows it.
final adminAccessProvider = FutureProvider.autoDispose<AdminAccess>((ref) {
  final session = ref.watch(sessionProvider).value;
  if (session == null) return AdminAccess.none;
  return ref.watch(accessRepositoryProvider).me();
});

/// The shell a person who is both admin and host picked with the switch. Forgotten at sign-out.
class ChosenShell extends Notifier<Shell?> {
  @override
  Shell? build() {
    ref.listen(sessionProvider, (prev, next) {
      if (next.value == null) state = null;
    });
    return null;
  }

  void choose(Shell? shell) => state = shell;
}

final chosenShellProvider = NotifierProvider<ChosenShell, Shell?>(
  ChosenShell.new,
);

/// The shell to show now; loading while the person's role is being read.
final shellProvider = Provider.autoDispose<AsyncValue<Shell>>((ref) {
  final session = ref.watch(sessionProvider);
  if (session.isLoading) return const AsyncLoading();
  final signedIn = session.value != null;
  if (!signedIn) return const AsyncData(Shell.signIn);
  final access = ref.watch(adminAccessProvider);
  final host = ref.watch(hostStatusProvider);
  if (access.isLoading || host.isLoading) return const AsyncLoading();
  if (access.hasError) return AsyncError(access.error!, access.stackTrace!);
  return AsyncData(
    decideShell(
      signedIn: true,
      isAdmin: access.value!.isAdmin,
      aal2: access.value!.aal2,
      hostStatus: host.value?.state.name ?? 'none',
      chosen: ref.watch(chosenShellProvider),
    ),
  );
});
