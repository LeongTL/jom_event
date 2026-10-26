import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:jom/features/home/data/map_repository.dart';
import 'package:jom/shared/models/event_summary.dart';

/// Draws every tile as one transparent pixel so no test touches the network.
class BlankTiles extends TileProvider {
  static final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => MemoryImage(_png);
}

class FakeMap implements MapRepository {
  FakeMap(this.all);
  final List<EventSummary> all;
  final queries = <MapQuery>[];

  @override
  Future<List<EventSummary>> pins(MapQuery q) async {
    queries.add(q);
    return all.where((e) => q.category == 'all' || e.categories.contains(q.category)).toList();
  }
}
