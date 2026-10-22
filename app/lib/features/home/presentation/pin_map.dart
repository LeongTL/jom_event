import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/models/event_summary.dart';
import '../domain/pin_layout.dart';

/// The little map: one pin per event, placed by [layoutPins], with the selected pin ringed. Tapping a pin
/// reports its index; the dock and the map share that index.
class PinMap extends StatelessWidget {
  const PinMap({
    super.key,
    required this.events,
    required this.selected,
    required this.onTap,
  });

  final List<EventSummary> events;
  final ValueListenable<int> selected;
  final ValueChanged<int> onTap;

  static const width = 340.0, height = 250.0, pinSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    final offsets = layoutPins([for (final e in events) e.id]);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _BackdropPainter(k.ink))),
          for (var i = 0; i < events.length; i++)
            Positioned(
              left: width / 2 + offsets[i].dx - pinSize / 2,
              top: height / 2 + offsets[i].dy - pinSize / 2,
              child: ValueListenableBuilder<int>(
                valueListenable: selected,
                builder: (context, sel, _) => _Pin(
                  event: events[i],
                  selected: sel == i,
                  onTap: () => onTap(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.event,
    required this.selected,
    required this.onTap,
  });
  final EventSummary event;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('pin-${event.id}'),
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.25 : 1,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // the marker's tip: a square turned 45 degrees behind the circle (prototype .node.pin::before)
            Positioned(
              bottom: -7,
              child: Transform.rotate(
                angle: .7853981634,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: event.colorB,
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              key: selected ? Key('pin-sel-${event.id}') : null,
              width: PinMap.pinSize,
              height: PinMap.pinSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [event.colorA, event.colorB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: selected ? 1 : .85),
                  width: selected ? 3 : 2,
                ),
                boxShadow: [
                  const BoxShadow(
                    color: Color(0x44000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                  if (selected)
                    const BoxShadow(color: Color(0x88FFFFFF), blurRadius: 22),
                ],
              ),
              child: Text(event.glyph, style: const TextStyle(fontSize: 22)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft stand-in for the prototype's map: a river, a few roads and a faint grid.
class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.ink);
  final Color ink;

  @override
  void paint(Canvas canvas, Size s) {
    final road = Paint()
      ..color = ink.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(-10, s.height * .3)
        ..cubicTo(
          s.width * .25,
          s.height * .5,
          s.width * .45,
          s.height * .15,
          s.width * .7,
          s.height * .35,
        )
        ..cubicTo(
          s.width * .85,
          s.height * .45,
          s.width * .95,
          s.height * .35,
          s.width + 10,
          s.height * .3,
        ),
      Paint()
        ..color = const Color(0xFF7FD0FF).withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(0, s.height * .6),
      Offset(s.width, s.height * .5),
      road..strokeWidth = 8,
    );
    canvas.drawLine(
      Offset(s.width * .2, 0),
      Offset(s.width * .35, s.height),
      road..strokeWidth = 6,
    );
    canvas.drawLine(
      Offset(s.width * .7, 0),
      Offset(s.width * .78, s.height),
      road..strokeWidth = 7,
    );
    final grid = Paint()
      ..color = ink.withValues(alpha: .07)
      ..strokeWidth = 1;
    for (final x in [s.width * .35, s.width * .8]) {
      canvas.drawLine(Offset(x, 0), Offset(x, s.height), grid);
    }
    for (final y in [s.height * .33, s.height * .75]) {
      canvas.drawLine(Offset(0, y), Offset(s.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.ink != ink;
}
