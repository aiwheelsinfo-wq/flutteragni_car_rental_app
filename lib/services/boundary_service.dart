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

    // 1. Try primary 2025 backend endpoint
    try {
      final response = await http.get(Uri.parse(
          'https://agnicarrental.com/2025/get_city_boundaries.php?action=active_only'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['cities'] != null) {
          final List<dynamic> rawList = data['cities'];
          final parsed = rawList.map<Map<String, dynamic>>((c) {
            final name = (c['city_name'] ?? c['name'] ?? '').toString();
            final minLat = double.tryParse((c['min_lat'] ?? c['minLat'] ?? 0).toString()) ?? 0.0;
            final maxLat = double.tryParse((c['max_lat'] ?? c['maxLat'] ?? 0).toString()) ?? 0.0;
            final minLng = double.tryParse((c['min_lng'] ?? c['minLng'] ?? 0).toString()) ?? 0.0;
            final maxLng = double.tryParse((c['max_lng'] ?? c['maxLng'] ?? 0).toString()) ?? 0.0;
            final poly = c['polygon_coords'] ?? c['polygonCoords'];
            final status = (c['status'] ?? 'active').toString();
            return {
              'name': name,
              'city_name': name,
              'minLat': minLat,
              'min_lat': minLat,
              'maxLat': maxLat,
              'max_lat': maxLat,
              'minLng': minLng,
              'min_lng': minLng,
              'maxLng': maxLng,
              'max_lng': maxLng,
              'polygonCoords': poly is String ? poly : jsonEncode(poly),
              'polygon_coords': poly,
              'status': status,
            };
          }).where((c) => c['status'].toString().toLowerCase() == 'active').toList();

          if (parsed.isNotEmpty) {
            majorCities = parsed;
            _hasFetched = true;
            debugPrint('BoundaryService: Loaded ${majorCities.length} active boundaries from 2025 API.');
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('BoundaryService 2025 API error: $e');
    }

    // 2. Fallback to admin2025 API
    try {
      final response = await http.get(Uri.parse(
          'https://agnicarrental.com/admin2025/api_city_boundary.php?action=get_active_boundaries'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['cities'] != null) {
          final List<dynamic> rawList = data['cities'];
          majorCities = rawList.map<Map<String, dynamic>>((c) {
            final name = (c['name'] ?? c['city_name'] ?? '').toString();
            final minLat = double.tryParse((c['minLat'] ?? c['min_lat'] ?? 0).toString()) ?? 0.0;
            final maxLat = double.tryParse((c['maxLat'] ?? c['max_lat'] ?? 0).toString()) ?? 0.0;
            final minLng = double.tryParse((c['minLng'] ?? c['min_lng'] ?? 0).toString()) ?? 0.0;
            final maxLng = double.tryParse((c['maxLng'] ?? c['max_lng'] ?? 0).toString()) ?? 0.0;
            final poly = c['polygonCoords'] ?? c['polygon_coords'];
            return {
              'name': name,
              'city_name': name,
              'minLat': minLat,
              'min_lat': minLat,
              'maxLat': maxLat,
              'max_lat': maxLat,
              'minLng': minLng,
              'min_lng': minLng,
              'maxLng': maxLng,
              'max_lng': maxLng,
              'polygonCoords': poly is String ? poly : jsonEncode(poly),
              'polygon_coords': poly,
              'status': 'active',
            };
          }).toList();
          _hasFetched = true;
          debugPrint('BoundaryService: Loaded ${majorCities.length} active boundaries from admin2025 API.');
        }
      }
    } catch (e) {
      debugPrint('BoundaryService Admin API error: $e');
    }
  }

  List<LatLng> getPolygonPoints(Map<String, dynamic> city) {
    dynamic raw = city['polygon_coords'] ?? city['polygonCoords'];
    if (raw != null) {
      try {
        List<dynamic> coords;
        if (raw is String && raw.trim().isNotEmpty && raw != 'null') {
          coords = jsonDecode(raw);
        } else if (raw is List) {
          coords = raw;
        } else {
          coords = [];
        }

        final List<LatLng> points = coords.map((c) {
          final lat = c['lat'] ?? c['latitude'] ?? (c is List && c.isNotEmpty ? c[0] : 0);
          final lng = c['lng'] ?? c['longitude'] ?? (c is List && c.length > 1 ? c[1] : 0);
          return LatLng(
            double.parse(lat.toString()),
            double.parse(lng.toString()),
          );
        }).toList();

        if (points.isNotEmpty) return points;
      } catch (e) {
        debugPrint("Error parsing polygonCoords for ${city['name']}: $e");
      }
    }

    // Fallback: Rectangle boundary from minLat, maxLat, minLng, maxLng
    try {
      final double minLat = double.parse((city["minLat"] ?? city["min_lat"]).toString());
      final double maxLat = double.parse((city["maxLat"] ?? city["max_lat"]).toString());
      final double minLng = double.parse((city["minLng"] ?? city["min_lng"]).toString());
      final double maxLng = double.parse((city["maxLng"] ?? city["max_lng"]).toString());

      return [
        LatLng(minLat, minLng),
        LatLng(maxLat, minLng),
        LatLng(maxLat, maxLng),
        LatLng(minLat, maxLng),
      ];
    } catch (e) {
      debugPrint("Error creating bounding box for ${city['name']}: $e");
      return [];
    }
  }

  bool isPointInPolygon(LatLng point, dynamic polygonCoords) {
    if (polygonCoords == null) return true;
    try {
      List<dynamic> coords;
      if (polygonCoords is String) {
        if (polygonCoords.trim().isEmpty || polygonCoords == 'null') return true;
        coords = jsonDecode(polygonCoords);
      } else if (polygonCoords is List) {
        coords = polygonCoords;
      } else {
        return true;
      }
      if (coords.isEmpty) return true;

      final List<LatLng> polygon = coords.map((c) {
        final lat = c['lat'] ?? c['latitude'] ?? (c is List && c.isNotEmpty ? c[0] : 0);
        final lng = c['lng'] ?? c['longitude'] ?? (c is List && c.length > 1 ? c[1] : 0);
        return LatLng(
          double.parse(lat.toString()),
          double.parse(lng.toString()),
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
      return true;
    }
  }

  Map<String, dynamic>? detectCity(LatLng point, String address) {
    bool hasValidPoint = point.latitude != 0.0 && point.longitude != 0.0;

    for (var city in majorCities) {
      final double minLat = double.parse((city["minLat"] ?? city["min_lat"]).toString());
      final double maxLat = double.parse((city["maxLat"] ?? city["max_lat"]).toString());
      final double minLng = double.parse((city["minLng"] ?? city["min_lng"]).toString());
      final double maxLng = double.parse((city["maxLng"] ?? city["max_lng"]).toString());

      if (hasValidPoint) {
        bool withinBoundingBox = (point.latitude >= minLat && point.latitude <= maxLat) &&
                                 (point.longitude >= minLng && point.longitude <= maxLng);
        if (!withinBoundingBox) {
          continue; // Strictly outside this city's bounding box
        }
        dynamic poly = city["polygonCoords"] ?? city["polygon_coords"];
        if (poly != null && !isPointInPolygon(point, poly)) {
          continue; // Outside city's polygon
        }
        return city;
      } else {
        // Fallback to name search only if no valid GPS coordinates are available
        final cityName = (city["name"] ?? city["city_name"] ?? '').toString().toLowerCase();
        if (cityName.isNotEmpty && address.toLowerCase().contains(cityName)) {
          return city;
        }
      }
    }
    return null;
  }

  bool isPointInCity(LatLng point, String address, Map<String, dynamic> city) {
    bool hasValidPoint = point.latitude != 0.0 && point.longitude != 0.0;
    final double minLat = double.parse((city["minLat"] ?? city["min_lat"]).toString());
    final double maxLat = double.parse((city["maxLat"] ?? city["max_lat"]).toString());
    final double minLng = double.parse((city["minLng"] ?? city["min_lng"]).toString());
    final double maxLng = double.parse((city["maxLng"] ?? city["max_lng"]).toString());

    if (hasValidPoint) {
      bool withinBoundingBox = (point.latitude >= minLat && point.latitude <= maxLat) &&
                               (point.longitude >= minLng && point.longitude <= maxLng);
      if (!withinBoundingBox) return false;
      dynamic poly = city["polygonCoords"] ?? city["polygon_coords"];
      if (poly != null && !isPointInPolygon(point, poly)) return false;
      return true;
    } else {
      final cityName = (city["name"] ?? city["city_name"] ?? '').toString().toLowerCase();
      return cityName.isNotEmpty && address.toLowerCase().contains(cityName);
    }
  }

  String getServicedCityNames() {
    final names = majorCities
        .map((c) => (c["name"] ?? c["city_name"] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    return names.isNotEmpty
        ? names.join(', ')
        : 'Mumbai, Pune, Nashik, Aurangabad, Kolhapur, Solapur, Nagpur, Irulam';
  }
}
