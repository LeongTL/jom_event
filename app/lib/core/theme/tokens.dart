import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The three skies. The prototype names them now / late / sat; the plan calls them now / night / weekend.
enum JomTheme { now, night, weekend }

/// Colour tokens copied from the prototype's CSS (`.phone[data-t=...]` in prototype/jom-hifi.html).
/// p1..p4 are the sky gradient; `sheet` is the background of screens and sheets ("--sheet").
@immutable
class JomTokens extends ThemeExtension<JomTokens> {
  const JomTokens({
    required this.p1,
    required this.p2,
    required this.p3,
    required this.p4,
    required this.ink,
    required this.sub,
    required this.glass,
    required this.glassBorder,
    required this.accent,
    required this.accentInk,
    required this.sheet,
    required this.sheetInk,
    required this.card,
    required this.line,
  });

  final Color p1, p2, p3, p4;
  final Color ink, sub, glass, glassBorder;
  final Color accent, accentInk;
  final Color sheet, sheetInk, card, line;

  /// The odometer tiles on Home: the same lime on every theme ("--inkc").
  static const Color odometer = Color(0xFFC8FF2E);

  static const _now = JomTokens(
    p1: Color(0xFFFFB88C), p2: Color(0xFFFF7AA8), p3: Color(0xFF8B5CF6), p4: Color(0xFFFFD166),
    ink: Color(0xFFFFFFFF), sub: Color.fromRGBO(255, 255, 255, .75),
    glass: Color.fromRGBO(255, 255, 255, .16), glassBorder: Color.fromRGBO(255, 255, 255, .28),
    accent: Color(0xFFFFD166), accentInk: Color(0xFF2A1450),
    sheet: Color(0xFF17102E), sheetInk: Color(0xFFF3EEFC),
    card: Color.fromRGBO(255, 255, 255, .08), line: Color.fromRGBO(255, 255, 255, .12),
  );

  static const _night = JomTokens(
    p1: Color(0xFF7F8CFF), p2: Color(0xFFB07BFF), p3: Color(0xFF2F2A78), p4: Color(0xFF4A5FD6),
    ink: Color(0xFFFFFFFF), sub: Color.fromRGBO(255, 255, 255, .72),
    glass: Color.fromRGBO(255, 255, 255, .12), glassBorder: Color.fromRGBO(255, 255, 255, .22),
    accent: Color(0xFF9DB0FF), accentInk: Color(0xFF0B1030),
    sheet: Color(0xFF0C0E22), sheetInk: Color(0xFFEEF0FF),
    card: Color.fromRGBO(255, 255, 255, .07), line: Color.fromRGBO(255, 255, 255, .1),
  );

  static const _weekend = JomTokens(
    p1: Color(0xFF7FD0FF), p2: Color(0xFFFFE08A), p3: Color(0xFFA8ECC8), p4: Color(0xFF6AA8FF),
    ink: Color(0xFF0D2038), sub: Color.fromRGBO(13, 32, 56, .7),
    glass: Color.fromRGBO(255, 255, 255, .5), glassBorder: Color.fromRGBO(255, 255, 255, .8),
    accent: Color(0xFF0D2038), accentInk: Color(0xFFFFFFFF),
    sheet: Color(0xFFFFFFFF), sheetInk: Color(0xFF14213A),
    card: Color(0xFFF1F6FB), line: Color.fromRGBO(20, 33, 58, .1),
  );

  factory JomTokens.of(JomTheme theme) => switch (theme) {
        JomTheme.now => _now,
        JomTheme.night => _night,
        JomTheme.weekend => _weekend,
      };

  // shortcut: the three token sets are fixed constants, never partly overridden or blended; switching
  // themes swaps the whole set. Implement real copyWith/lerp if a screen ever needs a cross-fade.
  @override
  JomTokens copyWith() => this;

  @override
  JomTokens lerp(ThemeExtension<JomTokens>? other, double t) => other is JomTokens && t >= .5 ? other : this;
}

/// The Flutter theme for a sky: dark for now and night, light for the weekend.
ThemeData jomThemeData(JomTheme theme) {
  final k = JomTokens.of(theme);
  final brightness = theme == JomTheme.weekend ? Brightness.light : Brightness.dark;
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: k.sheet,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: k.accent,
      onPrimary: k.accentInk,
      secondary: k.accent,
      onSecondary: k.accentInk,
      error: const Color(0xFFFF5A67),
      onError: const Color(0xFFFFFFFF),
      surface: k.sheet,
      onSurface: k.sheetInk,
    ),
    textTheme: base.textTheme.apply(bodyColor: k.sheetInk, displayColor: k.sheetInk),
    extensions: [k],
  );
}

extension JomThemeContext on BuildContext {
  JomTokens get jom => Theme.of(this).extension<JomTokens>()!;
}

/// Which sky the app is under. The Home time tabs switch it (Task 15).
class JomThemeController extends Notifier<JomTheme> {
  @override
  JomTheme build() => JomTheme.now;

  void select(JomTheme theme) => state = theme;
}

final jomThemeProvider = NotifierProvider<JomThemeController, JomTheme>(JomThemeController.new);
