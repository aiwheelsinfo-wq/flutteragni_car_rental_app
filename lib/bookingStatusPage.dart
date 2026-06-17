import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'bottom_nav_bar.dart';
import 'car_invoice.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:agni_car_rental/config/api_config.dart';
import 'DriverToPickupMap.dart';

class BookingStatusPage extends StatefulWidget {
  @override
  _BookingStatusPageState createState() => _BookingStatusPageState();
}

class _BookingStatusPageState extends State<BookingStatusPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> upcomingBookings = [];
  List<dynamic> pastBookings = [];
  Map<int, int> bookingDiscounts = {};

  bool isLoading = true;
  bool hasError = false;
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  String? phoneNumber;
  Timer? _timer;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPhoneNumber();
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (phoneNumber != null) fetchBookings(phoneNumber!);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPhoneNumber() async {
    String? savedNumber = await secureStorage.read(key: 'phone_number');
    if (savedNumber != null) {
      setState(() => phoneNumber = savedNumber);
      fetchBookings(savedNumber);
      fetchDiscountFromLocalStorage(savedNumber);
    }
  }

  Future<void> fetchBookings(String phone_number) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/bookingStatus.php?phone_number=$phone_number'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        if (jsonResponse["status"] == "success") {
          _separateAndSortBookings(jsonResponse["data"]);
          setState(() {
            isLoading = false;
            hasError = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  void _separateAndSortBookings(List<dynamic> data) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    List<dynamic> upcoming = [];
    List<dynamic> past = [];

    for (var b in data) {
      if (b['booking_status'] == 'Deleted') continue;
      DateTime bDate = DateTime.parse(b['date']);
      if (b['booking_status'] == 'Completed' ||
          b['booking_status'] == 'Cancelled' ||
          b['booking_status'] == 'Declined' ||
          bDate.isBefore(today)) {
        past.add(b);
      } else {
        upcoming.add(b);
      }
    }
    upcoming.sort((a, b) => a['date'].compareTo(b['date']));
    past.sort((a, b) => b['date'].compareTo(a['date']));

    setState(() {
      upcomingBookings = upcoming;
      pastBookings = past;
    });
  }

  Future<void> fetchDiscountFromLocalStorage(String phone) async {
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/5trips_trackor.php?booker_id=$phone'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          bookingDiscounts.clear();
          for (var b in data['bookings']) {
            bookingDiscounts[b['id']] = (b['discount_percent'] ?? 0).toInt();
          }
          setState(() {});
        }
      }
    } catch (e) {}
  }

  Future<Map<String, dynamic>?> fetchDriverDetails(String driverId) async {
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/driverDetails.php?driver_id=$driverId'));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json["status"] == "success" ? json["data"] : null;
      }
    } catch (e) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.yellow[700],
        elevation: 0,
        title: Text('Trip Status',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 18)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => BottomNavBar())),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 20),
          labelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle:
              GoogleFonts.poppins(fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: "UPCOMING"),
            Tab(text: "HISTORY"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTripList(upcomingBookings, false),
                _buildTripList(pastBookings, true),
              ],
            ),
    );
  }

  Widget _buildTripList(List<dynamic> bookings, bool isPast) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_outlined,
                size: 100, color: Colors.amber.withOpacity(0.1)),
            const SizedBox(height: 16),
            Text("No trips scheduled yet",
                style:
                    GoogleFonts.poppins(color: Colors.grey[400], fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return FutureBuilder<Map<String, dynamic>?>(
          future: fetchDriverDetails(booking['driver_id']?.toString() ?? ''),
          builder: (context, snapshot) =>
              _buildProfessionalCard(booking, snapshot.data, isPast),
        );
      },
    );
  }

  Widget _buildProfessionalCard(
      dynamic booking, Map<String, dynamic>? driver, bool isPast) {
    String status = booking['booking_status'] ?? 'Pending';
    int discount = bookingDiscounts[booking['id']] ?? 0;
    bool isToday =
        booking['date'] == DateTime.now().toString().substring(0, 10);

    double finalPrice = double.tryParse(booking['total_amount']?.toString() ?? '0') ?? 0.0;
    double savings = 0.0;
    if (discount > 0 && discount < 100) {
      double originalPrice = finalPrice / (1 - (discount / 100.0));
      savings = originalPrice - finalPrice;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          // 1. Status & Header Row
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Trip ID #${booking['id']}",
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[400])),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.amber[800]),
                        const SizedBox(width: 6),
                        Text("${booking['date']} • ${booking['time']}",
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87)),
                      ],
                    ),
                  ],
                ),
                _buildStatusBadge(status),
              ],
            ),
          ),

          // 2. Journey Timeline
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const Icon(Icons.radio_button_checked,
                        size: 20, color: Colors.amber),
                    Container(width: 2, height: 40, color: Colors.grey[200]),
                    Icon(Icons.location_on, size: 20, color: Colors.red[400]),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking['from_address'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 35),
                      Text(booking['to_address'] ?? 'Local Duty',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("₹${booking['total_amount']}",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Colors.yellow[800])),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(booking['car_type'],
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                    )
                  ],
                )
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. OTP High-Visibility Bar (Upcoming Only)
          if (!isPast && status != 'Cancelled') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.amber[400],
                // borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.vpn_key,
                          size: 18, color: Colors.black87),
                      const SizedBox(width: 8),
                      Text("DRIVER OTP",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              color: Colors.black87)),
                    ],
                  ),
                  Text(booking['otp'].toString(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          letterSpacing: 4,
                          color: Colors.black87)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("⚠️", style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "For your safety, do not share the OTP with anyone until the driver arrives at your pickup location. The OTP should only be provided to the driver when you are ready to start the trip.",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 4. Driver Info / Actions Footer
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (driver != null && !isPast) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.amber[50],
                        child: Icon(Icons.person, color: Colors.amber[800]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driver['full_name'],
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                                booking['vehicle_id'] ??
                                    'Allocating Vehicle...',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _makePhoneCall(driver['phone_number']),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.green[50], shape: BoxShape.circle),
                          child: const Icon(Icons.call,
                              color: Colors.green, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                ],
                Row(
                  children: [
                    if (!isPast && isToday)
                      Expanded(
                        child: _actionButton(
                            "Track Driver",
                            Icons.map_outlined,
                            Colors.blue[700]!,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        DriverToPickupMapYellowFinalV2(
                                            driverId:
                                                driver?['phone_number'] ?? '',
                                            bookingId:
                                                booking['id'].toString())))),
                      ),
                    if (isPast && status == 'Completed')
                      Expanded(
                        child: _actionButton(
                            "Download Invoice",
                            Icons.receipt_long_outlined,
                            Colors.yellow[800]!,
                            () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => InvoicePage(
                                        bookingId: booking['id'].toString())))),
                      ),
                  ],
                ),
                if (discount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.shade50, const Color(0xFFF3E5F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple.shade100, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.loyalty, color: Colors.purple, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Loyalty Discount Applied!",
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple.shade900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Saved ₹${savings.toStringAsFixed(0)} with your $discount% customer benefit",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "-$discount%",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback tap) {
    return ElevatedButton.icon(
      onPressed: tap,
      icon: Icon(icon, size: 18),
      label:
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    if (status == 'Completed') color = Colors.green;
    if (status == 'Accepted') color = Colors.blue;
    if (status == 'Cancelled' || status == 'Declined') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Future<void> _makePhoneCall(String num) async {
    final Uri uri = Uri.parse('tel:$num');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
