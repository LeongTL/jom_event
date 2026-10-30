import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../data/host_repository.dart';
import '../domain/host.dart';

/// "Delete this event?" Pops true once it is deleted (guests refunded in full by the server).
Future<bool?> showDeleteSheet(BuildContext context, HostEventRow event) =>
    showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Calm.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DeleteSheet(event),
    );

class _DeleteSheet extends ConsumerStatefulWidget {
  const _DeleteSheet(this.event);
  final HostEventRow event;

  @override
  ConsumerState<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends ConsumerState<_DeleteSheet> {
  late final Future<int> _gross = widget.event.seatsSold > 0
      ? ref.read(hostRepositoryProvider).grossSen(widget.event.id)
      : Future.value(0);
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(hostRepositoryProvider).delete(widget.event.id);
      if (mounted) Navigator.pop(context, true);
    } on HostError catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.text;
      });
    }
  }

  String _words(int gross) {
    final n = widget.event.seatsSold;
    if (n == 0) return "This event has no guests yet. This can't be undone.";
    final who = n == 1 ? '1 guest has' : '$n guests have';
    return gross > 0
        ? "$who paid ${formatMoney(gross)} in total. All of them are refunded in full and told the event was cancelled. This can't be undone."
        : "$who joined. All of them are told the event was cancelled. This can't be undone.";
  }

  @override
  Widget build(BuildContext context) => SafeArea(
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
            'Delete this event?',
            style: TextStyle(
              fontFamily: Calm.serif,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FutureBuilder<int>(
            future: _gross,
            builder: (_, s) => s.hasData
                ? Text(
                    _words(s.data!),
                    style: const TextStyle(color: Calm.mut, height: 1.4),
                  )
                : const SizedBox(height: 40),
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
            key: const Key('delete-yes'),
            child: JomButton(
              label: widget.event.seatsSold > 0
                  ? 'Yes, delete and refund'
                  : 'Yes, delete',
              busy: _busy,
              onPressed: _delete,
            ),
          ),
          const SizedBox(height: 10),
          JomButton(
            label: 'Keep event',
            primary: false,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ),
  );
}
