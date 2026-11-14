import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../data/host_repository.dart';
import '../domain/host.dart';
import '../domain/receipt.dart';
import 'host_parts.dart';

/// Host mode: one receipt. Accept it, or ask the guest to upload again with a note
/// (/host-mode/receipts/:id).
class ReceiptDetailScreen extends ConsumerStatefulWidget {
  const ReceiptDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<ReceiptDetailScreen> createState() => _ReceiptDetailState();
}

class _ReceiptDetailState extends ConsumerState<ReceiptDetailScreen> {
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() act) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await act();
      ref.invalidate(pendingReceiptsProvider);
      if (mounted) {
        context.canPop() ? context.pop() : context.go('/host-mode/receipts');
      }
    } on HostError catch (e) {
      if (mounted) setState(() => _error = e.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('receipt-detail'),
    backgroundColor: Calm.bg,
    body: ref
        .watch(pendingReceiptsProvider(null))
        .when(
          loading: hostLoading,
          error: (_, _) => hostFailed('the receipt'),
          data: (rows) {
            final r = rows.where((x) => x.id == widget.id).firstOrNull;
            return r == null
                ? const Center(child: Text('This receipt was already handled.'))
                : _body(r);
          },
        ),
  );

  Widget _body(PendingReceipt r) {
    final repo = ref.read(hostRepositoryProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        const BookingNav(title: 'Receipt'),
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.guestName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
              ),
              if (r.guestUsername != null)
                Text(
                  '@${r.guestUsername}',
                  style: const TextStyle(color: Calm.mut),
                ),
              const SizedBox(height: 8),
              Text('Expected ${rm(r.amountSen)} for ${r.eventTitle}'),
              if (r.late)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Late: their hold had already run out.',
                    style: TextStyle(color: Calm.warn),
                  ),
                ),
            ],
          ),
        ),
        ref
            .watch(receiptImageUrlProvider(r.imagePath))
            .when(
              loading: () => const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const Text('The image could not load.'),
              data: (url) => SizedBox(
                key: const Key('receipt-image'),
                height: 360,
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.receipt_long, size: 80)),
                  ),
                ),
              ),
            ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('receipt-note'),
          controller: _note,
          decoration: const InputDecoration(
            hintText: 'Note for the guest (if asking again)',
            border: OutlineInputBorder(),
          ),
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
        const SizedBox(height: 14),
        KeyedSubtree(
          key: const Key('receipt-accept'),
          child: JomButton(
            label: r.late ? 'Accept payment' : 'Accept',
            busy: _busy,
            onPressed: r.late
                ? () => context.push(
                    '/host-mode/assign-seat?eventId=${r.eventId}&userId=${r.guestId}&receiptId=${r.id}',
                  )
                : () => _run(() => repo.acceptReceipt(r.id)),
          ),
        ),
        const SizedBox(height: 10),
        if (!r.late)
          KeyedSubtree(
            key: const Key('receipt-ask'),
            child: JomButton(
              label: 'Ask to upload again',
              primary: false,
              busy: _busy,
              onPressed: () {
                final note = _note.text.trim();
                if (note.isEmpty) {
                  setState(() => _error = 'Write a short note for the guest.');
                  return;
                }
                _run(() => repo.askNewReceipt(r.bookingId, note));
              },
            ),
          ),
      ],
    );
  }
}
