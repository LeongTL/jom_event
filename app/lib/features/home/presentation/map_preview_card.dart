import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';

/// "On the map": a small illustrated map with the event count and an Open map button. Task 19E swaps the picture
/// for a live map preview.
class MapPreviewCard extends StatelessWidget {
  const MapPreviewCard({super.key, required this.count, required this.km});
  final int count;
  final int km;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('map-card'),
    onTap: () => context.push('/explore/map'),
    child: Container(
      height: 170,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Calm.line),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _MiniMap())),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count ${count == 1 ? 'event' : 'events'} within $km km',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Calm.acc,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Open map',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The prototype's MINIMAP drawing on a 350 x 170 canvas.
class _MiniMap extends CustomPainter {
  const _MiniMap();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 350 > size.height / 170
        ? size.width / 350
        : size.height / 170;
    canvas.save();
    canvas.translate((size.width - 350 * s) / 2, (size.height - 170 * s) / 2);
    canvas.scale(s);
    canvas.drawRect(
      const Rect.fromLTWH(-20, -20, 400, 220),
      Paint()..color = const Color(0xFFEFEBE3),
    );
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(-10, 120)
        ..cubicTo(80, 150, 140, 80, 230, 125)
        ..cubicTo(300, 150, 330, 150, 370, 110),
      stroke(const Color(0xFFBFD9E6), 16),
    );
    final park = Paint()..color = const Color(0xFFD3E5CC);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(70, 45), width: 96, height: 52),
      park,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(290, 40), width: 72, height: 40),
      park,
    );
    final big = stroke(Colors.white, 7);
    canvas.drawLine(const Offset(0, 80), const Offset(350, 60), big);
    canvas.drawLine(const Offset(110, 0), const Offset(150, 170), big);
    canvas.drawPath(
      Path()
        ..moveTo(250, 0)
        ..cubicTo(235, 70, 270, 110, 250, 170),
      big,
    );
    final small = stroke(Colors.white, 3);
    canvas.drawLine(const Offset(0, 130), const Offset(350, 150), small);
    canvas.drawLine(const Offset(40, 0), const Offset(20, 170), small);
    canvas.drawLine(const Offset(320, 0), const Offset(330, 170), small);
    for (final p in const [
      Offset(130, 70),
      Offset(205, 52),
      Offset(260, 95),
      Offset(90, 110),
    ]) {
      canvas.drawCircle(p, 9, Paint()..color = Calm.acc);
      canvas.drawCircle(p, 9, stroke(Colors.white, 2.5));
    }
    canvas.drawCircle(
      const Offset(175, 92),
      6,
      Paint()..color = const Color(0xFF2F6BFF),
    );
    canvas.drawCircle(const Offset(175, 92), 6, stroke(Colors.white, 2.5));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MiniMap old) => false;
}
