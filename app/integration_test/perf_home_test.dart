import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/seed.dart';

// Task 24 step 4: frame times while scrolling Home (list, carousel) and panning the map. Run on a real device in profile mode:
//   flutter drive --profile --driver=test_driver/integration_test.dart --target=integration_test/perf_home_test.dart -d <id> --no-dds --dart-define-from-file=env/e2e.json
// The numbers land in build/integration_response_data.json. Not a *_journey_test, so tools/e2e.sh skips it.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home scroll and map pan frame times', (t) async {
    await launchApp(t);
    await see(t, key('home-screen'));

    await binding.watchPerformance(() async {
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 6; i++) {
        await t.fling(list, const Offset(0, -500), 1500);
        await t.pumpAndSettle();
        await t.fling(list, const Offset(0, 500), 1500);
        await t.pumpAndSettle();
      }
      final carousel = find.byType(Scrollable).at(1);
      for (var i = 0; i < 4; i++) {
        await t.fling(carousel, const Offset(-300, 0), 1200);
        await t.pumpAndSettle();
        await t.fling(carousel, const Offset(300, 0), 1200);
        await t.pumpAndSettle();
      }
    }, reportKey: 'home_scroll');

    await t.ensureVisible(find.text('Open map').first);
    await settle(t);
    await t.tap(find.text('Open map').first);
    await settle(t, const Duration(seconds: 2));

    await binding.watchPerformance(() async {
      final map = find.byType(FlutterMap);
      for (var i = 0; i < 6; i++) {
        await t.drag(map, const Offset(-150, -150));
        await t.pump(const Duration(milliseconds: 300));
        await t.drag(map, const Offset(150, 150));
        await t.pump(const Duration(milliseconds: 300));
      }
    }, reportKey: 'map_pan');
  });
}
