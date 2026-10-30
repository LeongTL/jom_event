import 'package:jom/features/host/data/host_repository.dart';
import 'package:jom/features/host/domain/event_form_state.dart';
import 'package:jom/features/host/domain/host.dart';
import 'package:jom/features/host/domain/scan_controller.dart';

import 'fake_events.dart';

HostEventRow hostEvent(
  String id, {
  String status = 'published',
  int sold = 8,
  int cap = 12,
  DateTime? starts,
  int price = 3000,
}) {
  final s = starts ?? clock.add(const Duration(days: 3));
  return HostEventRow(
    id: id,
    title: 'Event $id',
    description: 'A gentle class',
    categories: const ['make'],
    area: 'Bangsar',
    venue: 'Deck 5',
    startsAt: status == 'draft' ? null : s,
    endsAt: status == 'draft' ? null : s.add(const Duration(hours: 2)),
    capacity: cap,
    priceSen: price,
    status: status,
    seatsSold: sold,
  );
}

HostProfile hostMe({String name = 'Mei Studio', DateTime? verifiedAt}) =>
    HostProfile(
      verifiedAt: verifiedAt,
      id: 'h1',
      name: name,
      area: 'Bangsar',
      holder: 'Mei Studio Sdn Bhd',
      bank: 'Maybank',
      accountNumber: '1234564821',
      ratingAvg: 4.8,
      ratingCount: 36,
    );

class FakeHost implements HostRepository {
  FakeHost({
    this.profile,
    List<HostEventRow>? events,
    this.dash,
    this.saveError,
    this.gross = 0,
    List<Guest>? guestRows,
    this.earn = const Earnings(gross: 0, gateway: 0, platform: 0, receives: 0),
    this.payoutsView = const Payouts(upcomingSen: 0, paidSen: 0, rows: []),
    this.scanReplies = const [],
  }) : guestRows = guestRows ?? [],
       rows = events ?? [];
  HostProfile? profile;
  final List<HostEventRow> rows;
  final HostDashboard? dash;
  final HostError? saveError;
  final int gross;
  final List<Guest> guestRows;
  final Earnings earn;
  final Payouts payoutsView;

  /// Answers to check-in calls, in order; a thrown value stands for no signal.
  final List<Object> scanReplies;

  final applied = <HostApplication>[];
  final saved = <(EventForm, String?)>[];
  final published = <String>[];
  final updated = <(String, String?, String?, int?)>[];
  final deleted = <String>[];
  final scanned = <String>[];
  final ticks = <(String, bool)>[];
  final completed = <String>[];

  @override
  Future<HostProfile?> me() async => profile;

  @override
  Future<void> apply(HostApplication a) async {
    applied.add(a);
    profile = hostMe(name: a.name);
  }

  @override
  Future<HostDashboard> dashboard() async =>
      dash ??
      HostDashboard(
        profile: profile ?? hostMe(),
        upcomingPayoutSen: 0,
        guests: 0,
      );

  @override
  Future<List<HostEventRow>> events(String status) async => [
    for (final r in rows)
      if (r.status == status) r,
  ];

  @override
  Future<HostEventRow?> event(String id) async =>
      rows.where((r) => r.id == id).firstOrNull;

  @override
  Future<String> saveDraft(EventForm f, {String? id}) async {
    if (saveError != null) throw saveError!;
    saved.add((f, id));
    return id ?? 'new1';
  }

  @override
  Future<void> publish(String id) async {
    if (saveError != null) throw saveError!;
    published.add(id);
  }

  @override
  Future<void> update(
    String id, {
    String? title,
    String? description,
    int? capacity,
  }) async {
    if (saveError != null) throw saveError!;
    updated.add((id, title, description, capacity));
  }

  @override
  Future<int> grossSen(String id) async => gross;

  @override
  Future<DeleteResult> delete(String id) async {
    deleted.add(id);
    return const DeleteResult(refunded: 0, released: 0);
  }

  @override
  Future<List<Guest>> guests(String eventId) async => guestRows;

  @override
  Future<void> setCheckedIn(String bookingId, bool value) async =>
      ticks.add((bookingId, value));

  @override
  Future<ScanResult> checkIn(String eventId, String token) async {
    scanned.add(token);
    final r = scanReplies[scanned.length - 1];
    if (r is ScanResult) return r;
    throw r;
  }

  @override
  Future<void> complete(String eventId) async => completed.add(eventId);

  @override
  Future<Earnings> earnings(String eventId) async => earn;

  @override
  Future<Payouts> payouts() async => payoutsView;
}
