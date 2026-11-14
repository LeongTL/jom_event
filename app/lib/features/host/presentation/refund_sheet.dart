import 'package:flutter/material.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';

/// Asks for a note about a refund the host made outside the app. Returns the note, or null when dismissed.
Future<String?> askRefundNote(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RefundSheet(),
    );

class _RefundSheet extends StatefulWidget {
  const _RefundSheet();

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Refund by hand',
          style: TextStyle(
            fontFamily: Calm.serif,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Send the money back from your bank first. This cancels the booking and frees the seat; the app moves no money.',
          style: TextStyle(color: Calm.mut),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('refund-note'),
          controller: _note,
          decoration: const InputDecoration(
            hintText: 'Note, e.g. how you paid them back',
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Calm.bad)),
          ),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('refund-confirm'),
          child: JomButton(
            label: 'Record refund',
            onPressed: () {
              final n = _note.text.trim();
              if (n.isEmpty) {
                setState(() => _error = 'Write a short note for your records.');
              } else {
                Navigator.pop(context, n);
              }
            },
          ),
        ),
      ],
    ),
  );
}
