import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/event/domain/event_labels.dart';
import 'package:jom/shared/models/event_summary.dart';

EventSummary at(String startsAtUtc, {bool live = false}) => EventSummary.fromJson({
      'event_id': 'e1', 'title': 'T', 'glyph': '🎉', 'color_a': '#11998e', 'color_b': '#38ef7d',
      'starts_at': startsAtUtc, 'ends_at': '2030-02-01T00:00:00Z', 'price_sen': 0, 'area': 'Bangsar',
      'distance_km': 1.0, 'is_live': live, 'spots_left': 5, 'score': 1.0,
    });

void main() {
  // 14:00 in Kuala Lumpur on Wednesday 9 January 2030
  final now = DateTime.utc(2030, 1, 9, 6);

  group('countdown', () {
    test('is minutes and seconds under an hour', () {
      expect(countdown(const Duration(minutes: 17, seconds: 42)), '17:42');
      expect(countdown(const Duration(minutes: 59, seconds: 59)), '59:59');
      expect(countdown(const Duration(seconds: 5)), '00:05');
    });
    test('is hours and minutes from an hour on', () {
      expect(countdown(const Duration(hours: 1, minutes: 32, seconds: 5)), '1h 32m');
      expect(countdown(const Duration(hours: 1)), '1h 0m');
    });
    test('never goes below zero', () => expect(countdown(const Duration(seconds: -3)), '00:00'));
  });

  group('posterTag', () {
    test('live events say HAPPENING', () => expect(posterTag(at('2030-01-09T05:00:00Z', live: true), now), 'HAPPENING'));
    test('an event whose time has come says HAPPENING', () => expect(posterTag(at('2030-01-09T06:00:00Z'), now), 'HAPPENING'));
    test('under 2 hours counts down', () {
      expect(posterTag(at('2030-01-09T06:17:42Z'), now), '⏱ in 17:42');
      expect(posterTag(at('2030-01-09T07:32:00Z'), now), '⏱ in 1h 32m');
    });
    test('from 2 hours on it shows the clock: tonight with a moon', () {
      expect(posterTag(at('2030-01-09T12:00:00Z'), now), '🌙 8:00 PM'); // 20:00 KL
    });
    test('earlier today with no moon', () => expect(posterTag(at('2030-01-09T09:00:00Z'), now), '5:00 PM'));
    test('tomorrow and the days after, by weekday and time', () {
      expect(posterTag(at('2030-01-10T01:00:00Z'), now), 'THU 9:00 AM');
      expect(posterTag(at('2030-01-12T06:00:00Z'), now), 'SAT 2:00 PM');
    });
    test('a week or more away, by date and time', () => expect(posterTag(at('2030-01-19T01:00:00Z'), now), '19 JAN 9:00 AM'));
    test('after midnight in KL counts as the next day even when UTC is still today', () {
      expect(posterTag(at('2030-01-09T17:00:00Z'), now), 'THU 1:00 AM'); // 01:00 on the 10th in KL
    });
  });

  test('whenLabel is the day and the time', () {
    expect(whenLabel(DateTime.utc(2030, 1, 9, 12), now), 'Today 8:00 PM');
    expect(whenLabel(DateTime.utc(2030, 1, 10, 1, 30), now), 'Tomorrow 9:30 AM');
    expect(whenLabel(DateTime.utc(2030, 1, 13, 1), now), 'Sun 9:00 AM');
    expect(whenLabel(DateTime.utc(2030, 1, 19, 1), now), '19 Jan 9:00 AM');
  });

  test('fullWhen is the weekday, date and time', () => expect(fullWhen(DateTime.utc(2030, 1, 13, 1)), 'Sun 13 Jan · 9:00 AM'));

  test('durationText reads like the prototype', () {
    expect(durationText(const Duration(hours: 1)), '1 hour');
    expect(durationText(const Duration(hours: 2)), '2 hours');
    expect(durationText(const Duration(hours: 1, minutes: 30)), '1 h 30 min');
    expect(durationText(const Duration(minutes: 45)), '45 min');
  });

  test('cancelPolicyText says it per policy', () {
    expect(cancelPolicyText('24h'), 'Free cancellation up to 24 hours before');
    expect(cancelPolicyText('48h'), 'Free cancellation up to 48 hours before');
    expect(cancelPolicyText('7d'), 'Free cancellation up to 7 days before');
    expect(cancelPolicyText('none'), 'No refunds once booked');
  });
}
