import 'dart:math';

import 'host.dart';

enum EditMode { create, publishedEdit }

/// The spots stepper: 1 to 40, and a published event never goes below the seats already sold.
int clampSpots(int v, {required EditMode mode, int sold = 0}) =>
    v.clamp(mode == EditMode.publishedEdit ? max(1, sold) : 1, 40);

/// What the host types into the event form. [problem] mirrors the SQL publish rules; the server stays the authority.
class EventForm {
  const EventForm({
    this.title = '',
    this.description = '',
    this.categories = const [],
    this.area,
    this.venue = '',
    this.startsAt,
    this.endsAt,
    this.capacity = 12,
    this.priceSen = 0,
    this.cancelPolicy = '24h',
    this.acceptBookings = true,
  });

  factory EventForm.fromRow(HostEventRow r) => EventForm(
    title: r.title,
    description: r.description ?? '',
    categories: r.categories,
    area: r.area,
    venue: r.venue ?? '',
    startsAt: r.startsAt,
    endsAt: r.endsAt,
    capacity: r.capacity ?? 12,
    priceSen: r.priceSen ?? 0,
    cancelPolicy: r.cancelPolicy,
    acceptBookings: r.acceptBookings,
  );

  final String title, description, venue, cancelPolicy;
  final List<String> categories;
  final String? area;
  final DateTime? startsAt, endsAt;
  final int capacity, priceSen;
  final bool acceptBookings;

  EventForm copyWith({
    String? title,
    String? description,
    List<String>? categories,
    String? area,
    String? venue,
    DateTime? startsAt,
    DateTime? endsAt,
    int? capacity,
    int? priceSen,
    String? cancelPolicy,
    bool? acceptBookings,
  }) => EventForm(
    title: title ?? this.title,
    description: description ?? this.description,
    categories: categories ?? this.categories,
    area: area ?? this.area,
    venue: venue ?? this.venue,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    capacity: capacity ?? this.capacity,
    priceSen: priceSen ?? this.priceSen,
    cancelPolicy: cancelPolicy ?? this.cancelPolicy,
    acceptBookings: acceptBookings ?? this.acceptBookings,
  );

  /// Why this cannot be published yet, or null.
  String? problem(DateTime now) {
    if (title.trim().isEmpty) return 'Give your event a name';
    if (venue.trim().isEmpty || area == null) return 'Say where it is';
    if (startsAt == null || endsAt == null) return 'Pick a date and time';
    if (!endsAt!.isAfter(startsAt!)) return 'It must end after it starts';
    if (!startsAt!.isAfter(now)) return 'Pick a start time in the future';
    if (capacity < 1 || capacity > 40) return 'Spots must be 1 to 40';
    if (priceSen < 0) return 'Price cannot be negative';
    return null;
  }

  Map<String, dynamic> toPayload(String? id) => {
    'id': ?id,
    'title': title.trim(),
    'description': description.trim().isEmpty ? null : description.trim(),
    'categories': categories,
    'area': area,
    'venue': venue.trim().isEmpty ? null : venue.trim(),
    'starts_at': startsAt?.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'capacity': capacity,
    'price_sen': priceSen,
    'cancel_policy': cancelPolicy,
    'accept_bookings': acceptBookings,
  };
}
