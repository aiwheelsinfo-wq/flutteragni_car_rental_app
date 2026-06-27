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

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleError);
    _openCheckout();
  }

  void _openCheckout() {
    var options = {
      'key': ApiConfig.razorpayKey, // Replace with your actual key
      'amount': (widget.amount * 100).toInt(), //(1 * 100).toInt(),
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
    return Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
