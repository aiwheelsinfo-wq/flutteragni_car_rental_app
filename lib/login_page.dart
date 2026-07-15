import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:agni_car_rental/config/api_config.dart';
import 'SavePhonePage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool isOtpSent = false;
  bool isLoading = false;
  String? generatedOtp;

  // --- Professional Amber Theme Palette ---
  final Color primaryAmber = const Color(0xFFFFB300); // Deep Amber
  final Color secondaryAmber = const Color(0xFFFFD54F); // Light Amber
  final Color darkText = const Color(0xFF212121); // Almost Black for text
  final Color inputFill = const Color(0xFFF5F5F5); // Light Grey for fields

  final String apiKey =
      "p9J1ofaxrnDXePcsUTdlRu630Vg7KQiWMC24OEmjwFSByh8AH5R5n6sSBzCuvQATbf2g87hV9mtqd0GD";

  // --- Logic Functions ---
  String generateOTP(int length) {
    const characters = '0123456789';
    return String.fromCharCodes(Iterable.generate(length,
        (_) => characters.codeUnitAt(Random().nextInt(characters.length))));
  }

  Future<void> _handleSendOtp() async {
    String phone = _phoneController.text.trim();
    if (phone.length != 10) {
      _showToast("Please enter a valid 10-digit number", isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1. Check Phone Status
      var statusUrl =
          Uri.parse("${ApiConfig.baseUrl}/check_phone_status.php");
      var response = await http.post(statusUrl, body: {"phone": phone});
      var statusData = jsonDecode(response.body);

      if (statusData['status'] == "blocked") {
        _showToast("This mobile number is blocked.", isError: true);
        setState(() => isLoading = false);
        return;
      }

      // 2. Generate and Send OTP (via our server send_otp.php proxy to support both SMS and WhatsApp)
      String otp = generateOTP(6);
      String smsUrl =
          "${ApiConfig.baseUrl}/send_otp.php?authorization=$apiKey&route=dlt&sender_id=agni&message=170275&variables_values=$otp&flash=0&numbers=$phone";

      var smsResponse = await http.get(Uri.parse(smsUrl));
      var smsData = jsonDecode(smsResponse.body);

      if (smsData["return"] == true) {
        setState(() {
          generatedOtp = otp;
          isOtpSent = true;
        });
        _showToast("OTP sent successfully to $phone");
      } else {
        _showToast("SMS Gateway Error", isError: true);
      }
    } catch (e) {
      _showToast("Connection error. Try again.", isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? Colors.redAccent : darkText,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: darkText, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [secondaryAmber, primaryAmber],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // 🔹 Top Branding
                Image.asset("assets/home.png", height: 55),
                const SizedBox(height: 5),
                Text(
                  "CAR RENTALS",
                  style: GoogleFonts.montserrat(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: darkText,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  "Your premium travel partner",
                  style: GoogleFonts.poppins(
                      color: darkText.withOpacity(0.6), fontSize: 14),
                ),
                const SizedBox(height: 40),

                // 🔹 Main Interaction Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        isOtpSent ? "Verify Mobile" : "Login / Signup",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: darkText,
                        ),
                      ),
                      const SizedBox(height: 25),

                      // 📱 Phone Input
                      _buildTextField(
                        controller: _phoneController,
                        label: "Phone Number",
                        icon: Icons.phone_android_rounded,
                        type: TextInputType.phone,
                        enabled: !isOtpSent,
                        limit: 10,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(
                              14), // allow +91XXXXXXXXXX
                        ],
                        onChanged: (value) {
                          // Remove country code if pasted (like +91XXXXXXXXXX)
                          if (value.length > 10) {
                            final cleaned = value.substring(value.length - 10);
                            _phoneController.value = TextEditingValue(
                              text: cleaned,
                              selection: TextSelection.collapsed(
                                  offset: cleaned.length),
                            );
                          }
                        },
                      ),

                      // 🔢 OTP Input
                      if (isOtpSent) ...[
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _otpController,
                          label: "6-Digit OTP",
                          icon: Icons.security_rounded,
                          type: TextInputType.number,
                          limit: 6,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                        ),
                      ],

                      const SizedBox(height: 30),

                      // 🚀 Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : (isOtpSent ? _verifyOtp : _handleSendOtp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkText,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 5,
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(
                                  isOtpSent ? "CONFIRM & PROCEED" : "SEND OTP",
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                        ),
                      ),

                      if (isOtpSent)
                        TextButton(
                          onPressed: () => setState(() => isOtpSent = false),
                          child: Text(
                            "Edit Phone Number",
                            style: TextStyle(
                                color: darkText.withOpacity(0.5), fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                Text(
                  "By continuing, you agree to our Terms & Conditions",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: darkText.withOpacity(0.5), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    bool enabled = true,
    int? limit,
    List<String>? autofillHints,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      enabled: enabled,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters ??
          (limit != null ? [LengthLimitingTextInputFormatter(limit)] : null),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim() == generatedOtp) {
      HapticFeedback.lightImpact();
      final phoneNumber = _phoneController.text.trim();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (context) => SavePhonePage(phoneNumber: phoneNumber)),
        (route) => false,
      );
    } else {
      _showToast("Invalid OTP entered", isError: true);
    }
  }
}
