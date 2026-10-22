import 'package:flutter/foundation.dart';

import '../../../shared/models/event_summary.dart';

/// One event page (events.event_detail): the poster fields plus what only the page shows.
@immutable
class EventDetail {
  const EventDetail({
    required this.summary,
    required this.hostId,
    required this.hostName,
    required this.ratingAvg,
    required this.ratingCount,
    required this.description,
    required this.venue,
    required this.lat,
    required this.lng,
    required this.cancelPolicy,
    required this.sourceUrl,
    required this.isBookable,
    required this.isEnded,
  });

  final EventSummary summary;
  final String hostId;
  final String? hostName;
  final double? ratingAvg; // null until the host has a review
  final int ratingCount;
  final String? description, venue, sourceUrl;
  final double? lat, lng;
  final String cancelPolicy; // 24h | 48h | 7d | none
  final bool isBookable; // takes bookings and costs money: the paid page; otherwise the free page
  final bool isEnded;

  factory EventDetail.fromJson(Map<String, dynamic> j) => EventDetail(
        summary: EventSummary.fromJson(j),
        hostId: j['host_id'] as String,
        hostName: j['host_name'] as String?,
        ratingAvg: (j['rating_avg'] as num?)?.toDouble(),
        ratingCount: (j['rating_count'] as num).toInt(),
        description: j['description'] as String?,
        venue: j['venue'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        cancelPolicy: j['cancel_policy'] as String,
        sourceUrl: j['source_url'] as String?,
        isBookable: j['is_bookable'] as bool,
        isEnded: j['is_ended'] as bool,
      );
}
