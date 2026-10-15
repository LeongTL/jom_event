import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_gate.dart';
import '../../features/auth/presentation/profile_placeholder.dart';
import '../../features/auth/presentation/signed_out_tab.dart';
import '../../shared/widgets/shell.dart';
import 'explore_placeholder.dart';
import 'placeholder_screen.dart';

/// A full-screen route with no tab bar.
GoRoute _screen(String path, String title) =>
    GoRoute(path: path, builder: (context, state) => PlaceholderScreen(title: title));

/// A route inside the tab bar.
StatefulShellBranch _tab(String path, String title, {Widget? screen}) => StatefulShellBranch(routes: [
      GoRoute(path: path, builder: (context, state) => screen ?? PlaceholderScreen(title: title, tabBarBelow: true)),
    ]);

/// A tab that belongs to an account: signed-out visitors see a sign-in prompt instead of [content].
StatefulShellBranch _account(String path, String title, String prompt, {Widget? content}) => _tab(
      path,
      title,
      screen: AuthGate(
        signedOut: SignedOutTab(heading: prompt),
        child: content ?? PlaceholderScreen(title: title, tabBarBelow: true),
      ),
    );

/// Every route in the plan. The screens are placeholders until their own task builds them. A path nobody
/// recognises goes to Explore.
GoRouter createRouter({String initialLocation = '/explore'}) => GoRouter(
      initialLocation: initialLocation,
      onException: (context, state, router) => router.go('/explore'),
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => JomShell(navigationShell: shell, host: false),
          branches: [
            _tab('/explore', 'Explore', screen: const ExplorePlaceholder()),
            _account('/saved', 'Saved', 'Sign in to see your saved events'),
            _account('/bookings', 'Bookings', 'Sign in to see your bookings'),
            _account('/chats', 'Chat', 'Sign in to see your chats'),
            _account('/profile', 'Profile', 'Sign in to see your profile', content: const ProfilePlaceholder()),
          ],
        ),
        _screen('/chats/:threadId', 'Chat thread'),
        _screen('/event/:id', 'Event'),
        _screen('/event/:id/checkout', 'Checkout'),
        _screen('/booking/:id/gateway', 'Gateway'),
        _screen('/booking/:id/processing', 'Confirming payment'),
        _screen('/booking/:id/failed', 'Payment failed'),
        _screen('/booking/:id/ticket', 'Ticket'),
        _screen('/review/:bookingId', 'Review'),
        _screen('/host/:id', 'Host profile'),
        _screen('/notifications', 'Notifications'),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => JomShell(navigationShell: shell, host: true),
          branches: [
            _tab('/host-mode/home', 'Host home'),
            _tab('/host-mode/events', 'Host events'),
            _tab('/host-mode/payouts', 'Payouts'),
            _tab('/host-mode/chats', 'Host chat'),
            _tab('/host-mode/profile', 'Host profile'),
          ],
        ),
        _screen('/host-mode/events/:id', 'Event details'),
        _screen('/host-mode/events/:id/edit', 'Edit event'),
        _screen('/host-mode/events/:id/scan', 'Scan tickets'),
        _screen('/host-mode/events/:id/checkin', 'Check-in'),
        _screen('/host-mode/events/:id/guests', 'Guest list'),
        _screen('/host-mode/new', 'New event'),
        _screen('/host-mode/payout-account', 'Payout account'),
      ],
    );

final routerProvider = Provider<GoRouter>((ref) => createRouter());
