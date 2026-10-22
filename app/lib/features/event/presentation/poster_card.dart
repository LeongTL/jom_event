import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/models/event_summary.dart';
import '../domain/event_labels.dart';
import '../domain/saved_controller.dart';

/// The heart. Every heart reads the one saved set, so the poster, the event hero, the bottom bar and the Saved
/// tab always agree. [style] only changes how it is drawn.
enum HeartStyle { poster, hero, bar }

class HeartButton extends ConsumerWidget {
  const HeartButton({super.key, required this.eventId, this.style = HeartStyle.poster});

  final String eventId;
  final HeartStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    final on = ref.watch(savedProvider).value?.contains(eventId) ?? false;
    final (size, glyph, fill, ink) = switch (style) {
      HeartStyle.poster => (30.0, '♥', on ? Colors.white : const Color(0x38FFFFFF), on ? const Color(0xFFFF3D6E) : Colors.white),
      HeartStyle.hero => (40.0, on ? '♥' : '♡', const Color(0x47000000), Colors.white),
      HeartStyle.bar => (54.0, on ? '♥' : '♡', k.card, k.sheetInk),
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => toggleHeart(ref, context, eventId),
      child: Container(
        key: Key('heart-${on ? 'on' : 'off'}:$eventId'),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: Text(glyph, style: TextStyle(color: ink, fontSize: style == HeartStyle.poster ? 14 : 20, height: 1)),
      ),
    );
  }
}

/// The tag in a poster's top corner. HAPPENING gets the blinking dot; under 2 hours it counts down each second.
class PosterTag extends ConsumerStatefulWidget {
  const PosterTag({super.key, required this.event});
  final EventSummary event;

  @override
  ConsumerState<PosterTag> createState() => _PosterTagState();
}

class _PosterTagState extends ConsumerState<PosterTag> {
  Timer? _timer;
  late String _text = _read();

  String _read() => posterTag(widget.event, ref.read(nowProvider)());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _read();
      if (next != _text) setState(() => _text = next);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(99)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (_text == 'HAPPENING') ...[
            Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFFF4D5E), shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(_text, key: Key('tag-${widget.event.id}'), style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// One event as a poster: art, tag, price, title, distance and the heart. [ended] adds the "Ended" tag and dims it.
class PosterCard extends StatelessWidget {
  const PosterCard({super.key, required this.event, required this.onTap, this.ended = false});

  final EventSummary event;
  final VoidCallback onTap;
  final bool ended;

  @override
  Widget build(BuildContext context) {
    final e = event;
    return Opacity(
      key: Key('dim:${e.id}'),
      opacity: ended ? .55 : 1,
      child: GestureDetector(
        key: Key('poster-${e.id}'),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [e.colorA, e.colorB], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Stack(children: [
              // the highlight and the dark foot (.poster::before)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(center: const Alignment(-.6, -.7), radius: .9, colors: const [Color(0x47FFFFFF), Color(0x00FFFFFF)], stops: const [0, .5]),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x8C000000)], stops: [.4, 1])),
                ),
              ),
              Positioned(
                right: -6,
                top: 6,
                child: Transform.rotate(angle: -10 * 3.14159 / 180, child: Text(e.glyph, style: const TextStyle(fontSize: 92, height: 1))),
              ),
              Positioned(left: 12, top: 12, child: ended ? const _EndedTag() : PosterTag(event: e)),
              Positioned(
                right: 12,
                top: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    child: Text(formatMoney(e.priceSen), style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.08)),
                  const SizedBox(height: 4),
                  Text(e.distanceKm == null ? '📍 ${e.area ?? ''}' : '📍 ${e.distanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                ]),
              ),
              Positioned(right: 10, bottom: 10, child: HeartButton(eventId: e.id)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EndedTag extends StatelessWidget {
  const _EndedTag();
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(99)),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text('Ended', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700)),
        ),
      );
}
