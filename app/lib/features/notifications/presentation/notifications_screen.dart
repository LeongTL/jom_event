import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/jom_switch.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../data/notification_repository.dart';
import '../domain/notification.dart';
import '../domain/notification_labels.dart';
import '../../../shared/widgets/skeleton.dart';

/// The in-app list of notices, then the "Show me" switches. Opening it marks what is on screen as read, but the
/// dots stay for this visit so you can see what was new.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _asked = <String>{}; // already sent to mark_read
  final _fresh = <String>{}; // were unread when they reached this screen
  NotificationPrefs? _prefs; // null until loaded: the two switches wait

  @override
  void initState() {
    super.initState();
    ref.listenManual(notificationsProvider, (_, next) => next.whenData(_seen), fireImmediately: true);
    ref.read(notificationRepositoryProvider).prefs().then((p) {
      if (mounted) setState(() => _prefs = p);
    }, onError: (_) {});
  }

  void _seen(List<AppNotification> list) {
    final ids = [for (final n in list) if (n.unread && _asked.add(n.id)) n.id];
    if (ids.isEmpty) return;
    _fresh.addAll(ids);
    // a failure here only leaves the dots on until next time
    ref.read(notificationRepositoryProvider).markRead(ids).catchError((_) {});
  }

  Future<void> _toggle(NotificationPrefs next) async {
    final before = _prefs;
    setState(() => _prefs = next);
    try {
      await ref.read(notificationRepositoryProvider).setPrefs(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefs = before);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save that. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(fontSize: 13, color: Calm.mut);
    final p = _prefs;
    Widget switchRow(String id, String title, {String? note, bool? value, ValueChanged<bool>? onChanged}) => CardBox(
          gap: 8,
          onTap: onChanged == null ? null : () => onChanged(!value!),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (note != null) Text(note, style: muted),
              ]),
            ),
            const SizedBox(width: 12),
            JomSwitch(key: Key('switch-$id'), value: value ?? true, onChanged: onChanged),
          ]),
        );

    return Scaffold(
      key: const Key('notifications-screen'),
      backgroundColor: Calm.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const BookingNav(title: 'Notifications'),
          ref.watch(notificationsProvider).when(
                skipLoadingOnReload: true,
                loading: () => Skeleton.rows(4),
                error: (_, _) => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Could not load your notifications. Check your connection.'))),
                data: (list) => list.isEmpty
                    ? const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Nothing yet')))
                    : Column(children: [for (final n in list) _Row(n, dot: n.unread || _fresh.contains(n.id))]),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Text('SHOW ME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .88, color: Calm.mut)),
          ),
          switchRow('booking', 'Booking and payment updates', note: 'Always on'),
          switchRow('chat', 'New chat messages', value: p?.chat, onChanged: p == null ? null : (v) => _toggle(p.copyWith(chat: v))),
          switchRow('event', 'Event changes and cancellations', note: 'Always on'),
          switchRow('review', 'Review requests', value: p?.reviewRequests, onChanged: p == null ? null : (v) => _toggle(p.copyWith(reviewRequests: v))),
          Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text("Notifications show inside Jom only. We don't send push notifications yet.", style: muted)),
        ],
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row(this.n, {required this.dot});
  final AppNotification n;
  final bool dot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = notifRoute(n);
    return CardBox(
      key: Key('notif-${n.id}'),
      gap: 8,
      onTap: route == null ? null : () => n.type == 'payout' ? context.go(route) : context.push(route),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 40, decoration: const BoxDecoration(color: Calm.accSoft, shape: BoxShape.circle), child: Icon(notifIcon(n.type), size: 20, color: Calm.acc)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (n.body != null) Text(n.body!, style: const TextStyle(fontSize: 13, color: Calm.mut)),
            const SizedBox(height: 4),
            Text(notifWhen(n.createdAt, ref.read(nowProvider)()), style: const TextStyle(fontSize: 11, color: Calm.faint)),
          ]),
        ),
        if (dot) ...[
          const SizedBox(width: 12),
          Container(key: Key('notif-dot-${n.id}'), width: 10, height: 10, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: Calm.badge, shape: BoxShape.circle)),
        ],
      ]),
    );
  }
}
