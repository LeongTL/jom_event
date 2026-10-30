import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../data/booking_repository.dart';
import '../data/payment_gateway_client.dart';
import '../domain/booking.dart';
import '../domain/hold_timer.dart';
import '../../event/domain/event_labels.dart';
import '../../../shared/widgets/skeleton.dart';

const _methods = [
  ('Online banking (FPX)', 'Maybank2u · CIMB Clicks · Public Bank'),
  ('Credit / debit card', 'Visa · Mastercard'),
  ('E-wallet', 'Touch ’n Go · GrabPay · Boost · ShopeePay'),
  ('DuitNow QR', 'Scan with any banking app'),
];

String _ringgit(int sen) => 'RM${(sen / 100).toStringAsFixed(2)}';

/// Stands in for the payment provider's own hosted page (so it has its own light look, not the app's theme).
/// A real provider opens in the browser instead. Pay tells the gateway; the webhook decides the outcome.
class GatewayScreen extends ConsumerStatefulWidget {
  const GatewayScreen({super.key, required this.bookingId, this.session});
  final String bookingId;
  final PaymentSession? session; // handed over by Checkout; absent after Try again, when it is asked for again

  @override
  ConsumerState<GatewayScreen> createState() => _GatewayScreenState();
}

class _GatewayScreenState extends ConsumerState<GatewayScreen> {
  PaymentSession? _session;
  String? _error;
  int _method = 0;
  String? _simulate; // success | failed | pending, mock only
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    if (_session == null) _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref
          .read(bookingRepositoryProvider)
          .startPayment(widget.bookingId);
      if (mounted) setState(() => _session = s);
    } on BookingError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  // The hold keeps running, so leaving here costs nothing; after Try again there is no checkout behind, so go to Tickets.
  void _back() => context.canPop() ? context.pop() : context.go('/tickets');

  Future<void> _pay() async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      await ref
          .read(paymentGatewayClientProvider)
          .pay(_session!, _methods[_method].$1, simulate: _simulate);
      if (mounted)
        context.pushReplacement('/booking/${widget.bookingId}/processing');
    } catch (_) {
      if (mounted)
        setState(() {
          _paying = false;
          _error = 'The payment could not be sent. Please try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    const grey = Color(0xFF6B7280);
    final s = _session;
    return Scaffold(
      key: const Key('gateway-screen'),
      backgroundColor: const Color(0xFFF6F7F9),
      body: DefaultTextStyle.merge(
        style: const TextStyle(color: Color(0xFF111111)),
        child: s == null
            ? Center(
                child: _error == null
                    ? Skeleton.box(120)
                    : Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(
                              key: const Key('gateway-back'),
                              onPressed: _back,
                              child: const Text('Back'),
                            ),
                          ],
                        ),
                      ),
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 110),
                      children: [
                        Container(
                          color: Colors.white,
                          padding: EdgeInsets.fromLTRB(
                            20,
                            MediaQuery.paddingOf(context).top + 5,
                            20,
                            14,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                key: const Key('gateway-back'),
                                onPressed: _back,
                                icon: const Icon(Icons.arrow_back),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '🔒 Secure payment',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const Text(
                                '[gateway]',
                                style: TextStyle(
                                  color: Color(0x80111111),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE5E7EB)),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Paying KL Local Session',
                                style: TextStyle(color: grey, fontSize: 13),
                              ),
                              Text(
                                _ringgit(s.amountSen),
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Ref ${s.reference}',
                                style: const TextStyle(
                                  color: grey,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 18),
                              for (final (i, m) in _methods.indexed)
                                GestureDetector(
                                  key: Key('method-$i'),
                                  onTap: () => setState(() => _method = i),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        width: 2,
                                        color: _method == i
                                            ? const Color(0xFF2F6BFF)
                                            : const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              width: _method == i ? 6 : 2,
                                              color: _method == i
                                                  ? const Color(0xFF2F6BFF)
                                                  : const Color(0xFFC3C8D1),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                m.$1,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                m.$2,
                                                style: const TextStyle(
                                                  color: grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              StreamBuilder<Duration>(
                                stream: holdTimer(
                                  s.expiresAt,
                                  ref.read(nowProvider),
                                ),
                                builder: (_, snap) => Text(
                                  'Methods shown are whatever the gateway offers. Session expires in ${countdown(snap.data ?? s.expiresAt.difference(ref.read(nowProvider)()))}.',
                                  style: const TextStyle(
                                    color: grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if (ref
                                  .watch(paymentGatewayClientProvider)
                                  .canSimulate)
                                _Simulate(
                                  value: _simulate,
                                  onChanged: (v) =>
                                      setState(() => _simulate = v),
                                ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Color(0xFFD92D20),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: const Color(0xFFF6F7F9),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          key: const Key('gateway-pay'),
                          onPressed: _paying ? null : _pay,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2F6BFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: Text('Pay ${_ringgit(s.amountSen)}'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Test-only helper of the mock gateway (never shown with a real provider): pick the answer it will give.
class _Simulate extends StatelessWidget {
  const _Simulate({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Test the mock:',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
        ),
        for (final (id, label) in const [
          ('success', 'Success'),
          ('failed', 'Failed'),
          ('pending', 'Slow'),
        ])
          ChoiceChip(
            key: Key('sim-$id'),
            label: Text(label),
            selected: value == id,
            onSelected: (on) => onChanged(on ? id : null),
          ),
      ],
    ),
  );
}
