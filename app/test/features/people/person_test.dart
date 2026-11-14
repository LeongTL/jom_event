import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/people/domain/person.dart';

void main() {
  test('person_from_json_reads_all_fields', () {
    final p = Person.fromJson({
      'user_id': 'u2',
      'name': 'Studio Dave',
      'username': 'dave.host',
      'avatar_url': 'http://x/d.png',
      'is_host': true,
    });
    expect(
      (p.userId, p.name, p.username, p.avatarUrl, p.isHost),
      ('u2', 'Studio Dave', 'dave.host', 'http://x/d.png', true),
    );
  });

  test('person_from_json_allows_no_avatar', () {
    final p = Person.fromJson({
      'user_id': 'u3',
      'name': 'Bob',
      'username': 'bob',
      'avatar_url': null,
      'is_host': false,
    });
    expect(p.avatarUrl, isNull);
  });

  test('follow_counts_from_json_reads_numbers_and_flag', () {
    final c = FollowCounts.fromJson({
      'followers': 3,
      'following': 1,
      'i_follow': true,
    });
    expect((c.followers, c.following, c.iFollow), (3, 1, true));
  });

  test('username_error_maps_each_code', () {
    expect(
      UsernameError.fromMessage('username_invalid').message,
      contains('3 to 20'),
    );
    expect(
      UsernameError.fromMessage('username_reserved').message,
      'That username is not available.',
    );
    expect(
      UsernameError.fromMessage('username_taken').message,
      'Someone already has that username.',
    );
  });

  test('username_error_unknown_falls_back', () {
    expect(
      UsernameError.fromMessage('boom').message,
      'Could not save. Try again.',
    );
  });
}
