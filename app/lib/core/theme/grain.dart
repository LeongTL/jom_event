import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Film grain over [child]. One small tile of noise is drawn once and tiled; the overlay sits in its own
/// repaint layer and ignores touches, so scrolling content underneath never repaints it or loses a tap.
class GrainBackground extends StatelessWidget {
  const GrainBackground({super.key, required this.child, this.opacity = .07});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              key: const Key('grain-overlay'),
              child: CustomPaint(painter: _GrainPainter(opacity)),
            ),
          ),
        ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.opacity);

  final double opacity;
  static const _tileSize = 96.0;

  // Built the first time it is needed, then reused by every GrainBackground.
  static final ui.Picture _tile = _buildTile();

  static ui.Picture _buildTile() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final random = Random(7);
    final paint = Paint();
    for (var i = 0; i < 1100; i++) {
      paint.color = (random.nextBool() ? Colors.white : Colors.black).withValues(alpha: .25 + random.nextDouble() * .75);
      canvas.drawRect(Rect.fromLTWH(random.nextDouble() * _tileSize, random.nextDouble() * _tileSize, 1, 1), paint);
    }
    return recorder.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: opacity));
    for (var y = 0.0; y < size.height; y += _tileSize) {
      for (var x = 0.0; x < size.width; x += _tileSize) {
        canvas.save();
        canvas.translate(x, y);
        canvas.drawPicture(_tile);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.opacity != opacity;
}
