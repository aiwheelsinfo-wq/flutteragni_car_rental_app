import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:agni_car_rental/config/api_config.dart';

class ActivityPage extends StatefulWidget {
  @override
  _ActivityPageState createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  List<dynamic> bookings = [];
  String? phoneNumber;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPhoneNumberAndBookings();
  }

  Future<void> fetchPhoneNumberAndBookings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    phoneNumber = prefs.getString('phone_number');

    if (phoneNumber != null) {
      fetchBookingData(phoneNumber!);
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchBookingData(String phone) async {
    final String apiUrl =
        "${ApiConfig.baseUrl}/bookingStatus.php?phone_number=$phone";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            bookings = data['data'];
          });
        }
      } else {
        print('Failed to load bookings: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching bookings: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget buildBookingCard(Map<String, dynamic> booking) {
    // Extract prices and discount
    double baseAmount =
        double.tryParse(booking['baseAmount']?.toString() ?? '0') ?? 0;
    double discountedPrice =
        double.tryParse(booking['discounted_price']?.toString() ?? '0') ?? 0;
    double discountPercentage =
        double.tryParse(booking['discount_percentage']?.toString() ?? '0') ?? 0;

    bool hasDiscount = discountedPrice > 0 && discountPercentage > 0;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title: Car Type and Trip Type
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  booking['car_type'] ?? 'Car',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[900],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    booking['trip_type'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),

            // From - To Locations
            Text(
              "From: ${booking['from_address'] ?? 'N/A'}",
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            Text(
              "To: ${booking['to_address'] ?? 'N/A'}",
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            SizedBox(height: 8),

            // Date and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Date: ${booking['date'] ?? 'N/A'}",
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
                Text(
                  "Status: ${booking['booking_status'] ?? 'N/A'}",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: booking['booking_status'] == 'Accepted'
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Price section with discount
            Row(
              children: [
                if (hasDiscount) ...[
                  Text(
                    "₹${baseAmount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.redAccent,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "₹${discountedPrice.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "-${discountPercentage.toStringAsFixed(0)}%",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    "₹${baseAmount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.blueGrey[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Your Bookings"),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : bookings.isEmpty
              ? Center(child: Text("No bookings found."))
              : ListView.builder(
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    return buildBookingCard(bookings[index]);
                  },
                ),
    );
  }
}
