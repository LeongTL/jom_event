import 'package:jom/core/location.dart';
import 'package:jom/features/reviews/data/review_repository.dart';
import 'package:jom/features/reviews/domain/review.dart';

class FakeReviews implements ReviewRepository {
  FakeReviews({
    this.mineList = const [],
    this.hosts = const {},
    this.submitError,
    this.submitDelay = Duration.zero,
  });
  final List<Review> mineList;
  final Map<String, HostPublic> hosts;
  final Object? submitError;
  final Duration submitDelay;
  final submitted = <(String, int, List<String>, String)>[];

  @override
  Future<void> submit(
    String bookingId,
    int stars,
    List<String> tags,
    String body,
  ) async {
    if (submitDelay > Duration.zero) await Future<void>.delayed(submitDelay);
    if (submitError != null) throw submitError!;
    submitted.add((bookingId, stars, tags, body));
  }

  @override
  Future<List<Review>> mine() async => mineList;

  @override
  Future<HostPublic?> host(String hostId, LatLng at) async => hosts[hostId];
}
