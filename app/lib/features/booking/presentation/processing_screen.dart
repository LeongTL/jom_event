import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../data/booking_repository.dart';
import '../../../shared/widgets/skeleton.dart';

/// "Confirming your payment": waits for the webhook. The booking decides where this goes, never this screen:
/// confirmed → ticket, failed or expired → the failed screen. Still processing, the guest can leave; Bookings
/// shows it as Processing until the webhook arrives.
class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  bool _left = false;

  void _leaveFor(String? status) {
    final to = switch (status) {
      'confirmed' => 'ticket',
      'payment_failed' || 'expired' || 'cancelled' => 'failed',
      _ => null,
    };
    if (to == null || _left) return;
    _left = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.pushReplacement(
          '/booking/${widget.bookingId}/$to${to == 'ticket' ? '?new=1' : ''}',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    final b = ref.watch(bookingProvider(widget.bookingId)).value;
    _leaveFor(b?.status);
    return Scaffold(
      key: const Key('processing-screen'),
      backgroundColor: k.sheet,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          44,
          200,
          44,
          0,
        ), // the prototype's padding-top: 200
        child: Column(
          children: [
            Skeleton.box(84),
            const SizedBox(height: 30),
            const Text(
              'Confirming your payment',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              "Please don't close the app or pay again. This takes a few seconds.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: k.sheetInk.withValues(alpha: .62),
              ),
            ),
            if (b != null) ...[
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: k.card,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    '${b.ticketCode} · Processing',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            TextButton(
              key: const Key('see-bookings'),
              onPressed: () => context.go('/tickets'),
              child: const Text('See my bookings'),
            ),
          ],
        ),
      ),
    );
  }
}
