import 'package:jom/features/host/data/host_repository.dart';
import 'package:jom/features/host/domain/event_form_state.dart';
import 'package:jom/features/host/domain/host.dart';

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

HostProfile hostMe({String name = 'Mei Studio'}) => HostProfile(
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
  }) : rows = events ?? [];
  HostProfile? profile;
  final List<HostEventRow> rows;
  final HostDashboard? dash;
  final HostError? saveError;
  final int gross;

  final applied = <HostApplication>[];
  final saved = <(EventForm, String?)>[];
  final published = <String>[];
  final updated = <(String, String?, String?, int?)>[];
  final deleted = <String>[];

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
}
