import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/auth/domain/phone_number.dart';

void main() {
  test('a Malaysian mobile number in any usual spelling becomes +60...', () {
    for (final raw in [
      '0123456789',
      '012-345 6789',
      '012 345 6789',
      '+60 12 345 6789',
      '+60123456789',
      '60123456789',
      '123456789',
      ' (012) 345-6789 ',
    ]) {
      expect(normalizeMyPhone(raw), '+60123456789', reason: raw);
    }
    expect(
      normalizeMyPhone('011-2345 6789'),
      '+601123456789',
    ); // 11-digit mobile numbers too
  });

  test('anything that is not a Malaysian mobile number is refused with a message to show', () {
    for (final raw in [
      '',
      '   ',
      'abc',
      '12',
      '0123',
      '03-2345 6789',
      '+65 9123 4567',
      '012345678901234',
    ]) {
      expect(
        () => normalizeMyPhone(raw),
        throwsA(isA<FormatException>()),
        reason: raw,
      );
    }
    try {
      normalizeMyPhone('12');
    } on FormatException catch (e) {
      expect(e.message, 'Enter a Malaysian mobile number, like 012 345 6789');
    }
  });

  test('showing a number back to the user groups the digits', () {
    expect(prettyMyPhone('+60123456789'), '+60 12 345 6789');
    expect(prettyMyPhone('+601123456789'), '+60 11 2345 6789');
  });
}
