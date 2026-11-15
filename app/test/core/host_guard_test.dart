import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/router/app_router.dart';
import 'package:jom/features/host/domain/host_status.dart';

import '../helpers/fake_host.dart';
import '../helpers/pump_app.dart';

void main() {
  group('hostGuard', () {
    const host = '/host-mode/events/e1/scan';

    test('only an approved host gets into Host mode', () {
      for (final s in HostState.values) {
        expect(
          hostGuard(host, HostAccess(s, true)),
          s == HostState.approved ? isNull : '/explore',
          reason: '$s',
        );
      }
    });

    test('a status that has not loaded yet is blocked, not let through', () {
      expect(
        hostGuard('/host-mode/home', const HostAccess(null, true)),
        '/explore',
      );
    });

    test('with the entrance off nobody gets in, not even an approved host', () {
      expect(
        hostGuard(
          '/host-mode/home',
          const HostAccess(HostState.approved, false),
        ),
        '/explore',
      );
      expect(
        hostGuard('/host-mode/apply', const HostAccess(HostState.none, false)),
        '/explore',
      );
    });

    test(
      'the apply form is open to people who have not applied or were rejected',
      () {
        for (final s in [HostState.none, HostState.rejected]) {
          expect(
            hostGuard('/host-mode/apply', HostAccess(s, true)),
            isNull,
            reason: '$s',
          );
        }
        for (final s in [HostState.pending, HostState.suspended]) {
          expect(
            hostGuard('/host-mode/apply', HostAccess(s, true)),
            '/explore',
            reason: '$s',
          );
        }
      },
    );

    test('everything outside Host mode is left alone', () {
      expect(
        hostGuard('/profile', const HostAccess(HostState.none, false)),
        isNull,
      );
      expect(hostGuard('/e/abc', const HostAccess(null, true)), isNull);
    });
  });

  group('the router', () {
    testWidgets('an approved host opens a Host mode screen', (t) async {
      final router = await pumpApp(
        t,
        location: '/host-mode/home',
        host: FakeHost(profile: hostMe()),
        access: ValueNotifier(const HostAccess(HostState.approved, true)),
      );
      expect(where(router), '/host-mode/home');
    });

    for (final s in [
      HostState.none,
      HostState.pending,
      HostState.rejected,
      HostState.suspended,
    ]) {
      testWidgets('$s is sent to Explore from a Host mode link', (t) async {
        final router = await pumpApp(
          t,
          location: '/host-mode/home',
          access: ValueNotifier(HostAccess(s, true)),
        );
        expect(where(router), '/explore');
      });
    }

    testWidgets(
      'an approved host is sent out when the entrance is switched off',
      (t) async {
        final access = ValueNotifier(
          const HostAccess(HostState.approved, true),
        );
        final router = await pumpApp(
          t,
          location: '/host-mode/home',
          access: access,
        );
        expect(where(router), '/host-mode/home');
        access.value = const HostAccess(HostState.approved, false);
        await t.pumpAndSettle();
        expect(where(router), '/explore');
      },
    );
  });
}
