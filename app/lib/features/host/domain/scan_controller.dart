import '../../event/domain/event_labels.dart';

enum ScanKind { checkedIn, already, wrongEvent, notConfirmed, invalid, offline }

/// What the scanner shows after one code.
class ScanResult {
  const ScanResult(this.kind, {this.name, this.people, this.code, this.at});

  /// From the server's `{result, guest_name, people, ticket_code, at}`.
  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
    switch (j['result']) {
      'checked_in' => ScanKind.checkedIn,
      'already' => ScanKind.already,
      'wrong_event' => ScanKind.wrongEvent,
      'not_confirmed' => ScanKind.notConfirmed,
      _ => ScanKind.invalid,
    },
    name: j['guest_name'] as String?,
    people: (j['people'] as num?)?.toInt(),
    code: j['ticket_code'] as String?,
    at: j['at'] == null ? null : DateTime.parse(j['at'] as String),
  );

  final ScanKind kind;
  final String? name, code;
  final int? people;
  final DateTime? at;

  bool get good => kind == ScanKind.checkedIn || kind == ScanKind.already;

  String get message => switch (kind) {
    ScanKind.checkedIn => 'Checked in just now',
    ScanKind.already =>
      'Already checked in${at == null ? '' : ' at ${timeLabel(at!)}'}',
    ScanKind.wrongEvent => 'This ticket is for another event',
    ScanKind.notConfirmed => 'This booking is not paid or was cancelled',
    ScanKind.invalid => 'Not a Jom ticket',
    ScanKind.offline => 'No signal. Use the manual list instead.',
  };
}

/// Sends scanned codes to the server. A code seen again within [debounce] gets the first answer back
/// without another call, so a camera held on one ticket does not fire twice.
class ScanController {
  ScanController(
    this._checkIn, {
    this.debounce = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Future<ScanResult> Function(String token) _checkIn;
  final Duration debounce;
  final DateTime Function() _now;
  String? _code;
  DateTime _at = DateTime.fromMillisecondsSinceEpoch(0);
  Future<ScanResult>? _last;

  Future<ScanResult> onCode(String raw) {
    if (raw == _code && _now().difference(_at) < debounce) return _last!;
    _code = raw;
    _at = _now();
    return _last = _send(raw);
  }

  Future<ScanResult> _send(String raw) async {
    try {
      return await _checkIn(raw);
    } catch (_) {
      return const ScanResult(ScanKind.offline);
    }
  }
}
