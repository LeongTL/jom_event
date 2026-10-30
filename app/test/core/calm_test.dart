import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/theme/calm.dart';
import 'package:jom/shared/widgets/category_art.dart';

// Every value is copied from the :root of docs/superpowers/kl-local-session-calm.html.
void main() {
  test('calm_tokens_match_the_prototype_values', () {
    expect(
      [Calm.bg, Calm.surface, Calm.ink, Calm.mut, Calm.faint, Calm.line],
      [
        0xFFFAF8F5,
        0xFFFFFFFF,
        0xFF1B2430,
        0xFF5F6B7A,
        0xFF8A94A1,
        0xFFE7E2DA,
      ].map(Color.new),
    );
    expect(
      [
        Calm.acc,
        Calm.accSoft,
        Calm.ok,
        Calm.okSoft,
        Calm.bad,
        Calm.badSoft,
        Calm.warn,
        Calm.warnSoft,
        Calm.badge,
      ],
      [
        0xFF1F5E5B,
        0xFFE3EFEC,
        0xFF1E7A4F,
        0xFFE4F1E9,
        0xFFB3261E,
        0xFFFBE9E7,
        0xFF9A6200,
        0xFFFBF0D9,
        0xFFC9432F,
      ].map(Color.new),
    );
  });

  test('ticketColor_per_category', () {
    expect([
      ticketColor('move'),
      ticketColor('make'),
      ticketColor('meet'),
      ticketColor('free'),
    ], [0xFF1F5E5B, 0xFFA8553A, 0xFF4B5A9E, 0xFF7A6A2B].map(Color.new));
  });

  test('primaryCategory_rules', () {
    expect(primaryCategory(['free', 'meet']), 'meet');
    expect(primaryCategory(['free']), 'free');
    expect(primaryCategory([]), 'free');
    expect(primaryCategory(['other']), 'meet');
    expect(primaryCategory(['move', 'meet']), 'move');
  });

  test('artKindFor_is_deterministic_and_meet_alternates_with_meet2', () {
    expect(artKindFor('x', ['make']), ArtKind.make);
    expect(artKindFor('x', ['free']), ArtKind.free);
    expect(artKindFor('x', ['move', 'meet']), ArtKind.move);
    final kinds = {
      for (final id in ['a', 'b', 'c', 'd']) artKindFor(id, ['meet']),
    };
    expect(kinds, {ArtKind.meet, ArtKind.meet2});
    expect(artKindFor('a', ['meet']), artKindFor('a', ['meet']));
  });

  test('the theme is the calm one: light, warm white, Inter, with the tokens attached', () {
    final data = calmTheme();
    expect(data.brightness, Brightness.light);
    expect(data.scaffoldBackgroundColor, Calm.bg);
    expect(data.extension<JomTokens>()!.accent, Calm.acc);
    expect(data.extension<JomTokens>()!.sheet, Calm.bg);
    expect(data.textTheme.bodyMedium!.fontFamily, 'Inter');
  });

  test('pubspec_declares_inter_and_fraunces', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('family: Inter'));
    expect(pubspec, contains('family: Fraunces'));
    expect(File('assets/fonts/Inter.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/Fraunces.ttf').existsSync(), isTrue);
  });
}
