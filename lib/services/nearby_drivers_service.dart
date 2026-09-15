import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/uber_map_markers.dart';

class NearbyDriversService {
  static final NearbyDriversService _instance = NearbyDriversService._internal();
  factory NearbyDriversService() => _instance;
  NearbyDriversService._internal();

  /// Fetch real online active drivers from the database by GPS coordinates
  Future<List<NearbyCab>> fetchNearbyDrivers(LatLng center, {double radiusKm = 50.0}) async {
    try {
      final url = Uri.parse(
        "${ApiConfig.baseUrl}/get_nearby_drivers.php?lat=${center.latitude}&lng=${center.longitude}&radius=$radiusKm",
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['drivers'] is List) {
          final List driversList = data['drivers'];
          final List<NearbyCab> realCabs = [];

          for (int i = 0; i < driversList.length; i++) {
            final d = driversList[i];
            final double lat = (d['latitude'] as num).toDouble();
            final double lng = (d['longitude'] as num).toDouble();
            final String id = d['id']?.toString() ?? "real_driver_$i";
            final String name = d['name']?.toString() ?? "Active Driver";
            final String vType = d['vehicle_type']?.toString() ?? "Cab";

            // Bearing
            final double heading = (math.Random(lat.toInt() + lng.toInt()).nextDouble() * 360);

            realCabs.add(
              NearbyCab(
                id: id,
                position: LatLng(lat, lng),
                heading: heading,
                isReal: true,
                driverName: name,
                vehicleType: vType,
              ),
            );
          }
          return realCabs;
        }
      }
    } catch (e) {
      debugPrint("Fetch nearby real drivers error: $e");
    }

    // Return empty list if no real drivers are online in the area (NO FAKE DATA)
    return [];
  }
}
