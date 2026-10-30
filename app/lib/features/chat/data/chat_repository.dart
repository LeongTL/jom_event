import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/chat.dart';

/// What the chat screens read and change. Tests replace it; [SupabaseChatRepository] is the real one.
/// (Opening a thread with a host lives in EventRepository.openThread, built with the event page.)
abstract class ChatRepository {
  /// My threads that have at least one message, newest first.
  Future<List<ThreadSummary>> mine();

  Future<ThreadInfo> thread(String threadId);

  /// The thread's messages, oldest first, and again each time one arrives.
  Stream<List<Message>> messages(String threadId);

  /// Throws [ChatError].
  Future<void> send(String threadId, String body);

  Future<void> markRead(String threadId);

  /// How many threads have something unread, now and whenever a message arrives.
  Stream<int> unread();
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._ref);
  final Ref _ref;

  SupabaseClient get _db => _ref.read(supabaseClientProvider);

  @override
  Future<List<ThreadSummary>> mine() async => [
    for (final r in await _db.schema('chat').rpc('my_threads') as List)
      ThreadSummary.fromJson(r as Map<String, dynamic>),
  ];

  @override
  Future<ThreadInfo> thread(String threadId) async {
    final me = _db.auth.currentUser!.id;
    final t = await _db
        .schema('chat')
        .from('threads')
        .select('attendee_id, host_id, event_id')
        .eq('id', threadId)
        .single();
    final iAmHost = t['host_id'] == me;
    String? name;
    if (iAmHost) {
      // a host reads the guest's name from the inbox (a thread they can open always has a message)
      name = (await mine())
          .where((x) => x.id == threadId)
          .map((x) => x.otherName)
          .firstOrNull;
    } else {
      final h = await _db
          .schema('identity')
          .from('host_public')
          .select('host_name')
          .eq('user_id', t['host_id'] as String)
          .maybeSingle();
      name = h?['host_name'] as String?;
    }
    return ThreadInfo(
      id: threadId,
      iAmHost: iAmHost,
      otherName: name ?? (iAmHost ? 'Guest' : 'Host'),
      eventId: t['event_id'] as String?,
    );
  }

  @override
  Stream<List<Message>> messages(String threadId) => _db
      .schema('chat')
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('thread_id', threadId)
      .order('created_at')
      .map((rows) => [for (final r in rows) Message.fromJson(r)]);

  @override
  Future<void> send(String threadId, String body) async {
    try {
      await _db
          .schema('chat')
          .rpc(
            'send_message',
            params: {'p_thread_id': threadId, 'p_body': body},
          );
    } on PostgrestException catch (e) {
      throw ChatError(e.message);
    }
  }

  @override
  Future<void> markRead(String threadId) => _db
      .schema('chat')
      .rpc('mark_thread_read', params: {'p_thread_id': threadId});

  @override
  Stream<int> unread() {
    late final StreamController<int> out;
    RealtimeChannel? channel;
    Future<void> fetch() async {
      try {
        out.add(await _db.schema('chat').rpc('unread_total') as int);
      } catch (_) {
        // offline: keep the last number
      }
    }

    out = StreamController<int>(
      onListen: () {
        fetch();
        try {
          channel = _db
              .channel('chat-unread')
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'chat',
                table: 'messages',
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

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => SupabaseChatRepository(ref),
);

/// The number on the Chat tab. Signed out there is no chat, so it asks nothing.
final chatUnreadProvider = StreamProvider.autoDispose<int>((ref) async* {
  if (await ref.watch(sessionProvider.future) == null) {
    yield 0;
    return;
  }
  try {
    yield* ref.watch(chatRepositoryProvider).unread();
  } catch (_) {
    yield 0; // a badge that cannot be read is no badge, never a crash
  }
});

/// The inbox; refetches whenever the unread count changes (a message arrived or a thread was read).
final chatThreadsProvider = FutureProvider.autoDispose<List<ThreadSummary>>((
  ref,
) {
  ref.watch(chatUnreadProvider);
  return ref.watch(chatRepositoryProvider).mine();
});

final threadInfoProvider = FutureProvider.autoDispose
    .family<ThreadInfo, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).thread(id),
    );

final messagesProvider = StreamProvider.autoDispose
    .family<List<Message>, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).messages(id),
    );
