import 'package:flutter/material.dart';

import '../../core/theme/calm.dart';

/// Grey placeholder shapes that pulse while a screen loads, in the layout of what will replace them.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});
  final Widget child;

  /// A list of event rows (72 px picture and two text lines).
  static Widget rows([int n = 4]) => Skeleton(child: Column(children: [for (var i = 0; i < n; i++) const _Row()]));

  /// A heading and a horizontal carousel of 262 px cards.
  static Widget carousel() => Skeleton(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 26),
          child: Row(children: [for (var i = 0; i < 2; i++) const Padding(padding: EdgeInsets.only(right: 12), child: _Card())]),
        ),
      );

  /// What Home shows before its data arrives: the carousel then the rows.
  static Widget feed() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        const Skeleton(child: _Bar(width: 120, height: 18)),
        const SizedBox(height: 12),
        carousel(),
        const Skeleton(child: _Bar(width: 90, height: 18)),
        const SizedBox(height: 12),
        rows(),
      ]);

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: Tween(begin: .45, end: 1.0).animate(_c), child: widget.child);
}

class _Bar extends StatelessWidget {
  const _Bar({this.width, this.height = 12});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(width: width, height: height, decoration: BoxDecoration(color: Calm.chip, borderRadius: BorderRadius.circular(6)));
}

class _Row extends StatelessWidget {
  const _Row();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Calm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Calm.line)),
        child: Row(children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(color: Calm.chip, borderRadius: BorderRadius.circular(12))),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Bar(height: 14), SizedBox(height: 8), _Bar(width: 90), SizedBox(height: 14), _Bar(width: 140)])),
        ]),
      );
}

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) => Container(
        width: 262,
        decoration: BoxDecoration(color: Calm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Calm.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 140, decoration: const BoxDecoration(color: Calm.chip, borderRadius: BorderRadius.vertical(top: Radius.circular(16)))),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_Bar(height: 14), SizedBox(height: 8), _Bar(width: 100), SizedBox(height: 10), _Bar(width: 150)]),
          ),
        ]),
      );
}
