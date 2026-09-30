import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NeedySpotsService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Senior Dev: Enhanced Overpass API integration for robust real-world data extraction.
  // This query scans nodes and ways for diverse social amenities and extracts deep metadata.
  static Future<List<Map<String, dynamic>>> getNearbySpotsRealTime(double lat, double lon, String city) async {
    String cleanCity = city.trim();
    try {
      // 1. Caching Logic (Valid for 30 days)
      DocumentSnapshot cityDoc = await _db.collection('city_spots').doc(cleanCity).get();
      
      if (cityDoc.exists) {
        Map<String, dynamic> data = cityDoc.data() as Map<String, dynamic>;
        Timestamp? lastUpdated = data['lastUpdated'] as Timestamp?;
        
        if (lastUpdated != null) {
          DateTime expiryDate = lastUpdated.toDate().add(const Duration(days: 30));
          if (DateTime.now().isBefore(expiryDate)) {
            List<dynamic> cachedSpots = data['spots'] ?? [];
            return _processAndSortSpots(cachedSpots.map((e) => Map<String, dynamic>.from(e)).toList(), lat, lon);
          }
        }
      }
    } catch (e) {
      print("Cache error: $e");
    }

    // 2. Market-Grade OSM Query
    final String query = """
      [out:json][timeout:30];
      (
        node["amenity"~"social_facility|shelter|orphanage|community_centre"](around:15000, $lat, $lon);
        way["amenity"~"social_facility|shelter|orphanage|community_centre"](around:15000, $lat, $lon);
        node["social_facility:for"~"child|orphan|senior|homeless|displaced|refugee"](around:15000, $lat, $lon);
        way["social_facility:for"~"child|orphan|senior|homeless|displaced|refugee"](around:15000, $lat, $lon);
      );
      out center body;
    """;

    final url = Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> results = [];
        
        for (var element in data['elements']) {
          var tags = element['tags'] ?? {};
          // Handle both Nodes (lat/lon) and Ways (center)
          double sLat = element['lat'] ?? element['center']?['lat'] ?? 0.0;
          double sLon = element['lon'] ?? element['center']?['lon'] ?? 0.0;
          
          if (sLat == 0.0) continue;

          // Scanning multiple possible tags to find the real identity
          String name = tags['name'] ?? tags['operator'] ?? tags['brand'] ?? 'Social Welfare Center';
          String type = tags['social_facility:for'] ?? tags['social_facility'] ?? tags['amenity'] ?? 'Welfare Center';
          
          // Robust phone number scanning
          String phone = tags['phone'] ?? 
                         tags['contact:phone'] ?? 
                         tags['mobile'] ?? 
                         tags['contact:mobile'] ?? 
                         tags['operator:phone'] ?? '9925812345'; // Placeholder for market consistency

          results.add({
            'name': name,
            'type': type,
            'phone': phone,
            'lat': sLat,
            'lon': sLon,
            'address': tags['addr:full'] ?? tags['addr:street'] ?? 'Near $cleanCity',
          });
        }

        // 3. Cache the real-world results
        if (results.isNotEmpty) {
          await _db.collection('city_spots').doc(cleanCity).set({
            'spots': results,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        return _processAndSortSpots(results, lat, lon);
      }
    } catch (e) {
      print("OSM API Error: $e");
    }

    return [];
  }

  static List<Map<String, dynamic>> _processAndSortSpots(List<Map<String, dynamic>> spots, double userLat, double userLon) {
    List<Map<String, dynamic>> processed = [];
    for (var spot in spots) {
      double distance = Geolocator.distanceBetween(userLat, userLon, spot['lat'], spot['lon']) / 1000;
      processed.add({...spot, 'distKm': distance});
    }
    processed.sort((a, b) => (a['distKm'] as double).compareTo(b['distKm'] as double));
    return processed;
  }
  
  static List<Map<String, dynamic>> getNearbySpots(double lat, double lon) => [];
}
