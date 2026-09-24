import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:agni_car_rental/config/api_config.dart';
import 'ShowBill.dart';

// --- MODELS ---
class Car {
  final String name;
  final double price; // kmRate
  final double discountedPrice;
  final double baseAmount;
  final double discountPercentage;
  final bool isDiscounted;
  final double driverAllowance;
  final double tollCharge;
  final double gstPercent;
  final bool gstActive;
  final int packageKm;
  final double extraKmAmount;
  final String imageUrl;
  final Map<String, dynamic>? dynamicPricing;

  Car({
    required this.name,
    required this.price,
    required this.discountedPrice,
    required this.baseAmount,
    required this.discountPercentage,
    required this.isDiscounted,
    required this.driverAllowance,
    required this.tollCharge,
    required this.gstPercent,
    this.gstActive = true,
    required this.packageKm,
    required this.extraKmAmount,
    this.imageUrl = '',
    this.dynamicPricing,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    final kmRate = double.tryParse(json['kmRate']?.toString() ?? '0') ?? 0.0;
    final discPrice = double.tryParse(json['discounted_price']?.toString() ?? '0') ?? 0.0;
    final baseAmt = double.tryParse(json['baseAmount']?.toString() ?? '0') ?? discPrice;
    final discPct = double.tryParse(json['discount_percentage']?.toString() ?? '0') ?? 0.0;
    final isDisc = json['is_discounted'] == 1 ||
        json['is_discounted'] == true ||
        (discPct > 0 && discPrice < baseAmt);
    final drvTa = double.tryParse(json['driverAllowance']?.toString() ?? '0') ?? 0.0;
    final toll = double.tryParse(json['tollCharge']?.toString() ?? '0') ?? 0.0;
    final gst = double.tryParse(json['gstPercent']?.toString() ?? '5') ?? 5.0;
    final bool gstAct = (json['gstActive'] == 1 ||
        json['gstActive'] == '1' ||
        json['gstActive'] == true) || (json['gstActive'] == null && gst > 0);
    final pkgKm = int.tryParse(json['packageKm']?.toString() ?? '0') ?? 0;
    final extraKm = double.tryParse(json['extraKMAmount']?.toString() ?? '0') ?? kmRate;
    final imgUrl = json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '';

    return Car(
      name: json['carType']?.toString() ?? '',
      price: kmRate,
      discountedPrice: discPrice > 0 ? discPrice : baseAmt,
      baseAmount: baseAmt > 0 ? baseAmt : discPrice,
      discountPercentage: discPct,
      isDiscounted: isDisc,
      driverAllowance: drvTa,
      tollCharge: toll,
      gstPercent: gst,
      gstActive: gstAct && gst > 0,
      packageKm: pkgKm,
      extraKmAmount: extraKm,
      imageUrl: imgUrl,
      dynamicPricing: json['dynamic_pricing'] is Map<String, dynamic>
          ? json['dynamic_pricing']
          : null,
    );
  }
}

class CarSelectionPage extends StatefulWidget {
  @override
  _CarSelectionPageState createState() => _CarSelectionPageState();
}

class _CarSelectionPageState extends State<CarSelectionPage> {
  final FlutterSecureStorage storage = FlutterSecureStorage();
  final TextEditingController _commissionController = TextEditingController();

  // Professional Theme Palette
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color accentYellow = const Color(0xFFFFD54F);
  final Color darkCanvas = const Color(0xFF1A1A1A);
  final Color surfaceLight = const Color(0xFFF8F9FA);

  int selectedCarIndex = 0;
  String selectedCategoryFilter = "All";
  String selectedSortOption = "default";
  double commissionAmount = 0.0;
  String apiKey = "";
  String fromAddress = "";
  String toAddress = "";
  String date = "";
  String time = "";
  String distance = "Calculating...";
  double numericDistance = 1;
  double baseCharge = 1;
  double driverTa = 1;
  double tollCharge = 1;
  bool belowFifty = false;
  String? userType;
  String? bookingId = "";

  bool isLoading = true;
  List<Car> cars = [];
  Map<String, dynamic> discountData = {};
  int discountPercentage = 0;
  String discountType = 'percentage';
  double discountValue = 0.0;
  String discountName = 'Loyalty';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      fromAddress = args['from'] ?? "";
      toAddress = args['to'] ?? "";
      date = args['date'] ?? "";
      time = args['time'] ?? "";
      bookingId = args['booking_id'];

      double? fromLat = args['fromLat'];
      double? fromLng = args['fromLng'];
      double? toLat = args['toLat'];
      double? toLng = args['toLng'];

      if (apiKey.isNotEmpty) {
        _initializeAfterApiKey(fromLat, fromLng, toLat, toLng);
      } else {
        fetchApiKey().then((_) {
          _initializeAfterApiKey(fromLat, fromLng, toLat, toLng);
        });
      }
    }
  }

  void _initializeAfterApiKey(
      double? fromLat, double? fromLng, double? toLat, double? toLng) {
    fetchDiscount();
    _getDistanceFromGoogle(fromAddress, toAddress,
        fromLat: fromLat, fromLng: fromLng, toLat: toLat, toLng: toLng);
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

  Future<void> fetchCars(
      {double? fromLat, double? fromLng, double? toLat, double? toLng}) async {
    setState(() => isLoading = true);
    try {
      final Map<String, String> queryParams = {
        'tripType': 'One-way',
      };
      if (bookingId != null && bookingId!.isNotEmpty) {
        queryParams['bookingId'] = bookingId!;
      }
      if (numericDistance > 0 && numericDistance != 1) {
        queryParams['distance'] = numericDistance.round().toString();
      }
      if (fromAddress.isNotEmpty) {
        queryParams['fromAddress'] = fromAddress;
      }
      if (toAddress.isNotEmpty) {
        queryParams['toAddress'] = toAddress;
      }
      if (date.isNotEmpty) {
        queryParams['pickupDate'] = date;
      }
      if (time.isNotEmpty) {
        queryParams['pickupTime'] = time;
      }
      if (fromLat != null) queryParams['fromLat'] = fromLat.toString();
      if (fromLng != null) queryParams['fromLng'] = fromLng.toString();
      if (toLat != null) queryParams['toLat'] = toLat.toString();
      if (toLng != null) queryParams['toLng'] = toLng.toString();

      final uri = Uri.parse('${ApiConfig.baseUrl}/selectCarCostList.php')
          .replace(queryParameters: queryParams);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          cars = data.map((item) => Car.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('fetchCars error: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchDiscount() async {
    try {
      final response = await http
          .get(Uri.parse("${ApiConfig.baseUrl}/discount.php"));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          discountData = data;
          discountPercentage = data['discount_percentage'] ?? 0;
          discountType = data['discount_type'] ?? 'percentage';
          discountValue = double.tryParse(data['discount_value']?.toString() ?? '0') ?? 0.0;
          discountName = data['discount_name'] ?? 'Loyalty';
        });
      }
    } catch (e) {
      debugPrint("Discount error: $e");
    }
  }

  Future<void> _getDistanceFromGoogle(String from, String to,
      {double? fromLat, double? fromLng, double? toLat, double? toLng}) async {
    userType = await storage.read(key: "userType");
    try {
      String encodedFrom = Uri.encodeComponent(from);
      String encodedTo = Uri.encodeComponent(to);
      String url =
          "https://maps.googleapis.com/maps/api/distancematrix/json?origins=$encodedFrom&destinations=$encodedTo&key=$apiKey";
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (response.statusCode == 200 &&
          data['rows'].isNotEmpty &&
          data['rows'][0]['elements'][0]['status'] == 'OK') {
        String distanceText =
            data['rows'][0]['elements'][0]['distance']['text'];
        String cleanText = distanceText.split(" ")[0].replaceAll(",", "");
        double doubleDistance = double.parse(cleanText);
        setState(() {
          numericDistance = doubleDistance;
          distance = distanceText;
          double earlyMorningFee = _isEarlyMorningTime(time) ? 300.0 : 0.0;
          driverTa = ((numericDistance < 200) ? 300.0 : 400.0) + earlyMorningFee;
          tollCharge = numericDistance * 2.25;
          baseCharge = driverTa + tollCharge;
          belowFifty = numericDistance < 50;
        });
      }
    } catch (e) {
      debugPrint("Distance error: $e");
    } finally {
      fetchCars(fromLat: fromLat, fromLng: fromLng, toLat: toLat, toLng: toLng);
    }
  }

  bool _isEarlyMorningTime(String timeStr) {
    if (timeStr.isEmpty) return false;
    try {
      final clean = timeStr.trim().toUpperCase();
      int hour = -1;
      int minute = 0;
      if (clean.contains('AM') || clean.contains('PM')) {
        final parts =
            clean.replaceAll('AM', '').replaceAll('PM', '').trim().split(':');
        hour = int.parse(parts[0]);
        if (parts.length > 1) minute = int.parse(parts[1]);
        if (clean.contains('AM')) {
          if (hour == 12) hour = 0;
        } else if (clean.contains('PM')) {
          if (hour != 12) hour += 12;
        }
      } else {
        final parts = clean.split(':');
        hour = int.parse(parts[0]);
        if (parts.length > 1) minute = int.parse(parts[1]);
      }
      return (hour >= 1 && hour < 6) || (hour == 6 && minute == 0);
    } catch (_) {
      return false;
    }
  }

  String _formatCarName(String raw) {
    if (raw.trim().isEmpty) return "Cab";
    final trimmed = raw.trim();
    if (trimmed.toUpperCase() == "SUV") return "SUV";
    final words = trimmed.split(' ');
    return words.map((w) {
      if (w.isEmpty) return '';
      if (w.toUpperCase() == "SUV") return "SUV";
      if (w.length == 1) return w.toUpperCase();
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  List<Car> get _filteredCars {
    List<Car> list = List.from(cars);

    if (selectedCategoryFilter != "All") {
      final f = selectedCategoryFilter.toLowerCase();
      list = list.where((car) {
        final name = car.name.toLowerCase();
        if (f == "sedan") {
          return name.contains("sedan") || name.contains("dzire") || name.contains("etios");
        } else if (f == "suv") {
          return name.contains("suv") || name.contains("ertiga") || name.contains("innova") || name.contains("crysta");
        } else if (f == "hatchback") {
          return name.contains("hatchback") || name.contains("wagonr") || name.contains("swift");
        } else if (f == "4 seater") {
          final specs = _getCarSpecs(car.name);
          return specs['seats'].toString().contains("4");
        } else if (f == "6+ seater") {
          final specs = _getCarSpecs(car.name);
          return specs['seats'].toString().contains("6") || specs['seats'].toString().contains("7");
        }
        return name.contains(f);
      }).toList();
    }

    if (selectedSortOption == "price_asc") {
      list.sort((a, b) {
        double priceA = a.discountedPrice > 0 ? a.discountedPrice : ((a.price * numericDistance * 1.05) + baseCharge);
        double priceB = b.discountedPrice > 0 ? b.discountedPrice : ((b.price * numericDistance * 1.05) + baseCharge);
        return priceA.compareTo(priceB);
      });
    }

    return list;
  }

  // --- Helper for Car Details ---
  Map<String, dynamic> _getCarSpecs(String carName) {
    String name = carName.toLowerCase();
    if (name.contains("hatchback")) {
      return {
        "seats": "4",
        "bags": "2",
        "type": "Economy",
        "models": "WagonR, Swift or similar",
        "desc": "Affordable rides in compact cars",
      };
    } else if (name.contains("sedan") || name.contains("dzire")) {
      return {
        "seats": "4",
        "bags": "3",
        "type": "Comfort",
        "models": "Dzire, Etios or similar",
        "desc": "Comfortable sedan ride",
      };
    } else if (name.contains("crysta")) {
      return {
        "seats": "7",
        "bags": "4",
        "type": "Luxury SUV",
        "models": "Innova Crysta or similar",
        "desc": "Premium luxury SUV ride",
      };
    } else if (name.contains("suv") ||
        name.contains("ertiga") ||
        name.contains("innova")) {
      return {
        "seats": "6",
        "bags": "3",
        "type": "Family SUV",
        "models": "Ertiga, Carens or similar",
        "desc": "Spacious family SUV ride",
      };
    }
    return {
      "seats": "4",
      "bags": "2",
      "type": "Standard",
      "models": "Standard Cab",
      "desc": "Reliable & comfortable ride",
    };
  }

  @override
  Widget build(BuildContext context) {
    final displayCars = _filteredCars;

    return Scaffold(
      backgroundColor: surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              "Select Your Ride",
              style: GoogleFonts.montserrat(
                color: darkCanvas,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (distance != "Calculating..." && distance.isNotEmpty)
              Text(
                distance,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: darkCanvas, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryAmber))
          : Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: (numericDistance < 50 && belowFifty)
                      ? _buildNoCarAvailableMessage()
                      : displayCars.isEmpty
                          ? _buildNoMatchingFilterMessage()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: displayCars.length,
                              itemBuilder: (context, index) {
                                final car = displayCars[index];
                                if (numericDistance > 200 &&
                                    car.name.toLowerCase() == "hatchback") {
                                  return const SizedBox.shrink();
                                }

                                double carTripFare = car.discountedPrice > 0
                                    ? car.discountedPrice
                                    : ((car.price * numericDistance * 1.05) + baseCharge);
                                double baselineFare = car.baseAmount > 0
                                    ? car.baseAmount
                                    : carTripFare;

                                double commissionWithTax = commissionAmount * 1.05;
                                double totalPrice = carTripFare + commissionWithTax;
                                double baselinePrice = baselineFare + commissionWithTax;
                                double partPay = totalPrice * 0.30;

                                return _buildModernCarCard(
                                  car: car,
                                  totalPrice: totalPrice,
                                  baselinePrice: baselinePrice,
                                  partPay: partPay,
                                  index: index,
                                );
                              },
                            ),
                ),
                if (userType == 'agent') _buildAgentCommissionInput(),
              ],
            ),
    );
  }

  Widget _buildFilterBar() {
    final List<Map<String, dynamic>> filters = [
      {"label": "All", "icon": Icons.apps_rounded},
      {"label": "Sedan", "icon": Icons.directions_car_rounded},
      {"label": "SUV", "icon": Icons.airport_shuttle_rounded},
      {"label": "Hatchback", "icon": Icons.electric_car_rounded},
      {"label": "4 Seater", "icon": Icons.people_alt_rounded},
      {"label": "6+ Seater", "icon": Icons.groups_rounded},
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: filters.map((f) {
            final String label = f['label'];
            final IconData icon = f['icon'];
            final bool isSelected = (selectedCategoryFilter == label);

            return GestureDetector(
              onTap: () {
                setState(() {
                  selectedCategoryFilter = label;
                  selectedCarIndex = 0; // reset selected index
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? darkCanvas : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? darkCanvas : Colors.grey.shade300,
                    width: 1.1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 13,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNoMatchingFilterMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              "No $selectedCategoryFilter cabs available",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => setState(() => selectedCategoryFilter = "All"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryAmber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text("Show All Cars", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCarCard({
    required Car car,
    required double totalPrice,
    required double baselinePrice,
    required double partPay,
    required int index,
  }) {
    final specs = _getCarSpecs(car.name);
    final double savings = baselinePrice - totalPrice;
    final bool hasDiscount = (savings > 0) || car.isDiscounted || (car.discountPercentage > 0);
    final bool isSelected = (selectedCarIndex == index);

    final String formattedTotal = totalPrice % 1 == 0
        ? totalPrice.toStringAsFixed(0)
        : totalPrice.toStringAsFixed(2);
    final String formattedBase = baselinePrice % 1 == 0
        ? baselinePrice.toStringAsFixed(0)
        : baselinePrice.toStringAsFixed(2);

    final String exactCarName = _formatCarName(car.name);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade200,
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isSelected ? 0.07 : 0.03),
            blurRadius: isSelected ? 12 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() => selectedCarIndex = index);
            _navigateToShowBill(car, totalPrice, partPay);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Left: Vehicle image (comfortably sized at 88x64)
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: car.imageUrl.isNotEmpty
                          ? Image.network(
                              car.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.directions_car_filled_rounded,
                                color: primaryAmber,
                                size: 38,
                              ),
                            )
                          : Icon(
                              Icons.directions_car_filled_rounded,
                              color: primaryAmber,
                              size: 38,
                            ),
                    ),
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Icon(
                        Icons.ac_unit_rounded,
                        size: 12,
                        color: Colors.blueGrey.shade400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // 2. Middle Column: Exact Car Name, Models, Clean Specs
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Line 1: Exact Database Car Name + Passenger capacity
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              exactCarName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: darkCanvas,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person, size: 14, color: Colors.grey.shade700),
                              Text(
                                " ${specs['seats']}",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Line 2: Models (e.g. "Dzire, Etios or similar")
                      Text(
                        specs['models'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Line 3: Clean Specs (AC • Bags • Distance)
                      Text(
                        "AC ❄️ • ${specs['bags']} Bags${car.packageKm > 0 ? ' • ${car.packageKm} KM' : ''}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 3. Right Column: Price & Strikethrough & Perfect GST Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Line 1: Orange tag icon + Bold Fare
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasDiscount && savings > 0) ...[
                          const Icon(
                            Icons.local_offer_rounded,
                            size: 14,
                            color: Color(0xFFF05A28),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          "₹$formattedTotal",
                          style: GoogleFonts.montserrat(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: darkCanvas,
                          ),
                        ),
                      ],
                    ),

                    // Line 2: Strikethrough baseline fare if discounted
                    if (hasDiscount && savings > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        "₹$formattedBase",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    // Line 3: Prominent & Perfect "GST Included" Pill Badge
                    if (car.gstActive && car.gstPercent > 0) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF81C784),
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 10,
                              color: Colors.green.shade800,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              "GST Included",
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade800,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAgentCommissionInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: TextField(
        controller: _commissionController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (value) =>
            setState(() => commissionAmount = double.tryParse(value) ?? 0.0),
        decoration: InputDecoration(
          labelText: "Agent Commission (Optional)",
          prefixIcon: Icon(Icons.add_moderator, color: primaryAmber),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: surfaceLight,
        ),
      ),
    );
  }

  Widget _buildNoCarAvailableMessage() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          Icon(Icons.error_outline_rounded,
              size: 80, color: Colors.red.shade200),
          const SizedBox(height: 20),
          Text("No Service Available",
              style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade400)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            child: Text(
                "Distance is less than 50km. Please choose Local Taxi or Hourly Rental.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _navigateToShowBill(Car car, double totalPrice, double partPay) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShowBillPage(
          fromAddress: fromAddress,
          toAddress: toAddress,
          carType: car.name,
          distance: car.packageKm > 0 ? car.packageKm : numericDistance.toInt(),
          baseCharge: car.baseAmount > 0 ? car.baseAmount : baseCharge,
          driverTa: car.driverAllowance,
          tollCharge: car.tollCharge,
          totalAmount: totalPrice,
          date: date,
          tripTime: time,
          commission: commissionAmount,
          partPay: partPay,
          bookingId: bookingId ?? "",
          discountedPrice: car.discountedPrice,
        ),
      ),
    );
  }
}
