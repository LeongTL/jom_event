import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jom/features/booking/data/booking_repository.dart';
import 'package:jom/features/booking/data/payment_gateway_client.dart';
import 'package:jom/features/booking/domain/booking.dart';

Booking bk(
  String id, {
  String event = 'e1',
  String status = 'confirmed',
  int people = 1,
  int amount = 3000,
  DateTime? hold,
  DateTime? cutoff,
  String code = 'KLS-4821',
  String title = 'Batik Workshop',
  DateTime? starts,
}) => Booking(
  id: id,
  eventId: event,
  people: people,
  status: status,
  ticketCode: code,
  amountSen: amount,
  holdExpiresAt: hold,
  cancelCutoffAt: cutoff,
  contactName: 'Mei',
  contactPhone: '60123456789',
  title: title,
  glyph: '🎨',
  colorA: const Color(0xFF11998E),
  colorB: const Color(0xFF38EF7D),
  area: 'Bangsar',
  startsAt: starts,
);

/// Stands in for the database: bookings live in memory and the test plays the webhook with [setStatus].
class FakeBookings implements BookingRepository {
  FakeBookings({
    DateTime Function()? now,
    this.priceSen = 3000,
    this.createError,
    this.upcoming = const [],
    this.past = const [],
  }) : now = now ?? DateTime.now;

  final DateTime Function() now;
  final int priceSen; // per person
  final Object? createError;
  final List<Booking> upcoming, past;
  final byId = <String, Booking>{};
  final created = <(String, int, String, String)>[];
  final cancelled = <String>[];
  final payments = <String>[];
  final tokenAsked = <String>[];
  final _ctrls = <String, StreamController<Booking>>{};
  var _n = 0;
  Object? payError;
  Object? cancelFails;

  StreamController<Booking> _c(String id) =>
      _ctrls.putIfAbsent(id, () => StreamController<Booking>.broadcast());

  @override
  Future<Booking> create(
    String eventId,
    int people,
    String name,
    String phone,
  ) async {
    if (createError != null) throw createError!;
    created.add((eventId, people, name, phone));
    final id = 'b${++_n}';
    final paid = priceSen > 0;
    final b = bk(
      id,
      event: eventId,
      people: people,
      status: paid ? 'held' : 'confirmed',
      amount: priceSen * people,
      hold: paid ? now().add(const Duration(minutes: 15)) : null,
      cutoff: now().add(const Duration(days: 3)),
    );
    byId[id] = b;
    return b;
  }

  @override
  Future<PaymentSession> startPayment(String bookingId) async {
    if (payError != null) throw payError!;
    final b = byId[bookingId];
    if (b == null) throw BookingError('not_owner');
    payments.add(bookingId);
    return PaymentSession(
      attemptId: 'a-$bookingId',
      reference: 'KLS-4821-AB12',
      amountSen: b.amountSen,
      expiresAt: now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<void> cancel(String bookingId) async {
    if (cancelFails != null) throw cancelFails!;
    cancelled.add(bookingId);
    setStatus(bookingId, 'cancelled');
  }

  @override
  Future<List<Booking>> mine(String scope) async =>
      scope == 'upcoming' ? upcoming : past;

  @override
  Stream<Booking> watch(String bookingId) async* {
    if (byId[bookingId] != null) yield byId[bookingId]!;
    yield* _c(bookingId).stream;
  }

  @override
  Future<String> ticketToken(String bookingId) async {
    tokenAsked.add(bookingId);
    return '$bookingId.signature';
  }

  /// The webhook arriving: the booking changes and everyone watching hears it.
  void setStatus(String id, String status, {DateTime? hold}) {
    final o = byId[id]!;
    final b = Booking(
      id: o.id,
      eventId: o.eventId,
      people: o.people,
      status: status,
      ticketCode: o.ticketCode,
      amountSen: o.amountSen,
      holdExpiresAt: hold ?? o.holdExpiresAt,
      cancelCutoffAt: o.cancelCutoffAt,
      contactName: o.contactName,
      contactPhone: o.contactPhone,
      title: o.title,
      glyph: o.glyph,
      colorA: o.colorA,
      colorB: o.colorB,
      area: o.area,
      startsAt: o.startsAt,
    );
    byId[id] = b;
    _c(id).add(b);
  }
}

class FakeGateway implements PaymentGatewayClient {
  @override
  bool get canSimulate => true;

  final calls = <(String, String, String?)>[]; // attempt, method, simulate
  void Function()? onPay; // what the webhook does once the gateway is paid
  Duration delay = Duration.zero;

  @override
  Future<void> pay(
    PaymentSession session,
    String method, {
    String? simulate,
  }) async {
    calls.add((session.attemptId, method, simulate));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    onPay?.call();
  }
}
