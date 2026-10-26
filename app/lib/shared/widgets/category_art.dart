import 'package:flutter/material.dart';

import '../../core/theme/calm.dart';

enum ArtKind { free, move, meet, meet2, make }

/// Which illustration an event gets: by its primary category; "meet" alternates with "meet2" by id so a list of
/// meetups does not repeat one picture.
ArtKind artKindFor(String eventId, List<String> categories) {
  final primary = primaryCategory(categories);
  if (primary != 'meet') return ArtKind.values.byName(primary);
  final sum = eventId.codeUnits.fold<int>(0, (a, b) => a + b);
  return sum.isEven ? ArtKind.meet : ArtKind.meet2;
}

const _backgrounds = {
  ArtKind.free: Color(0xFFF3EAD0),
  ArtKind.move: Color(0xFFDDEBE4),
  ArtKind.meet: Color(0xFFE1E6F2),
  ArtKind.meet2: Color(0xFFEEE3EC),
  ArtKind.make: Color(0xFFF3E6DD),
};

/// The category illustrations of the Calm prototype (its `P` table, drawn on a 400 x 300 canvas and cropped to fill).
class CategoryArt extends StatelessWidget {
  const CategoryArt({super.key, required this.kind});
  final ArtKind kind;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: _backgrounds[kind]!,
        child: SizedBox.expand(child: CustomPaint(painter: _ArtPainter(kind))),
      );
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.kind);
  final ArtKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 400 > size.height / 300 ? size.width / 400 : size.height / 300; // "slice": cover
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - 400 * scale) / 2, (size.height - 300 * scale) / 2);
    canvas.scale(scale);
    switch (kind) {
      case ArtKind.free:
        _circle(canvas, 300, 150, 70, const Color(0xFFE8B74A));
        _ring(canvas, 300, 150, 104, const Color(0x66E8B74A));
        _ring(canvas, 300, 150, 140, const Color(0x38E8B74A));
        _wave(canvas, 230, [110, 170, 220, 230, 330, 290, 440, 230], const Color(0xFFD9C58E));
      case ArtKind.move:
        _circle(canvas, 90, 90, 46, const Color(0xFFF3D9A4));
        _wave(canvas, 170, _swell(170, 40), const Color(0xFF9CC4B6));
        _wave(canvas, 215, _swell(215, 35), const Color(0xFF4F8F86));
        _wave(canvas, 260, _swell(260, 25), const Color(0xFF1F5E5B));
      case ArtKind.meet:
        _circle(canvas, 150, 150, 90, const Color(0xBF7F8FD0));
        _circle(canvas, 240, 150, 90, const Color(0xCCF0B7A4));
        _circle(canvas, 195, 150, 28, const Color(0x8CFFFFFF));
      case ArtKind.meet2:
        _circle(canvas, 130, 170, 80, const Color(0xB3C98BB0));
        _circle(canvas, 230, 120, 80, const Color(0xBFE8A87C));
        _circle(canvas, 300, 190, 50, const Color(0x997F8FD0));
      case ArtKind.make:
        _arch(canvas, 70, 150, 80, const Color(0xFFD98B6A));
        _arch(canvas, 110, 160, 40, const Color(0xFFFBF1E8));
        _circle(canvas, 300, 80, 26, const Color(0x8CC9704F));
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(250, 210, 110, 90), const Radius.circular(4)),
            Paint()..color = const Color(0xFFE9C3AB));
    }
    canvas.restore();
  }

  // Control points of "M0 y Q60 y-d 120 y T240 y T360 y T480 y": each T mirrors the last control point.
  static List<double> _swell(double y, double d) => [60, y - d, 120, y, 180, y + d, 240, y, 300, y - d, 360, y, 420, y + d, 480, y];

  void _circle(Canvas c, double x, double y, double r, Color color) => c.drawCircle(Offset(x, y), r, Paint()..color = color);

  void _ring(Canvas c, double x, double y, double r, Color color) => c.drawCircle(
      Offset(x, y), r, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);

  /// A filled band under a curve that starts at (0, y); [q] holds the control and end points of each quad segment.
  void _wave(Canvas c, double y, List<double> q, Color color) {
    final p = Path()..moveTo(0, y);
    for (var i = 0; i < q.length; i += 4) {
      p.quadraticBezierTo(q[i], q[i + 1], q[i + 2], q[i + 3]);
    }
    p..lineTo(q[q.length - 2], 300)..lineTo(0, 300)..close();
    c.drawPath(p, Paint()..color = color);
  }

  void _arch(Canvas c, double x, double top, double r, Color color) {
    final p = Path()
      ..moveTo(x, 300)
      ..lineTo(x, top)
      ..arcToPoint(Offset(x + 2 * r, top), radius: Radius.circular(r))
      ..lineTo(x + 2 * r, 300)
      ..close();
    c.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.kind != kind;
}

/// A poster photo when the event has one, else the category illustration.
class EventArt extends StatelessWidget {
  const EventArt({super.key, this.posterUrl, required this.kind});
  final String? posterUrl;
  final ArtKind kind;

  @override
  Widget build(BuildContext context) => posterUrl == null || posterUrl!.isEmpty
      ? CategoryArt(kind: kind)
      : Image.network(posterUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => CategoryArt(kind: kind));
}
