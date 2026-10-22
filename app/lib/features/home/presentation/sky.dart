import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

// The prototype's own Home skies (.skyL, .skystars and .orb in kl-local-session-hifi.html). They are not the
// theme's p1..p4 colours: Now is a dusk that runs dark purple to orange, Night is deep navy, Weekend is day sky.
class _Sky {
  const _Sky(
    this.colors,
    this.stops,
    this.stars,
    this.orbColors,
    this.orbAt,
    this.orbSize,
    this.orbOpacity,
  );
  final List<Color> colors;
  final List<double> stops;
  final double stars; // opacity of the little white stars
  final List<Color> orbColors;
  final Offset orbAt; // left/top in the prototype's 390 x 844 design
  final double orbSize, orbOpacity;
}

const _skies = {
  JomTheme.now: _Sky(
    [
      Color(0xFF1A0F3D),
      Color(0xFF4A1F7A),
      Color(0xFFD4467C),
      Color(0xFFFF9A62),
    ],
    [0, .34, .68, 1],
    .35,
    [Color(0xFFFFE29A), Color(0xFFFFB35C), Color(0x00FF965A)],
    Offset(200, 330),
    150,
    .9,
  ),
  JomTheme.night: _Sky(
    [Color(0xFF050816), Color(0xFF0F1538), Color(0xFF2A1F5C)],
    [0, .45, 1],
    .9,
    [Color(0xFFFFFFFF), Color(0xFFDFE3FF), Color(0x00C8D2FF)],
    Offset(250, 70),
    90,
    .95,
  ),
  JomTheme.weekend: _Sky(
    [Color(0xFF59B8FF), Color(0xFF9BE0FF), Color(0xFFFFF0C9)],
    [0, .45, 1],
    0,
    [Color(0xFFFFFBE0), Color(0xFFFFF3A0), Color(0x00FFF3A0)],
    Offset(230, 30),
    150,
    1,
  ),
};

class HomeSky extends StatelessWidget {
  const HomeSky({super.key, required this.tab});
  final JomTheme tab;

  @override
  Widget build(BuildContext context) {
    final sky = _skies[tab]!;
    return LayoutBuilder(
      builder: (context, c) {
        final sx = c.maxWidth / 390, sy = c.maxHeight / 844;
        return DecoratedBox(
          key: const Key('home-sky'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: sky.colors,
              stops: sky.stops,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              if (sky.stars > 0)
                Positioned.fill(
                  child: CustomPaint(painter: _Stars(sky.stars, sx, sy)),
                ),
              Positioned(
                left: sky.orbAt.dx * sx,
                top: sky.orbAt.dy * sy,
                width: sky.orbSize * sx,
                height: sky.orbSize * sx,
                child: Opacity(
                  opacity: sky.orbOpacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: sky.orbColors,
                        stops: const [0, .45, .7],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Stars extends CustomPainter {
  _Stars(this.opacity, this.sx, this.sy);
  final double opacity, sx, sy;
  static const _dots = [
    (30.0, 70.0, 1.5),
    (90.0, 130.0, 1.0),
    (160.0, 50.0, 1.5),
    (230.0, 110.0, 1.0),
    (300.0, 60.0, 1.5),
    (350.0, 140.0, 1.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
    for (final (x, y, r) in _dots) {
      canvas.drawCircle(Offset(x * sx, y * sy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_Stars old) =>
      old.opacity != opacity || old.sx != sx || old.sy != sy;
}
