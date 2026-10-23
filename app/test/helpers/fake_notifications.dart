import 'dart:async';

import 'package:jom/features/notifications/data/notification_repository.dart';
import 'package:jom/features/notifications/domain/notification.dart';

AppNotification note(String id, String type, String title, DateTime at,
        {String? refType, String? refId, String? body, bool read = false}) =>
    AppNotification(id: id, type: type, refType: refType, refId: refId, title: title, body: body, createdAt: at, readAt: read ? at : null);

/// Stands in for the database and Realtime: the test pushes new notices, and marking read changes the list and the count.
class FakeNotifications implements NotificationRepository {
  FakeNotifications({List<AppNotification> items = const [], this.prefsValue = const NotificationPrefs(chat: true, reviewRequests: true)}) : items = [...items];

  List<AppNotification> items;
  NotificationPrefs prefsValue;
  final _changes = StreamController<void>.broadcast();
  final marked = <String>[];
  final saved = <NotificationPrefs>[];
  Object? saveError;
  Object? markError;
  var unreadCalls = 0;

  int get count => items.where((n) => n.unread).length;

  void push(AppNotification n) {
    items = [n, ...items];
    _changes.add(null);
  }

  /// Like Realtime: the current value first, then every change, listening from the moment the first is sent.
  Stream<T> _live<T>(T Function() read) {
    late StreamController<T> out;
    out = StreamController<T>(onListen: () {
      out.add(read());
      final sub = _changes.stream.listen((_) => out.add(read()));
      out.onCancel = sub.cancel;
    });
    return out.stream;
  }

  @override
  Stream<List<AppNotification>> watch() => _live(() => [...items]);

  @override
  Stream<int> unread() {
    unreadCalls++;
    return _live(() => count);
  }

  @override
  Future<void> markRead(List<String> ids) async {
    if (markError != null) throw markError!;
    marked.addAll(ids);
    items = [
      for (final n in items)
        ids.contains(n.id) && n.unread
            ? AppNotification(id: n.id, type: n.type, refType: n.refType, refId: n.refId, title: n.title, body: n.body, createdAt: n.createdAt, readAt: DateTime.now())
            : n,
    ];
    _changes.add(null);
  }

  @override
  Future<NotificationPrefs> prefs() async => prefsValue;

  @override
  Future<void> setPrefs(NotificationPrefs p) async {
    if (saveError != null) throw saveError!;
    saved.add(p);
    prefsValue = p;
  }
}
