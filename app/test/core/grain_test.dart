import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/theme/grain.dart';

void main() {
  testWidgets('the grain is drawn over the child, in its own repaint layer', (t) async {
    await t.pumpWidget(const MaterialApp(home: GrainBackground(child: Text('hello'))));
    expect(find.text('hello'), findsOneWidget);
    expect(find.descendant(of: find.byType(GrainBackground), matching: find.byType(RepaintBoundary)), findsWidgets);
    expect(find.byKey(const Key('grain-overlay')), findsOneWidget);
  });

  testWidgets('the grain never swallows taps meant for what is underneath', (t) async {
    var taps = 0;
    await t.pumpWidget(MaterialApp(
      home: GrainBackground(child: Center(child: TextButton(onPressed: () => taps++, child: const Text('tap me')))),
    ));
    await t.tap(find.text('tap me'));
    expect(taps, 1);
  });

  testWidgets('the grain still builds on a very small area', (t) async {
    await t.pumpWidget(const MaterialApp(home: SizedBox(width: 3, height: 3, child: GrainBackground(child: SizedBox()))));
    expect(t.takeException(), isNull);
  });
}
