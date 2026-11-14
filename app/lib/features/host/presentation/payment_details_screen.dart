import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_button.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../booking/data/receipt_picker.dart';
import '../data/host_repository.dart';
import '../domain/host.dart';
import 'host_parts.dart';

/// Host mode: what guests see when they book a paid event: a DuitNow QR image, bank details, or both
/// (/host-mode/payment-details).
class PaymentDetailsScreen extends ConsumerWidget {
  const PaymentDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(hostMeProvider)
      .when(
        loading: () => Scaffold(backgroundColor: Calm.bg, body: hostLoading()),
        error: (_, _) => Scaffold(
          backgroundColor: Calm.bg,
          body: hostFailed('your payment details'),
        ),
        data: (me) => _Form(me: me),
      );
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.me});
  final HostProfile? me;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _holder = TextEditingController(text: widget.me?.holder);
  late final _bank = TextEditingController(text: widget.me?.bank);
  late final _number = TextEditingController(text: widget.me?.accountNumber);
  Uint8List? _qr;
  bool _busy = false;
  String? _error;

  bool get _hasQr => _qr != null || widget.me?.qrPath != null;
  bool get _bankFull =>
      [_holder, _bank, _number].every((c) => c.text.trim().isNotEmpty);
  bool get _bankStarted =>
      [_holder, _bank, _number].any((c) => c.text.trim().isNotEmpty);

  Future<void> _pickQr() async {
    try {
      final bytes = await ref.read(receiptPickerProvider)(false);
      if (bytes != null && mounted) setState(() => _qr = bytes);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'That image is too big or could not be read.');
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? blank(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await ref
          .read(hostRepositoryProvider)
          .savePaymentDetails(
            holder: blank(_holder),
            bank: blank(_bank),
            number: blank(_number),
            qr: _qr,
            keepQrPath: widget.me?.qrPath,
          );
      ref.invalidate(hostMeProvider);
      if (mounted)
        context.canPop() ? context.pop() : context.go('/host-mode/profile');
    } on HostError catch (e) {
      if (mounted) setState(() => _error = e.text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _hasQr || _bankFull;
    return Scaffold(
      key: const Key('payment-details'),
      backgroundColor: Calm.bg,
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
            children: [
              const BookingNav(title: 'Payment details'),
              const SoftNote(
                'These are shown to guests who book your events. Guests pay you directly.',
              ),
              CardBox(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _hasQr ? 'DuitNow QR added' : 'No DuitNow QR yet',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      key: const Key('details-qr'),
                      onPressed: _pickQr,
                      child: Text(_hasQr ? 'Change' : 'Add QR image'),
                    ),
                  ],
                ),
              ),
              HostField(
                label: 'Account holder',
                fieldKey: const Key('details-holder'),
                controller: _holder,
                onChanged: (_) => setState(() {}),
              ),
              HostField(
                label: 'Bank',
                fieldKey: const Key('details-bank'),
                controller: _bank,
                onChanged: (_) => setState(() {}),
              ),
              HostField(
                label: 'Account number',
                fieldKey: const Key('details-number'),
                controller: _number,
                keyboard: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              if (!valid && _bankStarted)
                const Text(
                  'Add the bank, account holder and account number, or a DuitNow QR image.',
                  key: Key('details-missing'),
                  style: TextStyle(
                    color: Calm.warn,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Calm.bad,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          CtaBar(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: const Key('details-save'),
                  child: JomButton(
                    label: 'Save',
                    busy: _busy,
                    onPressed: valid ? _save : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
