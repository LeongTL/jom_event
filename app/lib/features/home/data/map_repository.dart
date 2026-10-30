import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/supabase_client.dart';
import '../../../shared/models/event_summary.dart';

/// What the map asks for: a centre, a radius and the chip that is on.
typedef MapQuery = ({
  double lat,
  double lng,
  int km,
  String category,
  bool tonight,
});

double _round2(double v) => (v * 100).round() / 100;

/// The map_pins arguments; the centre may be the phone's position, so it goes out rounded to 0.01 degrees (about 1 km).
Map<String, Object> mapPinsParams(MapQuery q) => {
  'p_lat': _round2(q.lat),
  'p_lng': _round2(q.lng),
  'p_km': q.km,
  'p_category': q.category,
  'p_tonight': q.tonight,
};

class MapRepository {
  MapRepository(this._ref);
  final Ref _ref;

  /// Events with a position around the centre (events.map_pins).
  Future<List<EventSummary>> pins(MapQuery q) async {
    final rows =
        await _ref
                .read(supabaseClientProvider)
                .schema('events')
                .rpc('map_pins', params: mapPinsParams(q))
            as List;
    return [
      for (final r in rows) EventSummary.fromJson(r as Map<String, dynamic>),
    ];
  }
}

final mapRepositoryProvider = Provider<MapRepository>(MapRepository.new);

final mapPinsProvider = FutureProvider.autoDispose
    .family<List<EventSummary>, MapQuery>(
      (ref, q) => ref.watch(mapRepositoryProvider).pins(q),
    );

/// The text on a pin: "✓ Booked" for an event you have a ticket to, else "Free" or the price.
String pinLabel(EventSummary e, Set<String> bookedEventIds) =>
    bookedEventIds.contains(e.id) ? '✓ Booked' : formatMoney(e.priceSen);
