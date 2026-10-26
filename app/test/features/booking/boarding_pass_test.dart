import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/booking/domain/ticket.dart';
import 'package:jom/features/booking/presentation/boarding_pass_tile.dart';
import 'package:jom/shared/models/event_summary.dart';

import '../../helpers/fake_bookings.dart';
import '../../helpers/fake_events.dart';

Ticket ticket(String title, String host, {List<String> cats = const ['make']}) {
  final e = EventSummary.fromJson({
    'event_id': 'e1', 'title': title, 'starts_at': clock.add(const Duration(minutes: 22)).toIso8601String(),
    'ends_at': clock.add(const Duration(hours: 2)).toIso8601String(), 'price_sen': 0, 'area': 'Bangsar', 'is_live': false,
    'spots_left': 3, 'score': 0, 'categories': cats, 'host_name': host,
  });
  return Ticket(bk('b1', title: title), e);
}

Future<Size> pumpTile(WidgetTester t, Ticket tk) async {
  await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: BoardingPassTile(ticket: tk, now: clock, onTap: () {})))));
  expect(t.takeException(), isNull);
  return t.getSize(find.byType(BoardingPassTile));
}

void main() {
  testWidgets('boarding_pass_tiles_have_the_same_size_for_a_short_and_a_90_character_title_and_host', (t) async {
    final short = await pumpTile(t, ticket('Yoga', 'Mei'));
    final long = await pumpTile(t, ticket('A' * 90, 'B' * 90));
    expect(long, short);
    expect(short.width, 310);
  });

  testWidgets('shows_label_chip_title_host_and_the_three_columns', (t) async {
    await pumpTile(t, ticket('Sunset Yoga', 'Mei Studio'));
    expect(find.text('YOUR TICKET · TODAY'), findsOneWidget);
    expect(find.text('in 22 min'), findsOneWidget);
    expect(find.text('Sunset Yoga'), findsOneWidget);
    expect(find.text('Mei Studio · Bangsar'), findsOneWidget);
    for (final l in ['Date', 'Start time', 'Spots']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('9 Jan'), findsOneWidget);
    expect(find.text('2:22 PM'), findsOneWidget);
  });

  testWidgets('boarding_pass_clip_has_a_hole_on_each_edge_at_the_tear_line', (t) async {
    await pumpTile(t, ticket('Yoga', 'Mei'));
    final top = t.widget<ClipPath>(find.ancestor(of: find.byKey(const Key('boarding-top')), matching: find.byType(ClipPath)).first);
    final path = top.clipper!.getClip(const Size(310, 114));
    expect(path.contains(const Offset(1, 113)), isFalse, reason: 'bitten out at the bottom left');
    expect(path.contains(const Offset(309, 113)), isFalse, reason: 'and the bottom right');
    expect(path.contains(const Offset(155, 113)), isTrue);
    expect(path.contains(const Offset(1, 60)), isTrue);
  });

  testWidgets('a_processing_ticket_says_Processing_in_the_chip', (t) async {
    final tk = ticket('Yoga', 'Mei');
    await pumpTile(t, Ticket(bk('b1', status: 'processing'), tk.event));
    expect(find.text('Processing'), findsOneWidget);
  });
}
