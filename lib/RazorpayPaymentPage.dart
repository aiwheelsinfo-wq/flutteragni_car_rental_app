import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:agni_car_rental/config/api_config.dart';
import 'BookingCustomerMessagePage.dart';

class RazorpayPaymentPage extends StatefulWidget {
  final String bookingId;
  final double amount;
  final bool isFullPay;

  RazorpayPaymentPage({
    required this.bookingId,
    required this.amount,
    required this.isFullPay,
  });

  @override
  _RazorpayPaymentPageState createState() => _RazorpayPaymentPageState();
}

class _RazorpayPaymentPageState extends State<RazorpayPaymentPage> {
  late Razorpay _razorpay;
  String? _razorpayKey;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _fetchConfigAndOpenCheckout();
  }

  Future<void> _fetchConfigAndOpenCheckout() async {
    try {
      final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/get_razorpay_config.php"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['razorpay_key'] != null) {
          setState(() {
            _razorpayKey = data['razorpay_key'];
            _isLoading = false;
          });
          _openCheckout();
          return;
        }
      }
      throw Exception("Invalid configuration response");
    } catch (e) {
      print("Error fetching Razorpay configuration: $e");
      setState(() {
        _errorMessage = "Failed to load payment configuration. Please try again.";
        _isLoading = false;
      });
    }
  }

  void _openCheckout() {
    if (_razorpayKey == null) return;
    var options = {
      'key': _razorpayKey, // Dynamically loaded key
      'amount': (widget.amount * 100).toInt(),
      'name': 'Agni Car Rental',
      'description': widget.isFullPay ? 'Full Payment' : 'Part Payment',
      'prefill': {
        'email': '',
        'contact': '',
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print("Error opening Razorpay checkout: $e");
    }
  }

  Future<void> _handleSuccess(PaymentSuccessResponse response) async {
    print("Payment Successful: ${response.paymentId}");

    var url = Uri.parse("${ApiConfig.baseUrl}/updatePayment.php");

    try {
      var updateRes = await http.post(
        url,
        headers: {
          "Content-Type": "application/json", // 👈 VERY important!
        },
        body: json.encode({
          "booking_id": widget.bookingId,
          "payment_id": response.paymentId ?? "",
          "status": "success",
          "amount": widget.amount,
        }),
      );

      print("Server response: ${updateRes.body}");

      var resData = json.decode(updateRes.body);
      if (resData['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => BookingCustomerMessagePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment saved but booking update failed!")),
        );
      }
    } catch (e) {
      print("Error during booking update: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment was successful, but update failed.")),
      );
    }
  }

  Future<void> _handleError(PaymentFailureResponse response) async {
    print("Payment Failed: ${response.message}");
    var url = Uri.parse("${ApiConfig.baseUrl}/updatePayment.php");
    try {
      await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: json.encode({
          "booking_id": widget.bookingId,
          "payment_id": "",
          "status": "failed",
          "amount": widget.amount,
        }),
      );
    } catch (e) {
      print("Error during marking payment as failed: $e");
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment failed! Try again.")),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _fetchConfigAndOpenCheckout();
                  },
                  child: const Text("Retry"),
                )
              ],
            ),
          ),
        ),
      );
    }
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
