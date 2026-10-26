import 'package:flutter/material.dart';

/// Up to three overlapping circles with a person glyph. They only say "people are going"; the app never shows who.
class PeopleStack extends StatelessWidget {
  const PeopleStack({super.key, required this.count, this.size = 24});
  final int count;
  final double size;

  static const _colors = [Color(0xFF7F8FD0), Color(0xFFE8A87C), Color(0xFF1F5E5B)];

  @override
  Widget build(BuildContext context) {
    final n = count.clamp(0, 3);
    return SizedBox(
      key: const Key('people-stack'),
      width: n == 0 ? 0 : size + (n - 1) * (size - 7),
      height: size,
      child: Stack(children: [
        for (var i = 0; i < n; i++)
          Positioned(
            left: i * (size - 7),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: _colors[i], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: Icon(Icons.person, size: size * .55, color: Colors.white),
            ),
          ),
      ]),
    );
  }
}
