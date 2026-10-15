import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/theme/tokens.dart';

// Every value below is copied from the prototype's CSS (prototype/jom-hifi.html, `.phone[data-t=...]`).
// The prototype calls the three themes now / late / sat; the app calls them now / night / weekend.
void main() {
  test('tokens_match_prototype_for_each_theme', () {
    final now = JomTokens.of(JomTheme.now);
    expect(now.sheet, const Color(0xFF17102E));
    expect(now.sheetInk, const Color(0xFFF3EEFC));
    expect(now.accent, const Color(0xFFFFD166));
    expect(now.accentInk, const Color(0xFF2A1450));
    expect([now.p1, now.p2, now.p3, now.p4],
        [const Color(0xFFFFB88C), const Color(0xFFFF7AA8), const Color(0xFF8B5CF6), const Color(0xFFFFD166)]);

    final night = JomTokens.of(JomTheme.night);
    expect(night.sheet, const Color(0xFF0C0E22));
    expect(night.sheetInk, const Color(0xFFEEF0FF));
    expect(night.accent, const Color(0xFF9DB0FF));
    expect(night.accentInk, const Color(0xFF0B1030));
    expect([night.p1, night.p2, night.p3, night.p4],
        [const Color(0xFF7F8CFF), const Color(0xFFB07BFF), const Color(0xFF2F2A78), const Color(0xFF4A5FD6)]);

    final weekend = JomTokens.of(JomTheme.weekend);
    expect(weekend.sheet, const Color(0xFFFFFFFF));
    expect(weekend.sheetInk, const Color(0xFF14213A));
    expect(weekend.accent, const Color(0xFF0D2038));
    expect(weekend.accentInk, const Color(0xFFFFFFFF));
    expect(weekend.card, const Color(0xFFF1F6FB));
    expect([weekend.p1, weekend.p2, weekend.p3, weekend.p4],
        [const Color(0xFF7FD0FF), const Color(0xFFFFE08A), const Color(0xFFA8ECC8), const Color(0xFF6AA8FF)]);
  });

  test('translucent tokens keep the prototype alpha', () {
    final now = JomTokens.of(JomTheme.now);
    expect(now.sub, const Color.fromRGBO(255, 255, 255, .75));
    expect(now.glass, const Color.fromRGBO(255, 255, 255, .16));
    expect(now.glassBorder, const Color.fromRGBO(255, 255, 255, .28));
    expect(now.card, const Color.fromRGBO(255, 255, 255, .08));
    expect(now.line, const Color.fromRGBO(255, 255, 255, .12));
    expect(JomTokens.of(JomTheme.weekend).line, const Color.fromRGBO(20, 33, 58, .1));
  });

  test('the odometer lime is the same on every theme', () {
    expect(JomTokens.odometer, const Color(0xFFC8FF2E));
  });

  test('now and night are dark skies, weekend is a day sky', () {
    expect(jomThemeData(JomTheme.now).brightness, Brightness.dark);
    expect(jomThemeData(JomTheme.night).brightness, Brightness.dark);
    expect(jomThemeData(JomTheme.weekend).brightness, Brightness.light);
  });

  test('the theme data carries the tokens and paints the screen with the sheet colour', () {
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
