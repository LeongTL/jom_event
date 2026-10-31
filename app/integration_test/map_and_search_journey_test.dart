import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/seed.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'home: search narrows the list, a category tile filters it, the map opens an event',
    (t) async {
      final host = await newHost('E2E Map Host');
      final word = uniqueWord();
      final alpha = 'E2E Alpha $word';
      final beta = 'E2E Beta $word';
      final alphaId = await publishEvent(
        host,
        title: alpha,
        priceSen: 0,
        category: 'make',
        startsIn: const Duration(hours: 3),
      );
      final betaId = await publishEvent(
        host,
        title: beta,
        priceSen: 0,
        category: 'move',
        startsIn: const Duration(hours: 3),
      );

      await launchApp(t);
      await see(t, key('home-screen'));

      // the unique word finds both; the full name finds only one
      await t.enterText(key('home-search'), word);
      await see(t, label(alpha));
      await see(t, label(beta));
      await t.enterText(key('home-search'), alpha);
      await see(t, label(alpha));
      await see(
        t,
        key('home-screen'),
      ); // the list has narrowed once Beta is gone
      await eventually(
        () async {
          await t.pump(const Duration(milliseconds: 300));
          // Near you rows only: the This weekend carousel ignores the search, and on a Saturday it can hold Beta
          return key('event-row-$betaId').evaluate().isEmpty;
        },
        describe: () =>
            'search box: "${t.widget<TextField>(key('home-search')).controller?.text}". On screen: ${onScreen(t)}',
      );

      // a category tile filters what is left: Move keeps Beta only
      await t.enterText(key('home-search'), word);
      await see(t, label(alpha));
      await t.ensureVisible(key('tile-move'));
      await t.tap(key('tile-move'));
      await eventually(() async {
        await t.pump(const Duration(milliseconds: 300));
        return key('event-row-$alphaId').evaluate().isEmpty &&
            key('event-row-$betaId').evaluate().isNotEmpty;
      });

      // the map card opens the map; pick Beta's pin and View event
      await t.ensureVisible(find.text('Open map'));
      await settle(t);
      await t.tap(find.text('Open map').first);
      await see(t, key('pin-$betaId'));
      // pins in one area sit on top of each other, so call this pin's own handler rather than tap its centre
      t.widget<GestureDetector>(key('pin-$betaId')).onTap!();
      await settle(t);
      await see(t, key('map-view-event'));
      await t.tap(key('map-view-event'));
      await see(t, key('event-screen'));
      await see(t, find.textContaining(beta));
    },
  );
}
