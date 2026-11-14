import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../supabase_client.dart';

enum PushStatus { granted, denied }

/// Where this phone's push token comes from. Tests replace it; [FirebasePushService] is the real one.
abstract class PushService {
  Future<PushStatus> requestPermission();
  Future<String?> token();
  Stream<String> tokenChanges();
}

/// Firebase Cloud Messaging. Without a Firebase project in the build (no GoogleService-Info.plist or
/// google-services.json) starting Firebase fails; that is treated as "no push", never a crash.
class FirebasePushService implements PushService {
  FirebasePushService({Future<void> Function()? init})
    : _init = init ?? (() => Firebase.initializeApp());
  final Future<void> Function() _init;
  Future<bool>? _ready;

  Future<bool> _start() =>
      _ready ??= _init().then((_) => true, onError: (_) => false);

  @override
  Future<PushStatus> requestPermission() async {
    if (!await _start()) return PushStatus.denied;
    try {
      final s = await FirebaseMessaging.instance.requestPermission();
      final ok =
          s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
      return ok ? PushStatus.granted : PushStatus.denied;
    } catch (_) {
      return PushStatus.denied;
    }
  }

  @override
  Future<String?> token() async {
    if (!await _start()) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null; // e.g. iOS before the APNs token arrives; the refresh stream delivers it later
    }
  }

  @override
  Stream<String> tokenChanges() async* {
    if (await _start()) {
      yield* FirebaseMessaging.instance.onTokenRefresh;
    }
  }
}

final pushServiceProvider = Provider<PushService>(
  (ref) => FirebasePushService(),
);

/// Saves a token for the signed-in user (identity.register_device_token). Tests replace it.
final pushTokenSinkProvider =
    Provider<Future<void> Function(String token, String platform)>(
      (ref) =>
          (token, platform) => ref
              .read(supabaseClientProvider)
              .schema('identity')
              .rpc(
                'register_device_token',
                params: {'p_token': token, 'p_platform': platform},
              ),
    );

/// Asks for notification permission once per app run (the system itself only prompts once), then keeps the token
/// registered. Signed-out visitors are never asked. Watched by Host mode's home.
final pushSetupProvider = FutureProvider<PushStatus>((ref) async {
  if (await ref.read(authRepositoryProvider).session.first == null) {
    return PushStatus.denied;
  }
  final push = ref.read(pushServiceProvider);
  if (await push.requestPermission() != PushStatus.granted) {
    return PushStatus.denied;
  }
  final platform = defaultTargetPlatform == TargetPlatform.iOS
      ? 'ios'
      : 'android';
  final sink = ref.read(pushTokenSinkProvider);
  Future<void> save(String? token) async {
    if (token == null) return;
    try {
      await sink(token, platform);
    } catch (_) {
      // shortcut: a failed save is retried the next time Host mode opens or the token refreshes
    }
  }

  await save(await push.token());
  final sub = push.tokenChanges().listen(save);
  ref.onDispose(sub.cancel);
  return PushStatus.granted;
});
