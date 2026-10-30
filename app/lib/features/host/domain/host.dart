/// A refusal from the server, as the code it raised ('contact_info_not_allowed', ...). [text] is the same in words.
class HostError implements Exception {
  const HostError(this.code);
  final String code;

  String get text => switch (code) {
    'contact_info_not_allowed' => "Phone numbers and social handles aren't allowed in the title or description.",
    'locked_after_guests' => 'Date, place, price and refund window are locked once guests have joined.',
    'capacity_below_seats_sold' =>
      'Spots cannot go below the number already joined.',
    'starts_in_past' => 'Pick a start time in the future.',
    'invalid_times' => 'The event must end after it starts.',
    'event_started' =>
      'This event has already started, so it cannot be deleted.',
    'details_required' =>
      'Fill in every detail except the business registration.',
    _ => 'Something went wrong. Check your connection and try again.',
  };

  @override
  String toString() => 'HostError($code)';
}

class HostApplication {
  const HostApplication({
    required this.name,
    required this.area,
    this.bio,
    required this.holder,
    required this.bank,
    required this.accountNumber,
    this.ssm,
  });
  final String name, area, holder, bank, accountNumber;
  final String? bio, ssm;
}

class HostProfile {
  const HostProfile({
    required this.id,
    required this.name,
    required this.area,
    this.bio,
    this.ssm,
    required this.holder,
    required this.bank,
    required this.accountNumber,
    this.ratingAvg,
    this.ratingCount = 0,
  });
  final String id, name, area, holder, bank, accountNumber;
  final String? bio, ssm;
  final double? ratingAvg;
  final int ratingCount;

  /// "Maybank ••4821"
  String get accountLabel =>
      '$bank ••${accountNumber.length > 4 ? accountNumber.substring(accountNumber.length - 4) : accountNumber}';
}

class HostEventRow {
  const HostEventRow({
    required this.id,
    required this.title,
    this.description,
    this.categories = const [],
    this.area,
    this.venue,
    this.startsAt,
    this.endsAt,
    this.capacity,
    this.priceSen,
    this.cancelPolicy = '24h',
    this.acceptBookings = true,
    required this.status,
    this.seatsSold = 0,
  });

  factory HostEventRow.fromJson(Map<String, dynamic> j) => HostEventRow(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String?,
    categories: [for (final c in j['categories'] as List) c as String],
    area: j['area'] as String?,
    venue: j['venue'] as String?,
    startsAt: j['starts_at'] == null
        ? null
        : DateTime.parse(j['starts_at'] as String).toUtc(),
    endsAt: j['ends_at'] == null
        ? null
        : DateTime.parse(j['ends_at'] as String).toUtc(),
    capacity: (j['capacity'] as num?)?.toInt(),
    priceSen: (j['price_sen'] as num?)?.toInt(),
    cancelPolicy: j['cancel_policy'] as String,
    acceptBookings: j['accept_bookings'] as bool,
    status: j['status'] as String,
    seatsSold: (j['seats_sold'] as num).toInt(),
  );

  final String id, title, status, cancelPolicy;
  final String? description, area, venue;
  final List<String> categories;
  final DateTime? startsAt, endsAt;
  final int? capacity, priceSen;
  final bool acceptBookings;
  final int seatsSold;
}

class HostDashboard {
  const HostDashboard({
    required this.profile,
    required this.upcomingPayoutSen,
    required this.guests,
    this.next,
  });
  final HostProfile profile;
  final int upcomingPayoutSen;

  /// People booked into the host's published events.
  final int guests;
  final HostEventRow? next;
}

class DeleteResult {
  const DeleteResult({required this.refunded, required this.released});
  final int refunded, released;
}
