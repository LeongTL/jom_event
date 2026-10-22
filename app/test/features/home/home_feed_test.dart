import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/theme/tokens.dart';
import 'package:jom/features/home/domain/home_feed.dart';

void main() {
  group('shortWhen speaks Kuala Lumpur time whatever zone the phone is in', () {
    final now = DateTime.utc(2026, 10, 14, 12, 0); // 8:00 PM Wed in KL

    test('later the same KL day is Today', () => expect(shortWhen(DateTime.utc(2026, 10, 14, 14, 30), now), 'Today 10:30 PM'));

    test('an event at 17:00 UTC is already tomorrow in KL (1 AM)', () => expect(shortWhen(DateTime.utc(2026, 10, 14, 17, 0), now), 'Tomorrow 1:00 AM'));

    test('a few days out names the day', () => expect(shortWhen(DateTime.utc(2026, 10, 17, 1, 0), now), 'Sat 17 Oct 9:00 AM'));

    test('noon and midnight are 12, not 0', () {
      expect(shortWhen(DateTime.utc(2026, 10, 15, 4, 0), now), 'Tomorrow 12:00 PM');
      expect(shortWhen(DateTime.utc(2026, 10, 14, 16, 5), now), 'Tomorrow 12:05 AM');
    });
  });

  group('heroEyebrow is the small line above the headline, in KL time', () {
    final wed = DateTime.utc(2026, 10, 14, 11, 42); // Wed 7:42 PM in KL

    test('Now: weekday and the time', () => expect(heroEyebrow(JomTheme.now, wed), 'WED · 7:42 PM'));
    test('Night: weekday and TONIGHT', () => expect(heroEyebrow(JomTheme.night, wed), 'WED · TONIGHT'));
    test('Weekend from midweek: the coming Saturday and Sunday', () => expect(heroEyebrow(JomTheme.weekend, wed), 'SAT 17 – SUN 18 OCT'));
    test('Weekend on a Sunday: this weekend', () => expect(heroEyebrow(JomTheme.weekend, DateTime.utc(2026, 10, 18, 3)), 'SAT 17 – SUN 18 OCT'));
    test('Weekend across a month end names both months', () => expect(heroEyebrow(JomTheme.weekend, DateTime.utc(2026, 10, 28, 3)), 'SAT 31 OCT – SUN 1 NOV'));
    test('a UTC evening that is already tomorrow in KL', () => expect(heroEyebrow(JomTheme.now, DateTime.utc(2026, 10, 14, 17, 5)), 'THU · 1:05 AM'));
  });

  test('heroSub adds "best N shown" when there are more events than the nine shown', () {
    const s = HeroStats(total: 22, live: 7, free: 10, closestKm: .5);
    expect(heroSub(s, shown: 9), '7 happening now · 10 free · closest 0.5 km · best 9 shown');
    expect(heroSub(s, shown: 22), '7 happening now · 10 free · closest 0.5 km');
  });

  test('heroTail keeps each tab\'s own wording, singular for one', () {
    expect(heroTail(JomTheme.now, 9), 'things are happening near you');
    expect(heroTail(JomTheme.night, 9), 'ways to spend your night');
    expect(heroTail(JomTheme.weekend, 9), 'things to do this weekend');
    expect(heroTail(JomTheme.night, 1), 'way to spend your night');
  });

  test('heroSub lists what there is, and says Nothing right now otherwise', () {
    expect(heroSub(const HeroStats(total: 9, live: 2, free: 5, closestKm: 1.04)), '2 happening now · 5 free · closest 1.0 km');
    expect(heroSub(const HeroStats(total: 3, live: 0, free: 0, closestKm: 2.5)), 'closest 2.5 km');
    expect(heroSub(const HeroStats(total: 0, live: 0, free: 0, closestKm: null)), 'Nothing right now');
  });

  test('HeroStats reads the hero_stats row', () {
    final s = HeroStats.fromJson({'total': 11, 'live': 3, 'free': 7, 'closest_km': 0.9});
    expect((s.total, s.live, s.free, s.closestKm), (11, 3, 7, 0.9));
    expect(HeroStats.fromJson({'total': 0, 'live': 0, 'free': 0, 'closest_km': null}).closestKm, isNull);
  });
}
