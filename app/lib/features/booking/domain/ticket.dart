import 'package:flutter/material.dart';

import '../../../shared/models/event_summary.dart';
import '../../event/domain/event_labels.dart';
import 'booking.dart';

enum TicketScope { upcoming, past }

/// A booking with the event card it belongs to: what a ticket shows.
@immutable
class Ticket {
  const Ticket(this.booking, this.event);
  final Booking booking;
  final EventSummary event;

  String get id => booking.id;
  bool get processing => booking.status == 'processing';

  /// The ticket of a booking whose event the cards query no longer returns (cancelled or removed by the host).
  // shortcut: no host, categories or end time are known then, so the ticket shows the neutral colour and a 2 hour
  // slot; only a cancelled booking in Previous can end up here.
  factory Ticket.fromBooking(Booking b) => Ticket(
        b,
        EventSummary(
          id: b.eventId, title: b.title ?? 'Event', glyph: b.glyph ?? '', colorA: b.colorA ?? const Color(0xFF8B5CF6),
          colorB: b.colorB ?? const Color(0xFFFF7AA8), startsAt: b.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          endsAt: (b.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)).add(const Duration(hours: 2)),
          priceSen: 0, area: b.area, distanceKm: null, isLive: false, spotsLeft: 0, score: 0,
        ),
      );
}

/// Tickets grouped by the day they start, "Today" first, then in date order. The keys are the group labels:
/// "TODAY · WED 21 OCT" for today and "SAT 24 OCT" for any other day.
Map<String, List<Ticket>> groupByDay(List<Ticket> tickets, DateTime now) {
  final sorted = [...tickets]..sort((a, b) => a.event.startsAt.compareTo(b.event.startsAt));
  final groups = <String, List<Ticket>>{};
  for (final t in sorted) {
    final date = dateLabel(t.event.startsAt).toUpperCase();
    final key = dayLabel(t.event.startsAt, now) == 'Today' ? 'TODAY · $date' : date;
    (groups[key] ??= []).add(t);
  }
  return groups;
}
