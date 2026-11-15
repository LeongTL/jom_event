import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/chat/domain/chat.dart';
import 'package:jom/features/safety/domain/safety.dart';

void main() {
  test('report_wire_strings_match_the_database', () {
    expect(
      [for (final t in ReportTarget.values) t.wire],
      ['user', 'event', 'message'],
    );
    expect(
      [for (final r in ReportReason.values) r.wire],
      ['spam', 'harassment', 'scam', 'fake_event', 'other'],
    );
  });

  test('blocked_user_from_json_reads_my_blocks_row', () {
    final b = BlockedUser.fromJson({
      'user_id': 'u2',
      'name': 'Bobby Lim',
      'username': 'bobby',
      'avatar_url': null,
      'blocked_at': '2030-01-01T00:00:00Z',
    });
    expect(
      (b.userId, b.name, b.username, b.avatarUrl),
      ('u2', 'Bobby Lim', 'bobby', null),
    );
  });

  test('block_error_codes_read_as_a_sentence', () {
    expect(safetyMessage('blocked'), contains('block'));
    expect(safetyMessage('boom'), 'Something went wrong. Please try again.');
  });
  test('chat_says_so_when_the_other_side_is_blocked', () {
    expect(ChatError('blocked').message, "You can't message this person.");
  });
}
