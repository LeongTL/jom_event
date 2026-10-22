import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

typedef LatLng = ({double lat, double lng});

// shortcut: a copy of the events.areas table (six areas); read the table instead if areas ever change.
const kAreas = <String, LatLng>{
  'Bangsar': (lat: 3.1290, lng: 101.6710),
  'KLCC': (lat: 3.1579, lng: 101.7116),
  'PJ': (lat: 3.1073, lng: 101.6067),
  'Sri Hartamas': (lat: 3.1634, lng: 101.6500),
  'Mid Valley': (lat: 3.1177, lng: 101.6770),
  'Bukit Bintang': (lat: 3.1466, lng: 101.7107),
};

/// Which area and radius Home searches. Starts on the phone's location (when allowed), Bangsar and 5 km;
/// picking an area in the sheet stops using the phone.
typedef AreaSelection = ({String area, int km, bool useDevice});

class AreaSelectionController extends Notifier<AreaSelection> {
  @override
  AreaSelection build() => (area: 'Bangsar', km: 5, useDevice: true);

  void choose(String area, int km) => state = (area: area, km: km, useDevice: false);
}

final areaSelectionProvider = NotifierProvider<AreaSelectionController, AreaSelection>(AreaSelectionController.new);

/// The phone's position, or null when permission is refused or no fix arrives. Tests override it.
final deviceLocationProvider = Provider<Future<LatLng?> Function()>((ref) => _geolocate);

Future<LatLng?> _geolocate() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 8)),
    );
    return (lat: p.latitude, lng: p.longitude);
  } catch (_) {
    return null; // no GPS, no service or a timeout: the selected area stands in
  }
}

double _round2(double v) => (v * 100).round() / 100;

/// Where Home searches from: the phone's position rounded to 0.01 degrees (about 1 km), or the selected area's
/// centre when the phone cannot say. Used only as the feed query's lat/lng; never stored.
Future<LatLng> coarseLocation(Ref ref) async {
  final sel = ref.watch(areaSelectionProvider);
  if (sel.useDevice) {
    final p = await ref.read(deviceLocationProvider)();
    if (p != null) return (lat: _round2(p.lat), lng: _round2(p.lng));
  }
  return kAreas[sel.area]!;
}

final homeCentreProvider = FutureProvider<LatLng>(coarseLocation);
