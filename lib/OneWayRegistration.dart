import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart' as gp;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:agni_car_rental/config/api_config.dart';

// Your existing imports
import 'localDutyReg.dart';
import 'local_taxi.dart';
import 'oneWayDateAndTime.dart';

class FromToMapScreen extends StatefulWidget {
  @override
  _FromToMapScreenState createState() => _FromToMapScreenState();
}

class _FromToMapScreenState extends State<FromToMapScreen> {
  final fromController = TextEditingController();
  final toController = TextEditingController();
  late gp.GooglePlace googlePlace;
  List<gp.AutocompletePrediction> predictions = [];
  bool isFrom = true;
  bool isEditing =
      true; // Key for toggling between Search View and Summary View
  LatLng? fromLatLng;
  LatLng? toLatLng;
  String tripType = "One-way";
  String apiKey = "";
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  double? calculatedDistance;
  String? estimatedDuration;
  LatLng? currentLatLng;
  Timer? _debounce;

  final Color amberPrimary = const Color(0xFFFFC107);
  final Color charcoalDark = const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    fetchApiKey();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  static const String _yellowMapStyle = '''
[
  {"featureType":"all","elementType":"labels.text.fill","stylers":[{"color":"#7c7c7c"}]},
  {"featureType":"landscape","elementType":"geometry.fill","stylers":[{"color":"#fff9e1"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#ffd54f"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#ffe082"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]}
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
      debugPrint('API Key Fetch Error: $e');
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
        } else {
          toController.text = prediction.description!;
          toLatLng = LatLng(loc.lat!, loc.lng!);
        }
        predictions = [];
      });
      if (fromLatLng != null && toLatLng != null) {
        setState(() => isEditing = false);
        getRouteAndDistance();
      } else {
        _updateMapMarkers();
      }
    }
  }

  void _updateMapMarkers() {
    markers.clear();
    if (fromLatLng != null)
      markers.add(Marker(
          markerId: const MarkerId("from"),
          position: fromLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange)));
    if (toLatLng != null)
      markers.add(Marker(
          markerId: const MarkerId("to"),
          position: toLatLng!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)));
  }

// ...existing code...

  Future<void> getRouteAndDistance() async {
    if (apiKey.isEmpty || fromLatLng == null || toLatLng == null) {
      debugPrint("Missing API key or coordinates");
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
              "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline"
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
      print("ROUTES API RESPONSE: $data");

      if (data["routes"] == null || data["routes"].isEmpty) {
        debugPrint("No routes found");
        return;
      }

      final route = data["routes"][0];

      // ✅ Distance
      double distanceKm = (route["distanceMeters"] ?? 0) / 1000;

      // ✅ Duration ("7240s" → minutes)
      int durationSec =
          int.parse(route["duration"].toString().replaceAll("s", ""));
      String durationText = "${(durationSec / 60).round()} mins";

      // ✅ Base trip type logic
      String type = distanceKm > 75 ? "One-way" : "Local";

      // ✅ SPECIAL LOCATION CHECK (SAFE + OPTIONAL)
      try {
        final specialUrl = "${ApiConfig.baseUrl}/special_location.php"
            "?fromLat=${fromLatLng!.latitude}"
            "&fromLon=${fromLatLng!.longitude}"
            "&toLat=${toLatLng!.latitude}"
            "&toLon=${toLatLng!.longitude}";

        final specialResp = await http.get(Uri.parse(specialUrl));

        if (specialResp.statusCode == 200) {
          final specialData = json.decode(specialResp.body);

          if (specialData['isSpecial'] == true) {
            type = "One-way"; // override
          }
        }
      } catch (e) {
        debugPrint('Special location check failed: $e');
      }

      // ✅ Decode polyline
      List<PointLatLng> resultPoints =
          PolylinePoints().decodePolyline(route["polyline"]["encodedPolyline"]);

      // ✅ UI Update
      setState(() {
        calculatedDistance = distanceKm;
        estimatedDuration = durationText;
        tripType = type;

        polylines.clear(); // FIX: prevent stacking
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to calculate route')),
      );
    }
  }

// ...existing code...
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevents keyboard overflow
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
                target: currentLatLng ?? const LatLng(20.59, 78.96), zoom: 14),
            markers: markers,
            polylines: polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (c) {
              mapController = c;
              c.setMapStyle(_yellowMapStyle);
            },
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                isEditing ? _buildSearchCard() : _buildMinimizedRouteInfo(),
                if (predictions.isNotEmpty && isEditing)
                  _buildPredictionOverlay(),
              ],
            ),
          ),
          if (fromLatLng != null && toLatLng != null && !isEditing)
            _buildBottomRidePanel(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: charcoalDark, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w900),
              children: [
                TextSpan(
                    text: "ONE-WAY ", style: TextStyle(color: charcoalDark)),
                TextSpan(text: "TRIP", style: TextStyle(color: amberPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
      child: Column(
        children: [
          _buildInputRow(fromController, "Starting Point",
              Icons.radio_button_checked, amberPrimary, true),
          const Divider(height: 20),
          _buildInputRow(
              toController, "Where to?", Icons.location_on, Colors.red, false),
        ],
      ),
    );
  }

  Widget _buildMinimizedRouteInfo() {
    return GestureDetector(
      onTap: () => setState(() => isEditing = true),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
            color: charcoalDark,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
        child: Row(
          children: [
            const Icon(Icons.map, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "${fromController.text.split(',').first} → ${toController.text.split(',').first}",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: amberPrimary, borderRadius: BorderRadius.circular(5)),
              child: Text("EDIT",
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: charcoalDark)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(
    TextEditingController controller,
    String hint,
    IconData icon,
    Color color,
    bool isPickup,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: (v) => _onSearchChanged(v, isPickup),
            // textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: charcoalDark,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
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
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: predictions.length,
        itemBuilder: (context, i) => ListTile(
          leading: const Icon(Icons.place, size: 18),
          title: Text(predictions[i].description!,
              style: GoogleFonts.poppins(fontSize: 12)),
          onTap: () => selectPrediction(predictions[i]),
        ),
      ),
    );
  }

  Widget _buildBottomRidePanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(25, 20, 25, 35),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _badge(Icons.straighten,
                    "${calculatedDistance?.toStringAsFixed(1)} KM"),
                _badge(Icons.timer, estimatedDuration ?? "--"),
                _badge(Icons.local_taxi, tripType),
              ],
            ),
            const SizedBox(height: 25),

            // Logic for Local vs One-Way Buttons
            if (tripType == "Local")
              Row(
                children: [
                  Expanded(
                      child: _localBtn(
                          "Local Taxi",
                          () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => LocalTaxi())))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _localBtn(
                          "Local Duty",
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => LocalDutyBookingForm(
                                      fromLocation: fromController.text))))),
                ],
              )
            else
              ElevatedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => OneWayDateAndTime(
                            from: fromController.text, to: toController.text))),
                style: ElevatedButton.styleFrom(
                    backgroundColor: amberPrimary,
                    foregroundColor: charcoalDark,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 0),
                child: Text("PROCEED TO BOOKING",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text) {
    return Column(children: [
      Icon(icon, color: amberPrimary, size: 20),
      const SizedBox(height: 4),
      Text(text,
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold))
    ]);
  }

  Widget _localBtn(String label, VoidCallback tap) {
    return OutlinedButton(
      onPressed: tap,
      style: OutlinedButton.styleFrom(
        foregroundColor: charcoalDark,
        padding: const EdgeInsets.symmetric(vertical: 15),
        side: BorderSide(color: amberPrimary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label,
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}
