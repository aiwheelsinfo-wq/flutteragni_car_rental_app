import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

// Import your existing pages
import 'OneWayRegistration.dart';
import 'localTaxycustomer_reg.dart';
import 'package:agni_car_rental/config/api_config.dart';

class LocalTaxi extends StatefulWidget {
  final String? initialFrom;
  final String? initialTo;
  final LatLng? initialFromLatLng;
  final LatLng? initialToLatLng;

  const LocalTaxi({
    Key? key,
    this.initialFrom,
    this.initialTo,
    this.initialFromLatLng,
    this.initialToLatLng,
  }) : super(key: key);

  @override
  _LocalTaxiState createState() => _LocalTaxiState();
}

class _LocalTaxiState extends State<LocalTaxi> {
  // Logic Variables
  TextEditingController fromController = TextEditingController();
  TextEditingController toController = TextEditingController();
  TextEditingController distanceController = TextEditingController();

  String selectedCar = "";
  late GoogleMapController mapController;
  Set<Polyline> polylines = {};
  Set<Marker> markers = {};
  LatLng? fromLatLng;
  LatLng? toLatLng;

  List<Map<String, dynamic>> carFares = [];
  double? kmLimit;
  double? currentCalculatedDistance;
  String tripDuration = "";

  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  String fullAddress = "";
  bool serviceAvailable = true;
  bool showCarSection = false;
  bool showLoading = false;
  bool isGettingLocation = false;
  String apiKey = "";

  FocusNode fromFocusNode = FocusNode();
  FocusNode toFocusNode = FocusNode();

  // Color Palette
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color secondaryYellow = const Color(0xFFFFD54F);
  final Color darkCanvas = const Color(0xFF212121);
  final Color lightBg = const Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    fetchApiKey();
    _fetchCityBoundaries();

    // Check if initial parameters were passed
    if (widget.initialFrom != null) {
      fromController.text = widget.initialFrom!;
      fullAddress = widget.initialFrom!;
      fromLatLng = widget.initialFromLatLng;
      if (fromLatLng != null) {
        markers.add(Marker(
          markerId: const MarkerId("from"),
          position: fromLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ));
      }
    } else {
      _getCurrentLocation();
    }

    if (widget.initialTo != null) {
      toController.text = widget.initialTo!;
      toLatLng = widget.initialToLatLng;
      if (toLatLng != null) {
        markers.add(Marker(
          markerId: const MarkerId("to"),
          position: toLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ));
      }
    }

    if (fromLatLng != null && toLatLng != null) {
      _calculateDistance();
    }

    fromController.addListener(_onFromChanged);
    toController.addListener(_onToChanged);
  }

  void _onFromChanged() {
    if (fromController.text.isNotEmpty && toController.text.isNotEmpty) {
      _triggerSearchLogic();
    }
  }

  void _onToChanged() {
    if (fromController.text.isNotEmpty && toController.text.isNotEmpty) {
      _triggerSearchLogic();
    }
  }

  void _triggerSearchLogic() {
    setState(() => showLoading = true);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          showLoading = false;
          showCarSection = true;
        });
      }
    });
  }

  Future<void> fetchApiKey() async {
    try {
      final response = await http.get(Uri.parse(
          'https://agnicarrental.com/api_key/api.php?token=mySecretToken123'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => apiKey = data['apiKey']);
        if (fromLatLng != null && toLatLng != null) {
          _calculateDistance();
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => isGettingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String currentAddress =
            "${place.name}, ${place.locality}, ${place.administrativeArea}";
        setState(() {
          isGettingLocation = false;
          fromController.text = currentAddress;
          fullAddress = currentAddress;
          fromLatLng = LatLng(position.latitude, position.longitude);
          markers.add(Marker(
            markerId: const MarkerId("from"),
            position: fromLatLng!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
          ));
        });
      }
    } catch (e) {
      setState(() => isGettingLocation = false);
    }
  }

  Future<void> _calculateDistance() async {
    if (fromLatLng == null || toLatLng == null || apiKey.isEmpty) return;

    const String url =
        "https://routes.googleapis.com/directions/v2:computeRoutes";

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              "Content-Type": "application/json",
              "X-Goog-Api-Key": apiKey,
              "X-Goog-FieldMask":
                  "routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline"
            },
            body: jsonEncode({
              "origin": {
                "location": {
                  "latLng": {
                    "latitude": fromLatLng!.latitude,
                    "longitude": fromLatLng!.longitude
                  }
                }
              },
              "destination": {
                "location": {
                  "latLng": {
                    "latitude": toLatLng!.latitude,
                    "longitude": toLatLng!.longitude
                  }
                }
              },
              "travelMode": "DRIVE"
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception("API Error: ${response.statusCode}");
      }

      final data = jsonDecode(response.body);

      if (data["routes"] == null || data["routes"].isEmpty) {
        throw Exception("No routes found");
      }

      final route = data["routes"][0];

      double distanceInKm = (route["distanceMeters"] ?? 0) / 1000;

      String durationText = "";
      if (route["duration"] != null) {
        String durRaw = route["duration"].toString().replaceAll("s", "");
        int totalSecs = int.tryParse(durRaw) ?? 0;
        int mins = (totalSecs / 60).round();
        if (mins >= 60) {
          int hrs = mins ~/ 60;
          int remainingMins = mins % 60;
          durationText = remainingMins > 0 ? "$hrs hr $remainingMins min" : "$hrs hr";
        } else if (mins > 0) {
          durationText = "$mins mins";
        }
      }

      String encodedPolyline = route["polyline"]?["encodedPolyline"] ?? "";

      List<LatLng> points = _decodePolyline(encodedPolyline);

      setState(() {
        currentCalculatedDistance = distanceInKm;
        tripDuration = durationText;
        distanceController.text = "${distanceInKm.toStringAsFixed(1)} km";
        serviceAvailable = distanceInKm <= 80;
        showCarSection = true;

        polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            points: points,
            color: Colors.black,
            width: 4,
          )
        };
      });

      if (serviceAvailable) {
        await _fetchAndCompareFares(distanceInKm);
      }

      _fitMap();
    } catch (e) {
      debugPrint("Distance Error: $e");
    }
  }

  void _fitMap() {
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
          fromLatLng!.latitude < toLatLng!.latitude
              ? fromLatLng!.latitude
              : toLatLng!.latitude,
          fromLatLng!.longitude < toLatLng!.longitude
              ? fromLatLng!.longitude
              : toLatLng!.longitude),
      northeast: LatLng(
          fromLatLng!.latitude > toLatLng!.latitude
              ? fromLatLng!.latitude
              : toLatLng!.latitude,
          fromLatLng!.longitude > toLatLng!.longitude
              ? fromLatLng!.longitude
              : toLatLng!.longitude),
    );
    mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  Future<void> _fetchAndCompareFares(double distance) async {
    setState(() => showLoading = true);
    try {
      final now = DateTime.now();
      final timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      final uri = Uri.parse(
          "${ApiConfig.baseUrl}/selectCarCostList.php?tripType=Local%20Taxi&distance=${distance.toStringAsFixed(2)}&pickupTime=$timeStr");

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        if (decoded is List) {
          List<Map<String, dynamic>> parsedFares = [];
          for (var item in decoded) {
            final carType = item['carType']?.toString() ?? '';
            final discountedPrice =
                double.tryParse(item['discounted_price']?.toString() ?? '0') ??
                    0.0;
            final baseAmount =
                double.tryParse(item['baseAmount']?.toString() ?? '0') ??
                    discountedPrice;
            final discountPct = item['discount_percentage'] ?? 0;
            final kmRate = item['kmRate']?.toString() ?? '';
            final gstPercent = item['gstPercent']?.toString() ?? '5';

            final timeSurcharges =
                item['time_surcharges'] as Map<String, dynamic>?;
            final appliedLabels =
                (timeSurcharges?['applied_labels'] as List<dynamic>?) ?? [];
            String surgeTag = "";
            if (appliedLabels.isNotEmpty) {
              surgeTag = appliedLabels.first.toString();
            } else if (timeSurcharges?['is_peak'] == true) {
              surgeTag = "Peak Rush";
            } else if (timeSurcharges?['is_night'] == true) {
              surgeTag = "Night Surge";
            }

            parsedFares.add({
              "car_type": carType,
              "original_price": baseAmount,
              "discounted_price": discountedPrice,
              "discount_percent": discountPct,
              "surge_tag": surgeTag,
              "km_rate": kmRate,
              "gst_percent": gstPercent,
            });
          }

          setState(() {
            carFares = parsedFares;
            currentCalculatedDistance = distance;
            if (parsedFares.isNotEmpty &&
                (selectedCar.isEmpty ||
                    !parsedFares.any((c) => c["car_type"] == selectedCar))) {
              selectedCar = parsedFares.first["car_type"];
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Dynamic Local Taxi fare fetch error: $e");
    } finally {
      if (mounted) {
        setState(() => showLoading = false);
      }
    }
  }

  IconData _getCarIcon(String carType) {
    final lower = carType.toLowerCase();
    if (lower.contains('sedan')) {
      return Icons.directions_car;
    } else if (lower.contains('suv') ||
        lower.contains('crysta') ||
        lower.contains('innova') ||
        lower.contains('ertiga')) {
      return Icons.airport_shuttle;
    }
    return Icons.directions_car_outlined;
  }

  final String yellowMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#fef7e0"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#7c6f00"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffd54f"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#ffca28"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#ffe099"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]}
]
''';

  List<Map<String, dynamic>> majorCities = [
    {"name": "Pune", "minLat": 18.4100, "maxLat": 18.6500, "minLng": 73.7200, "maxLng": 73.9800},
    {"name": "Mumbai", "minLat": 18.8900, "maxLat": 19.3000, "minLng": 72.7500, "maxLng": 73.2000},
    {"name": "Nashik", "minLat": 19.9000, "maxLat": 20.1000, "minLng": 73.7000, "maxLng": 73.8800},
    {"name": "Nagpur", "minLat": 21.0500, "maxLat": 21.2200, "minLng": 79.0000, "maxLng": 79.1800},
    {"name": "Aurangabad", "minLat": 19.8200, "maxLat": 19.9500, "minLng": 75.2500, "maxLng": 75.4200},
    {"name": "Kolhapur", "minLat": 16.6500, "maxLat": 16.7500, "minLng": 74.2000, "maxLng": 74.2800},
    {"name": "Solapur", "minLat": 17.6200, "maxLat": 17.7200, "minLng": 75.8500, "maxLng": 75.9500},
  ];

  Future<void> _fetchCityBoundaries() async {
    try {
      final response = await http.get(Uri.parse(
          'https://agnicarrental.com/admin2025/api_city_boundary.php?action=get_active_boundaries'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['cities'] != null) {
          setState(() {
            majorCities = List<Map<String, dynamic>>.from(data['cities']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching city boundaries: $e');
    }
  }

  bool _isPointInPolygon(LatLng point, String polygonCoordsJson) {
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
      debugPrint("Error checking point in polygon: $e");
      return true; // Fallback to bounding box check
    }
  }

  Map<String, dynamic>? _detectCity(LatLng point, String address) {
    for (var city in majorCities) {
      bool withinCoords = (point.latitude >= city["minLat"] && point.latitude <= city["maxLat"]) &&
                           (point.longitude >= city["minLng"] && point.longitude <= city["maxLng"]);
      bool containsName = address.toLowerCase().contains(city["name"].toString().toLowerCase());
      if (withinCoords || containsName) {
        String polygonCoordsJson = city["polygonCoords"]?.toString() ?? "";
        if (withinCoords && !_isPointInPolygon(point, polygonCoordsJson)) {
          continue; // Point is outside the polygon boundary!
        }
        return city;
      }
    }
    return null;
  }

  bool _isPointInCity(LatLng point, String address, Map<String, dynamic> city) {
    bool withinCoords = (point.latitude >= city["minLat"] && point.latitude <= city["maxLat"]) &&
                         (point.longitude >= city["minLng"] && point.longitude <= city["maxLng"]);
    bool containsName = address.toLowerCase().contains(city["name"].toString().toLowerCase());
    if (withinCoords || containsName) {
      String polygonCoordsJson = city["polygonCoords"]?.toString() ?? "";
      if (withinCoords && !_isPointInPolygon(point, polygonCoordsJson)) {
        return false; // Point is outside the polygon boundary!
      }
      return true;
    }
    return false;
  }

  void _showOutsideServiceAreaDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Service Unavailable",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Text(
            "Local Cab services are only available within Pune, Mumbai, Nashik, Nagpur, Aurangabad, Kolhapur, and Solapur city limits. Your pickup location falls outside these areas. Please select One-Way or Round-Trip for your journey.",
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              child: Text(
                "OK",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFFFFB300)),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showBoundaryError(String cityName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Outside City Limits",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Text(
            "Your drop location is outside $cityName city limits. Local Taxi bookings must start and end within the same city limits. Please use our One-Way or Round-Trip service for travel outside $cityName.",
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              child: Text(
                "OK",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFFFFB300)),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _proceed() {
    if (selectedCar.isEmpty) return;
    if (fromLatLng == null) return;

    // 1. Detect which city boundary pickup lies in
    Map<String, dynamic>? detectedCity = _detectCity(fromLatLng!, fullAddress);

    if (detectedCity == null) {
      _showOutsideServiceAreaDialog();
      return;
    }

    // 2. Validate that drop address is inside the SAME city
    if (toLatLng != null && !_isPointInCity(toLatLng!, toController.text, detectedCity)) {
      _showBoundaryError(detectedCity["name"]);
      return;
    }

    var fareData = carFares.firstWhere(
      (f) => f["car_type"] == selectedCar,
      orElse: () => carFares.isNotEmpty ? carFares.first : <String, dynamic>{},
    );

    double finalAmount =
        (fareData["discounted_price"] as num?)?.toDouble() ?? 0.0;
    double tripDistance = currentCalculatedDistance ?? (kmLimit ?? 0.0);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerRegistrationPage(
          bookingData: {
            "from_address": fullAddress,
            "to_address": toController.text,
            "car_type": selectedCar,
            "total_amount": finalAmount.toStringAsFixed(0),
            "distance": tripDistance.toStringAsFixed(1),
            "from_lat": fromLatLng?.latitude.toString() ?? "",
            "from_lng": fromLatLng?.longitude.toString() ?? "",
            "to_lat": toLatLng?.latitude.toString() ?? "",
            "to_lng": toLatLng?.longitude.toString() ?? "",
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          "Book a Ride",
          style: GoogleFonts.poppins(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // 1. Map Layer
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(20.5937, 78.9629),
                zoom: 5,
              ),
              myLocationEnabled: true, // Blue dot
              myLocationButtonEnabled: true, // Location button
              zoomControlsEnabled: false,
              markers: markers,
              polylines: polylines,
              onMapCreated: (controller) {
                mapController = controller;
                mapController.setMapStyle(yellowMapStyle); // Apply yellow theme
              },
            ),
          ),

          // 2. Interaction Layer
          SafeArea(
            child: Column(
              children: [
                _buildAddressCard(),
                const Spacer(),
                if (MediaQuery.of(context).viewInsets.bottom == 0)
                  _buildBottomActionSheet(),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildAddressCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          _buildLocationInput(
              controller: fromController,
              hint: "Pickup location",
              icon: Icons.circle,
              iconColor: primaryAmber,
              focusNode: fromFocusNode,
              onLatLng: (lat, lng, desc) {
                fromLatLng = LatLng(lat, lng);
                fullAddress = desc;
                _calculateDistance();
              }),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(width: 2, height: 20, color: Colors.grey[300]),
            ),
          ),
          _buildLocationInput(
              controller: toController,
              hint: "Where to?",
              icon: Icons.location_on,
              iconColor: Colors.red,
              focusNode: toFocusNode,
              onLatLng: (lat, lng, desc) {
                toLatLng = LatLng(lat, lng);
                _calculateDistance();
              }),
          if (distanceController.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.straighten_rounded, size: 14, color: Colors.black54),
                  const SizedBox(width: 5),
                  Text(
                    "Distance: ${distanceController.text}${tripDuration.isNotEmpty ? '  •  $tripDuration' : ''}",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    required FocusNode focusNode,
    required Function(double, double, String) onLatLng,
  }) {
    if (apiKey.isEmpty) return const SizedBox();
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 15),
        Expanded(
          child: GooglePlaceAutoCompleteTextField(
            focusNode: focusNode,
            textEditingController: controller,
            googleAPIKey: apiKey,
            inputDecoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12, // top & bottom space
                horizontal: 15, // left & right space
              ),
            ),
            debounceTime: 400,
            countries: const ["IN"],
            isLatLngRequired: true,
            getPlaceDetailWithLatLng: (p) => onLatLng(
                double.parse(p.lat!), double.parse(p.lng!), p.description!),
            itemClick: (p) => controller.text = p.description!,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionSheet() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 5)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            if (showLoading)
              const CircularProgressIndicator(color: Colors.amber),
            if (!showLoading && showCarSection)
              serviceAvailable
                  ? _buildCarSelection()
                  : _buildServiceUnavailable(),
            if (!showCarSection && !showLoading)
              Text("Enter details to see available rides",
                  style: GoogleFonts.poppins(color: Colors.grey)),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildCarSelection() {
    if (carFares.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            const Icon(Icons.no_crash_outlined, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              "No vehicles available for this route.",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "Available Rides",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryAmber.withOpacity(0.5), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route_rounded, size: 13, color: Colors.amber.shade900),
                    const SizedBox(width: 4),
                    Text(
                      distanceController.text.isNotEmpty
                          ? distanceController.text
                          : "${(currentCalculatedDistance ?? 0.0).toStringAsFixed(1)} km",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    if (tripDuration.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        "• $tripDuration",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 185,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: carFares.length,
            itemBuilder: (context, index) {
              var car = carFares[index];
              bool isSelected = selectedCar == car["car_type"];
              String surgeTag = car["surge_tag"]?.toString() ?? "";
              double origPrice =
                  (car["original_price"] as num?)?.toDouble() ?? 0.0;
              double discPrice =
                  (car["discounted_price"] as num?)?.toDouble() ?? 0.0;

              // Dynamic discount calculations
              bool hasDiscount = origPrice > discPrice && origPrice > 0;
              double discountAmount = hasDiscount ? (origPrice - discPrice) : 0.0;
              int discountPercent = hasDiscount
                  ? (((origPrice - discPrice) / origPrice) * 100).round()
                  : 0;

              return GestureDetector(
                onTap: () => setState(() => selectedCar = car["car_type"]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 140,
                  margin: const EdgeInsets.only(right: 12, bottom: 6, top: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryAmber : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color:
                            isSelected ? primaryAmber : Colors.grey.shade300,
                        width: 2),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: primaryAmber.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ]
                        : [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top indicator: Surge tag (if present)
                      if (surgeTag.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.black.withOpacity(0.18)
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            surgeTag.contains('+')
                                ? "⚡ ${surgeTag.split('(').last.replaceAll(')', '')}"
                                : "⚡ Surge",
                            style: GoogleFonts.poppins(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.orange.shade900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const SizedBox(height: 4),

                      // Vehicle Icon
                      Icon(
                        _getCarIcon(car["car_type"] ?? ""),
                        size: 34,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),

                      // Vehicle Name
                      Text(
                        car["car_type"] ?? "",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Pricing & Discount Section
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasDiscount) ...[
                            // 1. SAVE BADGE (Rentox yellow/orange theme, highly readable on selected card)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFFFFF3CD),
                                borderRadius: BorderRadius.circular(6),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: const Color(0xFFFFB300),
                                        width: 0.8),
                              ),
                              child: Text(
                                "SAVE $discountPercent%",
                                style: GoogleFonts.poppins(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: isSelected
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),

                            // 2. STRIKETHROUGH ORIGINAL PRICE & PROMINENT FINAL PRICE
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  "₹${origPrice.toStringAsFixed(0)}",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    decoration: TextDecoration.lineThrough,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.75)
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  "₹${discPrice.toStringAsFixed(0)}",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16.5,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),

                            // 3. YOU SAVE AMOUNT
                            Text(
                              "You save ₹${discountAmount.toStringAsFixed(0)}",
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white.withOpacity(0.95)
                                    : const Color(0xFF15803D),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ] else ...[
                            // NO DISCOUNT: Only current fare, no fake crossed-out price or badges
                            Text(
                              "₹${discPrice.toStringAsFixed(0)}",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: selectedCar.isNotEmpty ? _proceed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: darkCanvas,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              elevation: 0,
            ),
            child: Text(
              selectedCar.isNotEmpty ? "Confirm $selectedCar" : "Select a Car",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceUnavailable() {
    return Column(
      children: [
        const Icon(Icons.info_outline, color: Colors.red, size: 40),
        const SizedBox(height: 10),
        Text("Distance exceeds 80km.",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        Text("Please use our One-Way service for long trips.",
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 15),
        ElevatedButton(
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => FromToMapScreen())),
          style: ElevatedButton.styleFrom(backgroundColor: primaryAmber),
          child: const Text("Go to One-Way"),
        )
      ],
    );
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    fromFocusNode.dispose();
    toFocusNode.dispose();
    super.dispose();
  }
}
