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

  Car({
    required this.name,
    required this.price,
    required this.gstPercent,
    required this.driverAllowance,
    required this.kmPerDay,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      name: json['carType'],
      price: double.tryParse(json['kmRate'].toString()) ?? 0.0,
      gstPercent: double.tryParse(json['gstPercent'].toString()) ?? 0.0,
      driverAllowance:
          double.tryParse(json['driverAllowance'].toString()) ?? 0.0,
      kmPerDay: double.tryParse(json['kmPerDay'].toString()) ?? 0.0,
    );
  }
}

class Roundtripcarselection extends StatefulWidget {
  const Roundtripcarselection({Key? key}) : super(key: key);

  @override
  State<Roundtripcarselection> createState() => _RoundtripcarselectionState();
}

class _RoundtripcarselectionState extends State<Roundtripcarselection> {
  // Theme Colors
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color secondaryYellow = const Color(0xFFFFD54F);
  final Color darkBg = const Color(0xFF121212);
  final Color cardBg = Colors.white;

  List<Car> cars = [];
  bool isLoading = true;
  bool message = false;
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  String? savedNumber;
  int? discount;

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

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    final String from = args['from'] ?? '';
    final String to = args['to'] ?? '';
    final String departureDate = args['departure_date'] ?? '';
    final String returnDate = args['return_date'] ?? '';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 238, 232, 219),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: darkBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Choose Your Ride",
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryAmber))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildTripItineraryHeader(
                      from, to, departureDate, returnDate),
                  if (message) _buildPromoBanner(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          "Available Options",
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: darkBg),
                        ),
                        const SizedBox(height: 10),
                        ...cars.map((car) => _buildCarCard(car, args)).toList(),
                        const SizedBox(height: 30),
                        _buildSafeTravelInfo(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTripItineraryHeader(
      String from, String to, String dep, String ret) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkBg,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, color: Colors.amber, size: 40),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$from → $to",
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text("Dates: $dep to $ret",
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white12, borderRadius: BorderRadius.circular(10)),
            child:
                const Icon(Icons.edit_calendar, color: Colors.white, size: 20),
          )
        ],
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryAmber, secondaryYellow]),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: primaryAmber.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.white, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Special Loyalty Discount!",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text("You are getting $discount% OFF on this booking.",
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCarCard(Car car, Map args) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RoundTripShowBill(
              from: args['from'],
              to: args['to'],
              departureDate: args['departure_date'],
              departureTime: args['departure_time'],
              returnDate: args['return_date'],
              returnTime: args['return_time'],
              selectedCar: car.name,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.directions_car,
                        color: primaryAmber, size: 35),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(car.name,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        Text("${car.kmPerDay} KM/day limit",
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("₹${car.price}",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: darkBg)),
                      Text("/KM",
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  )
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  _rowDetail(Icons.person, "Driver Allowance",
                      "₹${car.driverAllowance}/day"),
                  const Divider(),
                  _rowDetail(
                      Icons.receipt_long, "GST", "${car.gstPercent}% Included"),
                  const Divider(),
                  _rowDetail(
                      Icons.info_outline, "Terms", "Garage-to-Garage billing"),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _badge("Sanitized"),
                      _badge("Professional Driver"),
                      _badge("24/7 Support"),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _rowDetail(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(title,
            style:
                GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.bold, color: darkBg)),
      ],
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSafeTravelInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Text("Why Rentox Car Rental?",
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          _bulletPoint("No hidden charges, Toll & Parking extra at actuals."),
          _bulletPoint("Verified & experienced highway drivers."),
          _bulletPoint("Well maintained & cleaned fleet."),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.amber, size: 14),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white70, fontSize: 11))),
        ],
      ),
    );
  }
}
