import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/phone_number.dart';
import '../../host/data/host_repository.dart';

/// Who I am and the places to go from here. Signed-out visitors never see it (the tab shows the sign-in prompt).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final go = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('Your profile, chats and saved events are erased for good. Past bookings stay on record without your name.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep my account')),
          TextButton(key: const Key('confirm-delete'), onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete', style: TextStyle(color: Calm.bad))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      go.go('/explore');
    } on AccountDeleteRefused catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(e.reason == 'host_has_active_events'
            ? 'You still have events with guests. Finish or cancel them first, then try again.'
            : 'You still have a payout on its way. Wait for it to arrive, then try again.'),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not delete your account. Check your connection and try again.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).value?.user;
    final meta = user?.userMetadata;
    final name = ((meta?['full_name'] ?? meta?['name']) as String?)?.trim();
    final phone = user?.phone;
    final label = (name != null && name.isNotEmpty) ? name : (user?.email ?? 'Guest');

    Widget row(String text, VoidCallback onTap, {Color? ink}) => CardBox(
          gap: 8,
          onTap: onTap,
          child: Row(children: [
            Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w500, color: ink))),
            const Text('›', style: TextStyle(color: Calm.mut, fontSize: 18)),
          ]),
        );

    return Scaffold(
      key: const Key('profile-screen'),
      backgroundColor: Calm.bg,
      body: ListView(padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 8, 20, 130), children: [
        const Text('Profile', style: TextStyle(fontFamily: Calm.serif, fontSize: 30, fontWeight: FontWeight.w600)),
        const SizedBox(height: 18),
        Center(
          child: Column(children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: Calm.accSoft, shape: BoxShape.circle),
              child: Text(label.characters.first.toUpperCase(), style: const TextStyle(fontFamily: Calm.serif, fontSize: 32, color: Calm.acc)),
            ),
            const SizedBox(height: 10),
            Text(label, key: const Key('profile-name'), style: const TextStyle(fontFamily: Calm.serif, fontSize: 22, fontWeight: FontWeight.w500)),
            if (phone != null && phone.isNotEmpty) Text(prettyMyPhone(phone.startsWith('+') ? phone : '+$phone'), style: const TextStyle(color: Calm.mut)),
          ]),
        ),
        const SizedBox(height: 20),
        row('My reviews', () => context.push('/my-reviews')),
        row('Notifications', () => context.push('/notifications')),
        row('Help & support', () => context.push('/help')),
        row('Terms & privacy', () => context.push('/legal')),
        const SizedBox(height: 6),
        GestureDetector(
          key: const Key('host-mode-card'),
          onTap: () async {
            final go = GoRouter.of(context);
            go.go(await ref.read(hostRepositoryProvider).me() == null ? '/host-mode/apply' : '/host-mode/home');
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Calm.acc, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Switch to Host mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  Text('Run your own events', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                ]),
              ),
              Text('→', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        row('Sign out', () async {
          final go = GoRouter.of(context);
          await ref.read(authRepositoryProvider).signOut();
          go.go('/explore');
        }),
        row('Delete account', () => _delete(context, ref), ink: Calm.bad),
      ]),
    );
  }
}
