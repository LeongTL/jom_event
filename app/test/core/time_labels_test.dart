import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/event/domain/event_labels.dart';

void main() {
  final now = DateTime.utc(2026, 10, 21, 11, 42); // 7:42 PM in Kuala Lumpur
  DateTime at(Duration d) => now.add(d);

  test('relativeStart_cases', () {
    final end = at(const Duration(days: 9));
    expect(relativeStart(at(const Duration(minutes: -30)), at(const Duration(minutes: 30)), now), 'Happening now');
    expect(relativeStart(at(const Duration(minutes: 22)), end, now), 'in 22 min');
    expect(relativeStart(at(const Duration(minutes: 93)), end, now), 'in 93 min');
    expect(relativeStart(at(const Duration(minutes: 120)), end, now), 'in 2h');
    expect(relativeStart(at(const Duration(hours: 3, minutes: 18)), end, now), 'in 3h 18m');
    expect(relativeStart(at(const Duration(hours: 30)), end, now), 'in 1 day');
    expect(relativeStart(at(const Duration(days: 3, hours: 2)), end, now), 'in 3 days');
  });

  test('dayLabel_and_timeLabel_use_kuala_lumpur_not_the_device_zone', () {
    // 17:00 UTC on the 21st is 1:00 AM on the 22nd in KL
    final t = DateTime.utc(2026, 10, 21, 17);
    expect(timeLabel(t), '1:00 AM');
    expect(dayLabel(t, now), 'Tomorrow');
    expect(dayLabel(DateTime.utc(2026, 10, 24, 4), now), 'Sat 24 Oct');
    expect(dayLabel(DateTime.utc(2026, 10, 21, 12), now), 'Today');
    expect(timeLabel(DateTime.utc(2026, 10, 21, 12, 4)), '8:04 PM');
  });

  test('durationLabel_cases', () {
    expect(durationLabel(const Duration(minutes: 71)), '1h 11m');
    expect(durationLabel(const Duration(hours: 3)), '3h');
    expect(durationLabel(const Duration(minutes: 45)), '45m');
  });

  test('eyebrow_reads_like_the_prototype', () {
    expect(eyebrow(now), 'WED 21 OCT · 7:42 PM');
  });
}
