import '../../../core/location.dart';

/// Where Home looks: the centre and radius from the area selection.
typedef HomeArea = ({double lat, double lng, int km});

/// The Near-you question: the area plus the category tile and the search text.
typedef HomeQuery = ({
  double lat,
  double lng,
  int km,
  String? category,
  String query,
});

/// "Today in Bangsar" until 17:00 in Kuala Lumpur, "Tonight in Bangsar" from then on.
String homeTitle(DateTime now, String area) =>
    '${now.toUtc().add(const Duration(hours: 8)).hour < 17 ? 'Today' : 'Tonight'} in $area';

LatLng centreOf(HomeArea a) => (lat: a.lat, lng: a.lng);
