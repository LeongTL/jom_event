import 'package:flutter/material.dart';

import '../../../core/theme/calm.dart';
import '../../event/domain/event_labels.dart';
import '../domain/ticket.dart';
import 'dashed_line.dart';

/// The small boarding pass on Home: 310 wide and the same size for every ticket, whatever the title says. The two
/// halves meet at a dashed tear line with a half-circle bitten out of each edge.
class BoardingPassTile extends StatelessWidget {
  const BoardingPassTile({
    super.key,
    required this.ticket,
    required this.now,
    required this.onTap,
  });
  final Ticket ticket;
  final DateTime now;
  final VoidCallback onTap;

  static const width = 310.0,
      topHeight = 114.0,
      bottomHeight = 72.0,
      _notch = 11.0,
      _radius = 20.0;

  @override
  Widget build(BuildContext context) {
    final e = ticket.event;
    final color = ticketColor(primaryCategory(e.categories));
    final today = dayLabel(e.startsAt, now) == 'Today';
    final chip = ticket.processing
        ? 'Processing'
        : relativeStart(e.startsAt, e.endsAt, now);
    final host = [
      if (e.hostName != null) e.hostName!,
      if (e.area != null) e.area!,
    ].join(' · ');
    const white = TextStyle(color: Colors.white);
    return GestureDetector(
      key: Key('boarding-${ticket.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipPath(
              clipper: const _Half(top: true),
              child: Container(
                key: const Key('boarding-top'),
                height: topHeight,
                color: color,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                today ? 'YOUR TICKET · TODAY' : 'YOUR TICKET',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: white.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: .9,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                chip,
                                style: white.copyWith(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: white.copyWith(
                            fontFamily: Calm.serif,
                            fontSize: 21,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: white.copyWith(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: .85),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: 4,
                      right: 4,
                      bottom: 0,
                      child: DashedLine(
                        color: Colors.white.withValues(alpha: .45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ClipPath(
              clipper: const _Half(top: false),
              child: Container(
                key: const Key('boarding-bottom'),
                height: bottomHeight,
                color: color,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: _Col(
                        shortDate(e.startsAt),
                        'Date',
                        CrossAxisAlignment.start,
                      ),
                    ),
                    Flexible(
                      child: _Col(
                        timeLabel(e.startsAt),
                        'Start time',
                        CrossAxisAlignment.center,
                      ),
                    ),
                    Flexible(
                      child: _Col(
                        '${ticket.booking.people}',
                        'Spots',
                        CrossAxisAlignment.end,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Col extends StatelessWidget {
  const _Col(this.value, this.label, this.align);
  final String value, label;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: align,
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .75),
          fontSize: 12,
        ),
      ),
    ],
  );
}

/// One half of the pass: rounded on the outside, with a half-circle removed from the two corners on the tear line.
class _Half extends CustomClipper<Path> {
  const _Half({required this.top});
  final bool top;

  @override
  Path getClip(Size size) {
    const r = BoardingPassTile._radius, n = BoardingPassTile._notch;
    final rect = RRect.fromRectAndCorners(
      Offset.zero & size,
      topLeft: top ? const Radius.circular(r) : Radius.zero,
      topRight: top ? const Radius.circular(r) : Radius.zero,
      bottomLeft: top ? Radius.zero : const Radius.circular(r),
      bottomRight: top ? Radius.zero : const Radius.circular(r),
    );
    final y = top ? size.height : 0.0;
    final holes = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, y), radius: n))
      ..addOval(Rect.fromCircle(center: Offset(size.width, y), radius: n));
    return Path.combine(
      PathOperation.difference,
      Path()..addRRect(rect),
      holes,
    );
  }

  @override
  bool shouldReclip(_Half old) => old.top != top;
}
