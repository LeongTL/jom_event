import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/host/domain/scan_controller.dart';

void main() {
  test('same_code_within_2_seconds_calls_server_once', () async {
    var calls = 0, t = DateTime.utc(2030);
    final c = ScanController((_) async {
      calls++;
      return const ScanResult(ScanKind.checkedIn);
    }, now: () => t);
    final a = await c.onCode('x');
    t = t.add(const Duration(milliseconds: 1500));
    final b = await c.onCode('x');
    expect(calls, 1);
    expect(b, same(a));
    t = t.add(const Duration(milliseconds: 600));
    await c.onCode('x');
    expect(calls, 2);
    await c.onCode('y');
    expect(calls, 3);
  });

  test('a_failed_call_is_offline', () async {
    var t = DateTime.utc(2030);
    final c = ScanController(
      (_) async => throw Exception('no network'),
      now: () => t,
    );
    expect((await c.onCode('x')).kind, ScanKind.offline);
  });

  test('server_words_map_to_kinds', () {
    for (final (w, k) in [
      ('checked_in', ScanKind.checkedIn),
      ('already', ScanKind.already),
      ('wrong_event', ScanKind.wrongEvent),
      ('not_confirmed', ScanKind.notConfirmed),
      ('invalid', ScanKind.invalid),
      ('surprise', ScanKind.invalid),
    ]) {
      expect(ScanResult.fromJson({'result': w}).kind, k);
    }
  });
}
