import '../../../shared/models/event_summary.dart';

/// "17:42" under an hour, "1h 32m" from an hour on (the prototype's cd()).
String countdown(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  if (s >= 3600) return '${s ~/ 3600}h ${s % 3600 ~/ 60}m';
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

/// The small tag on a poster: HAPPENING, a ticking countdown under 2 hours, otherwise when it starts
/// ("🌙 8:00 PM" tonight, "TOMORROW", "SAT 17 OCT"), in Kuala Lumpur time.
String posterTag(EventSummary e, DateTime now) {
  final left = e.startsAt.difference(now);
  if (e.isLive || left <= Duration.zero) return 'HAPPENING';
  if (left < const Duration(hours: 2)) return '⏱ in ${countdown(left)}';
  DateTime kl(DateTime d) => d.toUtc().add(const Duration(hours: 8));
  final s = kl(e.startsAt), n = kl(now);
  final dayDiff = DateTime.utc(s.year, s.month, s.day).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
  if (dayDiff == 0) {
    final h = s.hour % 12 == 0 ? 12 : s.hour % 12;
    final time = '$h:${s.minute.toString().padLeft(2, '0')} ${s.hour < 12 ? 'AM' : 'PM'}';
    return s.hour >= 18 ? '🌙 $time' : time;
  }
  return dayDiff == 1 ? 'TOMORROW' : '${_days[s.weekday - 1]} ${s.day} ${_months[s.month - 1]}';
}

/// The host's refund promise as the event pages and checkout word it.
String cancelPolicyText(String policy) => switch (policy) {
      '24h' => 'Free cancellation up to 24 hours before',
      '48h' => 'Free cancellation up to 48 hours before',
      '7d' => 'Free cancellation up to 7 days before',
      _ => 'No refunds once booked',
    };
