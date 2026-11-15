import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/flags/flags_repository.dart';
import '../../../core/theme/calm.dart';
import '../../host/data/host_repository.dart';
import '../../host/domain/host_status.dart';

/// The Profile card that follows the host application: register, under review, switch to Host mode, apply again, or
/// paused. Nothing at all while the host entrance flag is off, or while the status is still loading.
class HostCard extends ConsumerWidget {
  const HostCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(hostEntryEnabledProvider).value != true) {
      return const SizedBox.shrink();
    }
    final s = ref.watch(hostStatusProvider).value;
    if (s == null) return const SizedBox.shrink();
    final (title, sub, go) = switch (s.state) {
      HostState.none => (
        'Register as Event owner',
        'Run your own events',
        '/host-mode/apply',
      ),
      HostState.pending => (
        'Application under review',
        'We will tell you when it is decided',
        null,
      ),
      HostState.approved => (
        'Switch to Host mode',
        'Run your own events',
        '/host-mode/home',
      ),
      HostState.rejected => (
        'Apply again',
        s.reason ?? 'Your application was not approved',
        '/host-mode/apply',
      ),
      HostState.suspended => (
        'Your host access is paused. Contact support',
        'You keep your guest account',
        null,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: GestureDetector(
        key: Key('host-card-${s.state.name}'),
        onTap: go == null ? null : () => context.go(go),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: go == null ? Calm.mut : Calm.acc,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (go != null)
                const Text(
                  '→',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
