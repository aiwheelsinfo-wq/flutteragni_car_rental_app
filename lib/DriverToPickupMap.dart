import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverToPickupMapYellowFinalV2 extends StatefulWidget {
  final String driverId;
  final String bookingId;

  const DriverToPickupMapYellowFinalV2({
    super.key,
    required this.driverId,
    required this.bookingId,
  });

  @override
  State<DriverToPickupMapYellowFinalV2> createState() =>
      _DriverToPickupMapYellowFinalV2State();
}

class _DriverToPickupMapYellowFinalV2State
    extends State<DriverToPickupMapYellowFinalV2>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLng? _driverPos;
  LatLng? _animatedDriverPos;
  LatLng? _destinationPos;

  double _driverRotation = 0.0;
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _pickupIcon;
  String googleApiKey = "";

  // Modern Silver-Amber Map Style
  static const String _professionalMapStyle = r'''
  [
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#e9e9e9"}, {"lightness": 17}]},
    {"featureType": "landscape", "elementType": "geometry", "stylers": [{"color": "#f5f5f5"}, {"lightness": 20}]},
    {"featureType": "road.highway", "elementType": "geometry.fill", "stylers": [{"color": "#ffffff"}, {"lightness": 17}]},
    {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#ffffff"}, {"lightness": 29}, {"weight": 0.2}]},
    {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#ffffff"}, {"lightness": 18}]},
    {"featureType": "road.local", "elementType": "geometry", "stylers": [{"color": "#ffffff"}, {"lightness": 16}]},
    {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#f5f5f5"}, {"lightness": 21}]},
    {"elementType": "labels.text.stroke", "stylers": [{"visibility": "on"}, {"color": "#ffffff"}, {"lightness": 16}]},
    {"elementType": "labels.text.fill", "stylers": [{"saturation": 36}, {"color": "#333333"}, {"lightness": 40}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]}
  ]
  ''';

  Timer? _refreshTimer;
  Timer? _smoothMoveTimer;
  bool _mapMovedByUser = false;

  late AnimationController _routeFadeController;
  late Animation<double> _routeFadeAnim;

  String _etaText = "--";
  String _distanceText = "--";
  List<LatLng> _polylineCoords = [];
  static const double _epsilon = 0.00003;

  // Colors
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color darkCharcoal = const Color(0xFF1A1A1A);
  final Color softAmberBg = const Color(0xFFFFF8E1);

  @override
  void initState() {
    super.initState();
    fetchApiKey();

    _routeFadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _routeFadeAnim =
        Tween<double>(begin: 0.0, end: 1.0).animate(_routeFadeController);

    _loadIcons().then((_) {
      _fetchDriverAndDestination(refreshOnly: false);
      _refreshTimer = Timer.periodic(const Duration(seconds: 40),
          (_) => _fetchDriverAndDestination(refreshOnly: true));
    });
  }

  Future<void> fetchApiKey() async {
    try {
      final response = await http.get(Uri.parse(
          'https://agnicarrental.com/api_key/api.php?token=mySecretToken123'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => googleApiKey = data['apiKey']);
      }
    } catch (e) {
      debugPrint('Key fetch error: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _smoothMoveTimer?.cancel();
    _routeFadeController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadIcons() async {
    _carIcon =
        await _bitmapDescriptorFromIcon(Icons.local_taxi, darkCharcoal, 80);
    _pickupIcon = await _createPickupMarker(primaryAmber, 100);
    setState(() {});
  }

  Future<BitmapDescriptor> _bitmapDescriptorFromIcon(
      IconData iconData, Color color, int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
            fontSize: size.toDouble(),
            fontFamily: iconData.fontFamily,
            color: color));
    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 0));
    final image = await recorder.endRecording().toImage(size, size);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<BitmapDescriptor> _createPickupMarker(Color color, int size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 5, paint);
    canvas.drawCircle(
        Offset(size / 2, size / 2), size / 4, Paint()..color = Colors.white);
    final image = await recorder.endRecording().toImage(size, size);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    return BitmapDescriptor.fromBytes(bytes);
  }

  Future<void> _fetchDriverAndDestination({bool refreshOnly = false}) async {
    try {
      final url = Uri.parse(
          'https://agnicarrental.com/driver2025/driver_details_fetching.php?driver_id=${widget.driverId}&booking_id=${widget.bookingId}');
      final response = await http.get(url);
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body);
      if (body['status'] != 'success') return;
      final info = body['data'];

      final dLat = double.tryParse(info['driver_lat']?.toString() ?? '');
      final dLng = double.tryParse(info['driver_lng']?.toString() ?? '');
      final fromAddress = info['from_address']?.toString() ?? '';

      LatLng? newDriver =
          (dLat != null && dLng != null) ? LatLng(dLat, dLng) : null;
      LatLng? newDest = _destinationPos;

      if (!refreshOnly && fromAddress.isNotEmpty) {
        final geoUrl = Uri.parse(
            'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(fromAddress)}&key=$googleApiKey');
        final geoResp = await http.get(geoUrl);
        if (geoResp.statusCode == 200) {
          final geoData = jsonDecode(geoResp.body);
          if (geoData['status'] == 'OK') {
            final loc = geoData['results'][0]['geometry']['location'];
            newDest = LatLng(loc['lat'], loc['lng']);
          }
        }
      }

      if (newDriver != null) {
        if (_driverPos != null)
          _driverRotation = _computeBearing(_driverPos!, newDriver);
        _driverPos = newDriver;
        _startSmoothMoveTo(newDriver);
      }
      if (newDest != null) _destinationPos = newDest;

      if (_driverPos != null && _destinationPos != null) {
        await _fetchDirectionsAndUpdateRoute(_driverPos!, _destinationPos!);
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
    }
  }

  void _startSmoothMoveTo(LatLng target) {
    _smoothMoveTimer?.cancel();
    if (_animatedDriverPos == null) {
      _animatedDriverPos = target;
      _updateMarkers();
      return;
    }
    final start = _animatedDriverPos!;
    final steps = 25;
    int currentStep = 0;
    _smoothMoveTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      currentStep++;
      _animatedDriverPos = LatLng(
        start.latitude +
            (target.latitude - start.latitude) * (currentStep / steps),
        start.longitude +
            (target.longitude - start.longitude) * (currentStep / steps),
      );
      _updateMarkers();
      if (currentStep >= steps) t.cancel();
    });
  }

  Future<void> _fetchDirectionsAndUpdateRoute(
      LatLng origin, LatLng dest) async {
    final directionsUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${dest.latitude},${dest.longitude}&key=$googleApiKey&mode=driving&departure_time=now');
    final resp = await http.get(directionsUrl);
    if (resp.statusCode != 200) return;
    final decoded = jsonDecode(resp.body);
    if (decoded['status'] == 'OK') {
      final leg = decoded['routes'][0]['legs'][0];
      setState(() {
        _etaText = leg['duration']['text'] ?? "--";
        _distanceText = leg['distance']['text'] ?? "--";
        _polylineCoords = _decodePolyline(
            decoded['routes'][0]['overview_polyline']['points']);
      });
      _routeFadeController.forward(from: 0.0);
      _updateMarkers();
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }

  void _updateMarkers() {
    final newMarkers = <Marker>{};
    if (_animatedDriverPos != null) {
      newMarkers.add(Marker(
          markerId: const MarkerId('driver'),
          position: _animatedDriverPos!,
          rotation: _driverRotation,
          icon: _carIcon ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndex: 5));
    }
    if (_destinationPos != null) {
      newMarkers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: _destinationPos!,
          icon: _pickupIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          zIndex: 4));
    }
    setState(() => _markers
      ..clear()
      ..addAll(newMarkers));
  }

  double _computeBearing(LatLng from, LatLng to) {
    double dLon = (to.longitude - from.longitude) * (math.pi / 180.0);
    double lat1 = from.latitude * (math.pi / 180.0);
    double lat2 = to.latitude * (math.pi / 180.0);
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * (180.0 / math.pi) + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
        title: Text("LIVE TRACKING",
            style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black,
                letterSpacing: 1.2)),
      ),
      body: Column(
        children: [
          // 1. Header Info Section
          _buildStatusHeader(),

          // 2. The Map Viewport (Professional Windowed Map)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.grey.shade200, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                            target:
                                _driverPos ?? const LatLng(20.5937, 78.9629),
                            zoom: 14),
                        markers: _markers,
                        polylines: {
                          Polyline(
                            polylineId: const PolylineId('route'),
                            points: _polylineCoords,
                            width: 5,
                            color:
                                primaryAmber.withOpacity(_routeFadeAnim.value),
                            jointType: JointType.round,
                          )
                        },
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _mapController!.setMapStyle(_professionalMapStyle);
                        },
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                      ),
                      Positioned(
                        bottom: 15,
                        right: 15,
                        child: _mapActionButtons(),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Footer Trip Details Section
          _buildTripDetailsFooter(),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Booking ID: #${widget.bookingId}",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text("Driver is arriving",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: darkCharcoal)),
            ],
          ),
          CircleAvatar(
            backgroundColor: softAmberBg,
            radius: 25,
            child: IconButton(
              icon: Icon(Icons.call, color: primaryAmber),
              onPressed: () => launchUrl(Uri.parse("tel:${widget.driverId}")),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTripDetailsFooter() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: darkCharcoal,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(35), topRight: Radius.circular(35)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoDetail(Icons.access_time_filled, "ETA", _etaText),
              _infoDetail(Icons.straighten, "Dist.", _distanceText),
            ],
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.navigation_rounded),
              label: Text("OPEN IN GOOGLE MAPS",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, letterSpacing: 1)),
              onPressed: () => launchUrl(
                  Uri.parse(
                      "https://www.google.com/maps/dir/?api=1&origin=${_driverPos?.latitude},${_driverPos?.longitude}&destination=${_destinationPos?.latitude},${_destinationPos?.longitude}&travelmode=driving"),
                  mode: LaunchMode.externalApplication),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryAmber,
                foregroundColor: darkCharcoal,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: primaryAmber, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ],
        )
      ],
    );
  }

  Widget _mapActionButtons() {
    return Column(
      children: [
        _miniFab(Icons.my_location, () {
          if (_driverPos != null)
            _mapController
                ?.animateCamera(CameraUpdate.newLatLngZoom(_driverPos!, 15));
        }),
        const SizedBox(height: 10),
        _miniFab(Icons.fit_screen, () {
          if (_markers.isEmpty) return;
          double minLat = _markers.first.position.latitude,
              maxLat = minLat,
              minLng = _markers.first.position.longitude,
              maxLng = minLng;
          for (var m in _markers) {
            minLat = math.min(minLat, m.position.latitude);
            maxLat = math.max(maxLat, m.position.latitude);
            minLng = math.min(minLng, m.position.longitude);
            maxLng = math.max(maxLng, m.position.longitude);
          }
          _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
              LatLngBounds(
                  southwest: LatLng(minLat, minLng),
                  northeast: LatLng(maxLat, maxLng)),
              50));
        }),
      ],
    );
  }

  Widget _miniFab(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
            ]),
        child: Icon(icon, size: 20, color: darkCharcoal),
      ),
    );
  }
}
