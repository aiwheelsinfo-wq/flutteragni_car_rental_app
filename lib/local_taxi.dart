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
  const LocalTaxi({Key? key}) : super(key: key);

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
    _getCurrentLocation();

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

      String encodedPolyline = route["polyline"]?["encodedPolyline"] ?? "";

      List<LatLng> points = _decodePolyline(encodedPolyline);

      setState(() {
        distanceController.text = "${distanceInKm.toStringAsFixed(1)} km";
        serviceAvailable = distanceInKm <= 80;

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
    try {
      String? savedNumber = await secureStorage.read(key: 'phone_number');
      if (savedNumber == null) return;

      final response = await http.get(Uri.parse(
          "${ApiConfig.baseUrl}/agni_taxi/fetch_fares.php?phone_number=$savedNumber"));
      if (response.statusCode == 200) {
        List fares = json.decode(response.body);
        Map<String, dynamic>? selectedFare;
        for (var fare in fares) {
          kmLimit = double.tryParse(fare["km"].toString()) ?? 0;
          if (distance <= kmLimit!) {
            selectedFare = fare;
            break;
          }
        }
        selectedFare ??= fares.last;

        setState(() {
          carFares = [
            _mapFare(selectedFare!, "Hatchback"),
            _mapFare(selectedFare, "Sedan"),
            _mapFare(selectedFare, "Ertiga"),
          ];
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Map<String, dynamic> _mapFare(Map<String, dynamic> data, String type) {
    return {
      "car_type": type,
      "original_price": double.tryParse(data[type].toString()) ?? 0,
      "discounted_price":
          double.tryParse(data["${type}_discounted"].toString()) ??
              double.tryParse(data[type].toString()) ??
              0,
      "discount_percent": data["discount_percent"] ?? 0,
    };
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

  bool _checkCityBoundary(LatLng latLng, String address) {
    // Bounding Box limits for Pune City
    const double minLat = 18.4100;
    const double maxLat = 18.6500;
    const double minLng = 73.7200;
    const double maxLng = 73.9800;

    bool withinCoords = (latLng.latitude >= minLat && latLng.latitude <= maxLat) &&
                         (latLng.longitude >= minLng && latLng.longitude <= maxLng);
    
    bool containsPune = address.toLowerCase().contains('pune');
    return withinCoords || containsPune;
  }

  void _showBoundaryError(String locationType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Outside City Limits",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Text(
            "Your selected $locationType is outside Pune city limits. Local Taxi bookings are restricted strictly within Pune City limits. For longer trips, please use our One-Way service.",
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

    // Validate Pune City Limits for Pickup Address
    if (fromLatLng != null && !_checkCityBoundary(fromLatLng!, fullAddress)) {
      _showBoundaryError("Pickup location");
      return;
    }

    // Validate Pune City Limits for Drop Address
    if (toLatLng != null && !_checkCityBoundary(toLatLng!, toController.text)) {
      _showBoundaryError("Drop location");
      return;
    }

    var fareData = carFares.firstWhere((f) => f["car_type"] == selectedCar);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerRegistrationPage(
          bookingData: {
            "from_address": fullAddress,
            "to_address": toController.text,
            "car_type": selectedCar,
            "total_amount": fareData["discounted_price"].toString(),
            "distance": kmLimit,
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
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: carFares.length,
            itemBuilder: (context, index) {
              var car = carFares[index];
              bool isSelected = selectedCar == car["car_type"];
              return GestureDetector(
                onTap: () => setState(() => selectedCar = car["car_type"]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 130,
                  margin: const EdgeInsets.only(right: 15, bottom: 10, top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryAmber : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isSelected ? primaryAmber : Colors.grey.shade300,
                        width: 2),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: primaryAmber.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car,
                          size: 40,
                          color: isSelected ? Colors.white : Colors.black54),
                      const SizedBox(height: 8),
                      Text(car["car_type"],
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black)),
                      Text("₹${car["discounted_price"].toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : primaryAmber)),
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
