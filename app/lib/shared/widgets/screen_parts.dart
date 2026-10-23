import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';

/// The top bar of a full screen: a round back button and the title (prototype .nav).
class BookingNav extends StatelessWidget {
  const BookingNav({super.key, required this.title, this.back = true, this.trailing});
  final String title;
  final bool back;
  final String? trailing; // a small muted label at the right ("Host", "Attendee")

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, MediaQuery.paddingOf(context).top + 5, 0, 14),
      child: Row(children: [
        if (back) ...[
          GestureDetector(
            key: const Key('nav-back'),
            onTap: () => context.canPop() ? context.pop() : context.go('/explore'),
            child: Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: k.card, shape: BoxShape.circle), child: const Text('‹', style: TextStyle(fontSize: 20, height: 1))),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.2))),
        if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62))),
      ]),
    );
  }
}

/// The 56-point rounded art square with the event's glyph (prototype .mini).
class MiniArt extends StatelessWidget {
  const MiniArt({super.key, required this.glyph, required this.a, required this.b});
  final String glyph;
  final Color a, b;

  @override
  Widget build(BuildContext context) => Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Text(glyph, style: const TextStyle(fontSize: 28, height: 1)),
      );
}

/// A rounded card (prototype .card).
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.jom.card, borderRadius: BorderRadius.circular(22)),
          child: child,
        ),
      );
}

/// The bottom bar that holds the main button over a fade (prototype .cta).
class CtaBar extends StatelessWidget {
  const CtaBar({super.key, required this.children, this.column = false});
  final List<Widget> children;
  final bool column;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 28),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [k.sheet.withValues(alpha: 0), k.sheet], stops: const [0, .38])),
        child: column ? Column(mainAxisSize: MainAxisSize.min, children: children) : Row(children: children),
      ),
    );
  }
}
