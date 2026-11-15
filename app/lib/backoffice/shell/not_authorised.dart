import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../auth/signin_screen.dart' show AuthCard;

/// Signed in, but neither an admin nor an approved host.
class NotAuthorisedScreen extends ConsumerWidget {
  const NotAuthorisedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AuthCard(
    cardKey: 'bo-not-authorised',
    children: [
      const Text(
        'Not authorised',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      const Text(
        'This account is not an admin or an approved host. Hosts can apply in the Jom app.',
      ),
      TextButton(
        key: const Key('bo-signout'),
        onPressed: () => ref.read(authRepositoryProvider).signOut(),
        child: const Text('Sign out'),
      ),
    ],
  );
}
