import 'package:flutter/foundation.dart';

/// Someone you can find and follow (identity.search_people, person, list_followers, list_following).
@immutable
class Person {
  const Person({
    required this.userId,
    required this.name,
    required this.username,
    required this.isHost,
    this.avatarUrl,
  });
  final String userId, name, username;
  final String? avatarUrl;
  final bool isHost;

  factory Person.fromJson(Map<String, dynamic> j) => Person(
    userId: j['user_id'] as String,
    name: j['name'] as String,
    username: j['username'] as String,
    avatarUrl: j['avatar_url'] as String?,
    isHost: j['is_host'] as bool,
  );
}

@immutable
class FollowCounts {
  const FollowCounts({
    required this.followers,
    required this.following,
    required this.iFollow,
  });
  final int followers, following;
  final bool iFollow;

  factory FollowCounts.fromJson(Map<String, dynamic> j) => FollowCounts(
    followers: (j['followers'] as num).toInt(),
    following: (j['following'] as num).toInt(),
    iFollow: j['i_follow'] as bool,
  );
}

/// The database refused a username; [message] says why in words.
class UsernameError implements Exception {
  const UsernameError(this.code);
  final String code;

  factory UsernameError.fromMessage(String m) => UsernameError(
    const {'username_invalid', 'username_reserved', 'username_taken'}.firstWhere(
      m.contains,
      orElse: () => 'other',
    ),
  );

  String get message => switch (code) {
    'username_invalid' =>
      'Use 3 to 20 letters, numbers, _ or . (not at the start or end, never two dots in a row).',
    'username_reserved' => 'That username is not available.',
    'username_taken' => 'Someone already has that username.',
    _ => 'Could not save. Try again.',
  };
}
