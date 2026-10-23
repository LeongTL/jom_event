import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../event/domain/event_labels.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';
import '../../../shared/widgets/screen_parts.dart';

/// The Bookings tab: Upcoming and Past, each booking with its status. Tapping a confirmed booking opens its
/// ticket and an attended one opens its review; the rest open nothing.
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  bool _past = false;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    final scope = _past ? 'past' : 'upcoming';
    Widget seg(String label, bool past) => Expanded(
          child: GestureDetector(
            key: Key('seg-${past ? 'past' : 'upcoming'}'),
            onTap: () => setState(() => _past = past),
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _past == past ? k.accent : Colors.transparent, borderRadius: BorderRadius.circular(18)),
              child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _past == past ? k.accentInk : k.sheetInk.withValues(alpha: .7))),
            ),
          ),
        );
    return Scaffold(
      key: const Key('bookings-screen'),
      backgroundColor: k.sheet,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const BookingNav(title: 'Bookings', back: false),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: k.card, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [seg('Upcoming', false), seg('Past', true)]),
          ),
          ref.watch(myBookingsProvider(scope)).when(
                loading: () => const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator())),
                error: (_, _) => const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('Could not load your bookings. Check your connection.'))),
                data: (list) => list.isEmpty
                    ? Padding(padding: const EdgeInsets.only(top: 60), child: Center(child: Text(_past ? 'No past bookings' : 'No upcoming bookings')))
                    : Column(children: [for (final b in list) _Row(b)]),
              ),
          if (_past) Padding(padding: const EdgeInsets.only(top: 6), child: Center(child: Text('Tap an attended event to write a review', style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62))))),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.b);
  final Booking b;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    final route = switch (b.status) { 'confirmed' => '/booking/${b.id}/ticket', 'attended' => '/review/${b.id}', _ => null };
    return KeyedSubtree(
      key: Key('booking-${b.id}'),
      child: CardBox(
        onTap: route == null ? null : () => context.push(route),
        child: Row(children: [
          MiniArt(glyph: b.glyph ?? '✨', a: b.colorA ?? k.p3, b: b.colorB ?? k.p2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.title ?? 'Event', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (b.startsAt != null) Text(fullWhen(b.startsAt!), style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62))),
            ]),
          ),
          StatusPill.booking(b.status),
        ]),
      ),
    );
  }
}
