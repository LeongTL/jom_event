import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/theme/calm.dart';
import 'package:jom/shared/widgets/status_pill.dart';

Widget host(Widget child) => MaterialApp(
  theme: calmTheme(),
  home: Scaffold(body: Center(child: child)),
);

Color? pillColor(WidgetTester t) {
  final box = t.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(StatusPill),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  testWidgets('a pill shows its label in the Calm colours', (t) async {
    await t.pumpWidget(
      host(const StatusPill(label: 'Confirmed', tone: StatusTone.good)),
    );
    expect(find.text('Confirmed'), findsOneWidget);
    expect(pillColor(t), Calm.okSoft);

    await t.pumpWidget(
      host(const StatusPill(label: 'Processing', tone: StatusTone.warn)),
    );
    expect(pillColor(t), Calm.warnSoft);

    await t.pumpWidget(
      host(const StatusPill(label: 'Cancelled', tone: StatusTone.bad)),
    );
    expect(pillColor(t), Calm.badSoft);
  });

  testWidgets('a neutral pill is the soft grey chip', (t) async {
    await t.pumpWidget(host(const StatusPill(label: 'Held')));
    expect(pillColor(t), Calm.chip);
  });

  testWidgets(
    'booking statuses get the labels and colours the Bookings screen uses',
    (t) async {
      const expected = {
        'confirmed': ('Confirmed', StatusTone.good),
        'processing': ('Processing', StatusTone.warn),
        'attended': ('Attended', StatusTone.good),
        'cancelled': ('Cancelled', StatusTone.bad),
        'no_show': ('No-show', StatusTone.bad),
      };
      for (final e in expected.entries) {
        await t.pumpWidget(host(StatusPill.booking(e.key)));
        expect(find.text(e.value.$1), findsOneWidget, reason: e.key);
        expect(
          t.widget<StatusPill>(find.byType(StatusPill)).tone,
          e.value.$2,
          reason: e.key,
        );
      }
    },
  );

  testWidgets('an unexpected booking status is shown readably and neutral', (
    t,
  ) async {
    await t.pumpWidget(host(StatusPill.booking('payment_failed')));
    expect(find.text('Payment failed'), findsOneWidget);
    expect(
      t.widget<StatusPill>(find.byType(StatusPill)).tone,
      StatusTone.neutral,
    );
  });
}
