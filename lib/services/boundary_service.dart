import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class BoundaryService {
  static final BoundaryService _instance = BoundaryService._internal();
  factory BoundaryService() => _instance;
  BoundaryService._internal();

  List<Map<String, dynamic>> majorCities = [
    {"name": "Pune", "minLat": 18.4100, "maxLat": 18.6500, "minLng": 73.7200, "maxLng": 73.9800},
    {"name": "Mumbai", "minLat": 18.8900, "maxLat": 19.3000, "minLng": 72.7500, "maxLng": 73.2000},
    {"name": "Nashik", "minLat": 19.9000, "maxLat": 20.1000, "minLng": 73.7000, "maxLng": 73.8800},
    {"name": "Nagpur", "minLat": 21.0500, "maxLat": 21.2200, "minLng": 79.0000, "maxLng": 79.1800},
    {"name": "Aurangabad", "minLat": 19.8200, "maxLat": 19.9500, "minLng": 75.2500, "maxLng": 75.4200},
    {"name": "Kolhapur", "minLat": 16.6500, "maxLat": 16.7500, "minLng": 74.2000, "maxLng": 74.2800},
    {"name": "Solapur", "minLat": 17.6200, "maxLat": 17.7200, "minLng": 75.8500, "maxLng": 75.9500},
  ];

  bool _hasFetched = false;

  Future<void> fetchCityBoundaries() async {
    if (_hasFetched) return;
    try {
      final response = await http.get(Uri.parse(
          'https://agnicarrental.com/admin2025/api_city_boundary.php?action=get_active_boundaries'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['cities'] != null) {
          majorCities = List<Map<String, dynamic>>.from(data['cities']);
          _hasFetched = true;
          debugPrint('BoundaryService: Loaded ${majorCities.length} active boundaries.');
        }
      }
    } catch (e) {
      debugPrint('BoundaryService Error: $e');
    }
  }

  bool isPointInPolygon(LatLng point, String polygonCoordsJson) {
    if (polygonCoordsJson.isEmpty) return true; // Fallback to bounding box only
    try {
      final List<dynamic> coords = jsonDecode(polygonCoordsJson);
      if (coords.isEmpty) return true;

      final List<LatLng> polygon = coords.map((c) {
        return LatLng(
          double.parse(c['lat'].toString()),
          double.parse(c['lng'].toString()),
        );
      }).toList();

      int i, j = polygon.length - 1;
      bool oddNodes = false;
      double x = point.longitude;
      double y = point.latitude;

      for (i = 0; i < polygon.length; i++) {
        if ((polygon[i].latitude < y && polygon[j].latitude >= y ||
                polygon[j].latitude < y && polygon[i].latitude >= y) &&
            (polygon[i].longitude +
                    (y - polygon[i].latitude) /
                        (polygon[j].latitude - polygon[i].latitude) *
                        (polygon[j].longitude - polygon[i].longitude) <
                x)) {
          oddNodes = !oddNodes;
        }
        j = i;
      }
      return oddNodes;
    } catch (e) {
      debugPrint("BoundaryService polygon check error: $e");
      return true; // Fallback to bounding box check
    }
  }

  Map<String, dynamic>? detectCity(LatLng point, String address) {
    for (var city in majorCities) {
      final double minLat = double.parse(city["minLat"].toString());
      final double maxLat = double.parse(city["maxLat"].toString());
      final double minLng = double.parse(city["minLng"].toString());
      final double maxLng = double.parse(city["maxLng"].toString());

      bool withinCoords = (point.latitude >= minLat && point.latitude <= maxLat) &&
                           (point.longitude >= minLng && point.longitude <= maxLng);
      bool containsName = address.toLowerCase().contains(city["name"].toString().toLowerCase());
      if (withinCoords || containsName) {
        String polygonCoordsJson = city["polygonCoords"]?.toString() ?? "";
        if (withinCoords && !isPointInPolygon(point, polygonCoordsJson)) {
          continue; // Point is outside the polygon boundary!
        }
        return city;
      }
    }
    return null;
  }

  bool isPointInCity(LatLng point, String address, Map<String, dynamic> city) {
    final double minLat = double.parse(city["minLat"].toString());
    final double maxLat = double.parse(city["maxLat"].toString());
    final double minLng = double.parse(city["minLng"].toString());
    final double maxLng = double.parse(city["maxLng"].toString());

    bool withinCoords = (point.latitude >= minLat && point.latitude <= maxLat) &&
                         (point.longitude >= minLng && point.longitude <= maxLng);
    bool containsName = address.toLowerCase().contains(city["name"].toString().toLowerCase());
    if (withinCoords || containsName) {
      String polygonCoordsJson = city["polygonCoords"]?.toString() ?? "";
      if (withinCoords && !isPointInPolygon(point, polygonCoordsJson)) {
        return false; // Point is outside the polygon boundary!
      }
      return true;
    }
    return false;
  }
}
