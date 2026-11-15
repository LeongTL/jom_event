import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/flags/flags_repository.dart';
import 'package:jom/features/host/domain/host_status.dart';

void main() {
  group('HostStatus.fromRows', () {
    test('every state the server can return is read', () {
      for (final s in HostState.values) {
        expect(
          HostStatus.fromRows([
            {'status': s.name, 'reason': null},
          ]).state,
          s,
        );
      }
    });

    test('a rejection carries its reason', () {
      final s = HostStatus.fromRows([
        {'status': 'rejected', 'reason': 'Add a real photo'},
      ]);
      expect(s.state, HostState.rejected);
      expect(s.reason, 'Add a real photo');
    });

    test('nothing or an unknown word is none, never an error', () {
      expect(HostStatus.fromRows([]).state, HostState.none);
      expect(
        HostStatus.fromRows([
          {'status': 'banana', 'reason': null},
        ]).state,
        HostState.none,
      );
    });
  });

  group('hostEntryFrom', () {
    test('reads the flag', () {
      expect(
        hostEntryFrom([
          {'key': 'host_entry_enabled', 'value': false},
        ]),
        isFalse,
      );
      expect(
        hostEntryFrom([
          {'key': 'host_entry_enabled', 'value': true},
        ]),
        isTrue,
      );
    });

    test('a missing flag means the entrance is on', () {
      expect(hostEntryFrom([]), isTrue);
    });
  });
}
