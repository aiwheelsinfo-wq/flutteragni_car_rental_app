import 'package:flutter/material.dart';
import 'roundTripBillPage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agni_car_rental/config/api_config.dart';

class Car {
  final String name;
  final double price;
  final double gstPercent;
  final double driverAllowance;
  final double kmPerDay;
  final String imageUrl;

  Car({
    required this.name,
    required this.price,
    required this.gstPercent,
    required this.driverAllowance,
    required this.kmPerDay,
    this.imageUrl = '',
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      name: json['carType']?.toString() ?? '',
      price: double.tryParse(json['kmRate']?.toString() ?? '0') ?? 0.0,
      gstPercent: double.tryParse(json['gstPercent']?.toString() ?? '5') ?? 5.0,
      driverAllowance:
          double.tryParse(json['driverAllowance']?.toString() ?? '400') ?? 400.0,
      kmPerDay: double.tryParse(json['kmPerDay']?.toString() ?? '0') ?? 0.0,
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString() ?? '',
    );
  }
}

class Roundtripcarselection extends StatefulWidget {
  const Roundtripcarselection({Key? key}) : super(key: key);

  @override
  State<Roundtripcarselection> createState() => _RoundtripcarselectionState();
}

class _RoundtripcarselectionState extends State<Roundtripcarselection> {
  // Theme Colors matching Rentox design system
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color secondaryYellow = const Color(0xFFFFD54F);
  final Color darkCanvas = const Color(0xFF1A1A1A);
  final Color surfaceLight = const Color(0xFFF8F9FA);

  List<Car> cars = [];
  bool isLoading = true;
  bool message = false;
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  String? savedNumber;
  int? discount;

  int selectedCarIndex = 0;
  String selectedCategoryFilter = "All";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      fetchDiscountFromLocalStorage();
      fetchCars();
    }
  }

  Future<void> fetchDiscountFromLocalStorage() async {
    try {
      savedNumber = await secureStorage.read(key: 'phone_number');
      final url =
          '${ApiConfig.baseUrl}/5trips_trackor.php?booker_id=$savedNumber';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          message = data['success'] ?? false;
          discount = (data['discount_percent'] ?? 0).toInt();
        });
      }
    } catch (e) {
      debugPrint("Discount Error: $e");
    }
  }

  Future<void> fetchCars() async {
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/selectCarCostList.php?tripType=Round-Trip'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          cars = data.map((item) => Car.fromJson(item)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
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
      };
    } else if (name.contains("sedan") || name.contains("dzire")) {
      return {
        "seats": "4",
        "bags": "3",
        "type": "Comfort",
        "models": "Dzire, Etios or similar",
      };
    } else if (name.contains("crysta")) {
      return {
        "seats": "7",
        "bags": "4",
        "type": "Luxury SUV",
        "models": "Innova Crysta or similar",
      };
    } else if (name.contains("suv") ||
        name.contains("ertiga") ||
        name.contains("innova")) {
      return {
        "seats": "6",
        "bags": "3",
        "type": "Family SUV",
        "models": "Ertiga, Carens or similar",
      };
    }
    return {
      "seats": "4",
      "bags": "2",
      "type": "Standard",
      "models": "Standard Cab",
    };
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

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args =
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?) ?? {};
    final String from = args['from'] ?? '';
    final String to = args['to'] ?? '';
    final String departureDate = args['departure_date'] ?? '';
    final String returnDate = args['return_date'] ?? '';

    final displayCars = _filteredCars;

    return Scaffold(
      backgroundColor: surfaceLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: darkCanvas, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
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
            if (from.isNotEmpty && to.isNotEmpty)
              Text(
                departureDate.isNotEmpty && returnDate.isNotEmpty
                    ? "$from → $to ($departureDate - $returnDate)"
                    : "$from → $to",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryAmber))
          : Column(
              children: [
                _buildFilterBar(),
                if (message && discount != null && discount! > 0)
                  _buildPromoBanner(),
                Expanded(
                  child: displayCars.isEmpty
                      ? _buildNoMatchingFilterMessage()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: displayCars.length + 1, // +1 for Safe Travel footer
                          itemBuilder: (context, index) {
                            if (index == displayCars.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 20),
                                child: _buildSafeTravelInfo(),
                              );
                            }

                            final car = displayCars[index];
                            return _buildModernCarCard(car, args, index);
                          },
                        ),
                ),
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
                  selectedCarIndex = 0;
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

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: Color(0xFFFF8F00), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Special Loyalty Discount: You are getting $discount% OFF on this booking!",
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE65100),
              ),
            ),
          ),
        ],
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

  Widget _buildModernCarCard(Car car, Map args, int index) {
    final specs = _getCarSpecs(car.name);
    final bool isSelected = (selectedCarIndex == index);
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RoundTripShowBill(
                  from: args['from'] ?? '',
                  to: args['to'] ?? '',
                  departureDate: args['departure_date'] ?? '',
                  departureTime: args['departure_time'] ?? '',
                  returnDate: args['return_date'] ?? '',
                  returnTime: args['return_time'] ?? '',
                  selectedCar: car.name,
                  kmPerDay: car.kmPerDay,
                  kmRate: car.price,
                  driverAllowance: car.driverAllowance,
                  gstPercent: car.gstPercent,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top Section: Image + Info + Rate
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: Vehicle image
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
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
                                    size: 36,
                                  ),
                                )
                              : Icon(
                                  Icons.directions_car_filled_rounded,
                                  color: primaryAmber,
                                  size: 36,
                                ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Icon(
                            Icons.ac_unit_rounded,
                            size: 11,
                            color: Colors.blueGrey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Middle Column: Exact Name, Models, Min KM
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Line 1: Exact Car Name + Seats
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  exactCarName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15.5,
                                    color: darkCanvas,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person, size: 13, color: Colors.grey.shade700),
                                  Text(
                                    " ${specs['seats']}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),

                          // Line 2: Models
                          Text(
                            specs['models'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Line 3: Min KM/day
                          Text(
                            "Min ${car.kmPerDay.toInt()} KM/day • AC ❄️",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Right Column: Rate / KM & GST Badge
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              "₹${car.price.toStringAsFixed(0)}",
                              style: GoogleFonts.montserrat(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: darkCanvas,
                              ),
                            ),
                            Text(
                              "/KM",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF81C784),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 9.5,
                                color: Colors.green.shade800,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                car.gstPercent > 0 ? "GST ${car.gstPercent.toInt()}%" : "GST Included",
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade800,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // 2. Full-Width Bottom Strip for Driver Allowance (Zero Overflow)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1), // soft amber
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFFE082),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.badge_outlined,
                        size: 13,
                        color: Color(0xFFE65100),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "Driver Allowance: ",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF5D4037),
                        ),
                      ),
                      Text(
                        "₹${car.driverAllowance.toInt()}/day",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFE65100),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "Toll extra",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafeTravelInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: primaryAmber, size: 20),
              const SizedBox(width: 8),
              Text(
                "Why Rentox Car Rental?",
                style: GoogleFonts.montserrat(
                  color: darkCanvas,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bulletPoint("No hidden charges, Toll & Parking extra at actuals."),
          _bulletPoint("Verified & experienced highway drivers."),
          _bulletPoint("Well maintained & sanitized fleet with 24/7 support."),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, color: primaryAmber, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
