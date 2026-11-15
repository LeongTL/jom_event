import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/host/domain/host_status.dart';

import '../../helpers/fake_host.dart';
import '../../helpers/pump_app.dart';

FakeHost host(HostState s, {String? reason}) =>
    FakeHost(profile: null, status: HostStatus(s, reason: reason));

void main() {
  testWidgets('none: Register as Event owner opens the apply form', (t) async {
    final router = await pumpApp(
      t,
      location: '/profile',
      host: host(HostState.none),
    );
    expect(find.text('Register as Event owner'), findsOneWidget);
    expect(find.text('Switch to Host mode'), findsNothing);
    await t.tap(key('host-card-none'));
    await t.pumpAndSettle();
    expect(where(router), '/host-mode/apply');
  });

  testWidgets('pending: Application under review, nothing to tap', (t) async {
    final router = await pumpApp(
      t,
      location: '/profile',
      host: host(HostState.pending),
    );
    expect(find.text('Application under review'), findsOneWidget);
    expect(find.text('Switch to Host mode'), findsNothing);
    await t.tap(key('host-card-pending'));
    await t.pumpAndSettle();
    expect(where(router), '/profile');
  });

  testWidgets('approved: Switch to Host mode goes to the host home', (t) async {
    final router = await pumpApp(
      t,
      location: '/profile',
      host: host(HostState.approved),
    );
    expect(find.text('Switch to Host mode'), findsOneWidget);
    await t.tap(key('host-card-approved'));
    await t.pumpAndSettle();
    expect(where(router), '/host-mode/home');
  });

  testWidgets('rejected: the reason and Apply again', (t) async {
    final router = await pumpApp(
      t,
      location: '/profile',
      host: host(HostState.rejected, reason: 'Add a real photo'),
    );
    expect(find.text('Add a real photo'), findsOneWidget);
    expect(find.text('Apply again'), findsOneWidget);
    await t.tap(key('host-card-rejected'));
    await t.pumpAndSettle();
    expect(where(router), '/host-mode/apply');
  });

  testWidgets('suspended: the paused message, nothing to tap', (t) async {
    final router = await pumpApp(
      t,
      location: '/profile',
      host: host(HostState.suspended),
    );
    expect(
      find.text('Your host access is paused. Contact support'),
      findsOneWidget,
    );
    await t.tap(key('host-card-suspended'));
    await t.pumpAndSettle();
    expect(where(router), '/profile');
  });

  testWidgets('the host entrance flag off hides the card, whatever the state', (
    t,
  ) async {
    for (final s in HostState.values) {
      await pumpApp(t, location: '/profile', host: host(s), hostEntry: false);
      expect(find.text('Switch to Host mode'), findsNothing, reason: '$s');
      expect(find.text('Register as Event owner'), findsNothing, reason: '$s');
      expect(find.text('Application under review'), findsNothing, reason: '$s');
      expect(find.text('Sign out'), findsOneWidget, reason: '$s');
    }
  });
}
