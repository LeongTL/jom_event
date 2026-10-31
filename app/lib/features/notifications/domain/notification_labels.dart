import 'package:flutter/material.dart' show IconData, Icons;

import '../../chat/domain/chat_labels.dart';
import 'notification.dart';

IconData notifIcon(String type) =>
    const {
      'payment': Icons.check_circle_outline,
      'booking': Icons.confirmation_number_outlined,
      'payout': Icons.account_balance_wallet_outlined,
      'event_cancelled': Icons.undo,
      'chat_message': Icons.chat_bubble_outline,
      'review_request': Icons.star_outline,
    }[type] ??
    Icons.notifications_none;

/// "Just now", "2 min ago" for the first hour, "1 h ago" for the rest of today (Kuala Lumpur time), then
/// "Yesterday", "Mon", "12 Oct".
String notifWhen(DateTime at, DateTime now) {
  final ago = now.difference(at);
  if (ago.inMinutes < 1) {
    return 'Just now'; // also a clock a little behind the server's
  }
  if (ago.inMinutes < 60) return '${ago.inMinutes} min ago';
  final day = chatWhen(at, now); // a clock time means today
  return day == clockLabel(at) ? '${ago.inHours} h ago' : day;
}

/// Where tapping the notice goes, or null when there is nothing to open. A payout is recognised by its type:
/// the database files it under its event.
String? notifRoute(AppNotification n) {
  final id = n.refId;
  if (n.type == 'payout' || n.refType == 'payout') return '/host-mode/payouts';
  if (id == null) return null;
  return switch (n.refType) {
    'booking' => '/booking/$id/ticket',
    'thread' => '/chats/$id',
    'event' => '/event/$id',
    _ => null,
  };
}
