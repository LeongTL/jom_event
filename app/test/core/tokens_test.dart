import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/theme/tokens.dart';

// Every value below is copied from the prototype's CSS (prototype/jom-hifi.html, `.phone[data-t=...]`).
// The prototype calls the three themes now / late / sat; the app calls them now / night / weekend.
void main() {
  test('sky colours of the old Home are still there until Task 19D', () {
    final now = JomTokens.of(JomTheme.now);
    expect([now.p1, now.p2, now.p3, now.p4],
        [const Color(0xFFFFB88C), const Color(0xFFFF7AA8), const Color(0xFF8B5CF6), const Color(0xFFFFD166)]);
  });

  test('translucent tokens keep the prototype alpha', () {
    final now = JomTokens.of(JomTheme.now);
    expect(now.sub, const Color.fromRGBO(255, 255, 255, .75));
    expect(now.glass, const Color.fromRGBO(255, 255, 255, .16));
    expect(now.glassBorder, const Color.fromRGBO(255, 255, 255, .28));
  });

  test('the odometer lime is the same on every theme', () {
    expect(JomTokens.odometer, const Color(0xFFC8FF2E));
  });

  test('the theme data carries the tokens and paints the screen warm white', () {
    for (final t in JomTheme.values) {
      final data = jomThemeData(t);
      expect(data.extension<JomTokens>(), JomTokens.of(t));
      expect(data.scaffoldBackgroundColor, JomTokens.of(t).sheet);
    }
  });

  test('the theme controller starts on Now and can switch', () {
    // the Home tabs (Task 15) switch it; here only the default and the switch are checked
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(jomThemeProvider), JomTheme.now);
    container.read(jomThemeProvider.notifier).select(JomTheme.night);
    expect(container.read(jomThemeProvider), JomTheme.night);
  });
}
