import 'package:jom/features/people/data/people_repository.dart';
import 'package:jom/features/people/domain/person.dart';

/// In-memory stand-in for the people database. [taken] are usernames someone else holds.
class FakePeople implements PeopleRepository {
  FakePeople({
    this.username = 'meitan1234',
    this.taken = const {},
    this.people = const [],
    this.followersOf = const {},
    this.followingOf = const {},
    this.setError,
    Set<String> iFollow = const {},
  }) : _iFollow = {...iFollow};

  String? username;
  final Set<String> taken;
  final List<Person> people;
  final Map<String, List<Person>> followersOf, followingOf;
  final UsernameError? setError;
  final Set<String> _iFollow;
  final followed = <String>[];
  final unfollowed = <String>[];
  final searches = <String>[];
  final availabilityAsked = <String>[];

  @override
  Future<String?> myUsername() async => username;

  @override
  Future<bool> available(String u) async {
    availabilityAsked.add(u);
    return !taken.contains(u.toLowerCase());
  }

  @override
  Future<String> setUsername(String u) async {
    if (setError != null) throw setError!;
    username = u.trim().toLowerCase();
    return username!;
  }

  @override
  Future<List<Person>> search(String q) async {
    searches.add(q);
    return [
      for (final p in people)
        if (p.username.contains(q.toLowerCase()) ||
            p.name.toLowerCase().contains(q.toLowerCase()))
          p,
    ];
  }

  @override
  Future<Person?> person(String id) async =>
      people.where((p) => p.userId == id).firstOrNull;

  @override
  Future<FollowCounts> counts(String id) async => FollowCounts(
    followers: (followersOf[id]?.length ?? 0) + (_iFollow.contains(id) ? 1 : 0),
    following: followingOf[id]?.length ?? 0,
    iFollow: _iFollow.contains(id),
  );

  @override
  Future<void> follow(String id) async {
    followed.add(id);
    _iFollow.add(id);
  }

  @override
  Future<void> unfollow(String id) async {
    unfollowed.add(id);
    _iFollow.remove(id);
  }

  @override
  Future<List<Person>> followers(String id, {int offset = 0}) async =>
      (followersOf[id] ?? const []).skip(offset).take(peoplePageSize).toList();

  @override
  Future<List<Person>> following(String id, {int offset = 0}) async =>
      (followingOf[id] ?? const []).skip(offset).take(peoplePageSize).toList();
}
