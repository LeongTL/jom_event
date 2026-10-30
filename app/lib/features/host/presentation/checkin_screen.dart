import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../data/host_repository.dart';
import '../domain/host.dart';
import 'complete_sheet.dart';

/// Host mode: the manual check-in list (/host-mode/events/:id/checkin), the fallback when scanning is not possible.
/// Ticks and unticks until the event is completed.
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  final _ticked =
      <
        String,
        bool
      >{}; // what the host just tapped, ahead of the server's answer
  String? _error;

  Future<void> _toggle(Guest g, bool now) async {
    setState(() {
      _ticked[g.bookingId] = !now;
      _error = null;
    });
    try {
      await ref.read(hostRepositoryProvider).setCheckedIn(g.bookingId, !now);
      ref.invalidate(hostGuestsProvider(widget.id));
    } on HostError catch (e) {
      if (!mounted) return;
      setState(() {
        _ticked.remove(g.bookingId);
        _error = e.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final guests =
        ref.watch(hostGuestsProvider(widget.id)).value ?? const <Guest>[];
    final event = ref.watch(hostEventProvider(widget.id)).value;
    final locked = event?.status == 'ended';
    final over =
        event?.endsAt != null &&
        !ref.watch(nowProvider)().isBefore(event!.endsAt!);
    bool on(Guest g) => _ticked[g.bookingId] ?? g.checkedIn;
    final total = guests.fold(0, (n, g) => n + g.people);
    final done = guests.where(on).fold(0, (n, g) => n + g.people);
    // the scanner under this screen asks for light status-bar icons; this one is on a light background
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        key: const Key('checkin-screen'),
        backgroundColor: Calm.bg,
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
              children: [
                const BookingNav(title: 'Check-in'),
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    child: SizedBox(
                      key: const Key('checkin-ring'),
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: total == 0 ? 0 : done / total,
                              strokeWidth: 7,
                              color: Calm.acc,
                              backgroundColor: const Color(0xFFE8E3DA),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$done / $total',
                                style: const TextStyle(
                                  fontFamily: Calm.serif,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Text(
                                'checked in',
                                style: TextStyle(color: Calm.mut, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Calm.bad,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                for (final g in guests)
                  CardBox(
                    key: Key('guest-${g.bookingId}'),
                    gap: 8,
                    onTap: locked ? null : () => _toggle(g, on(g)),
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
                                '${g.code} · ${g.people} ${g.people == 1 ? 'person' : 'people'}',
                                style: const TextStyle(
                                  color: Calm.mut,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: on(g) ? Calm.ok : Colors.transparent,
                            border: Border.all(
                              color: on(g) ? Calm.ok : Calm.line,
                              width: 2,
                            ),
                          ),
                          child: on(g)
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (!locked && event != null)
              CtaBar(
                children: [
                  Expanded(
                    flex: 2,
                    child: JomButton(
                      label: 'Scan',
                      primary: false,
                      onPressed: () =>
                          context.push('/host-mode/events/${widget.id}/scan'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: JomButton(
                      label: 'Mark as completed',
                      onPressed: over
                          ? () => completeAndLeave(
                              context,
                              ref,
                              event,
                              guests.where((g) => !on(g)).length,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
