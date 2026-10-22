import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/home/domain/pin_layout.dart';

List<String> ids(int n, [String prefix = 'event']) => [for (var i = 0; i < n; i++) '$prefix-$i-0000-4000-8000-00000000000$i'];

double minGap(List<Offset> p) => [
      for (var i = 0; i < p.length; i++)
        for (var j = i + 1; j < p.length; j++) (p[i] - p[j]).distance
    ].fold(double.infinity, min);

void main() {
  test('layoutPins_is_deterministic_for_same_ids', () {
    expect(layoutPins(ids(9)), layoutPins(ids(9)));
  });

  test('layoutPins_keeps_72px_minimum_gap', () {
    for (final n in [2, 5, 9]) {
      for (final prefix in ['a', 'b', 'c', 'd', 'e']) {
        expect(minGap(layoutPins(ids(n, prefix))), greaterThanOrEqualTo(71), reason: '$n pins, set $prefix');
      }
    }
  });

  // The spec says "about 215 x 190": the prototype's last relaxation pushes pins up to ~10% past it.
  test('layoutPins_fits_215x190_and_is_centred', () {
    for (final prefix in ['a', 'b', 'c', 'd', 'e']) {
      final p = layoutPins(ids(9, prefix));
      final xs = p.map((o) => o.dx), ys = p.map((o) => o.dy);
      expect(xs.reduce(max) - xs.reduce(min), lessThanOrEqualTo(215 * 1.15), reason: prefix);
      expect(ys.reduce(max) - ys.reduce(min), lessThanOrEqualTo(190 * 1.15), reason: prefix);
      expect((xs.reduce(max) + xs.reduce(min)) / 2, closeTo(0, .01), reason: prefix);
      expect((ys.reduce(max) + ys.reduce(min)) / 2, closeTo(0, .01), reason: prefix);
    }
  });

  test('layoutPins_is_stable_when_other_tabs_change_ids', () {
    final set = ids(9);
    final once = layoutPins(set);
    final shuffled = [...set]..shuffle(Random(3));
    final again = layoutPins(shuffled);
    for (var i = 0; i < set.length; i++) {
      expect(again[shuffled.indexOf(set[i])], once[i], reason: set[i]);
    }
  });

  test('layoutPins handles no pins and one pin', () {
    expect(layoutPins(const []), isEmpty);
    expect(layoutPins(const ['solo']), [Offset.zero]);
  });
}
