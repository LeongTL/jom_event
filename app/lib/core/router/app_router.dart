import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_gate.dart';
import '../../features/auth/presentation/profile_placeholder.dart';
import '../../features/auth/presentation/signed_out_tab.dart';
import '../../features/booking/presentation/tickets_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_thread_screen.dart';
import '../../features/booking/presentation/checkout_screen.dart';
import '../../features/booking/presentation/failed_screen.dart';
import '../../features/booking/presentation/gateway_screen.dart';
import '../../features/booking/presentation/processing_screen.dart';
import '../../features/booking/presentation/ticket_screen.dart';
import '../../features/booking/domain/booking.dart';
import '../../features/event/presentation/event_screen.dart';
import '../../features/event/presentation/saved_screen.dart';
import '../../features/event/presentation/view_all_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../shared/widgets/screen_parts.dart';
import '../../shared/widgets/shell.dart';
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
            _tab('/explore', 'Explore', screen: const HomeScreen()),
            _account('/saved', 'Saved', 'Sign in to see your saved events', content: const SavedScreen()),
            _account('/tickets', 'Tickets', 'Sign in to see your tickets', content: const TicketsScreen()),
            _account('/chats', 'Chat', 'Sign in to see your chats', content: const ChatListScreen()),
            _account('/profile', 'Profile', 'Sign in to see your profile', content: const ProfilePlaceholder()),
          ],
        ),
        GoRoute(path: '/chats/:threadId', builder: (context, state) => ChatThreadScreen(threadId: state.pathParameters['threadId']!)),
        GoRoute(path: '/explore/all', builder: (context, state) => ViewAllScreen(category: state.uri.queryParameters['category'])),
        _screen('/explore/map', 'Map'),
        GoRoute(path: '/event/:id', builder: (context, state) => EventScreen(id: state.pathParameters['id']!)),
        GoRoute(path: '/event/:id/checkout', builder: (context, state) => CheckoutScreen(eventId: state.pathParameters['id']!)),
        GoRoute(path: '/booking/:id/gateway', builder: (context, state) => GatewayScreen(bookingId: state.pathParameters['id']!, session: state.extra as PaymentSession?)),
        GoRoute(path: '/booking/:id/processing', builder: (context, state) => ProcessingScreen(bookingId: state.pathParameters['id']!)),
        GoRoute(path: '/booking/:id/failed', builder: (context, state) => FailedScreen(bookingId: state.pathParameters['id']!)),
        GoRoute(path: '/booking/:id/ticket', builder: (context, state) => TicketScreen(bookingId: state.pathParameters['id']!)),
        _screen('/review/:bookingId', 'Review'),
        _screen('/host/:id', 'Host profile'),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => AuthGate(
            signedOut: Stack(children: [
              const SignedOutTab(heading: 'Sign in to see your notifications'),
              const Positioned(top: 0, left: 20, right: 20, child: BookingNav(title: 'Notifications')),
            ]),
            child: const NotificationsScreen(),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => JomShell(navigationShell: shell, host: true),
          branches: [
            _tab('/host-mode/home', 'Host home'),
            _tab('/host-mode/events', 'Host events'),
            _tab('/host-mode/payouts', 'Payouts'),
            _tab('/host-mode/chats', 'Host chat', screen: const ChatListScreen(host: true)),
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
