import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/clock.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';
import '../domain/chat_labels.dart';

const _avatars = [
  [Color(0xFFFF9A62), Color(0xFFD4467C)],
  [Color(0xFF4FACFE), Color(0xFF00C6A7)],
  [Color(0xFFF093FB), Color(0xFFF5576C)],
];

/// The Chat tab, for guests and for hosts: one row per person, newest first. The same list serves both modes;
/// only the line under the title differs.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key, this.host = false});
  final bool host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    return Scaffold(
      key: const Key('chat-list-screen'),
      backgroundColor: k.sheet,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          const BookingNav(title: 'Chat', back: false),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(host ? 'Messages from guests about your events.' : 'Ask a host before you book.', style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62))),
          ),
          ref.watch(chatThreadsProvider).when(
                skipLoadingOnReload: true,
                loading: () => const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator())),
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
    final k = context.jom;
    final g = _avatars[t.otherName.codeUnits.fold<int>(0, (a, b) => a + b) % _avatars.length];
    final sub = host && t.eventTitle != null ? '${t.lastBody} · ${t.eventTitle}' : t.lastBody;
    return GestureDetector(
      key: Key('thread-${t.id}'),
      onTap: () => context.push('/chats/${t.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: k.card, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          MiniArt(glyph: t.otherName.characters.first.toUpperCase(), a: g[0], b: g[1]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62))),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(chatWhen(t.lastAt, ref.read(nowProvider)()), style: TextStyle(fontSize: 11, color: k.sheetInk.withValues(alpha: .5))),
            if (t.unread)
              Container(key: Key('unread-dot-${t.id}'), width: 10, height: 10, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: Color(0xFFFF4D6D), shape: BoxShape.circle)),
          ]),
        ]),
      ),
    );
  }
}
