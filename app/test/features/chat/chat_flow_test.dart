import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/app.dart';
import 'package:jom/core/clock.dart';
import 'package:jom/core/location.dart';
import 'package:jom/core/router/app_router.dart';
import 'package:jom/core/theme/calm.dart';
import 'package:jom/shared/widgets/category_art.dart';
import 'package:jom/features/auth/data/auth_repository.dart';
import 'package:jom/features/chat/data/chat_repository.dart';
import 'package:jom/features/chat/domain/chat.dart';
import 'package:jom/features/event/data/event_repository.dart';
import 'package:jom/features/home/data/home_repository.dart';
import 'package:jom/features/notifications/domain/bell_provider.dart';
import 'package:jom/shared/models/event_summary.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_chat.dart';
import '../../helpers/fake_events.dart';

// 14:00 in Kuala Lumpur on Wednesday 9 January 2030 (the shared fake clock)
final t1 = ThreadSummary(
  id: 't1',
  otherName: 'Mei Studio',
  lastBody: 'Yes, mats are provided',
  lastAt: DateTime.utc(2030, 1, 9, 1, 24),
  unread: true,
  eventTitle: 'Batik Workshop',
  eventId: 'e1',
  eventCategories: ['make'],
);
final t2 = ThreadSummary(
  id: 't2',
  otherName: 'Clay & Co',
  lastBody: 'Starts 2 PM sharp',
  lastAt: DateTime.utc(2030, 1, 8, 6),
  unread: false,
);
const info1 = ThreadInfo(
  id: 't1',
  iAmHost: false,
  otherName: 'Mei Studio',
  eventId: 'e1',
);
const infoHost = ThreadInfo(
  id: 't1',
  iAmHost: true,
  otherName: 'Aina Rahman',
  eventId: 'e1',
);

late FakeChat chat;

Future<void> pumpApp(
  WidgetTester t, {
  required String location,
  FakeChat? repo,
  bool signedIn = true,
}) async {
  // wider than a phone on purpose: the test font's letters are so wide that tab names would wrap
  t.view.physicalSize = const Size(800, 1700);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  chat = repo ?? FakeChat();
  final start = t.binding.clock.now();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        routerProvider.overrideWithValue(
          createRouter(initialLocation: location),
        ),
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initial: signedIn ? fakeSession(name: 'Mei') : null,
          ),
        ),
        eventRepositoryProvider.overrideWithValue(
          FakeEvents(
            details: {'e1': detailOf(sum('e1', title: 'Batik Workshop'))},
          ),
        ),
        chatRepositoryProvider.overrideWithValue(chat),
        nowProvider.overrideWithValue(
          () => clock.add(t.binding.clock.now().difference(start)),
        ),
        weekendProvider.overrideWith((ref, a) async => <EventSummary>[]),
        nearYouProvider.overrideWith((ref, q) async => <EventSummary>[]),
        deviceLocationProvider.overrideWithValue(() async => null),
        bellCountProvider.overrideWith((ref) => Stream.value(0)),
      ],
      child: const JomApp(),
    ),
  );
  await t.pumpAndSettle();
}

Finder key(String k) => find.byKey(Key(k));

void main() {
  group('inbox', () {
    testWidgets('list_shows_one_row_per_host_with_unread_dot_and_subtitle', (
      t,
    ) async {
      await pumpApp(
        t,
        location: '/chats',
        repo: FakeChat(threads: [t1, t2]),
      );
      expect(key('chat-list-screen'), findsOneWidget);
      expect(find.text('Ask a host before you book.'), findsOneWidget);
      expect(find.text('Mei Studio'), findsOneWidget);
      expect(find.text('Yes, mats are provided'), findsOneWidget);
      expect(find.text('9:24 AM'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(key('unread-dot-t1'), findsOneWidget);
      expect(key('unread-dot-t2'), findsNothing);
    });

    testWidgets(
      'chat_list_has_a_large_Chat_heading_and_category_art_tiles_in_attendee_mode_and_initial_avatars_in_host_mode',
      (t) async {
        await pumpApp(
          t,
          location: '/chats',
          repo: FakeChat(threads: [t1, t2]),
        );
        expect(t.widget<Text>(key('chat-heading')).data, 'Chat');
        expect(
          t.widget<Text>(key('chat-heading')).style!.fontSize,
          greaterThanOrEqualTo(28),
        );
        expect(
          find.descendant(
            of: key('thread-t1'),
            matching: find.byType(CategoryArt),
          ),
          findsOneWidget,
          reason: 'a guest sees the event art',
        );
        expect(
          find.descendant(
            of: key('thread-t2'),
            matching: find.byType(CategoryArt),
          ),
          findsOneWidget,
          reason: 'even with no event the tile has art',
        );
        expect(key('initial-t1'), findsNothing);

        await pumpApp(
          t,
          location: '/host-mode/chats',
          repo: FakeChat(threads: [t1], infos: {'t1': infoHost}),
        );
        expect(t.widget<Text>(key('chat-heading')).data, 'Chat');
        expect(
          find.descendant(of: key('initial-t1'), matching: find.text('M')),
          findsOneWidget,
          reason: 'a host sees the guest\'s initial',
        );
        expect(
          find.descendant(
            of: key('thread-t1'),
            matching: find.byType(CategoryArt),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('an empty inbox says so', (t) async {
      await pumpApp(t, location: '/chats');
      expect(find.text('No chats yet'), findsOneWidget);
    });

    testWidgets('signed_out_chat_tab_shows_sign_in_prompt', (t) async {
      await pumpApp(t, location: '/chats', signedIn: false);
      expect(find.text('Sign in to see your chats'), findsOneWidget);
      expect(key('chat-list-screen'), findsNothing);
    });

    testWidgets('a row opens its thread', (t) async {
      await pumpApp(
        t,
        location: '/chats',
        repo: FakeChat(threads: [t1], infos: {'t1': info1}),
      );
      await t.tap(key('thread-t1'));
      await t.pumpAndSettle();
      expect(key('thread-screen'), findsOneWidget);
    });

    testWidgets('host_mode_uses_host_copy_and_same_threads', (t) async {
      await pumpApp(
        t,
        location: '/host-mode/chats',
        repo: FakeChat(threads: [t1], infos: {'t1': infoHost}),
      );
      expect(
        find.text('Messages from guests about your events.'),
        findsOneWidget,
      );
      expect(find.text('Ask a host before you book.'), findsNothing);
      expect(
        find.text('Yes, mats are provided · Batik Workshop'),
        findsOneWidget,
        reason: 'a host sees which event the guest asked about',
      );
      await t.tap(key('thread-t1'));
      await t.pumpAndSettle();
      expect(key('thread-screen'), findsOneWidget);
      expect(find.text('Aina Rahman'), findsOneWidget);
      expect(find.text('Attendee'), findsOneWidget);
      expect(
        t.widget<TextField>(key('msg-field')).decoration!.hintText,
        'Message Aina…',
        reason: 'a host writes to a guest by first name',
      );
    });
  });

  group('thread', () {
    final msgs = {
      't1': [
        msg(
          'm1',
          'h9',
          'Yes, mats are provided 🙂',
          DateTime.utc(2030, 1, 9, 1, 24),
        ),
        msg(
          'm2',
          'u1',
          'Great, see you there',
          DateTime.utc(2030, 1, 9, 1, 30),
        ),
      ],
    };

    testWidgets('thread_shows_event_card_notice_and_bubbles_with_times', (
      t,
    ) async {
      await pumpApp(
        t,
        location: '/chats/t1',
        repo: FakeChat(infos: {'t1': info1}, messages: {...msgs}),
      );
      expect(find.text('Mei Studio'), findsOneWidget);
      expect(find.text('Host'), findsOneWidget);
      expect(
        t.widget<TextField>(key('msg-field')).decoration!.hintText,
        'Message Mei Studio…',
        reason: 'a guest writes to the host by name',
      );
      expect(
        find.descendant(
          of: key('event-card'),
          matching: find.text('Batik Workshop'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('event-card'),
          matching: find.textContaining('Bangsar'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          "Keep the chat in Jom. Phone numbers and social handles can't be shared here.",
        ),
        findsOneWidget,
      );
      expect(find.text('Yes, mats are provided 🙂'), findsOneWidget);
      expect(find.text('Great, see you there'), findsOneWidget);
      expect(t.widget<Text>(key('time-m1')).data, '9:24 AM');
      expect(t.widget<Text>(key('time-m2')).data, '9:30 AM');
      // mine on the right, theirs on the left
      expect(
        t.getTopLeft(key('bubble-m2')).dx,
        greaterThan(t.getTopLeft(key('bubble-m1')).dx),
      );
    });

    testWidgets('my_bubbles_are_accent_and_theirs_are_white_with_times', (
      t,
    ) async {
      await pumpApp(
        t,
        location: '/chats/t1',
        repo: FakeChat(infos: {'t1': info1}, messages: {...msgs}),
      );
      Color fill(String id) =>
          (t.widget<Container>(key('bubble-$id')).decoration! as BoxDecoration)
              .color!;
      expect(fill('m2'), Calm.acc, reason: 'mine');
      expect(fill('m1'), Colors.white, reason: 'theirs');
      expect(
        t
            .widget<Text>(
              find.descendant(
                of: key('bubble-m2'),
                matching: find.byType(Text),
              ),
            )
            .style!
            .color,
        Colors.white,
      );
      expect(key('time-m1'), findsOneWidget);
      expect(key('time-m2'), findsOneWidget);
    });

    testWidgets('a thread with no event shows no event card', (t) async {
      await pumpApp(
        t,
        location: '/chats/t1',
        repo: FakeChat(
          infos: {
            't1': const ThreadInfo(
              id: 't1',
              iAmHost: false,
              otherName: 'Mei Studio',
            ),
          },
        ),
      );
      expect(key('event-card'), findsNothing);
      expect(key('thread-screen'), findsOneWidget);
    });

    testWidgets('send_appends_message_and_clears_input', (t) async {
      await pumpApp(
        t,
        location: '/chats/t1',
        repo: FakeChat(infos: {'t1': info1}),
      );
      await t.enterText(key('msg-field'), 'Is there parking?');
      await t.tap(key('send-button'));
      await t.pumpAndSettle();
      expect(chat.sent, [('t1', 'Is there parking?')]);
      expect(find.text('Is there parking?'), findsOneWidget);
      expect(t.widget<TextField>(key('msg-field')).controller!.text, isEmpty);
    });

    testWidgets('an empty message is not sent', (t) async {
      await pumpApp(
        t,
        location: '/chats/t1',
        repo: FakeChat(infos: {'t1': info1}),
      );
      await t.tap(key('send-button'));
      await t.enterText(key('msg-field'), '   ');
      await t.tap(key('send-button'));
      await t.pumpAndSettle();
      expect(chat.sent, isEmpty);
    });

    testWidgets(
      'phone_number_error_shows_inline_Keep_the_chat_in_Jom_message',
      (t) async {
        await pumpApp(
          t,
          location: '/chats/t1',
          repo: FakeChat(infos: {'t1': info1})
            ..sendError = ChatError('contact_info_not_allowed'),
        );
        await t.enterText(key('msg-field'), 'call me on 0123456789');
        await t.tap(key('send-button'));
        await t.pumpAndSettle();
        expect(
          t.widget<Text>(key('send-error')).data,
          "Keep the chat in Jom. Phone numbers and social handles can't be shared here.",
        );
        expect(
          t.widget<TextField>(key('msg-field')).controller!.text,
          'call me on 0123456789',
          reason: 'the words stay so they can be edited',
        );
        expect(
          find.text('call me on 0123456789'),
          findsOneWidget,
          reason: 'only the field holds it, no bubble',
        );
        // typing again clears the warning
        await t.enterText(key('msg-field'), 'call me');
        await t.pump();
        expect(key('send-error'), findsNothing);
      },
    );

    testWidgets('opening_thread_marks_it_read', (t) async {
      await pumpApp(
        t,
        location: '/chats/t1',
        repo: FakeChat(infos: {'t1': info1}, messages: {...msgs}),
      );
      expect(chat.read, ['t1']);
    });

    testWidgets('realtime_message_arrives_and_badge_updates', (t) async {
      await pumpApp(
        t,
        location: '/chats',
        repo: FakeChat(threads: [t2], infos: {'t1': info1}),
      );
      expect(key('tab-badge'), findsNothing);
      expect(key('unread-dot-t1'), findsNothing);
      chat.threads = [t1, t2];
      chat.setUnread(2);
      await t.pumpAndSettle();
      expect(
        find.descendant(of: key('tab-bar'), matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        key('unread-dot-t1'),
        findsOneWidget,
        reason: 'the inbox refetches when a message arrives',
      );

      // and inside a thread a new message appears at once, and is read straight away
      await t.tap(key('thread-t1'));
      await t.pumpAndSettle();
      final before = chat.read.length;
      chat.push(
        't1',
        msg('m9', 'h9', 'One more thing', DateTime.utc(2030, 1, 9, 6, 2)),
      );
      await t.pumpAndSettle();
      expect(find.text('One more thing'), findsOneWidget);
      expect(chat.read.length, greaterThan(before));
    });
  });
}
