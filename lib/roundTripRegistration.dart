import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart' as gp;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';

// Assuming this exists in your project
import 'package:agni_car_rental/rounTripDateAndTime.dart';
import 'local_taxi.dart';
import 'services/boundary_service.dart';

class RoundTripFromToMapScreen extends StatefulWidget {
  const RoundTripFromToMapScreen({Key? key}) : super(key: key);

  @override
  _FromToMapScreenState createState() => _FromToMapScreenState();
}

class _FromToMapScreenState extends State<RoundTripFromToMapScreen> {
  final fromController = TextEditingController();
  final toController = TextEditingController();
  final FocusNode fromFocus = FocusNode();
  final FocusNode toFocus = FocusNode();

  late gp.GooglePlace googlePlace;
  List<gp.AutocompletePrediction> predictions = [];

  bool isFrom = true;
  bool isEditing = true; // Toggles between search view and summary view
  String apiKey = "";
  LatLng? fromLatLng;
  LatLng? toLatLng;

  GoogleMapController? mapController;
  LatLng? currentLatLng;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  double? tripDistanceInKm;
  Timer? _debounce;

  // Professional Theme Colors
  final Color primaryAmber = const Color(0xFFFFC107);
  final Color charcoalDark = const Color(0xFF1A1A1A);
  final Color bgLight = const Color(0xFFF8F8F8);

  @override
  void initState() {
    super.initState();
    fetchApiKey();
    BoundaryService().fetchCityBoundaries();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    fromController.dispose();
    toController.dispose();
    fromFocus.dispose();
    toFocus.dispose();
    super.dispose();
  }

  // Refined Premium Yellow Map Style
  static const String _yellowMapStyle = '''
[
  {"featureType":"all","elementType":"labels.text.fill","stylers":[{"color":"#7c7c7c"}]},
  {"featureType":"landscape","elementType":"geometry.fill","stylers":[{"color":"#fffef2"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#ffd54f"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#ffca28"}]},
  {"featureType":"road.arterial","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#ffe082"}]}
]
''';

  Future<void> fetchApiKey() async {
    try {
      final response = await http.get(Uri.parse(
          'https://agnicarrental.com/api_key/api.php?token=mySecretToken123'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          apiKey = data['apiKey'];
          googlePlace = gp.GooglePlace(apiKey);
        });
        getCurrentLocation();
      }
    } catch (e) {
      debugPrint('API Key Error: $e');
    }
  }

  void _onSearchChanged(String value, bool isFromSelection) {
    setState(() {
      isFrom = isFromSelection;
      isEditing = true;
    });
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (value.isNotEmpty)
        autoCompleteSearch(value);
      else
        setState(() => predictions = []);
    });
  }

  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    currentLatLng = LatLng(position.latitude, position.longitude);
    mapController
        ?.animateCamera(CameraUpdate.newLatLngZoom(currentLatLng!, 15));
    await _getAddressFromLatLng(position.latitude, position.longitude);
  }

  Future<void> _getAddressFromLatLng(double lat, double lng) async {
    if (apiKey.isEmpty) return;
    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey";
    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['results'].isNotEmpty) {
        setState(() {
          fromController.text = data['results'][0]['formatted_address'];
          fromLatLng = LatLng(lat, lng);
          _updateMapMarkers();
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void autoCompleteSearch(String value) async {
    var result = await googlePlace.autocomplete.get(value);
    if (result != null && result.predictions != null && mounted) {
      setState(() => predictions = result.predictions!);
    }
  }

  void selectPrediction(gp.AutocompletePrediction prediction) async {
    final details = await googlePlace.details.get(prediction.placeId!);
    if (details?.result != null) {
      final loc = details!.result!.geometry!.location!;
      setState(() {
        if (isFrom) {
          fromController.text = prediction.description!;
          fromLatLng = LatLng(loc.lat!, loc.lng!);
          FocusScope.of(context).requestFocus(toFocus);
        } else {
          toController.text = prediction.description!;
          toLatLng = LatLng(loc.lat!, loc.lng!);
          FocusScope.of(context).unfocus();
        }
        predictions = [];
      });
      if (fromLatLng != null && toLatLng != null) {
        setState(() => isEditing = false);
        _getRouteAndDistance();
      } else {
        _updateMapMarkers();
      }
    }
  }

  void _updateMapMarkers() {
    markers.clear();
    if (fromLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId("from"),
        position: fromLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }
    if (toLatLng != null) {
      markers.add(Marker(
        markerId: const MarkerId("to"),
        position: toLatLng!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }
  }

  Future<void> _getRouteAndDistance() async {
    if (fromLatLng == null || toLatLng == null || apiKey.isEmpty) {
      debugPrint("Missing data");
      return;
    }

    const String url =
        "https://routes.googleapis.com/directions/v2:computeRoutes";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask":
              "routes.distanceMeters,routes.polyline.encodedPolyline"
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
      );

      if (response.statusCode != 200) {
        debugPrint("HTTP ERROR: ${response.statusCode}");
        return;
      }

      final data = jsonDecode(response.body);
      print("ROUTE RESPONSE: $data");

      if (data["routes"] == null || data["routes"].isEmpty) {
        debugPrint("No routes found");
        return;
      }

      final route = data["routes"][0];

      // ✅ Distance
      double distanceKm = (route["distanceMeters"] ?? 0) / 1000;

      // ✅ Decode polyline
      List<PointLatLng> resultPoints =
          PolylinePoints().decodePolyline(route["polyline"]["encodedPolyline"]);

      setState(() {
        tripDistanceInKm = distanceKm;

        // 🚨 FIX: clear old polylines
        polylines.clear();

        polylines.add(
          Polyline(
            polylineId: const PolylineId("route"),
            color: charcoalDark,
            width: 5,
            points: resultPoints
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList(),
          ),
        );

        _updateMapMarkers();
      });

      // ✅ Camera fit
      mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              min(fromLatLng!.latitude, toLatLng!.latitude),
              min(fromLatLng!.longitude, toLatLng!.longitude),
            ),
            northeast: LatLng(
              max(fromLatLng!.latitude, toLatLng!.latitude),
              max(fromLatLng!.longitude, toLatLng!.longitude),
            ),
          ),
          100,
        ),
      );
    } catch (e) {
      debugPrint("Route API ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevents keyboard overflow
      backgroundColor: bgLight,
      body: Stack(
        children: [
          // 1. Map Layer
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: const LatLng(20.59, 78.96), zoom: 5),
              markers: markers,
              polylines: polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (c) {
                mapController = c;
                c.setMapStyle(_yellowMapStyle);
              },
            ),
          ),

          // 2. Top UI (Header & Selection)
          SafeArea(
            child: Column(
              children: [
                _buildHeaderSwitcher(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child:
                      isEditing ? _buildSearchCard() : _buildMinimizedSummary(),
                ),
                if (predictions.isNotEmpty && isEditing)
                  _buildPredictionOverlay(),
              ],
            ),
          ),

          // 3. Bottom Action Card
          if (fromLatLng != null && toLatLng != null && !isEditing)
            _buildBottomPanel(),
        ],
      ),
    );
  }

  void _handleProceed() {
    if (fromLatLng != null && toLatLng != null) {
      final boundaryService = BoundaryService();
      final Map<String, dynamic>? detectedCity = boundaryService.detectCity(fromLatLng!, fromController.text);
      if (detectedCity != null) {
        if (boundaryService.isPointInCity(toLatLng!, toController.text, detectedCity)) {
          _showWithinCityBoundaryDialog(detectedCity["name"]);
          return;
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoundTripDateAndTime(
          from: fromController.text,
          to: toController.text,
          distanceInKm: tripDistanceInKm ?? 0.0,
        ),
      ),
    );
  }

  void _showWithinCityBoundaryDialog(String cityName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Route Within City Limits",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Text(
            "This route is within $cityName city limits. Please choose Local Taxi for travel within the same city.",
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              child: Text(
                "Go to Local Taxi",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFFFFB300)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LocalTaxi()),
                );
              },
            ),
            TextButton(
              child: Text(
                "Cancel",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderSwitcher() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: charcoalDark, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            "Round",
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            "Trip",
            style: GoogleFonts.poppins(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: Colors.yellow[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          _buildInputRow(fromController, "Starting Location",
              Icons.radio_button_checked, primaryAmber, true, fromFocus),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
                margin: const EdgeInsets.only(left: 9),
                height: 15,
                width: 2,
                color: Colors.grey.shade200),
          ),
          _buildInputRow(toController, "Drop-off Location", Icons.location_on,
              Colors.red, false, toFocus),
        ],
      ),
    );
  }

  Widget _buildMinimizedSummary() {
    return GestureDetector(
      onTap: () => setState(() => isEditing = true),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: charcoalDark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.sync_alt, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "${fromController.text.split(',').first} ⇌ ${toController.text.split(',').first}",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.edit_note, color: Colors.amber, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(TextEditingController controller, String hint,
      IconData icon, Color color, bool isPickup, FocusNode focus) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 15),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focus,
            onChanged: (v) => _onSearchChanged(v, isPickup),
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w500, color: charcoalDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                  color: Colors.grey.shade400, fontSize: 13),
              border: InputBorder.none,
              isDense: true,
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.cancel, size: 18),
                      onPressed: () => setState(() {
                        controller.clear();
                        isPickup ? fromLatLng = null : toLatLng = null;
                      }),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionOverlay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: predictions.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.grey.shade100),
        itemBuilder: (context, i) => ListTile(
          dense: true,
          leading: const Icon(Icons.place, size: 18),
          title: Text(predictions[i].description!,
              style: GoogleFonts.poppins(fontSize: 12)),
          onTap: () => selectPrediction(predictions[i]),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(25, 25, 25, 45),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoBadge(Icons.straighten,
                    "${tripDistanceInKm?.toStringAsFixed(1)} KM"),
                _infoBadge(Icons.repeat, "ROUND TRIP"),
              ],
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: _handleProceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryAmber,
                foregroundColor: charcoalDark,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: Text("PROCEED TO NEXT STEP",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: primaryAmber, size: 22),
        const SizedBox(height: 5),
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: charcoalDark)),
      ],
    );
  }
}
