import '../../../shared/models/event_summary.dart';

/// "17:42" under an hour, "1h 32m" from an hour on (the prototype's cd()).
String countdown(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  if (s >= 3600) return '${s ~/ 3600}h ${s % 3600 ~/ 60}m';
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

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

// Kuala Lumpur is UTC+8 all year, whatever zone the phone is in.
DateTime _kl(DateTime d) => d.toUtc().add(const Duration(hours: 8));

String _time(DateTime kl) =>
    '${kl.hour % 12 == 0 ? 12 : kl.hour % 12}:${kl.minute.toString().padLeft(2, '0')} ${kl.hour < 12 ? 'AM' : 'PM'}';

int _dayDiff(DateTime startsAt, DateTime now) {
  final s = _kl(startsAt), n = _kl(now);
  return DateTime.utc(
    s.year,
    s.month,
    s.day,
  ).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
}

/// "Today 8:00 PM", "Tomorrow 9:30 AM", "Sun 9:00 AM" (within the week) or "19 Jan 9:00 AM", in KL time.
String whenLabel(DateTime startsAt, DateTime now) {
  final s = _kl(startsAt), diff = _dayDiff(startsAt, now);
  final day = switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    < 7 => _days[s.weekday - 1],
    _ => '${s.day} ${_months[s.month - 1]}',
  };
  return '$day ${_time(s)}';
}

/// "Sun 18 Oct · 9:00 AM", for lists of bookings.
String fullWhen(DateTime startsAt) {
  final s = _kl(startsAt);
  return '${_days[s.weekday - 1]} ${s.day} ${_months[s.month - 1]} · ${_time(s)}';
}

/// "1 hour", "2 hours", "1 h 30 min", "45 min".
String durationText(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h ${h == 1 ? 'hour' : 'hours'}';
  return '$h h $m min';
}

/// The small tag on a poster: HAPPENING, a ticking countdown under 2 hours, otherwise when it starts
/// ("🌙 8:00 PM" tonight, "SAT 2:00 PM", "19 JAN 9:00 AM"), in Kuala Lumpur time.
String posterTag(EventSummary e, DateTime now) {
  final left = e.startsAt.difference(now);
  if (e.isLive || left <= Duration.zero) return 'HAPPENING';
  if (left < const Duration(hours: 2)) return '⏱ in ${countdown(left)}';
  if (_dayDiff(e.startsAt, now) == 0) {
    final s = _kl(e.startsAt);
    return s.hour >= 18 ? '🌙 ${_time(s)}' : _time(s);
  }
  return whenLabel(
    e.startsAt,
    now,
  ).replaceFirst('Tomorrow', _days[_kl(e.startsAt).weekday - 1]).toUpperCase();
}

/// The title of the policy card on the event page: the host's refund promise, or "Free event".
String policyTitle(String policy, {bool free = false}) => free
    ? 'Free event'
    : switch (policy) {
        '24h' => 'Full refund up to 24 hours before it starts',
        '48h' => 'Full refund up to 48 hours before it starts',
        '7d' => 'Full refund up to 7 days before it starts',
        _ => 'No refunds once booked',
      };

/// The last moment a guest gets a full refund, or null when the policy gives none.
DateTime? refundCutoff(String policy, DateTime startsAt) => switch (policy) {
  '24h' => startsAt.subtract(const Duration(hours: 24)),
  '48h' => startsAt.subtract(const Duration(hours: 48)),
  '7d' => startsAt.subtract(const Duration(days: 7)),
  _ => null,
};

/// "8:04 PM" in KL time, for any instant.
String timeLabel(DateTime t) => _time(_kl(t));

/// "Today", "Tomorrow" or "Sat 24 Oct", by the KL calendar.
String dayLabel(DateTime t, DateTime now) {
  final s = _kl(t), diff = _dayDiff(t, now);
  return diff == 0
      ? 'Today'
      : diff == 1
      ? 'Tomorrow'
      : '${_days[s.weekday - 1]} ${s.day} ${_months[s.month - 1]}';
}

/// "1h 11m", "3h", "45m".
String durationLabel(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  return h == 0
      ? '${m}m'
      : m == 0
      ? '${h}h'
      : '${h}h ${m}m';
}

/// "Happening now", "in 22 min", "in 3h 18m", "in 2h", "in 1 day", "in 3 days".
String relativeStart(DateTime starts, DateTime ends, DateTime now) {
  final left = starts.difference(now);
  if (left <= Duration.zero)
    return now.isBefore(ends) ? 'Happening now' : 'Ended';
  if (left < const Duration(minutes: 120)) return 'in ${left.inMinutes} min';
  if (left < const Duration(hours: 24)) {
    final m = left.inMinutes % 60;
    return 'in ${left.inHours}h${m == 0 ? '' : ' ${m}m'}';
  }
  final days = left.inDays;
  return 'in $days ${days == 1 ? 'day' : 'days'}';
}

/// "WED 21 OCT · 7:42 PM", the small line above a screen title.
String eyebrow(DateTime now) {
  final s = _kl(now);
  return '${_days[s.weekday - 1]} ${s.day} ${_months[s.month - 1]} · ${_time(s)}'
      .toUpperCase();
}

/// "Wed 21 Oct", in KL time.
String dateLabel(DateTime t) {
  final s = _kl(t);
  return '${_days[s.weekday - 1]} ${s.day} ${_months[s.month - 1]}';
}

/// "21 Oct", in KL time.
String shortDate(DateTime t) {
  final s = _kl(t);
  return '${s.day} ${_months[s.month - 1]}';
}
