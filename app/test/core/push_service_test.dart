import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jom/core/push/push_service.dart';
import 'package:jom/features/auth/data/auth_repository.dart';

import '../helpers/fake_auth.dart';
import '../helpers/fake_host.dart';
import '../helpers/fake_push.dart';
import '../helpers/pump_app.dart';

void main() {
  late List<(String, String)> sent;
  late FakePush push;

  setUp(() => sent = []);

  Future<GoRouter> hostHome(WidgetTester t, FakePush p) {
    push = p;
    return pumpApp(
      t,
      location: '/host-mode/home',
      host: FakeHost(profile: hostMe()),
      overrides: [
        pushServiceProvider.overrideWithValue(p),
        pushTokenSinkProvider.overrideWithValue(
          (token, platform) async => sent.add((token, platform)),
        ),
      ],
    );
  }

  testWidgets('first_host_mode_open_asks_permission_once', (t) async {
    final router = await hostHome(t, FakePush());
    router.go('/host-mode/events');
    await t.pumpAndSettle();
    router.go('/host-mode/home');
    await t.pumpAndSettle();
    expect(push.asked, 1);
  });

  testWidgets('granted_registers_the_token_and_refresh_updates_it', (t) async {
    await hostHome(t, FakePush());
    expect(sent, [('tok1', 'android')]);
    push.refresh.add('tok2');
    await t.pumpAndSettle();
    expect(sent, [('tok1', 'android'), ('tok2', 'android')]);
    expect(key('push-banner'), findsNothing);
  });

  testWidgets('denied_shows_the_banner_reminders_only_in_app', (t) async {
    await hostHome(t, FakePush(status: PushStatus.denied));
    expect(key('push-banner'), findsOneWidget);
    expect(find.textContaining('only show inside the app'), findsOneWidget);
    expect(sent, isEmpty);
  });

  test('firebase_start_failure_is_handled_as_denied', () async {
    final service = FirebasePushService(
      init: () async => throw Exception('no config'),
    );
    expect(await service.requestPermission(), PushStatus.denied);
    expect(await service.token(), isNull);
    expect(await service.tokenChanges().isEmpty, isTrue);
  });

  test('signed_out_user_registers_nothing', () async {
    final p = FakePush();
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        pushServiceProvider.overrideWithValue(p),
        pushTokenSinkProvider.overrideWithValue(
          (token, platform) async => sent.add((token, platform)),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(await c.read(pushSetupProvider.future), PushStatus.denied);
    expect(p.asked, 0);
    expect(sent, isEmpty);
  });
}
