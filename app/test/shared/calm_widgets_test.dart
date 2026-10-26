import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/shared/widgets/category_art.dart';
import 'package:jom/shared/widgets/people_stack.dart';
import 'package:jom/shared/widgets/verified_badge.dart';

void main() {
  testWidgets('people_stack_contains_no_text_widgets_and_caps_at_three', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: PeopleStack(count: 12))));
    expect(find.descendant(of: find.byKey(const Key('people-stack')), matching: find.byType(Text)), findsNothing);
    expect(find.byIcon(Icons.person), findsNWidgets(3));
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: PeopleStack(count: 1))));
    expect(find.byIcon(Icons.person), findsOneWidget);
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: PeopleStack(count: 0))));
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('every illustration paints without error at card, row and hero sizes', (t) async {
    for (final kind in ArtKind.values) {
      for (final size in [const Size(262, 136), const Size(72, 72), const Size(390, 280)]) {
        await t.pumpWidget(MaterialApp(home: Center(child: SizedBox.fromSize(size: size, child: CategoryArt(kind: kind)))));
        expect(t.takeException(), isNull, reason: '$kind $size');
      }
    }
  });

  testWidgets('EventArt shows the category art when there is no poster', (t) async {
    await t.pumpWidget(const MaterialApp(home: SizedBox(width: 100, height: 100, child: EventArt(kind: ArtKind.make))));
    expect(find.byType(CategoryArt), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('verified_badge_renders_its_tick', (t) async {
    await t.pumpWidget(const MaterialApp(home: VerifiedBadge()));
    expect(find.byKey(const Key('verified-badge')), findsOneWidget);
  });
}
