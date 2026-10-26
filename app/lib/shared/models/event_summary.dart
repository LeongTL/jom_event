import 'package:flutter/material.dart';

/// One event as the Home feed and View all return it (events.feed / events.list_all).
@immutable
class EventSummary {
  const EventSummary({
    required this.id,
    required this.title,
    required this.glyph,
    required this.colorA,
    required this.colorB,
    required this.startsAt,
    required this.endsAt,
    required this.priceSen,
    required this.area,
    required this.distanceKm,
    required this.isLive,
    required this.spotsLeft,
    required this.score,
    this.categories = const [],
    this.description,
    this.posterUrl,
    this.cancelPolicy,
    this.lat,
    this.lng,
    this.hostId,
    this.hostName,
    this.hostVerified = false,
    this.going = 0,
  });

  final String id;
  final String title;
  final String glyph;
  final Color colorA, colorB;
  final DateTime startsAt, endsAt; // instants, in UTC; show them in Asia/Kuala_Lumpur
  final int priceSen;
  final String? area;
  final double? distanceKm; // null when the user's location is unknown
  final bool isLive;
  final int spotsLeft;
  final double score;
  final List<String> categories;
  // the Calm card columns (events.event_card); the old saved-events query leaves them empty
  final String? description, posterUrl, cancelPolicy, hostId, hostName;
  final double? lat, lng;
  final bool hostVerified;
  final int going; // people who are in, a number only

  bool get isFree => priceSen == 0;

  factory EventSummary.fromJson(Map<String, dynamic> json) => EventSummary(
        id: json['event_id'] as String,
        title: json['title'] as String,
        glyph: (json['glyph'] as String?) ?? _fallbackGlyph,
        colorA: parseHexColor(json['color_a'] as String?, _fallbackA),
        colorB: parseHexColor(json['color_b'] as String?, _fallbackB),
        startsAt: DateTime.parse(json['starts_at'] as String).toUtc(),
        endsAt: DateTime.parse(json['ends_at'] as String).toUtc(),
        priceSen: (json['price_sen'] as num).toInt(),
        area: json['area'] as String?,
        distanceKm: (json['distance_km'] as num?)?.toDouble(),
        isLive: json['is_live'] as bool,
        spotsLeft: (json['spots_left'] as num).toInt(),
        score: (json['score'] as num).toDouble(),
        categories: [for (final c in (json['categories'] as List?) ?? const []) c as String],
        description: json['description'] as String?,
        posterUrl: json['poster_url'] as String?,
        cancelPolicy: json['cancel_policy'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        hostId: json['host_id'] as String?,
        hostName: json['host_name'] as String?,
        hostVerified: (json['host_verified'] as bool?) ?? false,
        going: (json['going'] as num?)?.toInt() ?? 0,
      );

  static const _fallbackGlyph = '✨';
  static const _fallbackA = Color(0xFF8B5CF6);
  static const _fallbackB = Color(0xFFFF7AA8);
}

/// '#rrggbb' to a colour, or [fallback] for anything else (a draft may have no colours yet).
Color parseHexColor(String? hex, Color fallback) {
  final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex ?? '');
  return m == null ? fallback : Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}
