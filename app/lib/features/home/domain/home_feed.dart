import '../../../core/theme/tokens.dart';
import '../../../shared/models/event_summary.dart';

/// What the feed asks for. A record, so two equal queries share one cached answer.
typedef HomeQuery = ({JomTheme tab, double lat, double lng, int km});

class HeroStats {
  const HeroStats({
    required this.total,
    required this.live,
    required this.free,
    required this.closestKm,
  });
  final int total, live, free;
  final double? closestKm;

  factory HeroStats.fromJson(Map<String, dynamic> j) => HeroStats(
    total: (j['total'] as num).toInt(),
    live: (j['live'] as num).toInt(),
    free: (j['free'] as num).toInt(),
    closestKm: (j['closest_km'] as num?)?.toDouble(),
  );
}

/// One tab's worth of Home: the best nine events and the numbers for the headline.
class HomeFeed {
  const HomeFeed({required this.tab, required this.top9, required this.stats});
  final JomTheme tab;
  final List<EventSummary> top9;
  final HeroStats stats;
}

/// The words after the big number. The prototype says "thing is happening near you" for 1 on every tab; here
/// each tab keeps its own wording.
String heroTail(JomTheme tab, int n) => switch (tab) {
  JomTheme.now =>
    n == 1 ? 'thing is happening near you' : 'things are happening near you',
  JomTheme.night =>
    n == 1 ? 'way to spend your night' : 'ways to spend your night',
  JomTheme.weekend =>
    n == 1 ? 'thing to do this weekend' : 'things to do this weekend',
};

/// "1 happening now · 5 free · closest 1.0 km · best 9 shown", or "Nothing right now" when there is nothing.
/// "best N shown" appears when the area has more events than the [shown] ones on the map.
String heroSub(HeroStats s, {int? shown}) {
  final parts = [
    if (s.live > 0) '${s.live} happening now',
    if (s.free > 0) '${s.free} free',
    if (s.closestKm != null) 'closest ${s.closestKm!.toStringAsFixed(1)} km',
    if (shown != null && shown > 0 && s.total > shown) 'best $shown shown',
  ];
  return parts.isEmpty ? 'Nothing right now' : parts.join(' · ');
}

const _dayCaps = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _monthCaps = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Today 8:00 PM", "Tomorrow 9:30 AM" or "Sat 17 Oct 8:00 PM", always in Kuala Lumpur time (UTC+8, no daylight
/// saving) whatever zone the phone is in.
String shortWhen(DateTime startsAt, DateTime now) {
  DateTime kl(DateTime d) => d.toUtc().add(const Duration(hours: 8));
  final s = kl(startsAt), n = kl(now);
  final dayDiff = DateTime.utc(
    s.year,
    s.month,
    s.day,
  ).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
  final h = s.hour % 12 == 0 ? 12 : s.hour % 12;
  final time =
      '$h:${s.minute.toString().padLeft(2, '0')} ${s.hour < 12 ? 'AM' : 'PM'}';
  final day = switch (dayDiff) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => '${_days[s.weekday - 1]} ${s.day} ${_months[s.month - 1]}',
  };
  return '$day $time';
}

/// The small line above the headline, in Kuala Lumpur time: "WED · 7:42 PM", "WED · TONIGHT" or
/// "SAT 17 – SUN 18 OCT" (this weekend, or the coming one from Monday to Friday).
String heroEyebrow(JomTheme tab, DateTime now) {
  final kl = now.toUtc().add(const Duration(hours: 8));
  final day = _dayCaps[kl.weekday - 1];
  switch (tab) {
    case JomTheme.now:
      final h = kl.hour % 12 == 0 ? 12 : kl.hour % 12;
      return '$day · $h:${kl.minute.toString().padLeft(2, '0')} ${kl.hour < 12 ? 'AM' : 'PM'}';
    case JomTheme.night:
      return '$day · TONIGHT';
    case JomTheme.weekend:
      final sat = DateTime.utc(
        kl.year,
        kl.month,
        kl.day,
      ).add(Duration(days: kl.weekday == 7 ? -1 : 6 - kl.weekday));
      final sun = sat.add(const Duration(days: 1));
      return sat.month == sun.month
          ? 'SAT ${sat.day} – SUN ${sun.day} ${_monthCaps[sun.month - 1]}'
          : 'SAT ${sat.day} ${_monthCaps[sat.month - 1]} – SUN ${sun.day} ${_monthCaps[sun.month - 1]}';
  }
}
