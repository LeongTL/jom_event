import 'package:flutter/material.dart';

import '../../../shared/models/event_summary.dart';

/// One booking as bookings.my_bookings (or the table) returns it. The event fields are filled by my_bookings only;
/// the ticket and checkout read the full event from the event page provider instead.
@immutable
class Booking {
  const Booking({
    required this.id,
    required this.eventId,
    required this.people,
    required this.status,
    required this.ticketCode,
    required this.amountSen,
    this.holdExpiresAt,
    this.cancelCutoffAt,
    this.contactName,
    this.contactPhone,
    this.title,
    this.glyph,
    this.colorA,
    this.colorB,
    this.area,
    this.startsAt,
  });

  final String id, eventId, status, ticketCode; // status: held processing confirmed attended payment_failed cancelled expired no_show
  final int people, amountSen;
  final DateTime? holdExpiresAt, cancelCutoffAt, startsAt;
  final String? contactName, contactPhone, title, glyph, area;
  final Color? colorA, colorB;

  bool get isPaid => amountSen > 0;

  factory Booking.fromJson(Map<String, dynamic> j) {
    DateTime? t(String k) => j[k] == null ? null : DateTime.parse(j[k] as String).toUtc();
    return Booking(
      id: (j['booking_id'] ?? j['id']) as String,
      eventId: j['event_id'] as String,
      people: (j['people'] as num).toInt(),
      status: j['status'] as String,
      ticketCode: j['ticket_code'] as String,
      amountSen: (j['amount_sen'] as num).toInt(),
      holdExpiresAt: t('hold_expires_at'),
      cancelCutoffAt: t('cancel_cutoff_at'),
      contactName: j['contact_name'] as String?,
      contactPhone: j['contact_phone'] as String?,
      title: j['event_title'] as String?,
      glyph: j['event_glyph'] as String?,
      colorA: j['event_color_a'] == null ? null : parseHexColor(j['event_color_a'] as String, const Color(0xFF8B5CF6)),
      colorB: j['event_color_b'] == null ? null : parseHexColor(j['event_color_b'] as String, const Color(0xFFFF7AA8)),
      area: j['event_area'] as String?,
      startsAt: t('event_starts_at'),
    );
  }
}

/// What the gateway needs to take a payment (payments.start_payment).
@immutable
class PaymentSession {
  const PaymentSession({required this.attemptId, required this.reference, required this.amountSen, required this.expiresAt});
  final String attemptId, reference;
  final int amountSen;
  final DateTime expiresAt;

  factory PaymentSession.fromJson(Map<String, dynamic> j) => PaymentSession(
        attemptId: j['attempt_id'] as String,
        reference: j['reference'] as String,
        amountSen: (j['amount_sen'] as num).toInt(),
        expiresAt: DateTime.parse(j['expires_at'] as String).toUtc(),
      );
}

/// A refusal from the database ("sold_out", "hold_expired"...) with a sentence a person can read.
class BookingError implements Exception {
  BookingError(this.code);
  final String code;

  String get message => switch (code) {
        'sold_out' => 'Sorry, that just sold out.',
        'event_started' => 'This event has already started.',
        'event_not_available' => 'This event is no longer available.',
        'bookings_closed' => 'The host has closed bookings for this event.',
        'hold_expired' => 'Your spot was released because the time ran out.',
        'cancel_not_allowed' => 'The free cancellation window has passed.',
        _ => 'Something went wrong. Please try again.',
      };

  @override
  String toString() => 'BookingError($code)';
}
