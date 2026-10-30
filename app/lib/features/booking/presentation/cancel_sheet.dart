import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';

/// "Cancel this booking?" Shown only inside the host's free-cancellation window. Pops true once cancelled.
Future<bool?> showCancelSheet(BuildContext context, Booking b) =>
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: context.jom.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => _CancelSheet(b),
    );

class _CancelSheet extends ConsumerStatefulWidget {
  const _CancelSheet(this.b);
  final Booking b;

  @override
  ConsumerState<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends ConsumerState<_CancelSheet> {
  String? _error;
  bool _busy = false;

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(bookingRepositoryProvider).cancel(widget.b.id);
      if (mounted) Navigator.pop(context, true);
    } on BookingError catch (e) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = e.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    final b = widget.b;
    return SafeArea(
      key: const Key('cancel-sheet'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: k.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const Text(
              'Cancel this booking?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              b.isPaid
                  ? "You're within the free cancellation window. ${formatMoney(b.amountSen)} goes back to your original payment method in 3 to 7 working days."
                  : 'Your spot will be released.',
              style: TextStyle(
                fontSize: 13,
                color: k.sheetInk.withValues(alpha: .62),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF5A67),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: const Key('cancel-yes'),
              child: JomButton(
                label: 'Yes, cancel',
                busy: _busy,
                onPressed: _cancel,
              ),
            ),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: const Key('cancel-keep'),
              child: JomButton(
                label: 'Keep booking',
                primary: false,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
