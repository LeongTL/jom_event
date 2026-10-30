import 'package:flutter/material.dart';

/// The Calm palette, copied from the `:root` of docs/superpowers/kl-local-session-calm.html.
abstract final class Calm {
  static const bg = Color(0xFFFAF8F5);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1B2430);
  static const mut = Color(0xFF5F6B7A);
  static const faint = Color(0xFF8A94A1);
  static const line = Color(0xFFE7E2DA);
  static const acc = Color(0xFF1F5E5B);
  static const accSoft = Color(0xFFE3EFEC);
  static const ok = Color(0xFF1E7A4F);
  static const okSoft = Color(0xFFE4F1E9);
  static const bad = Color(0xFFB3261E);
  static const badSoft = Color(0xFFFBE9E7);
  static const warn = Color(0xFF9A6200);
  static const warnSoft = Color(0xFFFBF0D9);
  static const badge = Color(0xFFC9432F); // unread counts and the saved heart
  static const chip = Color(
    0xFFF0EDE8,
  ); // neutral status chip and segmented control track
  static const soft = Color(0xFFF4F1EC); // soft notes and locked fields

  /// Headings and big numbers: Fraunces. Everything else is Inter (the theme's font).
  static const serif = 'Fraunces';
}

/// The first category that is not "free" (an "other" event counts as "meet"), else "free".
String primaryCategory(List<String> categories) {
  for (final c in categories) {
    if (c != 'free') return c == 'other' ? 'meet' : c;
  }
  return 'free';
}

/// The ticket header colour of a primary category.
Color ticketColor(String primary) => switch (primary) {
  'move' => const Color(0xFF1F5E5B),
  'make' => const Color(0xFFA8553A),
  'meet' => const Color(0xFF4B5A9E),
  _ => const Color(0xFF7A6A2B),
};

/// The few colours the screens read through `context.jom` (screens, cards, lines, accent). They are the Calm palette.
@immutable
class JomTokens extends ThemeExtension<JomTokens> {
  const JomTokens();
  Color get accent => Calm.acc;
  Color get accentInk => Colors.white;
  Color get sheet => Calm.bg;
  Color get sheetInk => Calm.ink;
  Color get card => Calm.surface;
  Color get line => Calm.line;

  @override
  JomTokens copyWith() => this;

  @override
  JomTokens lerp(ThemeExtension<JomTokens>? other, double t) => this;
}

extension JomTokensContext on BuildContext {
  JomTokens get jom => Theme.of(this).extension<JomTokens>()!;
}

ThemeData calmTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Inter',
  );
  return base.copyWith(
    scaffoldBackgroundColor: Calm.bg,
    colorScheme: const ColorScheme.light(
      primary: Calm.acc,
      onPrimary: Colors.white,
      secondary: Calm.acc,
      onSecondary: Colors.white,
      error: Calm.bad,
      surface: Calm.bg,
      onSurface: Calm.ink,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Calm.ink,
      displayColor: Calm.ink,
    ),
    extensions: const [JomTokens()],
  );
}
