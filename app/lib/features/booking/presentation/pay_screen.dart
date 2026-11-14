import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/money.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../event/domain/event_labels.dart';
import '../data/booking_repository.dart';
import '../data/receipt_picker.dart';
import '../domain/booking.dart';
import '../domain/hold_timer.dart';
import '../domain/pay_instructions.dart';

final payInstructionsProvider = FutureProvider.autoDispose
    .family<PayInstructions, String>(
      (ref, id) => ref.watch(bookingRepositoryProvider).payInstructions(id),
    );

/// Pay by transfer: how to pay the host, then upload the receipt. Also where a guest whose hold ran out can still
/// send a receipt (the host decides what to do with a late one).
class PayScreen extends ConsumerStatefulWidget {
  const PayScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends ConsumerState<PayScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _upload(bool camera) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await ref.read(receiptPickerProvider)(camera);
      if (bytes == null) return;
      await ref
          .read(bookingRepositoryProvider)
          .uploadReceipt(widget.bookingId, bytes);
      ref.invalidate(ticketsProvider);
      if (mounted) {
        context.pushReplacement('/booking/${widget.bookingId}/waiting');
      }
    } on BookingError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = BookingError('upload_failed').message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _choose() => showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('pick-gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(ctx);
              _upload(false);
            },
          ),
          ListTile(
            key: const Key('pick-camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () {
              Navigator.pop(ctx);
              _upload(true);
            },
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('pay-screen'),
    backgroundColor: Calm.bg,
    body: ref
        .watch(payInstructionsProvider(widget.bookingId))
        .when(
          loading: () => SafeArea(child: Skeleton.page()),
          error: (_, _) =>
              const Center(child: Text('Could not load the payment details.')),
          data: _body,
        ),
  );

  Widget _body(PayInstructions p) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
    children: [
      const BookingNav(title: 'Pay by transfer'),
      if (p.status == 'expired')
        const _Note(
          'Your hold ran out, so the seat was released. You can still send a receipt if you already paid; '
          'the host decides whether they can give you a seat.',
        )
      else if (p.holdExpiresAt != null)
        _Hold(until: p.holdExpiresAt!),
      CardBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Amount to transfer', style: _mut),
            Text(
              formatMoney(p.amountSen),
              key: const Key('pay-amount'),
              style: const TextStyle(
                fontFamily: Calm.serif,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            const Text('Put this code in the transfer note', style: _mut),
            Row(
              children: [
                Text(
                  p.reference,
                  key: const Key('pay-reference'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                IconButton(
                  key: const Key('copy-reference'),
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copy(p.reference),
                ),
              ],
            ),
          ],
        ),
      ),
      if (p.qrUrl != null)
        CardBox(
          child: Column(
            children: [
              const Text(
                'Scan with your banking app (DuitNow QR)',
                style: _mut,
              ),
              const SizedBox(height: 10),
              Image.network(
                p.qrUrl!,
                key: const Key('pay-qr'),
                height: 240,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 240,
                  child: Center(child: Icon(Icons.qr_code_2, size: 80)),
                ),
              ),
            ],
          ),
        ),
      if (p.hasBank)
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bank transfer', style: _mut),
              const SizedBox(height: 6),
              Text(
                p.bank!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(p.holder!),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      p.number!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('copy-account'),
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () => _copy(p.number!),
                  ),
                ],
              ),
            ],
          ),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _error!,
            key: const Key('pay-error'),
            style: const TextStyle(
              color: Calm.bad,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      KeyedSubtree(
        key: const Key('upload-receipt'),
        child: JomButton(
          label: 'Upload receipt',
          busy: _busy,
          onPressed: _choose,
        ),
      ),
    ],
  );

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied')));
  }
}

const _mut = TextStyle(fontSize: 13, color: Calm.mut);

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Calm.warnSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Calm.warn, fontWeight: FontWeight.w600),
    ),
  );
}

class _Hold extends ConsumerWidget {
  const _Hold({required this.until});
  final DateTime until;

  @override
  Widget build(BuildContext context, WidgetRef ref) => StreamBuilder<Duration>(
    stream: holdTimer(until, ref.read(nowProvider)),
    builder: (context, snap) {
      final left = snap.data ?? until.difference(ref.read(nowProvider)());
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Calm.warnSoft,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text(
                'Spot held for ${countdown(left)}',
                key: const Key('hold-countdown'),
                style: const TextStyle(
                  color: Calm.warn,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
