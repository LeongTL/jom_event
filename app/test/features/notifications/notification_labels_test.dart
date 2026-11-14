import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/notifications/domain/notification.dart';
import 'package:jom/features/notifications/domain/notification_labels.dart';

// 14:00 in Kuala Lumpur on Wednesday 9 January 2030
final now = DateTime.utc(2030, 1, 9, 6);

AppNotification n(String type, {String? refType, String? refId = 'x1'}) =>
    AppNotification(
      id: 'n',
      type: type,
      refType: refType,
      refId: refType == null ? null : refId,
      title: 't',
      createdAt: now,
    );

void main() {
  group('manual payment notices', () {
    test('six_new_notification_types_have_icons_and_routes', () {
      for (final t in [
        'receipt_submitted',
        'receipt_reminder',
        'late_receipt',
        'receipt_accepted',
        'receipt_requested',
        'seat_assigned',
      ]) {
        expect(notifIcon(t), isNot(Icons.notifications_none), reason: t);
      }
      expect(
        notifRoute(n('receipt_submitted', refType: 'receipt')),
        '/host-mode/receipts/x1',
      );
      expect(
        notifRoute(n('receipt_reminder', refType: 'receipt')),
        '/host-mode/receipts/x1',
      );
      expect(
        notifRoute(n('late_receipt', refType: 'receipt')),
        '/host-mode/receipts/x1',
      );
      expect(
        notifRoute(n('receipt_requested', refType: 'booking')),
        '/booking/x1/pay',
      );
      expect(
        notifRoute(n('receipt_accepted', refType: 'booking')),
        '/booking/x1/ticket',
      );
      expect(
        notifRoute(n('seat_assigned', refType: 'booking')),
        '/booking/x1/ticket',
      );
    });
  });

  group('notifWhen', () {
    test(
      'says how long ago for today, then Yesterday, the weekday, the date',
      () {
        expect(
          notifWhen(now.subtract(const Duration(seconds: 20)), now),
          'Just now',
        );
        expect(
          notifWhen(now.subtract(const Duration(minutes: 2)), now),
          '2 min ago',
        );
        expect(
          notifWhen(now.subtract(const Duration(minutes: 59)), now),
          '59 min ago',
        );
        expect(
          notifWhen(now.subtract(const Duration(hours: 1)), now),
          '1 h ago',
        );
        expect(
          notifWhen(now.subtract(const Duration(hours: 5)), now),
          '5 h ago',
        );
        expect(
          notifWhen(now.subtract(const Duration(days: 1)), now),
          'Yesterday',
        );
        expect(notifWhen(now.subtract(const Duration(days: 2)), now), 'Mon');
        expect(notifWhen(now.subtract(const Duration(days: 9)), now), '31 Dec');
      },
    );

    test('counts days in Kuala Lumpur, not by 24-hour blocks', () {
      // 00:30 KL on the 9th; 23:50 KL on the 8th was only 40 minutes ago, but it is already yesterday
      final early = DateTime.utc(2030, 1, 8, 16, 30);
      expect(notifWhen(DateTime.utc(2030, 1, 8, 15, 50), early), '40 min ago');
      expect(
        notifWhen(
          DateTime.utc(2030, 1, 8, 15, 50),
          DateTime.utc(2030, 1, 9, 6),
        ),
        'Yesterday',
      );
    });
  });

  test('notifIcon: one icon per kind of notice, a bell for anything new', () {
    expect(
      {
        for (final t in [
          'payment',
          'booking',
          'payout',
          'event_cancelled',
          'chat_message',
          'review_request',
          'something_new',
        ])
          t: notifIcon(t),
      },
      {
        'payment': Icons.check_circle_outline,
        'booking': Icons.confirmation_number_outlined,
        'payout': Icons.account_balance_wallet_outlined,
        'event_cancelled': Icons.undo,
        'chat_message': Icons.chat_bubble_outline,
        'review_request': Icons.star_outline,
        'something_new': Icons.notifications_none,
      },
    );
  });

  group('notifRoute', () {
    test(
      'a booking opens its ticket, a thread its chat, an event its page',
      () {
        expect(
          notifRoute(n('payment', refType: 'booking', refId: 'b1')),
          '/booking/b1/ticket',
        );
        expect(
          notifRoute(n('chat_message', refType: 'thread', refId: 't1')),
          '/chats/t1',
        );
        expect(
          notifRoute(n('event_cancelled', refType: 'event', refId: 'e1')),
          '/event/e1',
        );
      },
    );

    test('a payout goes to Payouts, even though the database files it under the event', () {
      expect(
        notifRoute(n('payout', refType: 'event', refId: 'e1')),
        '/host-mode/payouts',
      );
      expect(notifRoute(n('x', refType: 'payout')), '/host-mode/payouts');
    });

    test(
      'a notice with nothing to open, or a kind we do not know, goes nowhere',
      () {
        expect(notifRoute(n('payment')), isNull);
        expect(notifRoute(n('x', refType: 'mystery')), isNull);
      },
    );
  });

  test('a row from the database becomes a notification, and a missing read time means unread', () {
    final a = AppNotification.fromJson({
      'id': 'a',
      'type': 'payment',
      'ref_type': 'booking',
      'ref_id': 'b1',
      'title': 'Payment received',
      'body': 'You are in',
      'created_at': '2030-01-09T06:00:00+00:00',
      'read_at': null,
    });
    expect(
      (a.title, a.body, a.unread, a.createdAt),
      ('Payment received', 'You are in', true, now),
    );
    expect(
      AppNotification.fromJson({
        'id': 'b',
        'type': 'x',
        'title': 't',
        'created_at': '2030-01-09T06:00:00Z',
        'read_at': '2030-01-09T07:00:00Z',
      }).unread,
      false,
    );
  });

  test('follow_notification_has_the_person_icon', () {
    expect(notifIcon('follow'), Icons.person_add_alt);
  });

  test('follow_notification_opens_the_person_page', () {
    expect(notifRoute(n('follow', refType: 'user', refId: 'u9')), '/people/u9');
  });
}
