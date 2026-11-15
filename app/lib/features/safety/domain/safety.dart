import 'package:flutter/foundation.dart';

enum ReportTarget {
  user('user'),
  event('event'),
  message('message');

  const ReportTarget(this.wire);
  final String wire;
}

enum ReportReason {
  spam('spam', 'Spam'),
  harassment('harassment', 'Harassment'),
  scam('scam', 'Scam'),
  fakeEvent('fake_event', 'Fake event'),
  other('other', 'Something else');

  const ReportReason(this.wire, this.label);
  final String wire, label;
}

/// One row of identity.my_blocks.
@immutable
class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.name,
    required this.username,
    required this.blockedAt,
    this.avatarUrl,
  });
  final String userId, name;
  final String? username, avatarUrl;
  final DateTime blockedAt;

  factory BlockedUser.fromJson(Map<String, dynamic> j) => BlockedUser(
    userId: j['user_id'] as String,
    name: (j['name'] as String?) ?? 'Guest',
    username: j['username'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    blockedAt: DateTime.parse(j['blocked_at'] as String).toUtc(),
  );
}

/// A refusal from the database as a sentence a person can read.
String safetyMessage(String code) => switch (code) {
  'blocked' => "You can't do that because one of you has blocked the other.",
  _ => 'Something went wrong. Please try again.',
};
