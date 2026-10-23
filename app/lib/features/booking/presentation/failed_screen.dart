import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../event/domain/event_labels.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';
import '../domain/hold_timer.dart';
import 'booking_widgets.dart';

/// Payment failed: the seat stays held for what is left of the 15 minutes. Try again reuses the hold; Give up
/// releases it. When the hold has run out the screen says the spot was released instead.
class FailedScreen extends ConsumerWidget {
  const FailedScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    final b = ref.watch(bookingProvider(bookingId)).value;
    final now = ref.read(nowProvider);
    final live = b != null && b.status == 'payment_failed' && (b.holdExpiresAt?.isAfter(now()) ?? false);
    Widget icon(String glyph, Color c) => Container(width: 92, height: 92, alignment: Alignment.center, decoration: BoxDecoration(color: c, shape: BoxShape.circle), child: Text(glyph, style: const TextStyle(color: Colors.white, fontSize: 44, height: 1)));
    return Scaffold(
      key: const Key('failed-screen'),
      backgroundColor: k.sheet,
      body: b == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 44),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    icon('!', const Color(0xFFFF5A67)),
                    const SizedBox(height: 24),
                    Text(live ? "Payment didn't go through" : 'Spot released', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (live)
                      StreamBuilder<Duration>(
                        stream: holdTimer(b.holdExpiresAt!, now),
                        builder: (_, snap) => Text(
                          "Your spot is held for another ${countdown(snap.data ?? b.holdExpiresAt!.difference(now()))}. If any money left your account, it's refunded automatically.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62)),
                        ),
                      )
                    else
                      Text(BookingError('hold_expired').message, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62))),
                  ]),
                ),
              ),
              CtaBar(column: true, children: [
                if (live) ...[
                  KeyedSubtree(key: const Key('try-again'), child: JomButton(label: 'Try again', onPressed: () => context.pushReplacement('/booking/$bookingId/gateway'))),
                  TextButton(key: const Key('give-up'), onPressed: () => _giveUp(context, ref), child: const Text('Give up')),
                ] else
                  KeyedSubtree(key: const Key('back-to-event'), child: JomButton(label: 'Back to the event', onPressed: () => context.go('/event/${b.eventId}'))),
              ]),
            ]),
    );
  }

  Future<void> _giveUp(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(bookingRepositoryProvider).cancel(bookingId);
    } catch (_) {
      // already released (the hold ran out): going home is still right
    }
    if (context.mounted) context.go('/explore');
  }
}
