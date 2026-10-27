import 'package:flutter/foundation.dart';

/// One row of the inbox (chat.my_threads).
@immutable
class ThreadSummary {
  const ThreadSummary({
    required this.id,
    required this.otherName,
    required this.lastBody,
    required this.lastAt,
    required this.unread,
    this.eventTitle,
    this.eventId,
    this.eventCategories = const [],
  });
  final String id, otherName, lastBody;
  final DateTime lastAt;
  final bool unread;
  final String? eventTitle, eventId;
  final List<String> eventCategories; // picks the art tile of a guest's row

  factory ThreadSummary.fromJson(Map<String, dynamic> j) => ThreadSummary(
        id: j['thread_id'] as String,
        otherName: (j['other_name'] as String?) ?? 'Guest',
        lastBody: j['last_body'] as String,
        lastAt: DateTime.parse(j['last_at'] as String).toUtc(),
        unread: j['unread'] as bool,
        eventTitle: j['event_title'] as String?,
        eventId: j['event_id'] as String?,
        eventCategories: [for (final c in (j['event_categories'] as List?) ?? const []) c as String],
      );
}

/// Who a thread is with and what it is about, for the thread's header.
@immutable
class ThreadInfo {
  const ThreadInfo({required this.id, required this.iAmHost, required this.otherName, this.eventId});
  final String id, otherName;
  final bool iAmHost; // the other side is then the guest
  final String? eventId;
}

@immutable
class Message {
  const Message({required this.id, required this.senderId, required this.body, required this.createdAt});
  final String id, senderId, body;
  final DateTime createdAt;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        senderId: j['sender_id'] as String,
        body: j['body'] as String,
        createdAt: DateTime.parse(j['created_at'] as String).toUtc(),
      );
}

/// A refusal from the database with a sentence a person can read.
class ChatError implements Exception {
  ChatError(this.code);
  final String code;

  String get message => switch (code) {
        'contact_info_not_allowed' => "Keep the chat in Jom. Phone numbers and social handles can't be shared here.",
        'message_too_long' => 'That message is too long. Keep it under 1000 characters.',
        _ => "The message didn't send. Please try again.",
      };

  @override
  String toString() => 'ChatError($code)';
}
