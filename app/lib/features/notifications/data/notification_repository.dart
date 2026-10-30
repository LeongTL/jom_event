import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../domain/notification.dart';

/// What the Notifications screen and the bell read and change. Tests replace it; [SupabaseNotificationRepository] is the real one.
abstract class NotificationRepository {
  /// My newest notifications, newest first, and again whenever one arrives or changes.
  Stream<List<AppNotification>> watch();

  Future<void> markRead(List<String> ids);

  Future<NotificationPrefs> prefs();

  Future<void> setPrefs(NotificationPrefs p);

  /// How many are unread, now and whenever that changes.
  Stream<int> unread();
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _db => _ref.read(supabaseClientProvider);

  @override
  Stream<List<AppNotification>> watch() => _db
      .schema('identity')
      .from('notifications')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(50)
      .map((rows) => [for (final r in rows) AppNotification.fromJson(r)]);

  @override
  Future<void> markRead(List<String> ids) =>
      _db.schema('identity').rpc('mark_read', params: {'ids': ids});

  @override
  Future<NotificationPrefs> prefs() async {
    final r = await _db
        .schema('identity')
        .from('notification_prefs')
        .select('chat, review_requests')
        .maybeSingle();
    return NotificationPrefs(
      chat: r?['chat'] as bool? ?? true,
      reviewRequests: r?['review_requests'] as bool? ?? true,
    );
  }

  @override
  Future<void> setPrefs(NotificationPrefs p) => _db
      .schema('identity')
      .rpc(
        'set_notification_prefs',
        params: {'p_chat': p.chat, 'p_review_requests': p.reviewRequests},
      );

  @override
  Stream<int> unread() {
    late final StreamController<int> out;
    RealtimeChannel? channel;
    Future<void> fetch() async {
      try {
        out.add(await _db.schema('identity').rpc('unread_count') as int);
      } catch (_) {
        // offline: keep the last number
      }
    }

    out = StreamController<int>(
      onListen: () {
        fetch();
        try {
          // any change: a new notice arrives, or one is marked read
          channel = _db
              .channel('notifications-unread')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'identity',
                table: 'notifications',
                callback: (_) => fetch(),
              )
              .subscribe();
        } catch (_) {
          // no live updates: the badge refreshes the next time it is read
        }
      },
      onCancel: () async {
        if (channel != null) await _db.removeChannel(channel!);
      },
    );
    return out.stream;
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => SupabaseNotificationRepository(ref),
);

final notificationsProvider = StreamProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(notificationRepositoryProvider).watch(),
);
