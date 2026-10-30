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

/// "9:24 AM".
String clockLabel(DateTime at) {
  final s = _kl(at);
  return '${s.hour % 12 == 0 ? 12 : s.hour % 12}:${s.minute.toString().padLeft(2, '0')} ${s.hour < 12 ? 'AM' : 'PM'}';
}

/// The time on the inbox row: "9:24 AM" today, "Yesterday", "Fri" within the week, otherwise "12 Oct".
String chatWhen(DateTime at, DateTime now) {
  final s = _kl(at), n = _kl(now);
  final diff = DateTime.utc(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime.utc(s.year, s.month, s.day)).inDays;
  if (diff <= 0) return clockLabel(at);
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return _days[s.weekday - 1];
  return '${s.day} ${_months[s.month - 1]}';
}
