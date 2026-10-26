import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/money.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/verified_badge.dart';
import '../../event/domain/event_labels.dart';
import '../domain/ticket.dart';
import 'dashed_line.dart';
import 'ticket_screen.dart' show ticketTokenProvider;

String paymentLabel(String? method, int amountSen) => switch (method) {
      'free' => 'Free',
      'fpx' => 'Online banking',
      'card' => 'Card',
      'ewallet' => 'E-wallet',
      'duitnow' => 'DuitNow',
      _ => amountSen == 0 ? 'Free' : 'Paid online',
    };

/// The full ticket: a coloured header with the times, a tear line, the QR, then the booking details. The colour
/// follows the event's primary category.
class TicketCard extends ConsumerWidget {
  const TicketCard({super.key, required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ticket.event, b = ticket.booking;
    final color = ticketColor(primaryCategory(e.categories));
    return Container(
      key: Key('ticket-${ticket.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Calm.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Calm.line),
        boxShadow: const [BoxShadow(color: Color(0x121B2430), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Stack(clipBehavior: Clip.none, children: [
        Column(children: [
          _Header(ticket: ticket, color: color),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            child: ticket.booking.status != 'confirmed' && !ticket.processing
                ? const SizedBox.shrink()
                : ticket.processing
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 34, horizontal: 10),
                    child: Text('Your QR code appears here as soon as the payment clears.', textAlign: TextAlign.center, style: TextStyle(color: Calm.mut, fontSize: 13)),
                  )
                : Column(children: [
                    ref.watch(ticketTokenProvider(b.id)).when(
                          loading: () => const SizedBox(width: 150, height: 150, child: Center(child: CircularProgressIndicator())),
                          error: (_, _) => const SizedBox(width: 150, height: 150, child: Center(child: Text('QR unavailable'))),
                          data: (token) => QrImageView(key: const Key('qr'), data: token, size: 150, padding: EdgeInsets.zero, semanticsLabel: 'Ticket QR code'),
                        ),
                    const SizedBox(height: 6),
                    const Text('Show this at the entrance', style: TextStyle(color: Calm.mut, fontSize: 13)),
                  ]),
          ),
          _Row(key: const Key('row-date'), left: dateLabel(e.startsAt), leftLabel: 'Date', right: '${b.people}', rightLabel: 'Spots'),
          _Row(key: const Key('row-attendee'), left: b.contactName ?? '', leftLabel: 'Attendee', right: b.ticketCode, rightLabel: 'Booking code'),
          _Row(
            key: const Key('row-host'),
            left: e.hostName ?? '',
            leftBadge: e.hostVerified ? const VerifiedBadge() : null,
            leftLabel: 'Host',
            right: e.area ?? '',
            rightLabel: 'Area',
          ),
          _Row(
            key: const Key('row-payment'),
            left: paymentLabel(b.paymentMethod, b.amountSen),
            leftLabel: 'Payment method',
            right: b.amountSen == 0 ? 'Free' : formatMoney(b.amountSen),
            rightLabel: 'Price paid',
            last: true,
          ),
        ]),
        // the two ring-shaped holes where the tear line meets the card edges
        for (final left in [true, false])
          Positioned(
            top: _Header.height - 14,
            left: left ? -14 : null,
            right: left ? null : -14,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: Calm.bg, shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
            ),
          ),
      ]),
    );
  }
}

String _chip(Ticket t) => switch (t.booking.status) {
      'confirmed' => '✓ Confirmed',
      'processing' => 'Processing',
      'attended' => 'Attended',
      'cancelled' => 'Cancelled',
      'no_show' => 'No-show',
      _ => t.booking.status,
    };

class _Header extends ConsumerWidget {
  const _Header({required this.ticket, required this.color});
  final Ticket ticket;
  final Color color;

  static const height = 120.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ticket.event;
    const white = TextStyle(color: Colors.white);
    final small = white.copyWith(fontSize: 12.5, color: Colors.white.withValues(alpha: .75));
    final big = white.copyWith(fontSize: 19, fontWeight: FontWeight.w600);
    return Container(
      key: const Key('ticket-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(21))),
      constraints: const BoxConstraints(minHeight: height),
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Text(e.title, style: white.copyWith(fontFamily: Calm.serif, fontSize: 21, fontWeight: FontWeight.w500, height: 1.15))),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: ticket.processing ? Calm.warnSoft : Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(8)),
                child: Text(_chip(ticket), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ticket.processing ? Calm.warn : Colors.white)),
              ),
            ]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(timeLabel(e.startsAt), style: big), Text('Starts', style: small)]),
              Column(children: [
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 22, decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .55), width: 2)))),
                  const SizedBox(width: 4),
                  const Icon(Icons.confirmation_number_outlined, size: 20, color: Colors.white),
                  const SizedBox(width: 4),
                  Container(width: 22, decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .55), width: 2)))),
                ]),
                const SizedBox(height: 4),
                Text(durationLabel(e.endsAt.difference(e.startsAt)), style: white.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(timeLabel(e.endsAt), style: big), Text('Ends', style: small)]),
            ]),
          ]),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: DashedLine(color: Colors.white.withValues(alpha: .5))),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.left, required this.leftLabel, required this.right, required this.rightLabel, this.leftBadge, this.last = false});
  final String left, leftLabel, right, rightLabel;
  final Widget? leftBadge;
  final bool last;

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget value, String label, CrossAxisAlignment a) => Column(crossAxisAlignment: a, children: [
          value,
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12.5, color: Calm.faint)),
        ]);
    const v = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Calm.ink);
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, last ? 6 : 0),
      child: Column(children: [
        const DashedLine(color: Calm.line, thickness: 1.5, dash: 5, gap: 3),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Flexible(child: cell(Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(left, maxLines: 1, overflow: TextOverflow.ellipsis, style: v)), if (leftBadge != null) ...[const SizedBox(width: 5), leftBadge!]]), leftLabel, CrossAxisAlignment.start)),
            const SizedBox(width: 12),
            Flexible(child: cell(Text(right, maxLines: 1, overflow: TextOverflow.ellipsis, style: v), rightLabel, CrossAxisAlignment.end)),
          ]),
        ),
      ]),
    );
  }
}
