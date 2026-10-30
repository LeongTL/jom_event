import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../data/host_repository.dart';
import 'host_parts.dart';

/// Host mode, Profile tab.
class HostProfileScreen extends ConsumerWidget {
  const HostProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget row(String text, String path) => CardBox(
      gap: 8,
      onTap: () => context.push(path),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text('›', style: TextStyle(color: Calm.mut, fontSize: 18)),
        ],
      ),
    );
    return Scaffold(
      key: const Key('host-profile'),
      backgroundColor: Calm.bg,
      body: ref
          .watch(hostMeProvider)
          .when(
            loading: hostLoading,
            error: (_, _) => hostFailed('your profile'),
            data: (me) => ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 8,
                20,
                130,
              ),
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    fontFamily: Calm.serif,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                if (me != null) ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Calm.accSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            me.name.characters.first.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: Calm.serif,
                              fontSize: 32,
                              color: Calm.acc,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          me.name,
                          style: const TextStyle(
                            fontFamily: Calm.serif,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          me.ratingAvg == null
                              ? 'New host'
                              : '★ ${me.ratingAvg} · ${me.ratingCount} reviews',
                          style: const TextStyle(color: Calm.mut),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  row('Payout account', '/host-mode/payout-account'),
                  row('View public profile', '/host/${me.id}'),
                ],
                const SizedBox(height: 6),
                GestureDetector(
                  key: const Key('attendee-mode-card'),
                  onTap: () => context.go('/explore'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Calm.acc,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Switch to Attendee mode',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
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
              ],
            ),
          ),
    );
  }
}
