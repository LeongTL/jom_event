import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/shared/models/event_summary.dart';

// A row shaped like events.feed / events.list_all returns it.
Map<String, dynamic> row([Map<String, dynamic> over = const {}]) => {
  'event_id': 'e1000000-0000-0000-0000-000000000001',
  'title': 'Sunset Yoga Deck',
  'glyph': '🧘',
  'color_a': '#11998e',
  'color_b': '#38ef7d',
  'starts_at': '2026-10-15T14:22:00+00:00',
  'ends_at': '2026-10-15T15:37:00+00:00',
  'price_sen': 2500,
  'area': 'Bangsar',
  'distance_km': 0.93,
  'is_live': false,
  'spots_left': 16,
  'score': 1.67,
  ...over,
};

void main() {
  test('fromJson reads a feed row', () {
    final e = EventSummary.fromJson(row());
    expect(e.id, 'e1000000-0000-0000-0000-000000000001');
    expect(e.title, 'Sunset Yoga Deck');
    expect(e.glyph, '🧘');
    expect(e.colorA, const Color(0xFF11998E));
    expect(e.colorB, const Color(0xFF38EF7D));
    expect(e.startsAt, DateTime.utc(2026, 10, 15, 14, 22));
    expect(e.endsAt, DateTime.utc(2026, 10, 15, 15, 37));
    expect(e.priceSen, 2500);
    expect(e.area, 'Bangsar');
    expect(e.distanceKm, 0.93);
    expect(e.isLive, false);
    expect(e.spotsLeft, 16);
    expect(e.score, 1.67);
    expect(e.isFree, false);
    expect(e.categories, isEmpty);
  });

  test('a time with an offset becomes the same instant', () {
    expect(
      EventSummary.fromJson(row({'starts_at': '2026-10-15T22:22:00+08:00'}))
          .startsAt,
      DateTime.utc(2026, 10, 15, 14, 22),
    );
  });

  test('numbers may arrive as whole numbers', () {
    final e = EventSummary.fromJson(
      row({'distance_km': 0, 'score': 4, 'price_sen': 0}),
    );
    expect(e.distanceKm, 0.0);
    expect(e.score, 4.0);
    expect(e.isFree, true);
  });

  test('no known location means no distance', () {
    expect(
      EventSummary.fromJson(row({'distance_km': null})).distanceKm,
      isNull,
    );
  });

  test(
    'a draft-like row without glyph or colours still gets something to draw',
    () {
      final e = EventSummary.fromJson(
        row({'glyph': null, 'color_a': null, 'color_b': null}),
      );
      expect(e.glyph, isNotEmpty);
      expect(e.colorA, isNot(e.colorB));
    },
  );

  test('a malformed colour falls back instead of crashing', () {
    final e = EventSummary.fromJson(
      row({'color_a': 'purple', 'color_b': '#12'}),
    );
    expect(e.colorA, isA<Color>());
    expect(e.colorB, isA<Color>());
  });

  test('list_all rows carry categories', () {
    expect(
      EventSummary.fromJson(
        row({
          'categories': ['make', 'meet'],
        }),
      ).categories,
      ['make', 'meet'],
    );
  });
}
