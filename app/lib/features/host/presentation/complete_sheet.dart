import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../data/host_repository.dart';
import '../domain/host.dart';

/// "Mark as completed?" Pops true once the event is completed (no-shows marked and the payout scheduled by the server).
Future<bool?> showCompleteSheet(
  BuildContext context,
  HostEventRow event,
  int noShows,
) => showModalBottomSheet<bool>(
  context: context,
  backgroundColor: Calm.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => _CompleteSheet(event, noShows),
);

/// The sheet, then back to the events list with every host list refreshed.
Future<void> completeAndLeave(
  BuildContext context,
  WidgetRef ref,
  HostEventRow event,
  int noShows,
) async {
  if (await showCompleteSheet(context, event, noShows) != true) return;
  ref.invalidate(hostEventsProvider);
  ref.invalidate(hostDashboardProvider);
  ref.invalidate(hostPayoutsProvider);
  if (context.mounted) context.go('/host-mode/events');
}

class _CompleteSheet extends ConsumerStatefulWidget {
  const _CompleteSheet(this.event, this.noShows);
  final HostEventRow event;
  final int noShows;

  @override
  ConsumerState<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends ConsumerState<_CompleteSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _complete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(hostRepositoryProvider).complete(widget.event.id);
      if (mounted) Navigator.pop(context, true);
    } on HostError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.noShows;
    final who = n == 1
        ? '1 guest did not check in'
        : '$n guests did not check in';
    return SafeArea(
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
                  color: Calm.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const Text(
              'Mark as completed?',
              style: TextStyle(
                fontFamily: Calm.serif,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              n == 0
                  ? "Everyone checked in. Your payout is scheduled for 3 working days from now. This can't be undone."
                  : "$who. They are marked as no-shows: no refund and no review. Your payout is scheduled for 3 working days from now. This can't be undone.",
              style: const TextStyle(color: Calm.mut, height: 1.4),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Calm.bad,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: const Key('complete-yes'),
              child: JomButton(
                label: 'Yes, complete',
                busy: _busy,
                onPressed: _complete,
              ),
            ),
            const SizedBox(height: 10),
            JomButton(
              label: 'Not yet',
              primary: false,
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
