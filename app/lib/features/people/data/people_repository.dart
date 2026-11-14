import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../domain/person.dart';

/// What the people screens read and write. Tests replace it; [SupabasePeopleRepository] is the real one.
abstract class PeopleRepository {
  /// My own username, or null when signed out.
  Future<String?> myUsername();
  Future<bool> available(String username);

  /// Saves and returns the cleaned username. Throws [UsernameError].
  Future<String> setUsername(String username);
  Future<List<Person>> search(String query);

  /// Null when [userId] has no public page (not a host and I am signed out, or an erased account).
  Future<Person?> person(String userId);
  Future<FollowCounts> counts(String userId);
  Future<void> follow(String userId);
  Future<void> unfollow(String userId);
  Future<List<Person>> followers(String userId, {int offset = 0});
  Future<List<Person>> following(String userId, {int offset = 0});
}

const peoplePageSize = 20;

class SupabasePeopleRepository implements PeopleRepository {
  SupabasePeopleRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _db => _ref.read(supabaseClientProvider);

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) =>
      _db.schema('identity').rpc(fn, params: params);

  List<Person> _people(dynamic rows) => [
    for (final r in rows as List) Person.fromJson(r as Map<String, dynamic>),
  ];

  @override
  Future<String?> myUsername() async {
    final id = _db.auth.currentUser?.id;
    if (id == null) return null;
    final row = await _db
        .schema('identity')
        .from('profiles')
        .select('username')
        .eq('user_id', id)
        .maybeSingle();
    return row?['username'] as String?;
  }

  @override
  Future<bool> available(String username) async =>
      await _rpc('username_available', {'p_username': username}) as bool;

  @override
  Future<String> setUsername(String username) async {
    try {
      return await _rpc('set_username', {'p_username': username}) as String;
    } on PostgrestException catch (e) {
      throw UsernameError.fromMessage(e.message);
    }
  }

  @override
  Future<List<Person>> search(String query) async =>
      _people(await _rpc('search_people', {'p_query': query}));

  @override
  Future<Person?> person(String userId) async {
    final rows = _people(await _rpc('person', {'p_user_id': userId}));
    return rows.firstOrNull;
  }

  @override
  Future<FollowCounts> counts(String userId) async {
    final rows = await _rpc('follow_counts', {'p_user_id': userId}) as List;
    return FollowCounts.fromJson(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> follow(String userId) async {
    await _rpc('follow', {'p_user_id': userId});
  }

  @override
  Future<void> unfollow(String userId) async {
    await _rpc('unfollow', {'p_user_id': userId});
  }

  @override
  Future<List<Person>> followers(String userId, {int offset = 0}) async =>
      _people(
        await _rpc('list_followers', {
          'p_user_id': userId,
          'p_limit': peoplePageSize,
          'p_offset': offset,
        }),
      );

  @override
  Future<List<Person>> following(String userId, {int offset = 0}) async =>
      _people(
        await _rpc('list_following', {
          'p_user_id': userId,
          'p_limit': peoplePageSize,
          'p_offset': offset,
        }),
      );
}

final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => SupabasePeopleRepository(ref),
);

final myUsernameProvider = FutureProvider.autoDispose<String?>(
  (ref) => ref.watch(peopleRepositoryProvider).myUsername(),
);

final personProvider = FutureProvider.autoDispose.family<Person?, String>(
  (ref, id) => ref.watch(peopleRepositoryProvider).person(id),
);

final followCountsProvider = FutureProvider.autoDispose
    .family<FollowCounts, String>(
      (ref, id) => ref.watch(peopleRepositoryProvider).counts(id),
    );
