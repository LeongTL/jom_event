import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/seed.dart';

const _bangsar = {'p_lat': 3.129, 'p_lng': 101.671};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'private event: open by link, hidden from every list, a guest keeps their ticket and can save it',
    (t) async {
      final host = await newHost('E2E Private Host');
      final secret = 'E2E Secret ${uniqueWord()}';
      final open = 'E2E Open ${uniqueWord()}';
      final secretId = await publishEvent(host, title: secret, isPrivate: true);
      await publishEvent(host, title: open);
      final code = await shareCodeOf(host, secretId);

      // a visitor browsing Explore does not see it
      await launchApp(t);
      await openEventFromHome(t, open);
      expect(find.text(secret), findsNothing, reason: 'Explore');

      // someone with the link opens it, signs in, and takes a seat
      await goTo(t, '/e/$code');
      await see(t, key('private-tag'));
      expect(find.text(secret), findsWidgets);
      await t.tap(key('join'));
      await see(t, find.text('Continue with phone number'));
      await signInWithPhone(t);
      await see(t, key('checkout-screen'));
      await bookAndPay(me(), secretId);

      // it is missing from every list the database serves, for someone with no booking
      final viewer = await newPerson();
      final s = viewer.db.schema('events');
      final listed = await s.rpc(
        'list_all',
        params: {
          ..._bangsar,
          'p_category': 'all',
          'p_km': 5,
          'p_query': secret,
        },
      ) as List;
      expect(listed, isEmpty, reason: 'search');
      final all = await s.rpc(
        'list_all',
        params: {..._bangsar, 'p_category': 'all', 'p_km': 5, 'p_query': 'E2E'},
      ) as List;
      expect([for (final r in all) (r as Map)['title']], contains(open));
      expect(
        [for (final r in all) (r as Map)['title']],
        isNot(contains(secret)),
        reason: 'View all',
      );
      final pins =
          await s.rpc('map_pins', params: {..._bangsar, 'p_km': 5}) as List;
      expect(
        [for (final r in pins) (r as Map)['title']],
        isNot(contains(secret)),
        reason: 'the map',
      );
      final page =
          await s.rpc('host_page', params: {'p_host_id': host.id}) as List;
      final upcoming = ((page.first as Map)['upcoming'] as List).cast<String>();
      expect(
        upcoming,
        isNot(contains(secretId)),
        reason: "the host's public page",
      );
      expect(upcoming, hasLength(1));

      // the guest with a booking still sees it in Tickets
      await goTo(t, '/tickets');
      await see(t, label(secret));

      // and can save it: Saved lists it although no list does
      await goTo(t, '/e/$code');
      await see(t, key('hero-heart'));
      await t.tap(key('hero-heart'));
      await settle(t, const Duration(seconds: 2));
      await goTo(t, '/saved');
      await see(t, label(secret));
    },
  );
}
