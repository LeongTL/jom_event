import 'dart:async';

/// Counts down to a hold's end, once a second, until it reaches zero. Leaving the screen cancels the timer.
Stream<Duration> holdTimer(DateTime expiresAt, DateTime Function() now) {
  Duration left() {
    final d = expiresAt.difference(now());
    return d.isNegative ? Duration.zero : d;
  }

  late final StreamController<Duration> out;
  Timer? timer;
  out = StreamController<Duration>(
    onListen: () {
      out.add(left());
      if (left() == Duration.zero) {
        out.close();
        return;
      }
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        out.add(left());
        if (left() == Duration.zero) {
          timer?.cancel();
          out.close();
        }
      });
    },
    onCancel: () => timer?.cancel(),
  );
  return out.stream;
}
