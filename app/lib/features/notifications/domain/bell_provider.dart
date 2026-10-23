import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../data/notification_repository.dart';

/// The number on the bell. Signed-out visitors have no notifications, so they do not ask the backend.
final bellCountProvider = StreamProvider.autoDispose<int>((ref) async* {
  if (await ref.watch(sessionProvider.future) == null) {
    yield 0;
    return;
  }
  try {
    yield* ref.watch(notificationRepositoryProvider).unread();
  } catch (_) {
    yield 0; // a badge that cannot be read is no badge, never a crash
  }
});
