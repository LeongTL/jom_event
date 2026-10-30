import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/chat/domain/chat_labels.dart';

void main() {
  // 14:00 in Kuala Lumpur on Friday 9 January 2032
  final now = DateTime.utc(2032, 1, 9, 6);

  test('clockLabel is the KL time of day', () {
    expect(clockLabel(DateTime.utc(2032, 1, 9, 1, 24)), '9:24 AM');
    expect(
      clockLabel(DateTime.utc(2032, 1, 9, 16, 5)),
      '12:05 AM',
    ); // 00:05 the next day in KL
    expect(clockLabel(DateTime.utc(2032, 1, 9, 4)), '12:00 PM');
  });

  group('chatWhen', () {
    test(
      'today is the time',
      () => expect(chatWhen(DateTime.utc(2032, 1, 9, 1, 24), now), '9:24 AM'),
    );
    test(
      'yesterday',
      () => expect(chatWhen(DateTime.utc(2032, 1, 8, 6), now), 'Yesterday'),
    );
    test(
      'within the week is the weekday',
      () => expect(chatWhen(DateTime.utc(2032, 1, 5, 6), now), 'Mon'),
    );
    test(
      'older is the date',
      () => expect(chatWhen(DateTime.utc(2031, 12, 20, 6), now), '20 Dec'),
    );
    test('after midnight in KL is already the next day', () {
      expect(
        chatWhen(DateTime.utc(2032, 1, 8, 17), now),
        '1:00 AM',
      ); // still the 8th in UTC, but 01:00 on the 9th in KL: today
    });
  });
}
