import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/main.dart' as app;
import 'package:supabase_flutter/supabase_flutter.dart';

// From env/e2e.json (tools/e2e.sh writes it from `supabase status`).
const _url = String.fromEnvironment('SUPABASE_URL');
const _anon = String.fromEnvironment('SUPABASE_ANON_KEY');
const _service = String.fromEnvironment('SERVICE_ROLE_KEY');

/// The one number the local Supabase accepts a fixed code for (supabase/config.toml, [auth.sms.test_otp]).
const testPhone = '0123456789';
const testOtp = '123456';

/// A second user (a host or a guest) with their own session, separate from the user the app is signed in as.
class Person {
  Person(this.db, this.id);
  final SupabaseClient db;
  final String id;
}

var _n = 0;

/// A word that is unique per run and has no digits (long digit runs are refused as phone numbers in event text).
String uniqueWord() => [
  for (final c in DateTime.now().microsecondsSinceEpoch.toString().split('')) 'abcdefghij'[int.parse(c)],
].join();

Future<Person> newPerson() async {
  final email = 'e2e-${DateTime.now().microsecondsSinceEpoch}-${_n++}@example.com';
  final admin = SupabaseClient(_url, _service);
  await admin.auth.admin.createUser(
    AdminUserAttributes(email: email, password: 'e2e-pass-123', emailConfirm: true),
  );
  final db = SupabaseClient(_url, _anon);
  final s = await db.auth.signInWithPassword(email: email, password: 'e2e-pass-123');
  return Person(db, s.user!.id);
}

Future<Person> newHost(String name) async {
  final p = await newPerson();
  await p.db.schema('identity').rpc('apply_host', params: {
    'host_name': name,
    'area': 'Bangsar',
    'bio': null,
    'account_holder': name,
    'bank': 'Maybank',
    'account_number': '1234564821',
  });
  return p;
}

/// Creates and publishes an event for [host]; returns its id.
Future<String> publishEvent(
  Person host, {
  required String title,
  int priceSen = 3000,
  int capacity = 10,
  Duration startsIn = const Duration(hours: 26),
  Duration lasts = const Duration(hours: 2),
  String category = 'make',
}) async {
  final start = DateTime.now().toUtc().add(startsIn);
  final id = await host.db.schema('events').rpc('save_draft', params: {
    'payload': {
      'title': title,
      'description': 'An end-to-end test event.',
      'categories': [category],
      'area': 'Bangsar',
      'venue': 'Test Deck',
      'starts_at': start.toIso8601String(),
      'ends_at': start.add(lasts).toIso8601String(),
      'capacity': capacity,
      'price_sen': priceSen,
      'cancel_policy': '24h',
      'accept_bookings': true,
    },
  }) as String;
  await host.db.schema('events').rpc('publish', params: {'event_id': id});
  return id;
}

/// What a guest does in the app: hold the seat, then pay at the mock gateway. Returns the booking id once the
/// gateway's webhook has confirmed it (a free event is confirmed straight away).
Future<String> bookAndPay(Person guest, String eventId, {int people = 1}) async {
  final b = await guest.db.schema('bookings').rpc('create_booking', params: {
    'p_event_id': eventId,
    'p_people': people,
    'p_name': 'E2E Guest',
    'p_phone': '60111111111',
  }) as Map<String, dynamic>;
  final id = b['id'] as String;
  if (b['status'] != 'confirmed') {
    final session = (await guest.db.schema('payments').rpc('start_payment', params: {'p_booking_id': id}) as List).first
        as Map<String, dynamic>;
    await guest.db.functions.invoke('mock-gateway-pay', body: {
      'attemptId': session['attempt_id'],
      'method': 'FPX',
    });
    await eventually(() async => await bookingStatus(guest, id) == 'confirmed');
  }
  return id;
}

Future<String> bookingStatus(Person who, String bookingId) async =>
    (await who.db.schema('bookings').from('bookings').select('status').eq('id', bookingId).single())['status'] as String;

/// The signed ticket token a guest shows at the door.
Future<String> ticketToken(Person guest, String bookingId) async =>
    await guest.db.schema('bookings').rpc('ticket_token', params: {'p_booking_id': bookingId}) as String;

/// Polls [check] until it is true (the webhook and Realtime are not instant).
Future<void> eventually(Future<bool> Function() check, {Duration within = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(within);
  while (!await check()) {
    if (DateTime.now().isAfter(end)) fail('condition not met within $within');
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
}

/// Starts the real app and waits for Home.
Future<void> launchApp(WidgetTester t) async {
  await app.main();
  await t.pumpAndSettle(const Duration(seconds: 2));
}

/// Pumps until [finder] appears (network calls make the usual pumpAndSettle too short).
Future<void> see(WidgetTester t, Finder finder, {Duration within = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(within);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      final texts = [for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? ''].where((x) => x.isNotEmpty);
      fail('never saw $finder. On screen: ${texts.take(40).join(' | ')}');
    }
    await t.pump(const Duration(milliseconds: 250));
  }
  await t.pump(const Duration(milliseconds: 300));
}

Finder key(String k) => find.byKey(Key(k));

/// Signs the app in with the test phone number: from the sign-in sheet or a tab's prompt, at the phone button.
Future<void> signInWithPhone(WidgetTester t) async {
  await t.tap(find.text('Continue with phone number'));
  await t.pumpAndSettle();
  await t.enterText(key('phone-field'), testPhone);
  await t.tap(find.text('Send code'));
  await see(t, key('otp-field'));
  await t.enterText(key('otp-field'), testOtp);
  await t.tap(find.text('Verify'));
  await t.pumpAndSettle(const Duration(seconds: 2));
  // a brand-new account is asked for a name once
  if (key('name-field').evaluate().isNotEmpty) {
    await t.enterText(key('name-field'), 'E2E Tester');
    await t.tap(find.text('Continue'));
    await t.pumpAndSettle(const Duration(seconds: 2));
  }
}

/// A Text with exactly [text]: unlike find.text it does not match what is typed into a search box.
Finder label(String text) => find.byWidgetPredicate((w) => w is Text && w.data == text);

/// From Home: search for [title], scroll to its card and open the event page.
Future<void> openEventFromHome(WidgetTester t, String title) async {
  await t.enterText(key('home-search'), title);
  await see(t, label(title));
  await t.pumpAndSettle(const Duration(seconds: 1)); // the list is rebuilt once the search settles
  await t.scrollUntilVisible(label(title), 200, scrollable: find.byType(Scrollable).first);
  await t.drag(find.byType(Scrollable).first, const Offset(0, -150)); // clear of the tab bar
  await t.pumpAndSettle();
  await t.tap(label(title));
  await see(t, key('event-screen'));
}
