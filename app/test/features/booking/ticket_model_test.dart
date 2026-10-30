import 'package:flutter_test/flutter_test.dart';
import 'package:jom/features/booking/domain/ticket.dart';

import '../../helpers/fake_bookings.dart';
import '../../helpers/fake_events.dart';

void main() {
  test('groupByDay puts Today first, then the other days in date order', () {
    Ticket at(String id, Duration d) =>
        Ticket(bk(id), sum(id, starts: clock.add(d)));
    final g = groupByDay([
      at('c', const Duration(days: 5)),
      at('b', const Duration(days: 3)),
      at('a', const Duration(hours: 4)),
      at('d', const Duration(days: 3, hours: 1)),
    ], clock);
    expect(g.keys.toList(), ['TODAY · WED 9 JAN', 'SAT 12 JAN', 'MON 14 JAN']);
    expect(g['SAT 12 JAN']!.map((t) => t.id), ['b', 'd']);
  });
}
