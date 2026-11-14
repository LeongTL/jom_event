import 'package:flutter/foundation.dart';

/// A receipt waiting for the host (payments.pending_receipts). A late one arrived after the guest's hold ran out.
@immutable
class PendingReceipt {
  const PendingReceipt({
    required this.id,
    required this.bookingId,
    required this.eventId,
    required this.eventTitle,
    required this.guestId,
    required this.guestName,
    required this.amountSen,
    required this.imagePath,
    required this.late,
    required this.uploadedAt,
    this.guestUsername,
  });

  final String id,
      bookingId,
      eventId,
      eventTitle,
      guestId,
      guestName,
      imagePath;
  final String? guestUsername;
  final int amountSen;
  final bool late;
  final DateTime uploadedAt;

  factory PendingReceipt.fromJson(Map<String, dynamic> j) => PendingReceipt(
    id: j['receipt_id'] as String,
    bookingId: j['booking_id'] as String,
    eventId: j['event_id'] as String,
    eventTitle: j['event_title'] as String,
    guestId: j['guest_id'] as String,
    guestName: j['guest_name'] as String,
    guestUsername: j['guest_username'] as String?,
    amountSen: (j['amount_sen'] as num).toInt(),
    imagePath: j['image_path'] as String,
    late: j['status'] == 'late',
    uploadedAt: DateTime.parse(j['uploaded_at'] as String).toUtc(),
  );
}
