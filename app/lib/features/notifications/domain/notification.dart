/// One line in the Notifications list (a row of identity.notifications).
class AppNotification {
  const AppNotification({required this.id, required this.type, this.refType, this.refId, required this.title, this.body, required this.createdAt, this.readAt});

  final String id;
  final String type; // payment, booking, payout, event_cancelled, chat_message, review_request
  final String? refType; // what refId points at: booking, thread or event
  final String? refId;
  final String title;
  final String? body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String,
        refType: j['ref_type'] as String?,
        refId: j['ref_id'] as String?,
        title: j['title'] as String,
        body: j['body'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        readAt: j['read_at'] == null ? null : DateTime.parse(j['read_at'] as String),
      );
}

/// The two switches a user can turn off. Booking, payment and event-change notices are always on.
class NotificationPrefs {
  const NotificationPrefs({required this.chat, required this.reviewRequests});

  final bool chat;
  final bool reviewRequests;

  NotificationPrefs copyWith({bool? chat, bool? reviewRequests}) => NotificationPrefs(chat: chat ?? this.chat, reviewRequests: reviewRequests ?? this.reviewRequests);

  @override
  bool operator ==(Object other) => other is NotificationPrefs && other.chat == chat && other.reviewRequests == reviewRequests;

  @override
  int get hashCode => Object.hash(chat, reviewRequests);
}
