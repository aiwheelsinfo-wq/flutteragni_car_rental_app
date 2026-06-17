import 'package:flutter/material.dart';
import 'SavePhonePage.dart'; // Import SavePhonePage

class OTPVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final String otp; // OTP from Fast2SMS

  OTPVerificationPage({required this.phoneNumber, required this.otp});

  @override
  _OTPVerificationPageState createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  TextEditingController otpController = TextEditingController();
  String errorMessage = "";

  void verifyOTP() {
    if (widget.phoneNumber == '9619963999' && otpController.text == '961996') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OTP Verified Successfully!")),
      );

      // ✅ Navigate to SavePhonePage after OTP verification
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => SavePhonePage(phoneNumber: widget.phoneNumber),
        ),
        (Route<dynamic> route) => false,
      );
    } else {
      setState(() {
        errorMessage = "Invalid OTP. Please try again.";

        if (otpController.text == widget.otp) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("OTP Verified Successfully!")),
          );

          // ✅ Navigate to SavePhonePage after OTP verification
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SavePhonePage(phoneNumber: widget.phoneNumber),
            ),
            (Route<dynamic> route) => false,
          );
        } else {
          setState(() {
            errorMessage = "Invalid OTP. Please try again.";
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Verify OTP")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Enter OTP sent to ${widget.phoneNumber}"),
            SizedBox(height: 10),

            // ✅ Standard OTP Input Field
            TextField(
              controller: otpController,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Enter OTP",
                border: OutlineInputBorder(),
              ),
            ),

            SizedBox(height: 10),
            if (errorMessage.isNotEmpty)
              Text(
                errorMessage,
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: verifyOTP,
              child: Text("Verify OTP"),
            ),
          ],
        ),
      ),
    );
  }
}
