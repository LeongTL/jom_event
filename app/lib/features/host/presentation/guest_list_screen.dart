import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../data/host_repository.dart';
import 'host_parts.dart';

/// Host mode: who has paid (/host-mode/events/:id/guests).
class GuestListScreen extends ConsumerWidget {
  const GuestListScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(hostEventProvider(id)).value;
    final earnings = ref.watch(hostEarningsProvider(id)).value;
    return Scaffold(
      key: const Key('guest-list'),
      backgroundColor: Calm.bg,
      body: ref
          .watch(hostGuestsProvider(id))
          .when(
            loading: hostLoading,
            error: (_, _) => hostFailed('the guest list'),
            data: (guests) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                const BookingNav(title: 'Guest list'),
                Text(
                  event?.title ?? '',
                  style: const TextStyle(
                    fontFamily: Calm.serif,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 14),
                  child: Text(
                    '${guests.fold(0, (n, g) => n + g.people)} joined · ${rm(earnings?.gross ?? 0)} gross',
                    style: const TextStyle(color: Calm.mut),
                  ),
                ),
                if (guests.isEmpty)
                  const Text(
                    'No guests yet.',
                    style: TextStyle(color: Calm.mut),
                  ),
                for (final g in guests)
                  CardBox(
                    gap: 8,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${g.people} ${g.people == 1 ? 'person' : 'people'} · ${g.code}',
                                style: const TextStyle(
                                  color: Calm.mut,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _Chip(g.checkedIn ? 'Checked in' : 'Paid', g.checkedIn),
                      ],
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.on);
  final String text;
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: on ? Calm.okSoft : Calm.chip,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: on ? Calm.ok : Calm.mut,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
