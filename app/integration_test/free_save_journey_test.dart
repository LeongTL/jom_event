import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('free event: no Join, Save it, the host sees the saves', (
    t,
  ) async {
    final host = await newHost('E2E Free Host');
    final title = 'E2E Free Meetup ${uniqueWord()}';
    final id = await publishEvent(
      host,
      title: title,
      priceSen: 0,
      startsIn: const Duration(hours: 3),
    );

    await launchApp(t);
    await openEventFromHome(t, title);

    // a listing: Directions and the source, but nothing to join
    await see(t, key('directions-cta'));
    expect(key('join'), findsNothing);

    // saving asks for an account, then the heart sticks
    await t.tap(key('hero-heart'));
    await see(t, find.text('Continue with phone number'));
    await signInWithPhone(t);
    await see(t, key('event-screen'));
    await eventually(() async {
      final saved =
          await me().db
                  .schema('identity')
                  .from('saved_events')
                  .select('event_id')
              as List;
      return saved.any((r) => r['event_id'] == id);
    });

    // the host reads how many saved it, and only the host can
    final rows =
        await host.db
                .schema('events')
                .rpc('host_events', params: {'p_event_id': id})
            as List;
    expect((rows.first as Map<String, dynamic>)['saves'], 1);
    await expectLater(
      me().db.schema('identity').rpc('saves_count', params: {'p_event_id': id}),
      throwsA(anything),
    );

    // and nobody can book it any more
    final guest = await newPerson();
    await expectLater(
      guest.db
          .schema('bookings')
          .rpc(
            'create_booking',
            params: {
              'p_event_id': id,
              'p_people': 1,
              'p_name': 'E2E Guest',
              'p_phone': '60111111111',
            },
          ),
      throwsA(predicate((e) => '$e'.contains('free_event_no_booking'))),
    );
  });
}
