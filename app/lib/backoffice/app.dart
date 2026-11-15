import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/calm.dart';
import 'access/access.dart';
import 'admin/applications_page.dart';
import 'auth/mfa_screen.dart';
import 'auth/signin_screen.dart';
import 'shell/frame.dart';
import 'shell/host_placeholder.dart';
import 'shell/not_authorised.dart';

/// The web back office. One window, no URL routes yet: the person's role decides what is shown.
class BackOfficeApp extends StatelessWidget {
  const BackOfficeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Jom back office',
    debugShowCheckedModeBanner: false,
    theme: calmTheme(),
    home: const _Gate(),
  );
}

class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.watch(shellProvider);
    return shell.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(adminAccessProvider),
            child: const Text("Couldn't load your access. Try again."),
          ),
        ),
      ),
      data: (s) => switch (s) {
        Shell.signIn => const SignInScreen(),
        Shell.mfa => const MfaScreen(),
        Shell.notAuthorised => const NotAuthorisedScreen(),
        Shell.host => const HostPlaceholder(),
        Shell.admin => const Frame(
          shellKey: 'bo-admin-shell',
          title: 'Applications',
          child: ApplicationsPage(),
        ),
      },
    );
  }
}
