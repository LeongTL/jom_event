import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/shared/widgets/jom_switch.dart';

import '../../helpers/fake_events.dart';
import '../../helpers/fake_host.dart';
import '../../helpers/pump_app.dart';

bool switchOn(WidgetTester t) => t
    .widget<JomSwitch>(
      find.descendant(
        of: key('form-visibility'),
        matching: find.byType(JomSwitch),
      ),
    )
    .value;

void main() {
  group('visibility switch', () {
    testWidgets('a new event is Public until the host switches it', (t) async {
      final host = FakeHost(profile: hostMe());
      await pumpApp(t, location: '/host-mode/new', host: host);
      expect(switchOn(t), isFalse);
      expect(
        find.text(
          'Private events are hidden from Explore and search. Only people with your link can open them.',
        ),
        findsOneWidget,
      );
      await t.tap(
        find.descendant(
          of: key('form-visibility'),
          matching: find.byType(JomSwitch),
        ),
      );
      await t.enterText(key('form-title'), 'Quiet supper');
      await t.pump();
      await t.tap(key('save-draft'));
      await t.pumpAndSettle();
      expect(host.saved.single.$1.isPrivate, isTrue);
    });

    testWidgets(
      'editing starts from the stored value and can flip it after guests joined',
      (t) async {
        final host = FakeHost(
          profile: hostMe(),
          events: [hostEvent('e1', sold: 8, isPrivate: true)],
        );
        await pumpApp(t, location: '/host-mode/events/e1/edit', host: host);
        expect(switchOn(t), isTrue);
        await t.tap(
          find.descendant(
            of: key('form-visibility'),
            matching: find.byType(JomSwitch),
          ),
        );
        await t.pump();
        expect(switchOn(t), isFalse, reason: 'not locked after guests joined');
        await t.tap(key('save-changes'));
        await t.pumpAndSettle();
        expect(host.visibilities, [('e1', false)]);
      },
    );
  });

  group('share card and opening by link', () {
    testWidgets('the host sees the link and can copy it', (t) async {
      final copied = <String>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpApp(
        t,
        location: '/host-mode/events/e1',
        host: FakeHost(
          profile: hostMe(),
          events: [hostEvent('e1', isPrivate: true, shareCode: 'abCD12efGH')],
        ),
      );
      expect(
        find.descendant(
          of: key('share-card'),
          matching: find.text('jom://e/abCD12efGH'),
        ),
        findsOneWidget,
      );
      await t.tap(key('copy-share-link'));
      await t.pump();
      expect(copied, ['jom://e/abCD12efGH']);
    });

    testWidgets('a link opens the event, a wrong one says so', (t) async {
      final ev = detailOf(sum('e9', title: 'Secret supper'), isPrivate: true);
      await pumpApp(
        t,
        location: '/e/abCD12efGH',
        events: FakeEvents(codes: {'abCD12efGH': ev}, details: {'e9': ev}),
      );
      expect(find.text('Secret supper'), findsOneWidget);
      expect(key('private-tag'), findsOneWidget);
      await pumpApp(t, location: '/e/nope', events: FakeEvents());
      expect(key('event-not-found'), findsOneWidget);
    });
  });
}
