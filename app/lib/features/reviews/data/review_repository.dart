import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/location.dart';
import '../../../core/supabase_client.dart';
import '../../event/data/event_repository.dart';
import '../domain/review.dart';

/// What the review screens read and write. Tests replace it; [SupabaseReviewRepository] is the real one.
abstract class ReviewRepository {
  /// Throws [ReviewError].
  Future<void> submit(
    String bookingId,
    int stars,
    List<String> tags,
    String body,
  );

  Future<List<Review>> mine();

  /// The public page of a host, or null when [hostId] is not a host. [at] is only used for the distance on the cards.
  Future<HostPublic?> host(String hostId, LatLng at);
}

class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _db => _ref.read(supabaseClientProvider);

  @override
  Future<void> submit(
    String bookingId,
    int stars,
    List<String> tags,
    String body,
  ) async {
    try {
      await _db
          .schema('reviews')
          .rpc(
            'submit_review',
            params: {
              'p_booking_id': bookingId,
              'p_stars': stars,
              'p_tags': tags,
              'p_body': body,
            },
          );
    } on PostgrestException catch (e) {
      throw ReviewError(e.message);
    }
  }

  @override
  Future<List<Review>> mine() async => [
    for (final r in await _db.schema('reviews').rpc('my_reviews') as List)
      Review.fromJson(r as Map<String, dynamic>),
  ];

  @override
  Future<HostPublic?> host(String hostId, LatLng at) async {
    final rows =
        await _db
                .schema('events')
                .rpc('host_page', params: {'p_host_id': hostId})
            as List;
    if (rows.isEmpty) return null;
    final h = rows.first as Map<String, dynamic>;
    final rating = await _db
        .schema('reviews')
        .from('host_rating')
        .select('average, count')
        .eq('host_id', hostId)
        .maybeSingle();
    final said =
        await _db
                .schema('reviews')
                .rpc('host_reviews', params: {'p_host_id': hostId})
            as List;
    final ids = [for (final id in h['upcoming'] as List) id as String];
    return HostPublic(
      name: h['host_name'] as String,
      area: h['area'] as String?,
      since: DateTime.parse(h['since'] as String).toUtc(),
      verified: h['verified'] as bool,
      ratingAvg: (rating?['average'] as num?)?.toDouble(),
      ratingCount: (rating?['count'] as num?)?.toInt() ?? 0,
      guests: (h['guests'] as num).toInt(),
      upcoming: ids.isEmpty
          ? const []
          : await _ref.read(eventRepositoryProvider).cards(ids, at),
      reviews: [
        for (final r in said) HostReview.fromJson(r as Map<String, dynamic>),
      ],
    );
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => SupabaseReviewRepository(ref),
);

final hostPublicProvider = FutureProvider.autoDispose
    .family<HostPublic?, String>((ref, hostId) async {
      final at = await ref.watch(homeCentreProvider.future);
      return ref.watch(reviewRepositoryProvider).host(hostId, at);
    });

final myReviewsProvider = FutureProvider.autoDispose<List<Review>>(
  (ref) => ref.watch(reviewRepositoryProvider).mine(),
);
