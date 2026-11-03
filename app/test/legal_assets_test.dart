import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The release checklist (Task 25) names what the two legal pages must say; these pin it.
void main() {
  String read(String name) => File('assets/legal/$name.md').readAsStringSync();

  test('privacy_says_what_is_collected_location_rounding_and_how_to_delete', () {
    final t = read('privacy');
    expect(t, contains('PDPA'));
    expect(t, contains('## What we collect'));
    expect(t, contains('rounded to about 1 km'));
    expect(t, contains('is not stored'));
    expect(t, contains('Delete account'));
  });

  test('terms_say_platform_role_refund_policy_no_show_and_illustrative_fees', () {
    final t = read('terms');
    expect(t, contains('Jom is a platform'));
    expect(t, contains('cancel policy'));
    expect(t, contains('no-show'));
    expect(t, contains('illustrative until the payment gateway goes live'));
  });
}
