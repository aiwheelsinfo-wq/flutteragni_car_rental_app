import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'agent_reg.dart';
import 'package:agni_car_rental/config/api_config.dart';
import 'bottom_nav_bar.dart';

class SavePhonePage extends StatefulWidget {
  final String phoneNumber;

  const SavePhonePage({super.key, required this.phoneNumber});

  @override
  _SavePhonePageState createState() => _SavePhonePageState();
}

class _SavePhonePageState extends State<SavePhonePage> {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  String statusMessage = "Signing you in securely...";

  // Colors matching Rentox branding
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color secondaryAmber = const Color(0xFFFFD54F);
  final Color darkText = const Color(0xFF1E2022);

  @override
  void initState() {
    super.initState();
    savePhoneNumber();
  }

  Future<void> savePhoneNumber() async {
    final cleanPhone = widget.phoneNumber.trim();

    // 1. Immediately store phone number in secure storage so authentication is safe
    try {
      await storage.write(key: "phone_number", value: cleanPhone);
    } catch (e) {
      debugPrint("Error writing phone_number to secure storage: $e");
    }

    // 2. Fetch userType (fallback to 'customer' if not set)
    String? userType;
    try {
      userType = await storage.read(key: "userType");
    } catch (_) {}
    if (userType == null || userType.isEmpty) {
      userType = 'customer';
      try {
        await storage.write(key: "userType", value: 'customer');
      } catch (_) {}
    }

    // 3. Get FCM Token with a strict 3-second timeout so it NEVER hangs
    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint("FCM token fetch timed out after 3s, proceeding without token");
          return null;
        },
      );
    } catch (e) {
      debugPrint("FCM token error: $e");
    }

    // 4. Subscribe to topics in background without blocking login
    try {
      FirebaseMessaging.instance.subscribeToTopic("rentox_customer").catchError((_) {});
      FirebaseMessaging.instance.subscribeToTopic("rentox_all").catchError((_) {});
    } catch (_) {}

    // 5. Send FCM Token and Phone to Backend with a 5-second timeout
    String apiUrl = "${ApiConfig.baseUrl}/savePhone.php";
    try {
      await http.post(
        Uri.parse(apiUrl),
        body: {
          "phone_number": cleanPhone,
          "userType": userType,
          "fcm_token": fcmToken ?? "",
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint("savePhone.php timed out, proceeding to app");
          return http.Response('{"success":true,"timeout":true}', 200);
        },
      );
    } catch (e) {
      debugPrint("savePhone.php error: $e");
    }

    // Small smooth delay
    await Future.delayed(const Duration(milliseconds: 300));

    // 6. Seamlessly Navigate to Destination Page
    if (!mounted) return;
    if (userType == 'agent') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => AgentRegistrationPage()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => BottomNavBar()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Branded Logo
                Image.asset(
                  "assets/home.png",
                  height: 60,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.directions_car_filled_rounded,
                    size: 60,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "RENTOX",
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: darkText,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 32),
                // Smooth Progress Indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(darkText),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  statusMessage,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: darkText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
