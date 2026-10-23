import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/clock.dart';
import '../../../core/launcher.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../event/data/event_repository.dart';
import '../../event/domain/event_detail.dart';
import '../../event/domain/event_labels.dart';
import '../data/booking_repository.dart';
import '../data/calendar.dart';
import '../domain/booking.dart';
import 'booking_widgets.dart';
import 'cancel_sheet.dart';

/// The QR the host scans: the booking's signed token, fetched for its owner.
final ticketTokenProvider = FutureProvider.autoDispose.family<String, String>((ref, id) => ref.watch(bookingRepositoryProvider).ticketToken(id));

class TicketScreen extends ConsumerWidget {
  const TicketScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    final booking = ref.watch(bookingProvider(bookingId));
    return Scaffold(
      key: const Key('ticket-screen'),
      backgroundColor: k.sheet,
      body: booking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load this ticket. Check your connection.')),
        data: (b) => ref.watch(eventDetailProvider(b.eventId)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('Could not load this ticket. Check your connection.')),
              data: (d) => d == null ? const Center(child: Text("This event isn't available")) : _Ticket(b, d),
            ),
      ),
    );
  }
}

class _Ticket extends ConsumerWidget {
  const _Ticket(this.b, this.d);
  final Booking b;
  final EventDetail d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    final e = d.summary;
    final now = ref.read(nowProvider)();
    final canCancel = b.status == 'confirmed' && b.cancelCutoffAt != null && now.isBefore(b.cancelCutoffAt!);
    final active = b.status == 'confirmed';
    return Stack(children: [
      Positioned.fill(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          children: [
            Padding(
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 60),
              child: Column(children: [
                if (active) ...[
                  Container(width: 92, height: 92, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFF1FBF75), shape: BoxShape.circle), child: const Text('✓', style: TextStyle(color: Colors.white, fontSize: 44, height: 1))),
                  const SizedBox(height: 16),
                  const Text("You're in!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                  Text('A receipt was sent to your email.', style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62))),
                ] else ...[
                  const Text('Your ticket', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                  const SizedBox(height: 8),
                  StatusPill.booking(b.status),
                ],
              ]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: k.card, borderRadius: BorderRadius.circular(28)),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [e.colorA, e.colorB], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Stack(children: [
                    Positioned(right: -6, top: -4, child: Transform.rotate(angle: -10 * 3.14159 / 180, child: Text(e.glyph, style: const TextStyle(fontSize: 88, height: 1)))),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('YOUR TICKET', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                      const SizedBox(height: 4),
                      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 210), child: Text(e.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
                      const SizedBox(height: 4),
                      Text('${whenLabel(e.startsAt, now)} · ${e.area ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ]),
                  ]),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: k.line, width: 2))),
                  child: Column(children: [
                    ref.watch(ticketTokenProvider(b.id)).when(
                          loading: () => const SizedBox(width: 170, height: 170, child: Center(child: CircularProgressIndicator())),
                          error: (_, _) => const SizedBox(width: 170, height: 170, child: Center(child: Text('QR unavailable'))),
                          data: (token) => Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.white,
                            child: QrImageView(key: const Key('qr'), data: token, size: 154, semanticsLabel: 'Ticket QR code'),
                          ),
                        ),
                    const SizedBox(height: 4),
                    Text(b.ticketCode, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('Show this to the host on arrival', style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62))),
                  ]),
                ),
              ]),
            ),
            Row(children: [
              Expanded(child: _Small(key: const Key('ticket-directions'), label: '📍 Directions', onTap: () => _directions(ref))),
              const SizedBox(width: 12),
              Expanded(child: _Small(key: const Key('ticket-calendar'), label: '🗓 Add to calendar', onTap: () => ref.read(addToCalendarProvider)(d))),
            ]),
            if (canCancel)
              Center(
                child: TextButton(
                  key: const Key('ticket-cancel'),
                  onPressed: () => showCancelSheet(context, b),
                  child: Text('Cancel booking', style: TextStyle(color: k.sheetInk.withValues(alpha: .7), decoration: TextDecoration.underline)),
                ),
              ),
          ],
        ),
      ),
      CtaBar(children: [Expanded(child: KeyedSubtree(key: const Key('ticket-done'), child: JomButton(label: 'Done', onPressed: () => context.go('/explore'))))]),
    ]);
  }

  void _directions(WidgetRef ref) {
    final dest = d.lat != null && d.lng != null ? '${d.lat},${d.lng}' : [d.venue, d.summary.area].whereType<String>().join(' ');
    if (dest.isNotEmpty) ref.read(launchUrlProvider)(Uri.https('www.google.com', '/maps/dir/', {'api': '1', 'destination': dest}));
  }
}

class _Small extends StatelessWidget {
  const _Small({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: context.jom.card, borderRadius: BorderRadius.circular(19)), child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
      );
}
