import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:agni_car_rental/config/api_config.dart';

class AgentEarningsPage extends StatefulWidget {
  const AgentEarningsPage({Key? key}) : super(key: key);

  @override
  State<AgentEarningsPage> createState() => _AgentEarningsPageState();
}

class _AgentEarningsPageState extends State<AgentEarningsPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  List<dynamic> earningsBookings = [];
  bool isLoading = true;
  bool hasError = false;
  String? phoneNumber;

  String activeFilter = 'All'; // 'All', 'Today', 'Week', 'Month'

  // Theme Colors
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color darkCharcoal = const Color(0xFF1A1A1A);
  final Color surfaceGrey = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    String? savedNumber = await secureStorage.read(key: 'phone_number');
    if (savedNumber != null) {
      setState(() => phoneNumber = savedNumber);
      await fetchEarnings(savedNumber);
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchEarnings(String phone) async {
    final String apiUrl =
        "${ApiConfig.baseUrl}/bookingStatus.php?phone_number=$phone";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          List<dynamic> allBookings = data['data'] ?? [];
          
          // Filter only bookings with agent commission
          List<dynamic> filtered = allBookings.where((b) {
            double comm = double.tryParse(b['agent_commission']?.toString() ?? '0') ?? 0.0;
            String status = b['booking_status'] ?? '';
            return comm > 0 && status != 'Deleted';
          }).toList();

          setState(() {
            earningsBookings = filtered;
            isLoading = false;
            hasError = false;
          });
        } else {
          setState(() {
            isLoading = false;
            hasError = true;
          });
        }
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  List<dynamic> getFilteredBookings() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    
    // Start of this week (Monday)
    DateTime startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    
    // Start of this month
    DateTime startOfMonth = DateTime(today.year, today.month, 1);

    return earningsBookings.where((b) {
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
        return true;
      }
      
      // Normalize to date-only for comparison
      DateTime bDateOnly = DateTime(bDate.year, bDate.month, bDate.day);

      if (activeFilter == 'Today') {
        return bDateOnly.isAtSameMomentAs(today);
      } else if (activeFilter == 'Week') {
        return bDateOnly.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) && 
               bDateOnly.isBefore(today.add(const Duration(days: 1)));
      } else if (activeFilter == 'Month') {
        return bDateOnly.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) && 
               bDateOnly.isBefore(today.add(const Duration(days: 1)));
      }
      return true;
    }).toList();
  }

  double getFilteredTotal() {
    double total = 0.0;
    for (var b in getFilteredBookings()) {
      double comm = double.tryParse(b['agent_commission']?.toString() ?? '0') ?? 0.0;
      total += comm;
    }
    return total;
  }

  double getFilteredCompleted() {
    double completed = 0.0;
    for (var b in getFilteredBookings()) {
      double comm = double.tryParse(b['agent_commission']?.toString() ?? '0') ?? 0.0;
      if (b['booking_status'] == 'Completed') {
        completed += comm;
      }
    }
    return completed;
  }

  double getFilteredPending() {
    double pending = 0.0;
    for (var b in getFilteredBookings()) {
      double comm = double.tryParse(b['agent_commission']?.toString() ?? '0') ?? 0.0;
      String status = b['booking_status'] ?? '';
      if (status != 'Completed' && 
          status != 'Cancelled' && 
          status != 'Customer Cancelled' && 
          status != 'Cancellation Requested' && 
          status != 'Declined' && 
          status != 'Failed') {
        pending += comm;
      }
    }
    return pending;
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final filteredList = getFilteredBookings();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "My Earnings",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: darkCharcoal,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: darkCharcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: darkCharcoal),
            onPressed: () {
              if (phoneNumber != null) {
                setState(() => isLoading = true);
                fetchEarnings(phoneNumber!);
              }
            },
          )
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryAmber))
          : hasError
              ? _buildErrorView()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      _buildSummarySection(size),
                      const SizedBox(height: 25),
                      _buildFilterRow(),
                      Text(
                        "Earnings History",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: darkCharcoal,
                        ),
                      ),
                      const SizedBox(height: 15),
                      filteredList.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                return _buildEarningCard(filteredList[index]);
                              },
                            ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummarySection(Size size) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: darkCharcoal,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryAmber.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Text(
                  "TOTAL EARNED",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white60,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "₹${getFilteredTotal().toStringAsFixed(2)}",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: primaryAmber,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat(
                  label: "COMPLETED",
                  value: "₹${getFilteredCompleted().toStringAsFixed(2)}",
                  color: Colors.greenAccent,
                ),
                Container(
                  width: 1,
                  height: 35,
                  color: Colors.white12,
                ),
                _buildSummaryStat(
                  label: "PENDING",
                  value: "₹${getFilteredPending().toStringAsFixed(2)}",
                  color: Colors.amberAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildFilterChip('All'),
          _buildFilterChip('Today'),
          _buildFilterChip('Week'),
          _buildFilterChip('Month'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = activeFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          activeFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryAmber : surfaceGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryAmber : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryAmber.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label == 'Week' 
                ? 'This Week' 
                : label == 'Month' 
                    ? 'This Month' 
                    : label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : darkCharcoal.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEarningCard(Map<String, dynamic> booking) {
    double comm = double.tryParse(booking['agent_commission']?.toString() ?? '0') ?? 0.0;
    String status = booking['booking_status'] ?? 'Pending';
    String tripType = booking['trip_type'] ?? '';
    Color statusColor = Colors.grey;
    if (status == 'Completed') {
      statusColor = Colors.green;
    } else if (status == 'Accepted' || status == 'Confirmed' || status == 'On Ride') {
      statusColor = Colors.blue;
    } else if (status == 'Cancelled' || status == 'Customer Cancelled' || status == 'Declined') {
      statusColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Trip ID #${booking['id']}",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                ),
              ),
              Row(
                children: [
                  if (tripType.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: primaryAmber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: primaryAmber.withOpacity(0.2), width: 0.5),
                      ),
                      child: Text(
                        tripType,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: primaryAmber,
                        ),
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.grey, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "${booking['from_address']} ➔ ${booking['to_address'] ?? 'Local'}",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: darkCharcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${booking['date']} • ${booking['time']}",
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                "+ ₹${comm.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: status == 'Cancelled' || status == 'Customer Cancelled' || status == 'Declined'
                      ? Colors.red.shade400
                      : Colors.green.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            "No commission earnings found for this period.",
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 60, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              "Failed to load earnings.",
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Please check your internet connection or try again.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
