import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'DriverToPickupMap.dart';
import 'car_invoice.dart';
import 'trip_feedback_dialog.dart';
import 'report_driver_dialog.dart';
import 'package:agni_car_rental/config/api_config.dart';

class TripDetailsPage extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? driver;
  final bool isPast;
  final Function(BuildContext, Map<String, dynamic>)? onCancelBooking;

  const TripDetailsPage({
    Key? key,
    required this.booking,
    this.driver,
    this.isPast = false,
    this.onCancelBooking,
  }) : super(key: key);

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  final Color amberPrimary = const Color(0xFFFFC107);
  final Color amberDark = const Color(0xFFFF8F00);
  final Color darkCharcoal = const Color(0xFF1C1F26);

  Map<String, dynamic> get booking => widget.booking;
  Map<String, dynamic>? get driver => widget.driver;
  bool get isPast => widget.isPast;
  Function(BuildContext, Map<String, dynamic>)? get onCancelBooking => widget.onCancelBooking;

  Map<String, dynamic>? _existingReview;
  bool _hasReviewed = false;

  Map<String, dynamic>? _existingIncident;
  bool _hasReportedIncident = false;

  @override
  void initState() {
    super.initState();
    _checkAndFetchReview();
  }

  Future<void> _checkAndFetchReview() async {
    final bId = widget.booking['id']?.toString() ?? widget.booking['booking_id']?.toString() ?? '';
    final status = widget.booking['booking_status'] ?? '';

    // Fetch review if completed
    if (status.toString().toLowerCase().contains('complet') && bId.isNotEmpty) {
      try {
        final url = Uri.parse("${ApiConfig.baseUrl}/get_trip_review.php?booking_id=$bId");
        final res = await http.get(url);
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['has_reviewed'] == true) {
          if (mounted) {
            setState(() {
              _hasReviewed = true;
              _existingReview = data['review'];
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _hasReviewed = false;
              _existingReview = null;
            });
          }
        }
      } catch (e) {
        // Ignore network errors gracefully
      }
    }

    // Always check for incident reports for this booking
    if (bId.isNotEmpty) {
      try {
        final incUrl = Uri.parse("${ApiConfig.baseUrl}/get_trip_incidents.php?booking_id=$bId");
        final incRes = await http.get(incUrl);
        final incData = jsonDecode(incRes.body);
        if (incData['success'] == true && incData['has_reported'] == true) {
          if (mounted) {
            setState(() {
              _hasReportedIncident = true;
              _existingIncident = incData['latest_report'];
            });
          }
        }
      } catch (e) {
        // Ignore network errors gracefully
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String status = booking['booking_status'] ?? 'Pending';
    final String tripType = booking['trip_type'] ?? 'One-way';
    final String carType = booking['car_type'] ?? 'Sedan';
    final String fromAddress = booking['from_address'] ?? 'Pickup Location';
    final String toAddress = booking['to_address'] ?? 'Drop Location';
    final String bookingDate = booking['date'] ?? '';
    final String bookingTime = booking['time'] ?? '';
    final String returnDate = booking['return_date'] ?? '';
    final String otp = (booking['otp'] ?? '').toString();
    final String endOtp = (booking['end_otp'] ?? '').toString();
    final double gpsKm = double.tryParse((booking['gps_accumulated_km'] ?? '0').toString()) ?? 0.0;
    final double totalAmount = double.tryParse(booking['total_amount']?.toString() ?? '0') ?? 0.0;
    final double paidAmount = double.tryParse(booking['paid_amount']?.toString() ?? '') ??
        (booking['payment_type'] == 'Advance' ? totalAmount : 0.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: amberPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Trip #${booking['id']} Details",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black87, size: 22),
            onPressed: () => _shareTripSummary(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Status & Header Banner
            _buildStatusHeader(status, bookingDate, bookingTime),
            const SizedBox(height: 16),

            // Safety Incident Report Card (if customer reported this trip)
            if (_hasReportedIncident && _existingIncident != null) ...[
              _buildIncidentReportCard(context),
              const SizedBox(height: 16),
            ],

            // Trip Feedback & Rating Section
            if (status.toString().toLowerCase().contains('complet') && _hasReviewed && _existingReview != null) ...[
              _buildTripReviewCard(context),
              const SizedBox(height: 16),
            ] else if (status.toString().toLowerCase().contains('complet') && !_hasReviewed) ...[
              _buildTripRatePromptCard(context),
              const SizedBox(height: 16),
            ],

            // 2. Driver OTP Card (Start OTP before trip / Completion OTP during In-Transit)
            if (!isPast && !_isCancelled(status)) ...[
              if ((status.toLowerCase() == 'in-transit' || status.toLowerCase() == 'started') && endOtp.isNotEmpty) ...[
                _buildEndOtpSecurityCard(context, endOtp, gpsKm),
                const SizedBox(height: 16),
              ] else if (otp.isNotEmpty && status.toLowerCase() != 'in-transit' && status.toLowerCase() != 'started') ...[
                _buildOtpSecurityCard(context, otp),
                const SizedBox(height: 16),
              ],
            ],

            // 3. Journey Route Details
            _buildRouteCard(context, fromAddress, toAddress, tripType, carType),
            const SizedBox(height: 16),

            // 4. Driver & Vehicle Information Card
            _buildDriverVehicleCard(context, driver, carType),
            const SizedBox(height: 16),

            // 5. Detailed Fare & Billing Breakdown
            _buildFareBreakdownCard(totalAmount, paidAmount, tripType),
            const SizedBox(height: 16),

            // 6. Customer & Trip Meta
            _buildBookingMetaCard(returnDate),
            const SizedBox(height: 24),

            // 7. Action Buttons
            _buildActionButtons(context, status),
          ],
        ),
      ),
    );
  }

  bool _isCancelled(String status) {
    return status == 'Cancelled' ||
        status == 'Customer Cancelled' ||
        status == 'Cancellation Requested' ||
        status == 'Declined';
  }

  Widget _buildStatusHeader(String status, String date, String time) {
    Color statusColor = Colors.orange.shade800;
    Color statusBg = Colors.orange.shade50;
    if (status == 'Completed') {
      statusColor = Colors.green.shade800;
      statusBg = Colors.green.shade50;
    } else if (status == 'Confirmed' || status == 'Accepted') {
      statusColor = Colors.blue.shade800;
      statusBg = Colors.blue.shade50;
    } else if (_isCancelled(status)) {
      statusColor = Colors.red.shade800;
      statusBg = Colors.red.shade50;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: darkCharcoal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "TRIP ID #${booking['id']}",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "$date • $time",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndOtpSecurityCard(BuildContext context, String endOtp, double gpsKm) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "TRIP COMPLETION OTP",
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "Required for drop-off verification",
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (gpsKm > 0) ...[
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "📍 ${gpsKm.toStringAsFixed(1)} KM TRACKED",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: endOtp));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Completion OTP $endOtp copied!"),
                        backgroundColor: darkCharcoal,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          endOtp,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 2.5,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFF059669), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "For your billing safety, share this OTP with driver only after reaching final destination.",
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpSecurityCard(BuildContext context, String otp) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC107), Color(0xFFFFB300)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.vpn_key_rounded, color: Colors.black87, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "DRIVER START OTP",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                                color: Colors.black87,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              "Share when trip begins",
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: otp));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("OTP $otp copied to clipboard!"),
                        backgroundColor: darkCharcoal,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          otp,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            letterSpacing: 2.5,
                            color: const Color(0xFFFFC107),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.copy_rounded, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFFD97706), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "For your safety, never share this OTP over phone before driver arrival.",
                    style: GoogleFonts.poppins(
                      fontSize: 10.5,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(
      BuildContext context, String from, String to, String tripType, String carType) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text(
                  "ROUTE & TRIP DETAILS",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.6,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (carType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          carType,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    if (tripType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Text(
                          tripType,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, color: Color(0xFF10B981), size: 16),
                  Container(
                    width: 2,
                    height: 48,
                    color: Colors.grey.shade300,
                  ),
                  const Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 20),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PICKUP LOCATION",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          from,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DROP LOCATION",
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFDC2626),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          to,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.3,
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
    );
  }

  Widget _buildDriverVehicleCard(
      BuildContext context, Map<String, dynamic>? driver, String defaultCarType) {
    final bool hasDriver = driver != null &&
        driver['full_name'] != null &&
        driver['full_name'].toString().trim().isNotEmpty;

    final String regNum = booking['vehicle_id']?.toString().trim().isNotEmpty == true
        ? booking['vehicle_id'].toString()
        : (driver?['vehicle_id']?.toString().trim().isNotEmpty == true
            ? driver!['vehicle_id'].toString()
            : 'Allocating...');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, size: 18, color: Colors.amber.shade900),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "DRIVER & VEHICLE INFORMATION",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (hasDriver) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.amber.shade100,
                  child: Icon(Icons.person_rounded, color: Colors.amber.shade900, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver!['full_name'] ?? 'Assigned Driver',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.phone_iphone_rounded, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            driver['phone_number'] ?? 'No contact',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: Colors.grey.shade700,
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
                    onTap: () => _callPhone(driver['phone_number'].toString()),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.directions_car_filled_rounded, color: Colors.amber.shade800, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (driver['vehicle_name'] != null && driver['vehicle_name'].toString().isNotEmpty)
                              ? "${driver['vehicle_name']} (${driver['vehicle_type'] ?? defaultCarType})"
                              : defaultCarType,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildLicensePlate(regNum),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (double.tryParse(booking['driver_latitude']?.toString() ?? driver?['latitude']?.toString() ?? '') != null &&
                double.tryParse(booking['driver_longitude']?.toString() ?? driver?['longitude']?.toString() ?? '') != null)
              FutureBuilder<String>(
                future: _getDriverAddress(
                  double.parse((booking['driver_latitude'] ?? driver!['latitude']).toString()),
                  double.parse((booking['driver_longitude'] ?? driver!['longitude']).toString()),
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final lat = (booking['driver_latitude'] ?? driver!['latitude']).toString();
                    final lng = (booking['driver_longitude'] ?? driver!['longitude']).toString();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: InkWell(
                        onTap: () async {
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
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.schedule_rounded, color: Colors.amber.shade900, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Driver Allocation in Progress",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Your booking is confirmed. Nearest driver & vehicle details will appear here shortly.",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLicensePlate(String regNum) {
    if (regNum.isEmpty || regNum.toLowerCase().contains('allocating')) {
      return Text(
        "Car assignment pending",
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600),
      );
    }
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black87, width: 1),
      ),
      child: Text(
        regNum.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFareBreakdownCard(double total, double paid, String tripType) {
    final double balance = (total - paid).clamp(0, double.infinity);
    final String paymentType = booking['payment_type'] ?? 'Cash / Post-Trip';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  "FARE & PAYMENT SUMMARY",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  paymentType.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _fareRow("Estimated / Total Trip Amount", "₹${total.toStringAsFixed(2)}", isBold: true),
          if (paid > 0) ...[
            const SizedBox(height: 8),
            _fareRow("Advance Amount Paid", "₹${paid.toStringAsFixed(2)}", color: const Color(0xFF10B981)),
          ],
          const SizedBox(height: 8),
          _fareRow(
            "Balance Due to Driver",
            "₹${balance.toStringAsFixed(2)}",
            isBold: true,
            color: balance > 0 ? Colors.amber.shade900 : Colors.green.shade800,
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _inclusionItem("Toll charges & parking fees as per actual receipts"),
                const SizedBox(height: 4),
                _inclusionItem("GST and applicable taxes included"),
                if (tripType == 'Round-Trip') ...[
                  const SizedBox(height: 4),
                  _inclusionItem("Driver allowance included per calendar day"),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fareRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _inclusionItem(String text) {
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingMetaCard(String returnDate) {
    final String customerName = booking['customer_name'] ?? 'Registered Customer';
    final String customerPhone = booking['customer_phone'] ?? booking['phone_number'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "CUSTOMER & BOOKING INFO",
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade600,
              letterSpacing: 0.8,
            ),
          ),
          const Divider(height: 24),
          _metaRow(Icons.person_outline_rounded, "Passenger Name", customerName),
          if (customerPhone.isNotEmpty) ...[
            const SizedBox(height: 10),
            _metaRow(Icons.phone_outlined, "Contact Number", customerPhone),
          ],
          if (returnDate.isNotEmpty && returnDate != '0000-00-00') ...[
            const SizedBox(height: 10),
            _metaRow(Icons.event_repeat_rounded, "Return Date", returnDate),
          ],
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(
          "$label: ",
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, String status) {
    final bool canCancel = !isPast && !_isCancelled(status) && status != 'Completed';
    final bool isCompleted = status == 'Completed';

    return Column(
      children: [
        Row(
          children: [
            // Share Trip
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _shareTripSummary(context),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: Text(
                  "Share Trip",
                  style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkCharcoal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Live Tracking or Invoice
            if (!isPast && driver != null) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DriverToPickupMapYellowFinalV2(
                          driverId: driver?['phone_number'] ?? '',
                          bookingId: booking['id'].toString(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_rounded, size: 16),
                  label: Text(
                    "Track Driver",
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ] else if (isCompleted) ...[
              if (!_hasReviewed) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final updated = await TripFeedbackDialog.show(
                        context,
                        bookingId: booking['id'].toString(),
                        driverName: driver?['full_name'],
                        carType: booking['car_type'],
                        customerPhone: booking['customer_number'] ?? booking['mobile'],
                      );
                      if (updated == true) {
                        _checkAndFetchReview();
                      }
                    },
                    icon: const Icon(Icons.star_rounded, size: 18),
                    label: Text(
                      "Rate Trip",
                      style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB300),
                      foregroundColor: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InvoicePage(bookingId: booking['id'].toString()),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: Text(
                    "Invoice",
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _callPhone("9847267465"), // Support hotline
                  icon: const Icon(Icons.support_agent_rounded, size: 18),
                  label: Text(
                    "Support",
                    style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
        // 3. Report Driver / Safety Concern Button
        if (driver != null || isPast || isCompleted) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton.icon(
              onPressed: () async {
                final reported = await ReportDriverDialog.show(
                  context,
                  bookingId: booking['id']?.toString() ?? booking['booking_id']?.toString() ?? '',
                  driverName: driver?['full_name'],
                  driverId: driver?['phone_number'] ?? driver?['driver_id'] ?? booking['driver_id']?.toString(),
                  customerPhone: booking['customer_number'] ?? booking['mobile'],
                );
                if (reported == true) {
                  _checkAndFetchReview();
                }
              },
              icon: Icon(
                _hasReportedIncident ? Icons.shield_rounded : Icons.shield_outlined,
                color: const Color(0xFFDC2626),
                size: 18,
              ),
              label: Text(
                _hasReportedIncident
                    ? "Safety Incident Reported (${_existingIncident?['ticket_no'] ?? 'Filed'})"
                    : "Report Driver / Safety Concern",
                style: GoogleFonts.poppins(
                  color: const Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFFECACA), width: 1.2),
                ),
              ),
            ),
          ),
        ],
        if (canCancel && onCancelBooking != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => onCancelBooking!(context, booking),
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
    );
  }

  void _shareTripSummary(BuildContext context) {
    final String tripId = booking['id']?.toString() ?? '';
    final String date = booking['date'] ?? '';
    final String time = booking['time'] ?? '';
    final String from = booking['from_address'] ?? '';
    final String to = booking['to_address'] ?? '';
    final String otp = booking['otp']?.toString() ?? '';

    final String text = "🚗 *RENTOX TRIP DETAILS (ID #$tripId)*\n\n"
        "📅 *Date & Time:* $date at $time\n"
        "📍 *Pickup:* $from\n"
        "🏁 *Drop:* $to\n"
        "${otp.isNotEmpty ? '🔑 *Driver OTP:* $otp\n' : ''}"
        "💳 *Total Fare:* ₹${booking['total_amount']}\n\n"
        "Track & manage your trip on the Rentox App.";

    Share.share(text, subject: "Rentox Trip #$tripId Details");
  }

  Future<void> _callPhone(String number) async {
    final Uri uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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

  Widget _buildIncidentReportCard(BuildContext context) {
    if (_existingIncident == null) return const SizedBox.shrink();

    final ticketNo = _existingIncident!['ticket_no'] ?? 'INCIDENT';
    final incidentType = _existingIncident!['incident_type'] ?? 'Safety Complaint';
    final status = _existingIncident!['status'] ?? 'Pending';
    final description = _existingIncident!['description'] ?? '';
    final adminAction = _existingIncident!['admin_action'];

    Color statusColor = const Color(0xFFD97706);
    if (status == 'Resolved') {
      statusColor = const Color(0xFF059669);
    } else if (status == 'Investigating') {
      statusColor = const Color(0xFF4F46E5);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Safety Incident Reported",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                    Text(
                      "Ticket #$ticketNo",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "$incidentType: \"$description\"",
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade800,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
          if (adminAction != null && adminAction.toString().trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Resolution: $adminAction",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTripReviewCard(BuildContext context) {
    if (_existingReview == null) return const SizedBox.shrink();

    final int rating = int.tryParse((_existingReview!['rating'] ?? 5).toString()) ?? 5;
    final String tags = (_existingReview!['tags'] ?? '').toString().trim();
    final String reviewText = (_existingReview!['review_text'] ?? '').toString().trim();
    final List<String> tagList = tags.isNotEmpty
        ? tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Trip Rating",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: const Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Feedback submitted",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final updated = await TripFeedbackDialog.show(
                    context,
                    bookingId: booking['id'].toString(),
                    driverName: driver?['full_name'],
                    carType: booking['car_type'],
                    customerPhone: booking['customer_number'] ?? booking['mobile'],
                    initialRating: rating,
                    initialTags: tags,
                    initialComment: reviewText,
                  );
                  if (updated == true) {
                    _checkAndFetchReview();
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB300)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded, size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 4),
                      Text(
                        "Edit",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Star Display & Score
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  final isFilled = (index + 1) <= rating;
                  return Icon(
                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFilled ? const Color(0xFFFFB300) : Colors.grey.shade300,
                    size: 26,
                  );
                }),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB300).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$rating.0 / 5.0",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),

          // Tag Pills
          if (tagList.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tagList.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Review Text Comment
          if (reviewText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE082).withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, size: 18, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reviewText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTripRatePromptCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFF3CD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD54F)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Rate Your Journey",
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  "How was your ride with our driver?",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = await TripFeedbackDialog.show(
                context,
                bookingId: booking['id'].toString(),
                driverName: driver?['full_name'],
                carType: booking['car_type'],
                customerPhone: booking['customer_number'] ?? booking['mobile'],
              );
              if (updated == true) {
                _checkAndFetchReview();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB300),
              foregroundColor: const Color(0xFF1A1A1A),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16),
                const SizedBox(width: 4),
                Text(
                  "Rate",
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
