import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/category_art.dart';
import '../../../shared/widgets/skeleton.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';
import '../domain/chat_labels.dart';

/// The Chat tab, for guests and for hosts: one row per person, newest first. The same list serves both modes;
/// a guest's row wears the event's art, a host's row the guest's initial.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key, this.host = false});
  final bool host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('chat-list-screen'),
      backgroundColor: Calm.bg,
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 13, 20, 120),
        children: [
          const Text('Chat', key: Key('chat-heading'), style: TextStyle(fontFamily: Calm.serif, fontSize: 30, fontWeight: FontWeight.w600)),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
            child: Text(host ? 'Messages from guests about your events.' : 'Ask a host before you book.', style: const TextStyle(fontSize: 13, color: Calm.mut)),
          ),
          ref.watch(chatThreadsProvider).when(
                skipLoadingOnReload: true,
                loading: () => Padding(padding: const EdgeInsets.only(top: 16), child: Skeleton.rows(4)),
                error: (_, _) => const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('Could not load your chats. Check your connection.'))),
                data: (list) => list.isEmpty
                    ? const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: Text('No chats yet')))
                    : Column(children: [for (final t in list) _Row(t, host: host)]),
              ),
        ],
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row(this.t, {required this.host});
  final ThreadSummary t;
  final bool host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = host && t.eventTitle != null ? '${t.lastBody} · ${t.eventTitle}' : t.lastBody;
    return GestureDetector(
      key: Key('thread-${t.id}'),
      onTap: () => context.push('/chats/${t.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Calm.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Calm.line)),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: host
                  ? Container(key: Key('initial-${t.id}'), alignment: Alignment.center, color: Calm.accSoft, child: Text(t.otherName.characters.first.toUpperCase(), style: const TextStyle(fontFamily: Calm.serif, fontSize: 22, fontWeight: FontWeight.w600, color: Calm.acc)))
                  : CategoryArt(kind: artKindFor(t.eventId ?? t.id, t.eventCategories)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Calm.mut)),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(chatWhen(t.lastAt, ref.read(nowProvider)()), style: const TextStyle(fontSize: 11, color: Calm.faint)),
            if (t.unread)
              Container(key: Key('unread-dot-${t.id}'), width: 10, height: 10, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: Calm.badge, shape: BoxShape.circle)),
          ]),
        ]),
      ),
    );
  }
}
