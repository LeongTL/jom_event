import 'package:flutter/foundation.dart';

/// What a guest needs to pay the host by transfer (payments.pay_instructions), with the QR as a ready-to-load link.
@immutable
class PayInstructions {
  const PayInstructions({
    required this.amountSen,
    required this.reference,
    required this.status,
    this.qrUrl,
    this.bank,
    this.holder,
    this.number,
    this.holdExpiresAt,
  });

  final int amountSen;
  final String reference, status; // status: held, processing or expired
  final String? qrUrl, bank, holder, number;
  final DateTime? holdExpiresAt;

  bool get hasBank => bank != null && holder != null && number != null;

  factory PayInstructions.fromJson(Map<String, dynamic> j, {String? qrUrl}) =>
      PayInstructions(
        amountSen: (j['amount_sen'] as num).toInt(),
        reference: j['reference'] as String,
        status: j['status'] as String,
        qrUrl: qrUrl,
        bank: j['bank'] as String?,
        holder: j['account_holder'] as String?,
        number: j['account_number'] as String?,
        holdExpiresAt: j['hold_expires_at'] == null
            ? null
            : DateTime.parse(j['hold_expires_at'] as String).toUtc(),
      );
}
