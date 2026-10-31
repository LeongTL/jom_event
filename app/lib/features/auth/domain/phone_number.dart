const _notMalaysian = 'Enter a Malaysian mobile number, like 012 345 6789';

/// A Malaysian mobile number as people write it (012-345 6789, +60 12 345 6789, 60123456789...) to the +60...
/// form Supabase wants. Mobile numbers start with 1 after the country code and have 9 or 10 digits.
/// Throws a [FormatException] whose message can be shown to the user.
String normalizeMyPhone(String raw) {
  var s = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  if (s.startsWith('+')) {
    if (!s.startsWith('+60')) throw const FormatException(_notMalaysian);
    s = s.substring(3);
  } else if (s.startsWith('60')) {
    s = s.substring(2);
  } else if (s.startsWith('0')) {
    s = s.substring(1);
  }
  if (!RegExp(r'^1\d{8,9}$').hasMatch(s)) {
    throw const FormatException(_notMalaysian);
  }
  return '+60$s';
}

/// +60123456789 to "+60 12 345 6789" (and the 10 digit kind to "+60 11 2345 6789").
String prettyMyPhone(String e164) {
  final n = e164.startsWith('+60') ? e164.substring(3) : e164;
  if (n.length < 9) return e164;
  final rest = n.substring(2);
  final split = rest.length == 7 ? 3 : 4;
  return '+60 ${n.substring(0, 2)} ${rest.substring(0, split)} ${rest.substring(split)}';
}
