import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/theme/calm.dart';
import 'package:jom/shared/widgets/shell.dart';

Widget host(Widget bar) => MaterialApp(
  theme: calmTheme(),
  home: Scaffold(
    body: Align(alignment: Alignment.bottomCenter, child: bar),
  ),
);

void main() {
  testWidgets('shell_shows_five_tabs_for_attendee_and_five_for_host', (
    t,
  ) async {
    await t.pumpWidget(host(AttendeeTabs(currentIndex: 0, onTap: (_) {})));
    for (final label in ['Explore', 'Saved', 'Tickets', 'Chat', 'Profile']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byKey(const Key('tab-bar')), findsOneWidget);

    await t.pumpWidget(host(HostTabs(currentIndex: 0, onTap: (_) {})));
    for (final label in ['Home', 'Events', 'Payouts', 'Chat', 'Profile']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Explore'), findsNothing);
  });

  testWidgets('the current tab is marked, the others are not', (t) async {
    await t.pumpWidget(host(AttendeeTabs(currentIndex: 2, onTap: (_) {})));
    expect(find.byKey(const Key('tab-on:Tickets')), findsOneWidget);
    expect(find.byKey(const Key('tab-off:Explore')), findsOneWidget);
    expect(find.byKey(const Key('tab-on:Explore')), findsNothing);
  });

  testWidgets('tapping a tab reports its position', (t) async {
    final taps = <int>[];
    await t.pumpWidget(host(AttendeeTabs(currentIndex: 0, onTap: taps.add)));
    await t.tap(find.text('Saved'));
    await t.tap(find.text('Profile'));
    expect(taps, [1, 4]);
  });

  testWidgets('tab_badge_renders_count_and_hides_at_zero', (t) async {
    await t.pumpWidget(
      host(AttendeeTabs(currentIndex: 0, onTap: (_) {}, chatBadge: 3)),
    );
    expect(find.byKey(const Key('tab-badge')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await t.pumpWidget(
      host(AttendeeTabs(currentIndex: 0, onTap: (_) {}, chatBadge: 0)),
    );
    expect(find.byKey(const Key('tab-badge')), findsNothing);
  });

  testWidgets('a big count reads 9+ so the badge stays small', (t) async {
    await t.pumpWidget(
      host(AttendeeTabs(currentIndex: 0, onTap: (_) {}, chatBadge: 12)),
    );
    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('the host Chat tab has the badge slot too, and only on Chat', (
    t,
  ) async {
    await t.pumpWidget(
      host(HostTabs(currentIndex: 0, onTap: (_) {}, chatBadge: 2)),
    );
    expect(find.byKey(const Key('tab-badge')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('tab-off:Chat')),
        matching: find.byKey(const Key('tab-badge')),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'the bar is white with a top hairline, the active tab is accent and the badge is C9432F',
    (t) async {
      await t.pumpWidget(
        host(AttendeeTabs(currentIndex: 0, onTap: (_) {}, chatBadge: 2)),
      );
      final box =
          t.widget<DecoratedBox>(find.byKey(const Key('tab-bar'))).decoration
              as BoxDecoration;
      expect(box.color, Calm.surface);
      expect((box.border! as Border).top.color, Calm.line);
      expect(t.widget<Text>(find.text('Explore')).style!.color, Calm.acc);
      expect(t.widget<Text>(find.text('Saved')).style!.color, Calm.faint);
      final badge = t.widget<Container>(find.byKey(const Key('tab-badge')));
      expect(
        (badge.decoration as BoxDecoration).color,
        const Color(0xFFC9432F),
      );
    },
  );
}
