import 'package:jom/core/location.dart';
import 'package:jom/features/event/data/event_repository.dart';
import 'package:jom/features/event/domain/event_detail.dart';
import 'package:jom/shared/models/event_summary.dart';

// 14:00 in Kuala Lumpur on Wednesday 9 January 2030
final clock = DateTime.utc(2030, 1, 9, 6);

EventSummary sum(String id, {String? title, DateTime? starts, bool live = false, int price = 3000, List<String> cats = const ['make'], double lat = 3.1290, double lng = 101.6710}) {
  final s = starts ?? DateTime.utc(2030, 1, 12, 1); // Sat 12 Jan, 9am KL
  return EventSummary.fromJson({
    'event_id': id, 'title': title ?? 'Event $id', 'glyph': '🎉', 'color_a': '#11998e', 'color_b': '#38ef7d',
    'starts_at': s.toIso8601String(), 'ends_at': s.add(const Duration(hours: 2)).toIso8601String(),
    'price_sen': price, 'area': 'Bangsar', 'distance_km': 1.2, 'is_live': live, 'spots_left': 7, 'score': 1.0,
    'categories': cats, 'lat': lat, 'lng': lng, 'host_name': 'Mei Studio',
  });
}

EventDetail detailOf(EventSummary s, {String policy = '24h', String? source, bool bookable = true, bool ended = false, String? host = 'Mei Studio'}) =>
    EventDetail(
      summary: s, hostId: 'h1', hostName: host, ratingAvg: 4.8, ratingCount: 36, description: 'Bring a mat.', venue: 'Deck 5',
      lat: 3.1290, lng: 101.6710, cancelPolicy: policy, sourceUrl: source, isBookable: bookable, isEnded: ended,
    );

class FakeEvents implements EventRepository {
  FakeEvents({this.all = const [], this.details = const {}, Set<String>? hearts, this.saveDelay = Duration.zero, this.savedList = const []})
      : hearts = hearts ?? {};
  final List<EventSummary> all, savedList;
  final Map<String, EventDetail> details;
  final Set<String> hearts;
  final Duration saveDelay;
  final toggles = <String>[];
  final threads = <(String, String)>[];

  @override
  Future<List<EventSummary>> listAll(String category, LatLng at, int km) async => all;
  @override
  Future<List<EventSummary>> cards(List<String> ids, LatLng at) async => [
        for (final e in {for (final e in [...all, ...savedList, ...details.values.map((d) => d.summary)]) e.id: e}.values)
          if (ids.contains(e.id)) e,
      ];
  @override
  Future<EventDetail?> detail(String id, LatLng at) async => details[id];
  @override
  Future<Set<String>> savedIds() async => {...hearts};
  @override
  Future<List<EventSummary>> saved(LatLng at) async => savedList;
  @override
  Future<bool> toggleSave(String id) async {
    toggles.add(id);
    if (saveDelay > Duration.zero) await Future<void>.delayed(saveDelay);
    return hearts.contains(id) ? !hearts.remove(id) : hearts.add(id);
  }

  @override
  Future<String> openThread(String hostId, String eventId) async {
    threads.add((hostId, eventId));
    return 't1';
  }
}

