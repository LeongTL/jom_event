import 'dart:async';

import 'package:jom/features/chat/data/chat_repository.dart';
import 'package:jom/features/chat/domain/chat.dart';

Message msg(String id, String sender, String body, DateTime at) =>
    Message(id: id, senderId: sender, body: body, createdAt: at);

/// Stands in for the database and Realtime: the test pushes messages and unread counts.
class FakeChat implements ChatRepository {
  FakeChat({
    this.threads = const [],
    this.infos = const {},
    Map<String, List<Message>>? messages,
    this.unreadCount = 0,
  }) : _messages = messages ?? {};

  List<ThreadSummary> threads;
  final Map<String, ThreadInfo> infos;
  final Map<String, List<Message>> _messages;
  final _msgCtrls = <String, StreamController<List<Message>>>{};
  final _unreadCtrl = StreamController<int>.broadcast();
  int unreadCount;
  final sent = <(String, String)>[];
  final read = <String>[];
  Object? sendError;

  StreamController<List<Message>> _c(String id) => _msgCtrls.putIfAbsent(
    id,
    () => StreamController<List<Message>>.broadcast(),
  );

  @override
  Future<List<ThreadSummary>> mine() async => threads;

  @override
  Future<ThreadInfo> thread(String threadId) async => infos[threadId]!;

  @override
  Stream<List<Message>> messages(String threadId) async* {
    yield [...?_messages[threadId]];
    yield* _c(threadId).stream;
  }

  @override
  Future<void> send(String threadId, String body) async {
    if (sendError != null) throw sendError!;
    sent.add((threadId, body));
    push(threadId, msg('m${sent.length}', 'u1', body, DateTime.now().toUtc()));
  }

  @override
  Future<void> markRead(String threadId) async => read.add(threadId);

  @override
  Stream<int> unread() async* {
    yield unreadCount;
    yield* _unreadCtrl.stream;
  }

  /// A message arriving (from either side).
  void push(String threadId, Message m) {
    final list = _messages.putIfAbsent(threadId, () => []);
    list.add(m);
    _c(threadId).add([...list]);
  }

  void setUnread(int n) {
    unreadCount = n;
    _unreadCtrl.add(n);
  }
}
