import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// The big number on Home: one lime tile per digit. Digits roll when the number changes and the tiles glow once.
class Odometer extends StatefulWidget {
  const Odometer({super.key, required this.value});
  final int value;

  @override
  State<Odometer> createState() => _OdometerState();
}

class _OdometerState extends State<Odometer> with SingleTickerProviderStateMixin {
  late final _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward(from: .5);

  @override
  void didUpdateWidget(Odometer old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _glow.forward(from: 0);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.value.toString().split('');
    return Semantics(
      label: '${widget.value}',
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _glow,
        builder: (context, _) {
          final pulse = 1 - (_glow.value - .5).abs() * 2; // 0 at the ends, 1 in the middle
          return Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < digits.length; i++)
              Container(
                margin: const EdgeInsets.only(right: 4),
                width: 44,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: JomTokens.odometer,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: JomTokens.odometer.withValues(alpha: .15 + .4 * pulse), blurRadius: 10 + 14 * pulse)],
                ),
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(anim),
                      child: child,
                    ),
                    child: Text(digits[i], key: ValueKey('$i-${digits[i]}'), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Color(0xFF14213A))),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
