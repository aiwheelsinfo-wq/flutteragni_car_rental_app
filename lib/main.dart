import 'package:agni_car_rental/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'agent_page.dart';
import 'CarSelectionPage.dart';
import 'bottom_nav_bar.dart';
import 'package:agni_car_rental/config/api_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 5));
    await FirebaseMessaging.instance.requestPermission().timeout(const Duration(seconds: 3));
    await NotificationService.instance.initialize().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Widget initialScreen =
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  @override
  void initState() {
    super.initState();

    // ✅ Delay heavy work to avoid UI freeze
    Future.delayed(const Duration(milliseconds: 500), () {
      checkStoredPhoneNumber();
    });
  }

  Future<void> checkStoredPhoneNumber() async {
    try {
      String? storedPhone = await storage
          .read(key: "phone_number")
          .timeout(const Duration(seconds: 3));

      // ✅ CASE 1: No user → go to login screen
      if (storedPhone == null || storedPhone.isEmpty) {
        if (!mounted) return;
        setState(() {
          initialScreen = AgentQuestionPage();
        });
        return;
      }

      // ✅ Run FCM in background (non-blocking)
      _setupFCM(storedPhone);

      // ✅ Check user in DB with timeout
      bool exists = await checkPhoneInDatabase(storedPhone);

      if (!mounted) return;

      setState(() {
        initialScreen = exists ? BottomNavBar() : AgentQuestionPage();
      });
    } catch (e) {
      debugPrint("Startup Error: $e");

      // ✅ Fail-safe fallback (VERY IMPORTANT)
      if (!mounted) return;
      setState(() {
        initialScreen = AgentQuestionPage();
      });
    }
  }

  // ✅ FCM moved to separate safe function
  Future<void> _setupFCM(String phone) async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      await FirebaseMessaging.instance
          .subscribeToTopic("rentox_customer")
          .timeout(const Duration(seconds: 5));

      await FirebaseMessaging.instance
          .subscribeToTopic("rentox_all")
          .timeout(const Duration(seconds: 5));

      if (fcmToken != null) {
        await http.post(
          Uri.parse("${ApiConfig.baseUrl}/update_cust_fcm.php"),
          body: {
            "phone_number": phone,
            "fcm_token": fcmToken,
          },
        ).timeout(const Duration(seconds: 8));
      }
    } catch (e) {
      debugPrint("FCM Error: $e");
    }
  }

  Future<bool> checkPhoneInDatabase(String phoneNumber) async {
    const String apiUrl = "${ApiConfig.baseUrl}/checkPhone.php";

    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {"phone_number": phoneNumber},
      ).timeout(const Duration(seconds: 8)); // ✅ CRITICAL

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        return jsonResponse["success"] == true;
      }
    } catch (e) {
      debugPrint("Check Phone Error: $e");
    }

    return false; // ✅ safe fallback
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rentox Car Rental',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: initialScreen,
      routes: {
        '/CarSelectionPage': (context) => CarSelectionPage(),
      },
    );
  }
}
