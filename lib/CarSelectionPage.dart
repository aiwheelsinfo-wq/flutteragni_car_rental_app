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
  final double price;

  Car({required this.name, required this.price});

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      name: json['carType'],
      price: double.tryParse(json['kmRate'].toString()) ?? 0.0,
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
    _getDistanceFromGoogle(fromAddress, toAddress);
    fetchCars(fromLat: fromLat, fromLng: fromLng, toLat: toLat, toLng: toLng);
    fetchDiscount();
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
    try {
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/selectCarCostList.php?tripType=One-way&bookingId=$bookingId&fromLat=$fromLat&fromLng=$fromLng&toLat=$toLat&toLng=$toLng');
      final response = await http.get(uri);
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

  Future<void> _getDistanceFromGoogle(String from, String to) async {
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
          driverTa = (numericDistance < 200) ? 300 : 400;
          tollCharge = numericDistance * 2.25;
          baseCharge = driverTa + tollCharge;
          belowFifty = false;
        });
      }
    } catch (e) {
      setState(() => numericDistance = 1);
    }
  }

  // --- Helper for Car Details ---
  Map<String, dynamic> _getCarSpecs(String carName) {
    String name = carName.toLowerCase();
    if (name.contains("hatchback")) {
      return {"seats": "3+1", "bags": "2", "type": "Economy"};
    } else if (name.contains("sedan") || name.contains("dzire")) {
      return {"seats": "3+1", "bags": "3", "type": "Comfort"};
    } else if (name.contains("suv") ||
        name.contains("ertiga") ||
        name.contains("innova") ||
        name.contains("crysta")) {
      return {"seats": "6+1", "bags": "4", "type": "Premium"};
    }
    return {"seats": "3+1", "bags": "2", "type": "Standard"};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text("Select Your Ride",
            style: GoogleFonts.montserrat(
                color: darkCanvas, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: darkCanvas, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryAmber))
          : Column(
              children: [
                _buildRouteSummary(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount:
                        (numericDistance < 50 && belowFifty) ? 1 : cars.length,
                    itemBuilder: (context, index) {
                      if (numericDistance < 50 && belowFifty)
                        return _buildNoCarAvailableMessage();

                      final car = cars[index];
                      // Logic checks
                      if (numericDistance > 200 &&
                          car.name.toLowerCase() == "hatchback")
                        return const SizedBox.shrink();

                      double standardPrice = (car.price * numericDistance * 1.05) +
                          baseCharge +
                          (commissionAmount * 1.05);
                      double partPay = (car.price * numericDistance * 0.20) +
                          (commissionAmount * 1.05);
                      
                      double savings = 0.0;
                      if (discountValue > 0) {
                        if (discountType == 'fixed') {
                          savings = discountValue;
                        } else {
                          savings = standardPrice * (discountValue / 100);
                        }
                      }
                      
                      double totalPrice = (standardPrice - savings) < 0 ? 0.0 : (standardPrice - savings);
                      double discountedPrice = standardPrice;

                      return _buildModernCarCard(
                        car: car,
                        totalPrice: totalPrice,
                        discountedPrice: discountedPrice,
                        partPay: partPay,
                      );
                    },
                  ),
                ),
                if (userType == 'agent') _buildAgentCommissionInput(),
              ],
            ),
    );
  }

  Widget _buildRouteSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  Icon(Icons.radio_button_checked,
                      color: primaryAmber, size: 16),
                  Container(width: 2, height: 30, color: Colors.grey[200]),
                  const Icon(Icons.location_on,
                      color: Colors.redAccent, size: 16),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fromAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 22),
                    Text(toAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoBadge(Icons.straighten, distance),
              _infoBadge(Icons.calendar_month, "$date | $time"),
            ],
          )
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: accentYellow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: primaryAmber),
          const SizedBox(width: 8),
          Text(text,
              style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildModernCarCard(
      {required Car car,
      required double totalPrice,
      required double discountedPrice,
      required double partPay}) {
    final specs = _getCarSpecs(car.name);
    final double savings = discountedPrice - totalPrice;

    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: primaryAmber,
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(15))),
                child: Text(specs['type'].toString().toUpperCase(),
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToShowBill(car.name, totalPrice, partPay),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 75,
                            height: 75,
                            decoration: BoxDecoration(
                                color: accentYellow.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(18)),
                            child: Icon(Icons.directions_car_filled_rounded,
                                color: primaryAmber, size: 45),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(car.name.toUpperCase(),
                                    style: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: darkCanvas)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _specItem(Icons.person, specs['seats']),
                                    const SizedBox(width: 12),
                                    _specItem(Icons.luggage, specs['bags']),
                                    const SizedBox(width: 12),
                                    _specItem(Icons.ac_unit, "AC"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Divider(height: 1, thickness: 0.5)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text("₹${totalPrice.toStringAsFixed(0)}",
                                      style: GoogleFonts.poppins(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700)),
                                  if (savings > 0) ...[
                                    const SizedBox(width: 8),
                                    Text("₹${discountedPrice.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                            decoration:
                                                TextDecoration.lineThrough)),
                                  ],
                                ],
                              ),
                              Text("Inclusive of Driver TA & Tolls",
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                          if (savings > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFF8E1), // light amber/gold
                                    Color(0xFFFFECB3), // slightly deeper amber/gold
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFD54F), // accent yellow/gold border
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFB300).withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.stars_rounded,
                                    color: Color(0xFFFF8F00), // dark amber/orange gold
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "SAVE ₹${savings.toStringAsFixed(0)}",
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFE65100), // deep warm orange/gold
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        discountType == 'fixed'
                                            ? "$discountName ₹${discountValue.toStringAsFixed(0)} OFF"
                                            : "$discountName ${discountValue.toStringAsFixed(0)}% OFF",
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFFF6F00),
                                          fontSize: 8,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _specItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500)),
      ],
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
                "Distance is less than 50km. Please choose Local Taxi or Local Duty.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _navigateToShowBill(String carName, double totalPrice, double partPay) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShowBillPage(
          fromAddress: fromAddress,
          toAddress: toAddress,
          carType: carName,
          distance: numericDistance.toInt(),
          baseCharge: baseCharge,
          driverTa: driverTa,
          tollCharge: tollCharge,
          totalAmount: totalPrice,
          date: date,
          tripTime: time,
          commission: commissionAmount,
          partPay: partPay,
          bookingId: bookingId ?? "",
        ),
      ),
    );
  }
}
