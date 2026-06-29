import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'bottom_nav_bar.dart';
import 'car_invoice.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:agni_car_rental/config/api_config.dart';
import 'DriverToPickupMap.dart';
import 'package:share_plus/share_plus.dart';
import 'cancellationSuccessPage.dart';

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
      
      // Parse date safely as local date to prevent timezone shifts (e.g. UTC-offset device showing today's trips in Past tab)
      DateTime bDate;
      try {
        List<String> dateParts = b['date'].toString().split('-');
        if (dateParts.length == 3) {
          bDate = DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
          );
        } else {
          bDate = DateTime.parse(b['date'].toString()).toLocal();
        }
      } catch (_) {
        bDate = DateTime.now();
      }

      if (b['booking_status'] == 'Completed' ||
          b['booking_status'] == 'Cancelled' ||
          b['booking_status'] == 'Customer Cancelled' ||
          b['booking_status'] == 'Cancellation Requested' ||
          b['booking_status'] == 'Declined' ||
          b['booking_status'] == 'Failed' ||
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

  Future<String> _getDriverAddress(double lat, double lng) async {
    const String apiKey = "AIzaSyC41U3p08LqY8G15ruxDCEfTvBLkG_OrsM";
    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey";
    try {
      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);
      if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
        final result = data['results'][0];
        return result['formatted_address'] ?? "Unknown Location";
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
    }
    return "Location not available";
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
              _buildProfessionalCard(context, booking, snapshot.data, isPast),
        );
      },
    );
  }

  Widget _buildProfessionalCard(
      BuildContext context, dynamic booking, Map<String, dynamic>? driver, bool isPast) {
    String status = booking['booking_status'] ?? 'Pending';
    if (status == 'Pending' && (booking['trip_type'] ?? '') == 'Round-Trip') {
      status = 'Confirmed';
    }
    
    // Try to get discount from the booking record (dynamic database discount),
    // fallback to bookingDiscounts (5 trips Loyalty tracker)
    double dbDiscountPercent = double.tryParse(booking['discount_percentage']?.toString() ?? '0') ?? 0.0;
    int discount = dbDiscountPercent > 0 
        ? dbDiscountPercent.toInt() 
        : (bookingDiscounts[booking['id']] ?? 0);
        
    String discountName = booking['discount_name'] ?? 'Loyalty';
    bool isToday =
        booking['date'] == DateTime.now().toString().substring(0, 10);

    double finalPrice = double.tryParse(booking['total_amount']?.toString() ?? '0') ?? 0.0;
    double discountedPrice = double.tryParse(booking['discounted_price']?.toString() ?? '0') ?? 0.0;
    double savings = 0.0;
    
    if (discountedPrice > finalPrice) {
      savings = discountedPrice - finalPrice;
    } else if (discount > 0 && discount < 100) {
      double originalPrice = finalPrice / (1 - (discount / 100.0));
      savings = originalPrice - finalPrice;
    }

    String registrationNumber = 'Allocating...';
    if (booking['vehicle_id'] != null && booking['vehicle_id'].toString().trim().isNotEmpty) {
      registrationNumber = booking['vehicle_id'].toString().trim();
    } else if (driver != null && driver['vehicle_id'] != null && driver['vehicle_id'].toString().trim().isNotEmpty) {
      registrationNumber = driver['vehicle_id'].toString().trim();
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
                Expanded(
                  child: Column(
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
                          Expanded(
                            child: Text("${booking['date']} • ${booking['time']}",
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
                    Builder(builder: (context) {
                      // For Round-Trip completed: calculate actual total dynamically
                      if ((booking['trip_type'] ?? '') == 'Round-Trip' && status == 'Completed') {
                        int rtDays = 1;
                        try {
                          final s = booking['date']?.toString() ?? '';
                          final r = booking['return_date']?.toString() ?? '';
                          if (s.isNotEmpty && r.isNotEmpty && s != '0000-00-00' && r != '0000-00-00') {
                            try {
                              rtDays = DateFormat('dd MMM yyyy').parse(r).difference(DateFormat('dd MMM yyyy').parse(s)).inDays + 1;
                            } catch (_) {
                              rtDays = DateTime.parse(r).difference(DateTime.parse(s)).inDays + 1;
                            }
                          }
                        } catch (_) {}
                        if (rtDays <= 0) rtDays = 1;
                        double rtDailyLimit = double.tryParse(booking['daily_limit']?.toString() ?? '0') ?? 0.0;
                        double rtStartKm = double.tryParse(booking['starting_km']?.toString() ?? '0') ?? 0.0;
                        double rtCloseKm = double.tryParse(booking['closing_km']?.toString() ?? '0') ?? 0.0;
                        double rtRunKm = (rtCloseKm - rtStartKm).clamp(0, double.infinity);
                        double rtMaxKm = max(rtRunKm, rtDailyLimit * rtDays);
                        double rtKmRate = double.tryParse(booking['kmRate']?.toString() ?? '0') ?? 0.0;
                        double rtComm = double.tryParse(booking['agent_commission']?.toString() ?? '0') ?? 0.0;
                        double rtCommRate = (rtComm > 0 && rtDays > 0 && rtDailyLimit > 0) ? (rtComm / (rtDailyLimit * rtDays)).roundToDouble() : 0.0;
                        double rtBase = rtMaxKm * (rtKmRate + rtCommRate);
                        double rtGstPct = double.tryParse(booking['gstPercent']?.toString() ?? '0') ?? 0.0;
                        double rtGst = rtBase * rtGstPct / 100;
                        double rtPark = double.tryParse(booking['parking_charge']?.toString() ?? '0') ?? 0.0;
                        double rtToll = double.tryParse(booking['toll_charge']?.toString() ?? '0') ?? 0.0;
                        double rtPermit = double.tryParse(booking['permit_charge']?.toString() ?? '0') ?? 0.0;
                        double rtAllowDay = double.tryParse(booking['driver_allowance']?.toString() ?? '0') ?? 0.0;
                        double rtNet = rtBase + rtGst + rtPark + rtToll + rtPermit + (rtAllowDay * rtDays);
                        return Text("₹${rtNet.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: Colors.yellow[800]));
                      }
                      // For non-Round-Trip or non-Completed: show stored total_amount
                      if ((booking['trip_type'] ?? '') != 'Round-Trip' || status == 'Completed') {
                        return Text("₹${booking['total_amount']}",
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: Colors.yellow[800]));
                      }
                      return const SizedBox.shrink();
                    }),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(booking['car_type'],
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600])),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade200, width: 0.5)),
                      child: Text(booking['trip_type'] ?? '',
                          style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[900])),
                    ),
                    // ── Round-trip ₹/km compact pill ──
                    if ((booking['trip_type'] ?? '') == 'Round-Trip' &&
                        booking['kmRate'] != null) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF8F00),
                              const Color(0xFFFFB300),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          "₹${booking['kmRate']}/km",
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              ],
            ),
          ),

          if (booking['booking_status'] == 'Cancelled' || 
              booking['booking_status'] == 'Customer Cancelled' || 
              booking['booking_status'] == 'Cancellation Requested') ...[
            _buildCancellationDetailsCard(booking),
            _buildCancellationTimeline(booking),
            const SizedBox(height: 20),
          ] else ...[
            if (booking['payment_type'] == 'Advance') ...[
              Builder(
                builder: (context) {
                  double totalFare = double.tryParse(booking['total_amount']?.toString() ?? '0') ?? 0.0;
                  if ((booking['trip_type'] ?? '') == 'Round-Trip') {
                    double advancePaid = double.tryParse(booking['paid_amount']?.toString() ?? '') ??
                                         double.tryParse(booking['total_amount']?.toString() ?? '') ?? 0.0;

                    // Calculate days from booked dates
                    int days = 1;
                    try {
                      final bStartStr = booking['date']?.toString() ?? '';
                      final bReturnStr = booking['return_date']?.toString() ?? '';
                      if (bStartStr.isNotEmpty && bReturnStr.isNotEmpty && bStartStr != '0000-00-00' && bReturnStr != '0000-00-00') {
                        try {
                          final bStart = DateFormat('dd MMM yyyy').parse(bStartStr);
                          final bReturn = DateFormat('dd MMM yyyy').parse(bReturnStr);
                          days = bReturn.difference(bStart).inDays + 1;
                        } catch (_) {
                          final bStart = DateTime.parse(bStartStr);
                          final bReturn = DateTime.parse(bReturnStr);
                          days = bReturn.difference(bStart).inDays + 1;
                        }
                      }
                    } catch (_) {}
                    if (days <= 0) days = 1;

                    // Calculate remaining balance dynamically (same logic as invoice)
                    double dailyLimit = double.tryParse(booking['daily_limit']?.toString() ?? '0') ?? 0.0;
                    double startingKm = double.tryParse(booking['starting_km']?.toString() ?? '0') ?? 0.0;
                    double closingKm = double.tryParse(booking['closing_km']?.toString() ?? '0') ?? 0.0;
                    double runningKm = (closingKm - startingKm).clamp(0, double.infinity);
                    double maxKm = max(runningKm, dailyLimit * days);

                    double kmRate = double.tryParse(booking['kmRate']?.toString() ?? '0') ?? 0.0;
                    double agentCommission = double.tryParse(booking['agent_commission']?.toString() ?? '0') ?? 0.0;
                    double commissionRate = 0.0;
                    if (agentCommission > 0 && days > 0 && dailyLimit > 0) {
                      commissionRate = (agentCommission / (dailyLimit * days)).roundToDouble();
                    }
                    double effectiveKmRate = kmRate + commissionRate;
                    double baseAmount = maxKm * effectiveKmRate;

                    double gstPercent = double.tryParse(booking['gstPercent']?.toString() ?? '0') ?? 0.0;
                    double gst = baseAmount * gstPercent / 100;
                    double parking = double.tryParse(booking['parking_charge']?.toString() ?? '0') ?? 0.0;
                    double toll = double.tryParse(booking['toll_charge']?.toString() ?? '0') ?? 0.0;
                    double permit = double.tryParse(booking['permit_charge']?.toString() ?? '0') ?? 0.0;
                    double driverAllowancePerDay = double.tryParse(booking['driver_allowance']?.toString() ?? '0') ?? 0.0;
                    double totalDriverAllowance = driverAllowancePerDay * days;

                    double netTotal = baseAmount + gst + parking + toll + permit + totalDriverAllowance;
                    double remaining = netTotal - advancePaid;

                    bool isCompleted = (booking['booking_status'] ?? '') == 'Completed';
                    String balanceText = isCompleted
                        ? "₹${remaining.toStringAsFixed(2)}"
                        : "₹${remaining.toStringAsFixed(2)} (Est.)";

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.shade200, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Advance Paid",
                                    style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[800])),
                                const SizedBox(height: 2),
                                Text("₹${advancePaid.toStringAsFixed(2)}",
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800])),
                              ],
                            ),
                            Container(width: 1, height: 30, color: Colors.green.shade200),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(isCompleted ? "Balance Due" : "Est. Balance",
                                    style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600])),
                                const SizedBox(height: 2),
                                Text(balanceText,
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: remaining > 0 ? Colors.red[700] : Colors.green[700])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    bool isLocalDuty = (booking['trip_type'] ?? '').toString().toLowerCase().contains('local-duty') || 
                                       (booking['trip_type'] ?? '').toString().toLowerCase().contains('local duty');
                    double advancePaid = isLocalDuty
                        ? (double.tryParse(booking['paid_amount']?.toString() ?? '') ?? 200.0)
                        : (totalFare * 0.30);
                    double remaining = isLocalDuty
                        ? (totalFare - advancePaid)
                        : (totalFare * 0.75);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.shade200, width: 0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Advance Paid",
                                    style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[800])),
                                const SizedBox(height: 2),
                                Text("₹${advancePaid.toStringAsFixed(2)}",
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800])),
                              ],
                            ),
                          Container(width: 1, height: 30, color: Colors.green.shade200),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("Remaining Balance",
                                  style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600])),
                              const SizedBox(height: 2),
                              Text("₹${remaining.toStringAsFixed(2)}",
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
            ),
          ],

            const SizedBox(height: 20),

            // 3. OTP High-Visibility Bar (Upcoming Only)
            if (!isPast && 
                status != 'Cancelled' && 
                status != 'Customer Cancelled' && 
                status != 'Cancellation Requested') ...[
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.shade200, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.assignment_ind_rounded, size: 16, color: Colors.amber.shade900),
                              const SizedBox(width: 8),
                              Text(
                                "DRIVER & VEHICLE DETAILS",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.amber.shade900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, thickness: 0.5),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Colors.amber.shade100,
                                child: Icon(Icons.person_rounded, color: Colors.amber.shade800, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driver['full_name'] ?? 'Assigned Driver',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.phone_iphone_rounded, size: 13, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          driver['phone_number'] ?? 'No contact number',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (driver['phone_number'] != null && driver['phone_number'].toString().isNotEmpty)
                                GestureDetector(
                                  onTap: () => _makePhoneCall(driver['phone_number'].toString()),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.green.shade200, width: 0.8),
                                    ),
                                    child: Icon(Icons.call, color: Colors.green.shade700, size: 18),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.directions_car_rounded, color: Colors.amber.shade700, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (driver['vehicle_name'] != null && driver['vehicle_name'].toString().isNotEmpty)
                                            ? "${driver['vehicle_name']} ${driver['vehicle_type'] != null && driver['vehicle_type'].toString().isNotEmpty ? '(${driver['vehicle_type']})' : ''}"
                                            : (booking['car_type'] ?? 'Allocating Car...'),
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildLicensePlate(registrationNumber),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (double.tryParse(booking['driver_latitude']?.toString() ?? '') != null &&
                              double.tryParse(booking['driver_longitude']?.toString() ?? '') != null)
                            FutureBuilder<String>(
                              future: _getDriverAddress(
                                double.parse(booking['driver_latitude'].toString()),
                                double.parse(booking['driver_longitude'].toString()),
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: InkWell(
                                      onTap: () async {
                                        final lat = booking['driver_latitude'].toString();
                                        final lng = booking['driver_longitude'].toString();
                                        final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                                        if (await canLaunchUrl(url)) {
                                          await launchUrl(url, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.blue.shade100,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.withOpacity(0.2),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.navigation_rounded,
                                                  size: 11,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        "DRIVER LIVE LOCATION",
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.blue.shade800,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red.shade500,
                                                          borderRadius: BorderRadius.circular(3),
                                                        ),
                                                        child: const Text(
                                                          "LIVE",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 7,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: 0.2,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    snapshot.data!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      color: Colors.grey[700],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.open_in_new_rounded,
                                              size: 14,
                                              color: Colors.blue.shade600,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 30),
                  ],
                  Row(
                    children: [
                      if (booking['payment_type'] == 'Advance') ...[
                        Expanded(
                          child: _actionButton(
                              "Advance Receipt",
                              Icons.receipt_outlined,
                              Colors.green[700]!,
                              () => _showAdvanceReceipt(context, booking)),
                        ),
                        if ((!isPast && driver != null) || (isPast && status == 'Completed'))
                          const SizedBox(width: 8),
                      ],
                      if (!isPast && driver != null)
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
                  if (discount > 0 || savings > 0)
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
                                    "$discountName Discount Applied!",
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Saved ₹${savings.toStringAsFixed(0)} with your dynamic customer benefit",
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
                                discount > 0 ? "-$discount%" : "-₹${savings.toStringAsFixed(0)}",
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
                    ),
                  if (!isPast && _canCancelBooking(booking)) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _showCancellationBottomSheet(context, booking),
                        icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                        label: Text(
                          "Cancel Booking",
                          style: GoogleFonts.poppins(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback tap) {
    return ElevatedButton.icon(
      onPressed: tap,
      icon: Icon(icon, size: 18),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        minimumSize: const Size(0, 48),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLicensePlate(String regNum) {
    if (regNum.isEmpty || regNum.toLowerCase().contains('allocating')) {
      return Text(
        "Car assignment pending",
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.yellow.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black87, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFF0033A0), // IND HSRP blue color
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.circle,
                    size: 6,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "IND",
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Text(
                regNum.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.orange;
    if (status == 'Completed') color = Colors.green;
    if (status == 'Accepted') color = Colors.blue;
    if (status == 'Cancelled' || status == 'Customer Cancelled' || status == 'Declined' || status == 'Failed') color = Colors.red;

    String displayText = status;
    if (status == 'Customer Cancelled') {
      displayText = 'Cancelled';
    } else if (status == 'Cancellation Requested') {
      displayText = 'Refund Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        displayText.toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Future<void> _makePhoneCall(String num) async {
    final Uri uri = Uri.parse('tel:$num');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showAdvanceReceipt(BuildContext context, Map<String, dynamic> booking) {
    if ((booking['trip_type'] ?? '') == 'Round-Trip') {
      double advancePaid = double.tryParse(booking['paid_amount']?.toString() ?? '') ??
                           double.tryParse(booking['total_amount']?.toString() ?? '') ?? 0.0;
      int days = 1;
      try {
        DateTime dep = DateTime.parse(booking['date']);
        DateTime ret = DateTime.parse(booking['return_date']);
        days = ret.difference(dep).inDays + 1;
        if (days <= 0) days = 1;
      } catch (_) {}
      
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      "ADVANCE PAYMENT RECEIPT",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Status: SUCCESS",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 30),
                  _buildReceiptRow("Booking ID", "#${booking['id']}"),
                  _buildReceiptRow("Date & Time", "${booking['date']} • ${booking['time']}"),
                  _buildReceiptRow("Car Type", "${booking['car_type']}"),
                  _buildReceiptRow("Route", "${booking['from_address']} to ${booking['to_address'] ?? 'Local'}"),
                  _buildReceiptRow("Trip Type", "Round Trip"),
                  _buildReceiptRow("Number of Days", "$days Days"),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Paid Advance Now",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "₹${advancePaid.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildReceiptRow("Remaining Balance", "Pay to Driver at Trip End"),
                  const Divider(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final String receiptText = """
AGNI CAR RENTAL
ADVANCE PAYMENT RECEIPT
-------------------------------
Booking ID: #${booking['id']}
Date: ${booking['date']}
Time: ${booking['time']}
Route: ${booking['from_address']} to ${booking['to_address'] ?? 'Local'}
Car Type: ${booking['car_type']}
Trip Type: Round Trip ($days Days)
-------------------------------
Advance Paid: ₹${advancePaid.toStringAsFixed(2)} (SUCCESS)
Remaining Balance: Pay to Driver at Trip End
-------------------------------
Thank you for choosing Rentox system!
""";
                        Share.share(receiptText);
                      },
                      icon: const Icon(Icons.share, size: 20),
                      label: const Text("Share Receipt"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    bool isLocalDuty = (booking['trip_type'] ?? '').toString().toLowerCase().contains('local-duty') || 
                       (booking['trip_type'] ?? '').toString().toLowerCase().contains('local duty');
    double totalFare = double.tryParse(booking['total_amount']?.toString() ?? '0') ?? 0.0;
    double advancePaid = isLocalDuty 
        ? (double.tryParse(booking['paid_amount']?.toString() ?? '') ?? 200.0)
        : (double.tryParse(booking['agni_amount']?.toString() ?? '0') ?? (totalFare * 0.30));
    double remaining = isLocalDuty
        ? (totalFare - advancePaid)
        : (double.tryParse(booking['vendor_amount']?.toString() ?? '0') ?? (totalFare * 0.75));
    double baseAdvance = isLocalDuty ? advancePaid : (totalFare * 0.25);
    double gst = isLocalDuty ? 0.0 : (totalFare * 0.05);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    "ADVANCE PAYMENT RECEIPT",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.green[800],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Status: SUCCESS",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ),
                ),
                const Divider(height: 30),
                _buildReceiptRow("Booking ID", "#${booking['id']}"),
                _buildReceiptRow("Date & Time", "${booking['date']} • ${booking['time']}"),
                _buildReceiptRow("Car Type", "${booking['car_type']}"),
                _buildReceiptRow("Route", "${booking['from_address']} to ${booking['to_address'] ?? 'Local'}"),
                const Divider(height: 20),
                _buildReceiptRow("Total Trip Fare", "₹${totalFare.toStringAsFixed(2)}"),
                _buildReceiptRow(isLocalDuty ? "Advance" : "Advance (25%)", "₹${baseAdvance.toStringAsFixed(2)}"),
                if (!isLocalDuty) _buildReceiptRow("GST (5%)", "₹${gst.toStringAsFixed(2)}"),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isLocalDuty ? "Paid Amount Now" : "Paid Amount Now (30%)",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "₹${advancePaid.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildReceiptRow("Remaining Balance (75%)", "₹${remaining.toStringAsFixed(2)}"),
                const Divider(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final String receiptText = """
AGNI CAR RENTAL
ADVANCE PAYMENT RECEIPT
-------------------------------
Booking ID: #${booking['id']}
Date: ${booking['date']}
Time: ${booking['time']}
Route: ${booking['from_address']} to ${booking['to_address'] ?? 'Local'}
Car Type: ${booking['car_type']}

Fare Details:
Total Trip Fare: ₹${totalFare.toStringAsFixed(2)}
Advance (25%): ₹${baseAdvance.toStringAsFixed(2)}
GST (5%): ₹${gst.toStringAsFixed(2)}
-------------------------------
Amount Paid: ₹${advancePaid.toStringAsFixed(2)} (SUCCESS)
Remaining Balance: ₹${remaining.toStringAsFixed(2)}
-------------------------------
Thank you for choosing Rentox system!
""";
                      Share.share(receiptText);
                    },
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text("Share Receipt"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canCancelBooking(Map<String, dynamic> booking) {
    String status = booking['booking_status'] ?? 'Pending';
    if (status == 'Pending' && (booking['trip_type'] ?? '') == 'Round-Trip') {
      status = 'Confirmed';
    }
    
    // Check status
    if (status != 'Pending' && status != 'Confirmed' && status != 'Accepted') {
      return false;
    }

    final bool isLocalTaxi = (booking['trip_type'] ?? '').toString().toLowerCase().contains('local') &&
                             (booking['trip_type'] ?? '').toString().toLowerCase().contains('taxi');
    if (isLocalTaxi) {
      // Local Taxi bookings can be cancelled any time before the driver starts the trip
      return true;
    }
    
    // Check if trip started (pickup time in future)
    try {
      DateTime now = DateTime.now();
      DateTime pickup = _parsePickupDateTime(booking['date'].toString(), booking['time'].toString());
      if (pickup.isBefore(now)) {
        return false;
      }
    } catch (_) {
      try {
        List<String> dateParts = booking['date'].toString().split('-');
        DateTime bDate = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);
        if (bDate.isBefore(today)) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  DateTime _parsePickupDateTime(String dateStr, String timeStr) {
    try {
      List<String> dateParts = dateStr.trim().split('-');
      int year = int.parse(dateParts[0]);
      int month = int.parse(dateParts[1]);
      int day = int.parse(dateParts[2]);
      
      int hour = 0;
      int minute = 0;
      
      String cleanTime = timeStr.trim().toUpperCase();
      bool isPm = cleanTime.contains("PM");
      bool isAm = cleanTime.contains("AM");
      
      cleanTime = cleanTime.replaceAll("AM", "").replaceAll("PM", "").trim();
      List<String> parts = cleanTime.split(RegExp(r'[:.]'));
      if (parts.length >= 2) {
        hour = int.parse(parts[0]);
        minute = int.parse(parts[1]);
      } else if (parts.length == 1) {
        hour = int.parse(parts[0]);
      }
      
      if (isPm && hour < 12) {
        hour += 12;
      } else if (isAm && hour == 12) {
        hour = 0;
      }
      
      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      try {
        List<String> dateParts = dateStr.trim().split('-');
        if (dateParts.length == 3) {
          return DateTime(int.parse(dateParts[0]), int.parse(dateParts[1]), int.parse(dateParts[2]));
        }
      } catch (_) {}
      return DateTime.parse(dateStr).toLocal();
    }
  }

  void _showCancellationBottomSheet(BuildContext context, Map<String, dynamic> booking) {
    final bool isLocalTaxi = (booking['trip_type'] ?? '').toString().toLowerCase().contains('local') &&
                             (booking['trip_type'] ?? '').toString().toLowerCase().contains('taxi');
    String selectedReason = 'Change of Plans';
    final List<String> reasons = [
      'Change of Plans',
      'Booked by Mistake',
      'Found Another Vehicle',
      'Price Issue',
      'Driver Delay',
      'Other'
    ];
    
    bool isSubmitting = false;
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // Define the future once to prevent refetching during bottom sheet rebuilds (e.g. when reason chip selected)
    final previewFuture = http.get(Uri.parse('${ApiConfig.baseUrl}/cancellation_preview.php?booking_id=${booking['id']}'));

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext modalContext, StateSetter setModalState) {
            return FutureBuilder<http.Response>(
              future: previewFuture,
              builder: (futureBuilderContext, snapshot) {
                Widget previewCard;
                double refundAmt = 0.0;
                double chargeAmt = 0.0;
                double advancePaid = double.tryParse(booking['paid_amount']?.toString() ?? '0') ?? 0.0;
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  previewCard = const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(color: Colors.amber)),
                  );
                } else if (snapshot.hasError || snapshot.data?.statusCode != 200) {
                  previewCard = Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      "Error fetching refund preview. Standard policy applies.",
                      style: GoogleFonts.poppins(color: Colors.red[800], fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  );
                } else {
                  try {
                    final data = jsonDecode(snapshot.data!.body);
                    if (data['status'] == 'success') {
                      final calc = data['data'];
                      refundAmt = double.tryParse(calc['refund_amount']?.toString() ?? '0') ?? 0.0;
                      chargeAmt = double.tryParse(calc['cancellation_charge']?.toString() ?? '0') ?? 0.0;
                      advancePaid = double.tryParse(calc['advance_paid']?.toString() ?? '0') ?? 0.0;
                      
                      previewCard = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "REFUND ESTIMATION",
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[400],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                  Text("Advance Paid", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                                  Text("₹${advancePaid.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Cancellation Charge", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                                Text("₹${chargeAmt.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 13, color: Colors.red[700], fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Refund Amount", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                                Text("₹${refundAmt.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 16, color: Colors.green[700], fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ],
                        ),
                      );
                    } else {
                      previewCard = Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          data['message'] ?? "Error loading refund preview.",
                          style: GoogleFonts.poppins(color: Colors.red[800], fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      );
                    }
                  } catch (_) {
                    previewCard = const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text("Failed to parse refund details."),
                    );
                  }
                }

                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(modalContext).viewInsets.bottom),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 24),
                              const SizedBox(width: 8),
                              Text(
                                "Cancel Booking",
                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[900]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isLocalTaxi
                                ? "Are you sure you want to cancel this booking? Since this is a Local Taxi booking, free cancellation applies."
                                : "Are you sure you want to cancel this booking? Refund will be calculated according to our cancellation policy.",
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600], height: 1.4, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isLocalTaxi
                                  ? Colors.green.shade50.withOpacity(0.3)
                                  : Colors.amber.shade50.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isLocalTaxi ? Colors.green.shade200 : Colors.amber.shade200,
                                width: 0.8,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.policy_outlined,
                                      size: 16,
                                      color: isLocalTaxi ? Colors.green.shade900 : Colors.amber.shade900,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "CANCELLATION POLICY",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isLocalTaxi ? Colors.green.shade900 : Colors.amber.shade900,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16, thickness: 0.5),
                                isLocalTaxi
                                    ? Text(
                                        "Free Cancellation - You can cancel your Local Taxi booking anytime before the trip starts with no cancellation fee.",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.green.shade900,
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          _buildPolicyRuleRow("More than 48 Hours", "100% Refund", isGreen: true),
                                          _buildPolicyRuleRow("24–48 Hours", "75% Refund"),
                                          _buildPolicyRuleRow("12–24 Hours", "50% Refund"),
                                          _buildPolicyRuleRow("6–12 Hours", "25% Refund"),
                                          _buildPolicyRuleRow("Less than 6 Hours", "No Refund", isRed: true),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "REASON FOR CANCELLATION",
                            style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 10),
                          // Reason Selectors
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: reasons.map<Widget>((reason) {
                              final isSelected = selectedReason == reason;
                              return ChoiceChip(
                                label: Text(
                                  reason,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.black87 : Colors.grey[700],
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setModalState(() {
                                      selectedReason = reason;
                                    });
                                  }
                                },
                                selectedColor: Colors.amber[300],
                                backgroundColor: Colors.grey[100],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                pressElevation: 0,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          previewCard,
                          if (!isLocalTaxi) ...[
                            const SizedBox(height: 12),
                            Text(
                              "* Refund will be processed within 3–7 business days.",
                              style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: isSubmitting ? null : () => Navigator.pop(modalContext),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[200],
                                      foregroundColor: Colors.grey[800],
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Text("CLOSE", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: (isSubmitting || snapshot.connectionState == ConnectionState.waiting) 
                                        ? null 
                                        : () async {
                                            setModalState(() {
                                              isSubmitting = true;
                                            });
                                            bool success = false;
                                            try {
                                              final response = await http.post(
                                                Uri.parse('${ApiConfig.baseUrl}/cancel_booking.php'),
                                                body: {
                                                  "booking_id": booking['id'].toString(),
                                                  "reason": selectedReason
                                                },
                                              );
                                              if (response.statusCode == 200) {
                                                final res = jsonDecode(response.body);
                                                if (res['status'] == 'success') {
                                                  success = true;
                                                  navigator.pop(); // Close sheet
                                                  
                                                  // Navigate to success screen
                                                  navigator.push(
                                                    MaterialPageRoute(
                                                      builder: (_) => CancellationSuccessPage(
                                                        bookingId: booking['id'].toString(),
                                                        advancePaid: advancePaid,
                                                        cancellationCharge: chargeAmt,
                                                        refundAmount: refundAmt,
                                                        refundStatus: res['data']['refund_status'] ?? 'Processing',
                                                        isLocalTaxi: isLocalTaxi,
                                                      ),
                                                    ),
                                                  );
                                                  
                                                  // Refresh the bookings list
                                                  if (phoneNumber != null) fetchBookings(phoneNumber!);
                                                } else {
                                                  scaffoldMessenger.showSnackBar(
                                                    SnackBar(content: Text(res['message'] ?? "Cancellation failed")),
                                                  );
                                                }
                                              } else {
                                                scaffoldMessenger.showSnackBar(
                                                  const SnackBar(content: Text("Server error. Please try again later.")),
                                                );
                                              }
                                            } catch (e) {
                                              scaffoldMessenger.showSnackBar(
                                                SnackBar(content: Text("Error: $e")),
                                              );
                                            } finally {
                                              if (!success) {
                                                setModalState(() {
                                                  isSubmitting = false;
                                                });
                                              }
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: isSubmitting
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text("CONFIRM CANCEL", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCancellationDetailsCard(Map<String, dynamic> booking) {
    final bool isLocalTaxi = (booking['trip_type'] ?? '').toString().toLowerCase().contains('local') &&
                             (booking['trip_type'] ?? '').toString().toLowerCase().contains('taxi');
    double advancePaid = double.tryParse(booking['paid_amount']?.toString() ?? '0') ?? 0.0;
    double chargeAmt = double.tryParse(booking['cancellation_charge']?.toString() ?? '0') ?? 0.0;
    double refundAmt = double.tryParse(booking['refund_amount']?.toString() ?? '0') ?? 0.0;
    String reason = booking['cancellation_reason'] ?? 'Not Specified';
    String refundStatus = booking['refund_status'] ?? 'Processing';
    String cancelledAt = booking['cancelled_at'] ?? booking['date'];

    Color statusColor = Colors.orange;
    if (refundStatus == 'Completed' || refundStatus == 'Refunded') statusColor = Colors.green;
    if (refundStatus == 'Failed' || refundStatus == 'Rejected') statusColor = Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLocalTaxi
              ? Colors.green.shade50.withOpacity(0.4)
              : Colors.red.shade50.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLocalTaxi ? Colors.green.shade100 : Colors.red.shade100,
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: isLocalTaxi ? Colors.green[800] : Colors.red[800],
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  "CANCELLATION DETAILS",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isLocalTaxi ? Colors.green[800] : Colors.red[800],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 0.5),
            _buildDetailRow("Cancelled Date/Time", cancelledAt),
            _buildDetailRow("Cancellation Reason", reason, isItalic: true),
            _buildDetailRow("Advance Paid", "₹${advancePaid.toStringAsFixed(0)}"),
            _buildDetailRow("Cancellation Charge", "₹${chargeAmt.toStringAsFixed(0)}", valueColor: Colors.red[700]),
            const Divider(height: 16, thickness: 0.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Refund Amount",
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  "₹${refundAmt.toStringAsFixed(0)}",
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.green[700]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Refund Status",
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    refundStatus.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 0.5),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLocalTaxi ? Colors.green.shade100 : Colors.red.shade100,
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.policy_outlined,
                        size: 14,
                        color: isLocalTaxi ? Colors.green[800] : Colors.red[800],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "CANCELLATION POLICY REFERENCE",
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isLocalTaxi ? Colors.green[800] : Colors.red[800],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 12, thickness: 0.5),
                  isLocalTaxi
                      ? Text(
                          "Free Cancellation - You can cancel your Local Taxi booking anytime before the trip starts with no cancellation fee.",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.green[900],
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        )
                      : Column(
                          children: [
                            _buildPolicyRuleRow("More than 48 Hours", "100% Refund", isGreen: true),
                            _buildPolicyRuleRow("24–48 Hours", "75% Refund"),
                            _buildPolicyRuleRow("12–24 Hours", "50% Refund"),
                            _buildPolicyRuleRow("6–12 Hours", "25% Refund"),
                            _buildPolicyRuleRow("Less than 6 Hours", "No Refund", isRed: true),
                          ],
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black87,
                fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationTimeline(Map<String, dynamic> booking) {
    final bool isLocalTaxi = (booking['trip_type'] ?? '').toString().toLowerCase().contains('local') &&
                             (booking['trip_type'] ?? '').toString().toLowerCase().contains('taxi');
    String bookingStatus = booking['booking_status'] ?? 'Pending';
    String refundStatus = booking['refund_status'] ?? 'Processing';
    bool driverAssigned = booking['driver_id'] != null && booking['driver_id'].toString().isNotEmpty;
    
    String bookedAt = booking['booked_at'] ?? 'Confirmed';
    String assignedAt = booking['driver_assigned_at'] ?? 'Assigned';
    String cancelledAt = booking['cancelled_at'] ?? 'Cancelled';
    
    // Determine active steps
    bool step1 = true; // Confirmed
    bool step2 = driverAssigned; // Driver Assigned
    bool step3 = true; // Cancellation Requested
    bool step4 = bookingStatus == 'Cancelled' || bookingStatus == 'Customer Cancelled'; // Cancellation Completed
    bool step5 = (bookingStatus == 'Cancelled' || bookingStatus == 'Customer Cancelled') && 
                 (refundStatus == 'Pending Approval' || refundStatus == 'Processing' || refundStatus == 'Completed'); // Refund Initiated
    bool step6 = refundStatus == 'Completed'; // Refund Completed

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              isLocalTaxi ? "CANCELLATION TIMELINE" : "CANCELLATION & REFUND TIMELINE",
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTimelineStep("Booking Confirmed", bookedAt, step1, Colors.green),
          _buildTimelineDivider(step2),
          _buildTimelineStep("Driver Assigned", assignedAt, step2, Colors.green, isOptional: !driverAssigned),
          if (isLocalTaxi) ...[
            _buildTimelineDivider(step4),
            _buildTimelineStep("Booking Cancelled", cancelledAt, step4, Colors.red),
          ] else ...[
            if (driverAssigned) _buildTimelineDivider(step3),
            _buildTimelineStep("Cancellation Requested", cancelledAt, step3, Colors.orange),
            _buildTimelineDivider(step4),
            _buildTimelineStep("Booking Cancelled", cancelledAt, step4, Colors.red),
            _buildTimelineDivider(step5),
            _buildTimelineStep(
              refundStatus == 'Pending Approval' ? 'Refund Pending Approval'
              : refundStatus == 'Processing' ? 'Refund Processing'
              : 'Refund Initiated',
              '', step5, Colors.blue,
            ),
            _buildTimelineDivider(step6),
            _buildTimelineStep("Refund Completed", "Settled", step6, Colors.green),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String title, String subtitle, bool isCompleted, Color color, {bool isOptional = false}) {
    if (isOptional && !isCompleted) return const SizedBox.shrink();
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted ? color.withOpacity(0.12) : Colors.grey[100],
            shape: BoxShape.circle,
            border: Border.all(color: isCompleted ? color : Colors.grey.shade300, width: 2),
          ),
          child: Icon(
            isCompleted ? Icons.check : Icons.circle,
            size: isCompleted ? 12 : 6,
            color: isCompleted ? color : Colors.grey.shade400,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.w500,
                  color: isCompleted ? Colors.black87 : Colors.grey[500],
                ),
              ),
              if (isCompleted && subtitle.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineDivider(bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(left: 11),
      child: Container(
        width: 2,
        height: 20,
        color: isActive ? Colors.green.shade300 : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildPolicyRuleRow(String timing, String refund, {bool isGreen = false, bool isRed = false}) {
    Color valColor = Colors.black87;
    if (isGreen) valColor = const Color(0xFF2E7D32);
    if (isRed) valColor = const Color(0xFFC62828);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            timing,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              Text(
                "→  ",
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.bold),
              ),
              Text(
                refund,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: valColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
