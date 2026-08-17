import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/boundary_service.dart';

class AvailableBoundariesMapPage extends StatefulWidget {
  const AvailableBoundariesMapPage({Key? key}) : super(key: key);

  @override
  State<AvailableBoundariesMapPage> createState() => _AvailableBoundariesMapPageState();
}

class _AvailableBoundariesMapPageState extends State<AvailableBoundariesMapPage> {
  GoogleMapController? _mapController;
  final BoundaryService _boundaryService = BoundaryService();
  
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _cities = [];
  bool _isLoading = true;
  String? _selectedCityName;

  static const LatLng _initialCenter = LatLng(19.1500, 73.1000); // Default view over MH

  @override
  void initState() {
    super.initState();
    _loadBoundaries();
  }

  Future<void> _loadBoundaries() async {
    setState(() => _isLoading = true);
    try {
      await _boundaryService.fetchCityBoundaries();
      final cities = _boundaryService.majorCities;
      
      final Set<Polygon> loadedPolygons = {};
      final Set<Marker> loadedMarkers = {};
      final List<Color> colors = [
        Colors.orange,
        Colors.purple,
        Colors.blue,
        Colors.green,
        Colors.teal,
        Colors.indigo
      ];

      for (int i = 0; i < cities.length; i++) {
        final city = cities[i];
        final String cityName = city['name'] ?? 'City ${i + 1}';
        final List<LatLng> points = List<LatLng>.from(city['points'] ?? []);
        final Color color = colors[i % colors.length];

        if (points.isNotEmpty) {
          // Add Polygon
          loadedPolygons.add(
            Polygon(
              polygonId: PolygonId(cityName),
              points: points,
              strokeWidth: 3,
              strokeColor: color,
              fillColor: color.withOpacity(0.20),
            ),
          );

          // Calculate center of polygon for marker placement
          double sumLat = 0;
          double sumLng = 0;
          for (var p in points) {
            sumLat += p.latitude;
            sumLng += p.longitude;
          }
          final LatLng center = LatLng(sumLat / points.length, sumLng / points.length);

          // Add Marker
          loadedMarkers.add(
            Marker(
              markerId: MarkerId(cityName),
              position: center,
              infoWindow: InfoWindow(
                title: '$cityName Service Area',
                snippet: 'Local Cab & Duty Available',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
              onTap: () {
                setState(() => _selectedCityName = cityName);
              },
            ),
          );
        }
      }

      setState(() {
        _cities = cities;
        _polygons = loadedPolygons;
        _markers = loadedMarkers;
        _isLoading = false;
      });

      if (cities.isNotEmpty && _mapController != null) {
        _fitAllBoundaries();
      }
    } catch (e) {
      debugPrint("Error loading boundaries map: $e");
      setState(() => _isLoading = false);
    }
  }

  void _fitAllBoundaries() {
    if (_cities.isEmpty || _mapController == null) return;
    
    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;

    for (var city in _cities) {
      List<LatLng> points = List<LatLng>.from(city['points'] ?? []);
      for (var p in points) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }
    }

    if (minLat < maxLat && minLng < maxLng) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          60.0, // padding
        ),
      );
    }
  }

  void _zoomToCity(Map<String, dynamic> city) {
    final String cityName = city['name'] ?? '';
    final List<LatLng> points = List<LatLng>.from(city['points'] ?? []);
    if (points.isEmpty) return;

    setState(() => _selectedCityName = cityName);

    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Active Service Boundaries',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1A1A24),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBoundaries,
            tooltip: 'Refresh Boundaries',
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: _fitAllBoundaries,
            tooltip: 'Fit All Cities',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map View
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _initialCenter,
              zoom: 8.5,
            ),
            polygons: _polygons,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_cities.isNotEmpty) {
                _fitAllBoundaries();
              }
            },
          ),

          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8008)),
              ),
            ),

          // Bottom Active Cities Sheet
          if (!_isLoading && _cities.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: Color(0xFFFFC837), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Available Local Service Areas (${_cities.length})',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Tap city to view',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cities.length,
                        itemBuilder: (context, index) {
                          final city = _cities[index];
                          final String cityName = city['name'] ?? 'City';
                          final bool isSelected = _selectedCityName == cityName;

                          return GestureDetector(
                            onTap: () => _zoomToCity(city),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? const LinearGradient(colors: [Color(0xFFFF8008), Color(0xFFFFC837)])
                                    : null,
                                color: isSelected ? null : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: isSelected ? Colors.transparent : Colors.white24,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_city_rounded,
                                    size: 16,
                                    color: isSelected ? Colors.black : Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cityName,
                                    style: GoogleFonts.poppins(
                                      color: isSelected ? Colors.black : Colors.white,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
