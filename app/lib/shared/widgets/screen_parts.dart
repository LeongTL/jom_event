import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/calm.dart';

/// The top bar of a full screen: a round back button and the title (prototype .nav).
class BookingNav extends StatelessWidget {
  const BookingNav({
    super.key,
    required this.title,
    this.back = true,
    this.trailing,
  });
  final String title;
  final bool back;
  final String?
  trailing; // a small muted label at the right ("Host", "Attendee")

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        MediaQuery.paddingOf(context).top + 5,
        0,
        14,
      ),
      child: Row(
        children: [
          if (back) ...[
            GestureDetector(
              key: const Key('nav-back'),
              onTap: () =>
                  context.canPop() ? context.pop() : context.go('/explore'),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Calm.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Calm.line),
                ),
                child: const Icon(Icons.chevron_left, size: 22),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(fontSize: 13, color: Calm.mut),
            ),
        ],
      ),
    );
  }
}

/// The 56-point rounded art square with the event's glyph (prototype .mini).
class MiniArt extends StatelessWidget {
  const MiniArt({
    super.key,
    required this.glyph,
    required this.a,
    required this.b,
  });
  final String glyph;
  final Color a, b;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        colors: [a, b],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Text(glyph, style: const TextStyle(fontSize: 28, height: 1)),
  );
}

/// A rounded card (prototype .card).
class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.onTap, this.gap = 12});
  final Widget child;
  final VoidCallback? onTap;
  final double
  gap; // space below the card (the prototype uses 8 in lists of small cards)

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: gap),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Calm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Calm.line),
      ),
      child: child,
    ),
  );
}

/// The bottom bar that holds the main button (prototype .cta): white with a hairline on top.
class CtaBar extends StatelessWidget {
  const CtaBar({super.key, required this.children, this.column = false});
  final List<Widget> children;
  final bool column;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        decoration: const BoxDecoration(
          color: Calm.surface,
          border: Border(top: BorderSide(color: Calm.line)),
        ),
        child: column
            ? Column(mainAxisSize: MainAxisSize.min, children: children)
            : Row(children: children),
      ),
    );
  }
}
