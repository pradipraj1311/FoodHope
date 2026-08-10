import 'package:geolocator/geolocator.dart';

class NeedySpot {
  final String name;
  final double lat;
  final double lon;
  final String type; // 'Labor Colony', 'Orphanage', 'Old Age Home'
  final int capacity;
  final String phone; // NEW: Added phone number

  NeedySpot({required this.name, required this.lat, required this.lon, required this.type, required this.capacity, required this.phone});
}

class NeedySpotsService {
  // Mock Data (Expanded with real-world-style contact numbers)
  static final List<NeedySpot> _allSpots = [
    NeedySpot(name: 'Metro Site Labor Camp', lat: 22.705, lon: 72.870, type: 'Labor Colony', capacity: 150, phone: '9876543210'),
    NeedySpot(name: 'Shanti Nagar Labor Colony', lat: 22.695, lon: 72.858, type: 'Labor Colony', capacity: 220, phone: '8765432109'),
    NeedySpot(name: 'Sunrise Orphanage', lat: 22.712, lon: 72.865, type: 'Orphanage', capacity: 45, phone: '7654321098'),
    NeedySpot(name: 'Grace Children\'s Home', lat: 22.688, lon: 72.842, type: 'Orphanage', capacity: 30, phone: '6543210987'),
    NeedySpot(name: 'Golden Years Old Age Home', lat: 22.720, lon: 72.880, type: 'Old Age Home', capacity: 60, phone: '9012345678'),
    NeedySpot(name: 'Peaceful Living Shelter', lat: 22.675, lon: 72.830, type: 'Old Age Home', capacity: 40, phone: '8123456789'),
    NeedySpot(name: 'City Bridge Underpass Shelter', lat: 22.700, lon: 72.860, type: 'Labor Colony', capacity: 100, phone: '7234567890'),
  ];

  static List<Map<String, dynamic>> getNearbySpots(double userLat, double userLon) {
    List<Map<String, dynamic>> nearby = [];
    
    for (var spot in _allSpots) {
      double distance = Geolocator.distanceBetween(userLat, userLon, spot.lat, spot.lon) / 1000;
      if (distance < 20.0) { // Within 20km
        nearby.add({
          'name': spot.name,
          'lat': spot.lat,
          'lon': spot.lon,
          'type': spot.type,
          'capacity': spot.capacity,
          'phone': spot.phone,
          'distKm': distance,
        });
      }
    }
    // Sort by proximity
    nearby.sort((a, b) => (a['distKm'] as double).compareTo(b['distKm'] as double));
    return nearby;
  }
}
