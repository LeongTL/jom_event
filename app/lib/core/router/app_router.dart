import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_gate.dart';
import '../../features/host/data/host_repository.dart';
import '../../features/host/domain/host_status.dart';
import '../flags/flags_repository.dart';
import '../../features/auth/presentation/signed_out_tab.dart';
import '../../features/booking/presentation/tickets_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_thread_screen.dart';
import '../../features/booking/presentation/checkout_screen.dart';
import '../../features/booking/presentation/failed_screen.dart';
import '../../features/booking/presentation/gateway_screen.dart';
import '../../features/booking/presentation/pay_screen.dart';
import '../../features/host/presentation/assign_seat_screen.dart';
import '../../features/host/presentation/payment_details_screen.dart';
import '../../features/host/presentation/pending_receipts_screen.dart';
import '../../features/host/presentation/receipt_detail_screen.dart';
import '../../features/booking/presentation/processing_screen.dart';
import '../../features/booking/presentation/waiting_screen.dart';
import '../../features/booking/presentation/ticket_screen.dart';
import '../../features/booking/domain/booking.dart';
import '../../features/event/presentation/event_by_code_screen.dart';
import '../../features/event/presentation/event_screen.dart';
import '../../features/event/presentation/saved_screen.dart';
import '../../features/event/presentation/view_all_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/people/presentation/edit_username_screen.dart';
import '../../features/people/presentation/find_people_screen.dart';
import '../../features/people/presentation/follow_list_screen.dart';
import '../../features/people/presentation/person_by_username_screen.dart';
import '../../features/people/presentation/person_screen.dart';
import '../../features/home/presentation/map_screen.dart';
import '../../features/host/presentation/apply_host_screen.dart';
import '../../features/host/presentation/checkin_screen.dart';
import '../../features/host/presentation/guest_list_screen.dart';
import '../../features/host/presentation/host_event_screen.dart';
import '../../features/host/presentation/payouts_screen.dart';
import '../../features/host/presentation/scan_screen.dart';
import '../../features/host/presentation/event_form_screen.dart';
import '../../features/host/presentation/host_events_screen.dart';
import '../../features/host/presentation/host_home_screen.dart';
import '../../features/host/presentation/host_profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/help_screen.dart';
import '../../features/profile/presentation/legal_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reviews/presentation/host_public_screen.dart';
import '../../features/reviews/presentation/my_reviews_screen.dart';
import '../../features/reviews/presentation/review_screen.dart';
import '../../shared/widgets/screen_parts.dart';
import '../../shared/widgets/shell.dart';
import 'placeholder_screen.dart';

/// A route inside the tab bar.
StatefulShellBranch _tab(String path, String title, {Widget? screen}) =>
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: path,
          builder: (context, state) =>
              screen ?? PlaceholderScreen(title: title, tabBarBelow: true),
        ),
      ],
    );

/// A tab that belongs to an account: signed-out visitors see a sign-in prompt instead of [content].
StatefulShellBranch _account(
  String path,
  String title,
  String prompt, {
  Widget? content,
}) => _tab(
  path,
  title,
  screen: AuthGate(
    signedOut: SignedOutTab(heading: prompt),
    child: content ?? PlaceholderScreen(title: title, tabBarBelow: true),
  ),
);

/// Every route in the plan. The screens are placeholders until their own task builds them. A path nobody
/// recognises goes to Explore.
/// A link from outside the app (`jom://e/<code>`) becomes the in-app path (`/e/<code>`); anything else is left alone.
String? deepLinkRedirect(Uri uri) {
  if (uri.scheme != 'jom') return null;
  final path = '/${uri.host}${uri.path}';
  return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
}

/// What the Host mode guard knows: my application's state (null until it has loaded) and the host entrance flag.
class HostAccess {
  const HostAccess(this.state, this.entryEnabled);
  final HostState? state;
  final bool entryEnabled;
}

/// Where to send a visitor away from a /host-mode path, or null to let them in. Only an approved host gets into Host
/// mode; someone who has not applied (or was rejected) may open the apply form; with the entrance off, nobody does.
/// A state that has not loaded yet is blocked.
String? hostGuard(String path, HostAccess a) {
  if (path != '/host-mode' && !path.startsWith('/host-mode/')) return null;
  if (!a.entryEnabled) return '/explore';
  if (a.state == HostState.approved) return null;
  final mayApply = a.state == HostState.none || a.state == HostState.rejected;
  return path == '/host-mode/apply' && mayApply ? null : '/explore';
}

GoRouter createRouter({
  String initialLocation = '/explore',
  ValueListenable<HostAccess>? access,
}) => GoRouter(
  initialLocation: initialLocation,
  refreshListenable: access,
  redirect: (context, state) =>
      deepLinkRedirect(state.uri) ??
      (access == null ? null : hostGuard(state.uri.path, access.value)),
  onException: (context, state, router) => router.go('/explore'),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          JomShell(navigationShell: shell, host: false),
      branches: [
        _tab('/explore', 'Explore', screen: const HomeScreen()),
        _account(
          '/saved',
          'Saved',
          'Sign in to see your saved events',
          content: const SavedScreen(),
        ),
        _account(
          '/tickets',
          'Tickets',
          'Sign in to see your tickets',
          content: const TicketsScreen(),
        ),
        _account(
          '/chats',
          'Chat',
          'Sign in to see your chats',
          content: const ChatListScreen(),
        ),
        _account(
          '/profile',
          'Profile',
          'Sign in to see your profile',
          content: const ProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/chats/:threadId',
      builder: (context, state) =>
          ChatThreadScreen(threadId: state.pathParameters['threadId']!),
    ),
    GoRoute(
      path: '/explore/all',
      builder: (context, state) =>
          ViewAllScreen(category: state.uri.queryParameters['category']),
    ),
    GoRoute(
      path: '/explore/map',
      builder: (context, state) => const MapScreen(),
    ),
    GoRoute(
      path: '/event/:id',
      builder: (context, state) => EventScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/u/:username',
      builder: (context, state) =>
          PersonByUsernameScreen(username: state.pathParameters['username']!),
    ),
    GoRoute(
      path: '/e/:code',
      builder: (context, state) =>
          EventByCodeScreen(code: state.pathParameters['code']!),
    ),
    GoRoute(
      path: '/event/:id/checkout',
      builder: (context, state) =>
          CheckoutScreen(eventId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/booking/:id/gateway',
      builder: (context, state) => GatewayScreen(
        bookingId: state.pathParameters['id']!,
        session: state.extra as PaymentSession?,
      ),
    ),
    GoRoute(
      path: '/booking/:id/pay',
      builder: (context, state) =>
          PayScreen(bookingId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/booking/:id/waiting',
      builder: (context, state) =>
          WaitingScreen(bookingId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/booking/:id/processing',
      builder: (context, state) =>
          ProcessingScreen(bookingId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/booking/:id/failed',
      builder: (context, state) =>
          FailedScreen(bookingId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/booking/:id/ticket',
      builder: (context, state) => TicketScreen(
        bookingId: state.pathParameters['id']!,
        fresh: state.uri.queryParameters['new'] == '1',
      ),
    ),
    GoRoute(
      path: '/review/:bookingId',
      builder: (context, state) =>
          ReviewScreen(bookingId: state.pathParameters['bookingId']!),
    ),
    GoRoute(
      path: '/host/:id',
      builder: (context, state) =>
          HostPublicScreen(hostId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/my-reviews',
      builder: (context, state) => const MyReviewsScreen(),
    ),
    GoRoute(
      path: '/edit-username',
      builder: (context, state) => const EditUsernameScreen(),
    ),
    GoRoute(
      path: '/people',
      builder: (context, state) => const FindPeopleScreen(),
    ),
    GoRoute(
      path: '/people/:id',
      builder: (context, state) =>
          PersonScreen(userId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/people/:id/followers',
      builder: (context, state) => FollowListScreen(
        userId: state.pathParameters['id']!,
        followers: true,
      ),
    ),
    GoRoute(
      path: '/people/:id/following',
      builder: (context, state) => FollowListScreen(
        userId: state.pathParameters['id']!,
        followers: false,
      ),
    ),
    GoRoute(path: '/help', builder: (context, state) => const HelpScreen()),
    GoRoute(path: '/legal', builder: (context, state) => const LegalScreen()),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => AuthGate(
        signedOut: Stack(
          children: [
            const SignedOutTab(heading: 'Sign in to see your notifications'),
            const Positioned(
              top: 0,
              left: 20,
              right: 20,
              child: BookingNav(title: 'Notifications'),
            ),
          ],
        ),
        child: const NotificationsScreen(),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          JomShell(navigationShell: shell, host: true),
      branches: [
        _tab('/host-mode/home', 'Host home', screen: const HostHomeScreen()),
        _tab(
          '/host-mode/events',
          'Host events',
          screen: const HostEventsScreen(),
        ),
        _tab('/host-mode/payouts', 'Payouts', screen: const PayoutsScreen()),
        _tab(
          '/host-mode/chats',
          'Host chat',
          screen: const ChatListScreen(host: true),
        ),
        _tab(
          '/host-mode/profile',
          'Host profile',
          screen: const HostProfileScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/host-mode/assign-seat',
      builder: (context, state) => AssignSeatScreen(
        eventId: state.uri.queryParameters['eventId'],
        userId: state.uri.queryParameters['userId'],
        receiptId: state.uri.queryParameters['receiptId'],
      ),
    ),
    GoRoute(
      path: '/host-mode/receipts',
      builder: (context, state) =>
          PendingReceiptsScreen(eventId: state.uri.queryParameters['event']),
    ),
    GoRoute(
      path: '/host-mode/receipts/:id',
      builder: (context, state) =>
          ReceiptDetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/host-mode/events/:id',
      builder: (context, state) =>
          HostEventScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/host-mode/events/:id/edit',
      builder: (context, state) =>
          EventFormScreen(id: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/host-mode/events/:id/scan',
      builder: (context, state) => ScanScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/host-mode/events/:id/checkin',
      builder: (context, state) =>
          CheckinScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/host-mode/events/:id/guests',
      builder: (context, state) =>
          GuestListScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/host-mode/new',
      builder: (context, state) => const EventFormScreen(),
    ),
    GoRoute(
      path: '/host-mode/apply',
      builder: (context, state) => const ApplyHostScreen(),
    ),
    GoRoute(
      path: '/host-mode/payment-details',
      builder: (context, state) => const PaymentDetailsScreen(),
    ),
    GoRoute(
      path: '/host-mode/payout-account',
      builder: (context, state) => const ApplyHostScreen(edit: true),
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) {
  final access = ValueNotifier(const HostAccess(null, true));
  void sync() => access.value = HostAccess(
    ref.read(hostStatusProvider).value?.state,
    ref.read(hostEntryEnabledProvider).value ?? true,
  );
  ref.listen(hostStatusProvider, (_, _) => sync(), fireImmediately: true);
  ref.listen(hostEntryEnabledProvider, (_, _) => sync());
  ref.onDispose(access.dispose);
  return createRouter(access: access);
});
