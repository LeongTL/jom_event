import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../presentation/sign_in_sheet.dart';
import '../../../shared/widgets/skeleton.dart';

/// Why the app is asking someone to sign in: it decides what the sheet says.
enum AuthReason { join, save, chat }

/// Call this before anything that needs an account (Join, the heart, Message). Returns true at once when the
/// user is signed in. Otherwise it opens the sign-in sheet and, once they have signed in, returns true so the
/// caller can carry on with what they were doing; it returns false if they close the sheet.
Future<bool> requireAuth(WidgetRef ref, BuildContext context, AuthReason why) async {
  // The repository's stream always starts with the current session, so its first event is "who is signed in now".
  // (Asking the provider here would wait for a listener that a button press does not have.)
  final session = await ref.read(authRepositoryProvider).session.first;
  if (session != null) return true;
  if (!context.mounted) return false;
  return await showSignInSheet(context, reason: why) ?? false;
}

/// A new phone user has no name yet; a Google user arrives with one.
bool needsName(Session session) {
  final meta = session.user.userMetadata ?? const {};
  final name = (meta['full_name'] ?? meta['name']) as String?;
  return name == null || name.trim().isEmpty;
}

/// Shows [child] to signed-in users and [signedOut] to everyone else. While the session is still being
/// read it shows a spinner, so the sign-in prompt never flashes at someone who is signed in.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.signedOut, required this.child});

  final Widget signedOut;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(sessionProvider).when(
          loading: () => Scaffold(body: SafeArea(child: Skeleton.page())),
          error: (_, _) => signedOut,
          data: (session) => session == null ? signedOut : child,
        );
  }
}
