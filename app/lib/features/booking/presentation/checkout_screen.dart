import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/money.dart';
import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/jom_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../auth/data/auth_repository.dart';
import '../../auth/domain/phone_number.dart';
import '../../event/data/event_repository.dart';
import '../../event/domain/event_detail.dart';
import '../../event/domain/event_labels.dart';
import '../data/booking_repository.dart';
import '../domain/booking.dart';
import '../domain/hold_timer.dart';
import '../../../shared/widgets/screen_parts.dart';

/// Checkout. Paid events hold the seat for 15 minutes the moment this opens (the spec's "Join, then Checkout
/// creates a held booking"); free events are booked only when you confirm.
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key, required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        key: const Key('checkout-screen'),
        backgroundColor: context.jom.sheet,
        body: ref.watch(eventDetailProvider(eventId)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('Could not load this event. Check your connection.')),
              data: (d) => d == null ? const Center(child: Text("This event isn't available")) : _Body(d),
            ),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body(this.d);
  final EventDetail d;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  int _people = 1;
  Booking? _held;
  String? _error;
  bool _busy = false;

  EventDetail get d => widget.d;
  int get _unit => d.summary.priceSen;
  bool get _paid => _unit > 0;

  @override
  void initState() {
    super.initState();
    if (_paid) _hold();
  }

  (String, String) _contactOf(User? user) {
    final name = ((user?.userMetadata?['full_name'] ?? user?.userMetadata?['name']) as String?)?.trim() ?? '';
    return (name, user?.phone ?? '');
  }

  /// Who is booking, read from the signed-in session. Asked of the repository, because a stream provider has
  /// nothing yet in the first frame after the screen opens.
  Future<(String, String)> _contactNow() async => _contactOf((await ref.read(authRepositoryProvider).session.first)?.user);

  /// (Re)holds the seat for the current head count, releasing the previous hold first.
  Future<void> _hold() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(bookingRepositoryProvider);
    try {
      if (_held != null) await repo.cancel(_held!.id).catchError((_) {});
      final (name, phone) = await _contactNow();
      final b = await repo.create(d.summary.id, _people, name, phone);
      if (mounted) setState(() => _held = b);
    } on BookingError catch (e) {
      if (mounted) setState(() { _held = null; _error = e.message; });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _step(int by) {
    final next = (_people + by).clamp(1, 2);
    if (next == _people) return;
    setState(() => _people = next);
    if (_paid) _hold();
  }

  Future<void> _confirm() async {
    setState(() { _busy = true; _error = null; });
    try {
      final (name, phone) = await _contactNow();
      final b = await ref.read(bookingRepositoryProvider).create(d.summary.id, _people, name, phone);
      if (mounted) context.pushReplacement('/booking/${b.id}/ticket');
    } on BookingError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    setState(() { _busy = true; _error = null; });
    try {
      final s = await ref.read(bookingRepositoryProvider).startPayment(_held!.id);
      if (mounted) context.push('/booking/${_held!.id}/gateway', extra: s);
    } on BookingError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    final e = d.summary;
    final total = _unit * _people;
    final (name, phone) = _contactOf(ref.watch(sessionProvider).value?.user);
    final now = ref.read(nowProvider)();
    return Stack(children: [
      Positioned.fill(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          children: [
            const BookingNav(title: 'Checkout'),
            CardBox(
              child: Row(children: [
                MiniArt(glyph: e.glyph, a: e.colorA, b: e.colorB),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${whenLabel(e.startsAt, now)} · ${e.area ?? ''}', style: _mut(k)),
                  ]),
                ),
              ]),
            ),
            if (_paid && _held != null) _Hold(held: _held!)
            else
              const SizedBox(height: 12),
            CardBox(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('People', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('Up to 2 per booking', style: _mut(k)),
                  ]),
                ),
                _Round(key: const Key('people-minus'), glyph: '−', onTap: _busy ? null : () => _step(-1)),
                SizedBox(width: 32, child: Text('$_people', key: const Key('people-count'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                _Round(key: const Key('people-plus'), glyph: '+', onTap: _busy ? null : () => _step(1)),
              ]),
            ),
            CardBox(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Contact', style: _mut(k)),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(prettyMyPhone(phone.startsWith('+') ? phone : '+$phone'), style: _mut(k)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total', style: _mut(k)),
                Text(formatMoney(total), key: const Key('total'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('${cancelPolicyText(d.cancelPolicy)}. ${_paid ? 'Paying' : 'Joining'} means you accept the host\'s policy.', style: _mut(k)),
            ),
            if (_error != null)
              Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 0), child: Text(_error!, key: const Key('checkout-error'), style: const TextStyle(color: Color(0xFFFF5A67), fontWeight: FontWeight.w600))),
          ],
        ),
      ),
      CtaBar(children: [
        Expanded(
          child: _paid
              ? (_held == null
                  ? const SizedBox.shrink()
                  : KeyedSubtree(key: const Key('pay'), child: JomButton(label: 'Pay ${formatMoney(total)}', busy: _busy, onPressed: _pay)))
              : KeyedSubtree(key: const Key('confirm'), child: JomButton(label: 'Confirm my spot', busy: _busy, onPressed: _confirm)),
        ),
      ]),
    ]);
  }
}

TextStyle _mut(JomTokens k) => TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62));

class _Round extends StatelessWidget {
  const _Round({super.key, required this.glyph, required this.onTap});
  final String glyph;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: context.jom.card, shape: BoxShape.circle), child: Text(glyph, style: const TextStyle(fontSize: 20, height: 1))),
      );
}

/// "⏱ Spot held for 14:32", ticking down to the end of the hold.
class _Hold extends ConsumerWidget {
  const _Hold({required this.held});
  final Booking held;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final until = held.holdExpiresAt;
    if (until == null) return const SizedBox(height: 12);
    return StreamBuilder<Duration>(
      key: ValueKey(held.id),
      stream: holdTimer(until, ref.read(nowProvider)),
      builder: (context, snap) {
        final left = snap.data ?? until.difference(ref.read(nowProvider)());
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xFFFFB020), borderRadius: BorderRadius.circular(99)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text('⏱ Spot held for ${countdown(left)}', key: const Key('hold-countdown'), style: const TextStyle(color: Color(0xFF2A1A00), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        );
      },
    );
  }
}
