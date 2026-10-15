import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/placeholder_screen.dart';
import '../data/auth_repository.dart';
import '../domain/phone_number.dart';

/// Profile until Task 20 builds it: who you are, and a way to sign out (so sign-in can be tried again).
class ProfilePlaceholder extends ConsumerWidget {
  const ProfilePlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value?.user;
    final name = (user?.userMetadata?['full_name'] ?? user?.userMetadata?['name']) as String?;
    final phone = user?.phone;
    return PlaceholderScreen(
      title: 'Profile',
      note: 'The full Profile (Task 20) replaces this. For now it shows who is signed in.',
      tabBarBelow: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (name != null && name.isNotEmpty) Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        if (phone != null && phone.isNotEmpty) Text(prettyMyPhone(phone.startsWith('+') ? phone : '+$phone')),
        if (user?.email != null && user!.email!.isNotEmpty) Text(user.email!),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: () => ref.read(authRepositoryProvider).signOut(), child: const Text('Sign out')),
      ]),
    );
  }
}
