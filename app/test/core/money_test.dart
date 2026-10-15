import 'package:flutter_test/flutter_test.dart';
import 'package:jom/core/money.dart';

void main() {
  test('formatMoney_free_whole_and_cents', () {
    expect(formatMoney(0), 'Free');
    expect(formatMoney(4500), 'RM 45');
    expect(formatMoney(4550), 'RM 45.50');
  });

  test('formatMoney keeps two digits for small cents and shows big sums whole', () {
    expect(formatMoney(5), 'RM 0.05');
    expect(formatMoney(4505), 'RM 45.05');
    expect(formatMoney(100), 'RM 1');
    expect(formatMoney(31860), 'RM 318.60'); // 12 guests at RM 30: what the host receives
  });

  test('formatMoney refuses a negative amount instead of printing nonsense', () {
    expect(() => formatMoney(-1), throwsArgumentError);
  });
}
