import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/location.dart';
import '../../../core/supabase_client.dart';
import '../../../core/theme/calm.dart';
import '../../../shared/models/event_summary.dart';
import '../../auth/data/auth_repository.dart';
import '../../booking/data/booking_repository.dart';
import '../../booking/domain/ticket.dart';
import '../data/map_repository.dart';
import 'area_sheet.dart';
import 'map_chips.dart';
import 'map_event_card.dart';
import 'price_pin.dart';
import '../../../shared/widgets/skeleton.dart';

/// Tiles come from [AppConfig.mapTileUrl]; tests replace this with a provider that draws nothing.
final mapTileProvider = Provider<TileProvider>((ref) => NetworkTileProvider());

/// A pan of at least this far makes "Search this area" appear.
const _searchThresholdM = 500.0;

/// Explore on a map: price pins, filter chips, the selected event on a sheet at the bottom.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _controller = MapController();
  MapQuery? _query; // what the pins were fetched for
  ll.LatLng? _me;
  ll.LatLng? _camera;
  bool _moved = false;
  String _chip = 'all';
  String? _selected;

  AreaSelection get _area => ref.read(areaSelectionProvider);

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final sel = _area;
    final p = sel.useDevice ? await ref.read(deviceLocationProvider)() : null;
    if (!mounted) return;
    final at = p ?? kAreas[sel.area]!;
    setState(() {
      if (p != null) _me = ll.LatLng(p.lat, p.lng);
      _query = _queryAt(at.lat, at.lng);
    });
  }

  MapQuery _queryAt(double lat, double lng) =>
      (lat: lat, lng: lng, km: _area.km, category: _chip == 'tonight' ? 'all' : _chip, tonight: _chip == 'tonight');

  void _pick(String chip) => setState(() {
        _chip = chip;
        final q = _query!;
        _query = _queryAt(q.lat, q.lng);
      });

  void _searchHere() {
    final c = _camera;
    if (c == null) return;
    setState(() {
      _query = _queryAt(c.latitude, c.longitude);
      _moved = false;
    });
  }

  Future<void> _locate() async {
    final p = await ref.read(deviceLocationProvider)();
    if (!mounted) return;
    if (p == null) {
      final at = kAreas[_area.area]!;
      _controller.move(ll.LatLng(at.lat, at.lng), _controller.camera.zoom);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Showing the selected area')));
      return;
    }
    final me = ll.LatLng(p.lat, p.lng);
    _controller.move(me, _controller.camera.zoom);
    setState(() {
      _me = me;
      _query = _queryAt(p.lat, p.lng);
      _moved = false;
    });
  }

  void _onMoved(MapCamera camera, bool byGesture) {
    _camera = camera.center;
    final q = _query;
    if (!byGesture || q == null) return;
    final far = const ll.Distance().as(ll.LengthUnit.Meter, camera.center, ll.LatLng(q.lat, q.lng)) > _searchThresholdM;
    if (far != _moved) setState(() => _moved = far);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query;
    final pins = q == null ? null : ref.watch(mapPinsProvider(q));
    final list = (pins?.value ?? const <EventSummary>[]).where((e) => e.lat != null && e.lng != null).toList();
    final selected = list.isEmpty ? null : list.firstWhere((e) => e.id == _selected, orElse: () => list.first);
    final signedIn = ref.watch(sessionProvider).value != null;
    final booked = signedIn ? {for (final t in ref.watch(ticketsProvider(TicketScope.upcoming)).value ?? const <Ticket>[]) t.booking.eventId} : <String>{};
    final config = ref.watch(appConfigProvider);
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: q == null
          ? SafeArea(child: Skeleton.page())
          : Stack(children: [
              Positioned.fill(
                child: FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: ll.LatLng(q.lat, q.lng),
                    initialZoom: 13.5,
                    onPositionChanged: (camera, byGesture) => _onMoved(camera, byGesture),
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    TileLayer(urlTemplate: config.mapTileUrl, userAgentPackageName: config.mapUserAgentPackage, tileProvider: ref.watch(mapTileProvider)),
                    MarkerLayer(markers: [
                      if (_me != null)
                        Marker(
                          point: _me!,
                          width: 22,
                          height: 22,
                          child: Container(key: const Key('map-me'), decoration: BoxDecoration(color: const Color(0xFF2F6BFF), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3))),
                        ),
                      // The selected pin is added last so it draws on top.
                      for (final e in [...list.where((e) => e != selected), ?selected])
                        Marker(
                          point: ll.LatLng(e.lat!, e.lng!),
                          width: 96,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            key: Key('pin-${e.id}'),
                            onTap: () => setState(() => _selected = e.id),
                            child: PricePin(label: pinLabel(e, booked), selected: e == selected, booked: booked.contains(e.id)),
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
              Positioned(
                top: top + 8,
                left: 16,
                right: 16,
                child: Row(children: [
                  _RoundButton(key: const Key('map-back'), icon: Icons.arrow_back, onTap: () => context.canPop() ? context.pop() : context.go('/explore')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 44,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x1F1B2430), blurRadius: 8, offset: Offset(0, 2))]),
                      child: Text('${_area.area}, KL', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundButton(
                    key: const Key('map-filter'),
                    icon: Icons.tune,
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Calm.bg,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                      builder: (_) => const AreaSheet(),
                    ).then((_) {
                      // The sheet may have picked another area: search it from its centre.
                      final at = kAreas[_area.area]!;
                      if (!_area.useDevice) {
                        _controller.move(ll.LatLng(at.lat, at.lng), _controller.camera.zoom);
                        setState(() {
                          _query = _queryAt(at.lat, at.lng);
                          _moved = false;
                        });
                      }
                    }),
                  ),
                ]),
              ),
              Positioned(top: top + 60, left: 0, right: 0, child: MapChips(selected: _chip, onSelect: _pick)),
              if (_moved)
                Positioned(
                  top: top + 108,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      key: const Key('map-search-area'),
                      onTap: _searchHere,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x2E1B2430), blurRadius: 8, offset: Offset(0, 2))]),
                        child: const Text('Search this area', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Calm.acc)),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 16, 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: Colors.white70,
                        child: const Text('© OpenStreetMap contributors', key: Key('map-attribution'), style: TextStyle(fontSize: 10.5, color: Calm.mut)),
                      ),
                      const Spacer(),
                      _RoundButton(key: const Key('map-locate'), icon: Icons.my_location, onTap: _locate),
                    ]),
                  ),
                  MapEventCard(event: selected, count: list.length),
                ]),
              ),
            ]),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x2E1B2430), blurRadius: 8, offset: Offset(0, 2))]),
          child: Icon(icon, size: 22, color: Calm.ink),
        ),
      );
}
