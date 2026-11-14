import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../data/booking_repository.dart';

/// "Waiting for host to confirm": the receipt is sent and the seat is kept with no countdown. The booking decides where
/// this goes: confirmed → ticket, the host asked for a new receipt → back to pay.
class WaitingScreen extends ConsumerStatefulWidget {
  const WaitingScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends ConsumerState<WaitingScreen> {
  bool _left = false;

  void _leaveFor(String? status) {
    final to = switch (status) {
      'confirmed' => 'ticket?new=1',
      'held' => 'pay',
      _ => null,
    };
    if (to == null || _left) return;
    _left = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pushReplacement('/booking/${widget.bookingId}/$to');
    });
  }

  @override
  Widget build(BuildContext context) {
    _leaveFor(ref.watch(bookingProvider(widget.bookingId)).value?.status);
    return Scaffold(
      key: const Key('waiting-screen'),
      backgroundColor: Calm.bg,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_top, size: 48, color: Calm.acc),
            const SizedBox(height: 16),
            const Text(
              'Waiting for host to confirm',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Calm.serif,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your seat is kept while the host checks their bank. We will tell you as soon as they answer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Calm.mut),
            ),
            const SizedBox(height: 28),
            KeyedSubtree(
              key: const Key('waiting-done'),
              child: JomButton(
                label: 'Done',
                onPressed: () => context.go('/tickets'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
