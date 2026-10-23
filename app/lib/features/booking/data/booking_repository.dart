import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/booking.dart';

/// What the booking screens read and change. Tests replace it; [SupabaseBookingRepository] is the real one.
abstract class BookingRepository {
  /// Free events come back confirmed; paid ones held for 15 minutes. Throws [BookingError].
  Future<Booking> create(String eventId, int people, String name, String phone);

  /// The payment session for a held booking; asking again reuses the live one. Throws [BookingError].
  Future<PaymentSession> startPayment(String bookingId);

  Future<void> cancel(String bookingId);

  /// 'upcoming' or 'past'.
  Future<List<Booking>> mine(String scope);

  /// The booking now, and again each time it changes.
  Stream<Booking> watch(String bookingId);

  /// What the ticket's QR holds.
  Future<String> ticketToken(String bookingId);
}

class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository(this._db);
  final SupabaseClient _db;

  Future<T> _rpc<T>(String schema, String fn, Map<String, dynamic> params) async {
    try {
      return await _db.schema(schema).rpc(fn, params: params) as T;
    } on PostgrestException catch (e) {
      throw BookingError(e.message);
    }
  }

  @override
  Future<Booking> create(String eventId, int people, String name, String phone) async => Booking.fromJson(
        await _rpc<Map<String, dynamic>>('bookings', 'create_booking',
            {'p_event_id': eventId, 'p_people': people, 'p_name': name, 'p_phone': phone}),
      );

  @override
  Future<PaymentSession> startPayment(String bookingId) async =>
      PaymentSession.fromJson(((await _rpc<List>('payments', 'start_payment', {'p_booking_id': bookingId})).first) as Map<String, dynamic>);

  @override
  Future<void> cancel(String bookingId) => _rpc<void>('bookings', 'cancel_booking', {'p_booking_id': bookingId});

  @override
  Future<List<Booking>> mine(String scope) async => [
        for (final r in await _rpc<List>('bookings', 'my_bookings', {'p_scope': scope})) Booking.fromJson(r as Map<String, dynamic>),
      ];

  // shortcut: polls every 2 seconds because bookings is not in the realtime publication; switch to
  // .stream(primaryKey: ['id']) if the table is ever published.
  @override
  Stream<Booking> watch(String bookingId) async* {
    while (true) {
      final rows = await _db.schema('bookings').from('bookings').select().eq('id', bookingId) as List;
      if (rows.isNotEmpty) yield Booking.fromJson(rows.first as Map<String, dynamic>);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  @override
  Future<String> ticketToken(String bookingId) => _rpc<String>('bookings', 'ticket_token', {'p_booking_id': bookingId});
}

final bookingRepositoryProvider = Provider<BookingRepository>((ref) => SupabaseBookingRepository(ref.watch(supabaseClientProvider)));

/// One booking, kept fresh while a screen watches it.
final bookingProvider = StreamProvider.autoDispose.family<Booking, String>((ref, id) => ref.watch(bookingRepositoryProvider).watch(id));

/// The Bookings tab's lists. Signed-out visitors never get here (the tab shows the sign-in prompt).
final myBookingsProvider = FutureProvider.autoDispose.family<List<Booking>, String>((ref, scope) async {
  await ref.watch(sessionProvider.future);
  return ref.watch(bookingRepositoryProvider).mine(scope);
});
