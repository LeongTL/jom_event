import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/event/domain/event_detail.dart';

// A row exactly as events.event_detail returns it (copied from staging): no score, no categories-free fields.
const row = {
  'event_id': 'd66d95f1-e189-413c-9121-81208bf3cf9d',
  'host_id': 'd5eed000-0000-4000-8000-000000000001',
  'host_name': 'KLCC Pokémon Club',
  'rating_avg': null,
  'rating_count': 0,
  'title': 'Pokémon Trade Night',
  'description': 'Bring your binder.',
  'venue': 'KLCC Pokémon Club, KLCC',
  'glyph': '🎴',
  'color_a': '#ff5f6d',
  'color_b': '#ffc371',
  'starts_at': '2026-10-23T07:04:26.884487+00:00',
  'ends_at': '2026-10-23T09:34:26.884487+00:00',
  'price_sen': 0,
  'area': 'KLCC',
  'lat': 3.1553,
  'lng': 101.7122,
  'distance_km': 5.42926988510857,
  'is_live': true,
  'is_ended': false,
  'spots_left': 12,
  'categories': ['meet'],
  'cancel_policy': '24h',
  'source_url': null,
  'is_bookable': false,
  'poster_url': null,
  'going': 5,
  'host_verified': true,
  'host_event_count': 38,
};

void main() {
  test('EventDetail reads a real event_detail row', () {
    final d = EventDetail.fromJson(row);
    expect(d.summary.title, 'Pokémon Trade Night');
    expect(d.summary.spotsLeft, 12);
    expect(d.summary.distanceKm, closeTo(5.43, .01));
    expect(d.hostName, 'KLCC Pokémon Club');
    expect(d.ratingAvg, isNull);
    expect(d.isBookable, isFalse);
    expect(d.sourceUrl, isNull);
  });

  test('it also reads the going count, the host tick, the events hosted and the poster', () {
    final d = EventDetail.fromJson({
      ...row,
      'poster_url': 'https://x.test/p.jpg',
    });
    expect(d.summary.going, 5);
    expect(d.summary.hostVerified, isTrue);
    expect(d.summary.posterUrl, 'https://x.test/p.jpg');
    expect(d.hostEventCount, 38);
  });

  test('a rated host and a paid event read too', () {
    final d = EventDetail.fromJson({
      ...row,
      'rating_avg': 4.8,
      'rating_count': 36,
      'price_sen': 3000,
      'is_bookable': true,
      'source_url': 'https://x.test',
    });
    expect(d.ratingAvg, 4.8);
    expect(d.ratingCount, 36);
    expect(d.summary.priceSen, 3000);
    expect(d.sourceUrl, 'https://x.test');
  });
}
