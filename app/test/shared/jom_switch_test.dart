import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/theme/calm.dart';
import 'package:jom/shared/widgets/jom_switch.dart';

Future<void> pump(WidgetTester t, bool value, ValueChanged<bool>? onChanged) => t.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [const JomTokens()]),
      home: Scaffold(body: Center(child: JomSwitch(value: value, onChanged: onChanged))),
    ));

void main() {
  testWidgets('off: grey track, knob on the left; on: accent track, knob on the right', (t) async {
    await pump(t, false, (_) {});
    var box = t.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(((box.decoration as BoxDecoration).color), const Color(0xFFD8D3CA));
    expect(box.alignment, Alignment.centerLeft);
    await pump(t, true, (_) {});
    box = t.widget<AnimatedContainer>(find.byType(AnimatedContainer));
    expect(((box.decoration as BoxDecoration).color), Calm.acc);
    expect(box.alignment, Alignment.centerRight);
    expect(t.getSize(find.byType(AnimatedContainer)), const Size(46, 28));
  });

  testWidgets('a tap asks for the opposite value; with no callback it does nothing', (t) async {
    bool? asked;
    await pump(t, true, (v) => asked = v);
    await t.tap(find.byType(JomSwitch));
    expect(asked, false);
    asked = null;
    await pump(t, true, null);
    await t.tap(find.byType(JomSwitch));
    expect(asked, isNull);
  });
}
