import 'dart:async';

import 'package:jom/core/push/push_service.dart';

class FakePush implements PushService {
  FakePush({this.status = PushStatus.granted, this.tokenValue = 'tok1'});
  final PushStatus status;
  final String? tokenValue;
  var asked = 0;
  final refresh = StreamController<String>.broadcast();

  @override
  Future<PushStatus> requestPermission() async {
    asked++;
    return status;
  }

  @override
  Future<String?> token() async => tokenValue;

  @override
  Stream<String> tokenChanges() => refresh.stream;
}
