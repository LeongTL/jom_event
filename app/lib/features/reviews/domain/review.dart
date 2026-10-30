import 'package:flutter/foundation.dart';

import '../../../shared/models/event_summary.dart';

/// The four tags a review can carry, in the order the screen shows them (the database accepts only these).
const reviewTags = {
  'friendly_host': 'Friendly host',
  'good_value': 'Good value',
  'beginner_friendly': 'Beginner-friendly',
  'clean_venue': 'Clean venue',
};

/// A review I wrote (reviews.my_reviews).
@immutable
class Review {
  const Review({
    required this.id,
    required this.bookingId,
    required this.stars,
    required this.tags,
    required this.createdAt,
    this.body,
  });
  final String id, bookingId;
  final int stars;
  final List<String> tags;
  final String? body;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] as String,
    bookingId: j['booking_id'] as String,
    stars: (j['stars'] as num).toInt(),
    tags: [for (final t in j['tags'] as List) t as String],
    body: j['body'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String).toUtc(),
  );
}

/// One line of "What people said" (reviews.host_reviews): first name only.
@immutable
class HostReview {
  const HostReview({required this.firstName, required this.stars, this.body});
  final String firstName;
  final int stars;
  final String? body;

  factory HostReview.fromJson(Map<String, dynamic> j) => HostReview(
    firstName: j['attendee_first_name'] as String,
    stars: (j['stars'] as num).toInt(),
    body: j['body'] as String?,
  );
}

/// Everything on a host's public page.
@immutable
class HostPublic {
  const HostPublic({
    required this.name,
    required this.since,
    required this.verified,
    required this.ratingCount,
    required this.guests,
    required this.upcoming,
    required this.reviews,
    this.area,
    this.ratingAvg,
  });
  final String name;
  final String? area;
  final DateTime since;
  final bool verified;
  final double? ratingAvg; // null until the first review
  final int ratingCount, guests;
  final List<EventSummary> upcoming;
  final List<HostReview> reviews;
}

/// The database refused a review; [message] says why in words.
class ReviewError implements Exception {
  const ReviewError(this.code);
  final String code;

  String get message => switch (code) {
    'already_reviewed' => 'You already reviewed this event.',
    'event_not_completed' =>
      'You can review once the host has closed the event.',
    'not_attended' ||
    'not_owner' => 'Only events you attended can be reviewed.',
    'contact_info_not_allowed' =>
      'Please leave phone numbers and links out of your review.',
    _ => 'Could not send your review. Try again.',
  };

  @override
  String toString() => 'ReviewError($code)';
}
