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

  // Palette of distinct, high-visibility colors for boundaries
  static const List<Color> _boundaryColors = [
    Color(0xFFFF5722), // Vibrant Deep Orange
    Color(0xFF2196F3), // Electric Blue
    Color(0xFF4CAF50), // Fresh Green
    Color(0xFF9C27B0), // Vivid Purple
    Color(0xFFFFC107), // Golden Yellow
    Color(0xFF00BCD4), // Bright Cyan
    Color(0xFFE91E63), // Hot Pink
  ];

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

      for (int i = 0; i < cities.length; i++) {
        final city = cities[i];
        final String cityName = city['name'] ?? 'City ${i + 1}';
        final List<LatLng> points = List<LatLng>.from(city['points'] ?? []);
        final Color color = _boundaryColors[i % _boundaryColors.length];

        if (points.isNotEmpty) {
          // 1. Draw bold boundary polygon with fill
          loadedPolygons.add(
            Polygon(
              polygonId: PolygonId(cityName),
              points: points,
              strokeWidth: 4,
              strokeColor: color,
              fillColor: color.withOpacity(0.28),
            ),
          );

          // 2. Calculate center of polygon for pin marker
          double sumLat = 0;
          double sumLng = 0;
          for (var p in points) {
            sumLat += p.latitude;
            sumLng += p.longitude;
          }
          final LatLng center = LatLng(sumLat / points.length, sumLng / points.length);

          // 3. Add marker pin with info window
          loadedMarkers.add(
            Marker(
              markerId: MarkerId(cityName),
              position: center,
              infoWindow: InfoWindow(
                title: '$cityName Local Area',
                snippet: 'Local Cab & Duty Available Here',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _getHueForColor(color),
              ),
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

  double _getHueForColor(Color color) {
    if (color == const Color(0xFFFF5722)) return BitmapDescriptor.hueOrange;
    if (color == const Color(0xFF2196F3)) return BitmapDescriptor.hueAzure;
    if (color == const Color(0xFF4CAF50)) return BitmapDescriptor.hueGreen;
    if (color == const Color(0xFF9C27B0)) return BitmapDescriptor.hueViolet;
    if (color == const Color(0xFFFFC107)) return BitmapDescriptor.hueYellow;
    if (color == const Color(0xFF00BCD4)) return BitmapDescriptor.hueCyan;
    return BitmapDescriptor.hueRose;
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
      setState(() => _selectedCityName = null);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          70.0, // padding
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
        55.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Active Service Areas',
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF14141E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            onPressed: _fitAllBoundaries,
            tooltip: 'Fit All Cities',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadBoundaries,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Google Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _initialCenter,
              zoom: 8.5,
            ),
            polygons: _polygons,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_cities.isNotEmpty) {
                _fitAllBoundaries();
              }
            },
          ),

          // 2. Map Legend / Banner Top Float
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF14141E).withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5722),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Colored areas on map indicate local service boundaries',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Loading Indicator
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.35),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8008)),
              ),
            ),

          // 4. Bottom City Selector Card (Fixed Overflow Bug)
          if (!_isLoading && _cities.isNotEmpty)
            Positioned(
              left: 14,
              right: 14,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141E).withOpacity(0.96),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row with Expanded text to prevent overflow
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFFFFC107), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Active Service Cities (${_cities.length})',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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

                    // City Chips Horizontal Scroll
                    SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _cities.length,
                        itemBuilder: (context, index) {
                          final city = _cities[index];
                          final String cityName = city['name'] ?? 'City';
                          final bool isSelected = _selectedCityName == cityName;
                          final Color cityColor = _boundaryColors[index % _boundaryColors.length];

                          return GestureDetector(
                            onTap: () => _zoomToCity(city),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSelected ? cityColor : Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected ? Colors.transparent : cityColor.withOpacity(0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_city_rounded,
                                    size: 15,
                                    color: isSelected ? Colors.white : cityColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    cityName,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
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
