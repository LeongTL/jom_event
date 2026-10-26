import 'package:flutter/material.dart';

/// A horizontal dashed line (the tear line of a ticket).
class DashedLine extends StatelessWidget {
  const DashedLine({super.key, required this.color, this.thickness = 2, this.dash = 6, this.gap = 4});
  final Color color;
  final double thickness, dash, gap;

  @override
  Widget build(BuildContext context) => SizedBox(height: thickness, width: double.infinity, child: CustomPaint(painter: _Dashes(color, thickness, dash, gap)));
}

class _Dashes extends CustomPainter {
  _Dashes(this.color, this.thickness, this.dash, this.gap);
  final Color color;
  final double thickness, dash, gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = thickness;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, thickness / 2), Offset((x + dash).clamp(0, size.width), thickness / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.color != color || old.thickness != thickness || old.dash != dash || old.gap != gap;
}
