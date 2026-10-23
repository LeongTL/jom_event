import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tokens.dart';
import '../../../shared/widgets/screen_parts.dart';
import '../../auth/data/auth_repository.dart';
import '../../event/data/event_repository.dart';
import '../../event/domain/event_labels.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';
import '../domain/chat_labels.dart';

/// One conversation: who it is with, the event it is about, the messages (live) and the box to write in.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.threadId});
  final String threadId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _field = TextEditingController();
  final _scroll = ScrollController();
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void dispose() {
    _field.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Opening the thread, and each message that arrives while it is open, counts as read.
  Future<void> _markRead() async {
    try {
      await ref.read(chatRepositoryProvider).markRead(widget.threadId);
      ref.invalidate(chatUnreadProvider);
    } catch (_) {
      // offline: it stays unread until the next time
    }
  }

  Future<void> _send() async {
    final text = _field.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() { _sending = true; _error = null; });
    _field.clear();
    try {
      await ref.read(chatRepositoryProvider).send(widget.threadId, text);
    } on ChatError catch (e) {
      if (mounted) {
        _field.text = text; // the words stay so they can be edited
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    ref.listen(messagesProvider(widget.threadId), (prev, next) {
      final n = next.value?.length ?? 0;
      if (n > (prev?.value?.length ?? 0)) {
        if (prev?.value != null) _markRead(); // a message came in while the thread is open
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    });
    final info = ref.watch(threadInfoProvider(widget.threadId));
    final me = ref.watch(sessionProvider).value?.user.id;
    final messages = ref.watch(messagesProvider(widget.threadId)).value ?? const <Message>[];
    return Scaffold(
      key: const Key('thread-screen'),
      backgroundColor: k.sheet,
      body: info.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Could not load this chat. Check your connection.')),
        data: (i) => Column(children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              children: [
                BookingNav(title: i.otherName, trailing: i.iAmHost ? 'Attendee' : 'Host'),
                if (i.eventId != null) _EventCard(eventId: i.eventId!),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: k.card, borderRadius: BorderRadius.circular(16)),
                  child: const Text("Keep the chat in Jom. Phone numbers and social handles can't be shared here.", style: TextStyle(fontSize: 12)),
                ),
                for (final m in messages) _Bubble(m, mine: m.senderId == me),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(_error!, key: const Key('send-error'), style: const TextStyle(color: Color(0xFFFF5A67), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      key: const Key('msg-field'),
                      controller: _field,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Message ${i.iAmHost ? i.otherName.split(' ').first : i.otherName}…',
                        filled: true,
                        fillColor: k.card,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    key: const Key('send-button'),
                    onTap: _send,
                    child: Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: k.accent, shape: BoxShape.circle), child: Text('↑', style: TextStyle(color: k.accentInk, fontSize: 20, fontWeight: FontWeight.w700, height: 1))),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.eventId});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.jom;
    final d = ref.watch(eventDetailProvider(eventId)).value;
    if (d == null) return const SizedBox.shrink();
    final e = d.summary;
    return KeyedSubtree(
      key: const Key('event-card'),
      child: CardBox(
        child: Row(children: [
          MiniArt(glyph: e.glyph, a: e.colorA, b: e.colorB),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${fullWhen(e.startsAt)} · ${e.area ?? ''}', style: TextStyle(fontSize: 13, color: k.sheetInk.withValues(alpha: .62))),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m, {required this.mine});
  final Message m;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final k = context.jom;
    return Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        child: Container(
          key: Key('bubble-${m.id}'),
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: mine ? k.accent : k.card,
            borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: Radius.circular(mine ? 18 : 6), bottomRight: Radius.circular(mine ? 6 : 18)),
          ),
          child: Text(m.body, style: TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w500, color: mine ? k.accentInk : k.sheetInk)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
        child: Text(clockLabel(m.createdAt), key: Key('time-${m.id}'), style: TextStyle(fontSize: 10, color: k.sheetInk.withValues(alpha: .5))),
      ),
    ]);
  }
}
