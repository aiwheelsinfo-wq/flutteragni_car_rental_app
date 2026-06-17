import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import secure storage
import 'agent_reg.dart';
import 'package:agni_car_rental/config/api_config.dart';
import 'bottom_nav_bar.dart'; // Import the new page

class SavePhonePage extends StatefulWidget {
  final String phoneNumber;

  SavePhonePage({required this.phoneNumber});

  @override
  _SavePhonePageState createState() => _SavePhonePageState();
}

class _SavePhonePageState extends State<SavePhonePage> {
  bool isSaving = true;
  String message = "Saving phone number...";
  final FlutterSecureStorage storage =
      FlutterSecureStorage(); // Initialize secure storage

  @override
  void initState() {
    super.initState();
    savePhoneNumber();
  }

  void savePhoneNumber() async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    await FirebaseMessaging.instance.subscribeToTopic("rentox_customer");
    await FirebaseMessaging.instance.subscribeToTopic("rentox_all");
    String? userType = await storage.read(key: "userType");
    String apiUrl = "${ApiConfig.baseUrl}/savePhone.php";
    try {
      var response = await http.post(
        Uri.parse(apiUrl),
        body: {
          "phone_number": widget.phoneNumber,
          "userType": userType,
          "fcm_token": fcmToken,
        },
      );

      var jsonResponse = jsonDecode(response.body);

      if (jsonResponse["success"] == true) {
        // ✅ Store phone number securely
        await storage.write(key: "phone_number", value: widget.phoneNumber);
        if (userType == 'agent') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AgentRegistrationPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => BottomNavBar()),
          );
        }
        // ✅ Navigate to Trip Selection Page
      } else {
        setState(() {
          isSaving = false;
          message = "Failed to Save Phone Number.";
        });
      }
    } catch (e) {
      setState(() {
        isSaving = false;
        message = "Error saving phone number!";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Save Phone Number")),
      body: Center(
        child: isSaving
            ? CircularProgressIndicator()
            : Text(
                message,
                style: TextStyle(fontSize: 18, color: Colors.black),
              ),
      ),
    );
  }
}
