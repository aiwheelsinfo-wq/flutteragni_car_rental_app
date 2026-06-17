import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:agni_car_rental/config/api_config.dart';

// Import your existing pages
import 'login_page.dart';

class AgentQuestionPage extends StatefulWidget {
  const AgentQuestionPage({Key? key}) : super(key: key);

  @override
  State<AgentQuestionPage> createState() => _AgentQuestionPageState();
}

class _AgentQuestionPageState extends State<AgentQuestionPage> {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  bool isOffline = false;
  bool isChecking = true;

  // Theme Colors
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color secondaryYellow = const Color(0xFFFFD54F);
  final Color darkCharcoal = const Color(0xFF1A1A1A);
  final Color surfaceGrey = const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    checkConnection();
  }

  Future<void> checkConnection() async {
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/selectCarCostList.php?tripType=One-way'))
          .timeout(const Duration(seconds: 5));

      setState(() {
        isOffline = response.statusCode != 200;
        isChecking = false;
      });
    } catch (e) {
      setState(() {
        isOffline = true;
        isChecking = false;
      });
    }
  }

  Future<void> _handleSelection(String type) async {
    await storage.write(key: 'userType', value: type);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isChecking
          ? Center(child: CircularProgressIndicator(color: primaryAmber))
          : isOffline
              ? _buildOfflineView()
              : _buildMainSelectionView(),
    );
  }

  Widget _buildMainSelectionView() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [surfaceGrey, Colors.white],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),
              // Brand Logo or Icon Placeholder
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryAmber,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.directions_car_filled,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(height: 25),
              Text(
                "Welcome to\nRentox Car Rental",
                textAlign: TextAlign.center, // 👈 This centers the text
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: darkCharcoal,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 10),
              Text(
                "Please select your account type to continue your journey with us.",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 50),

              // Agent Selection Card
              _buildSelectionCard(
                title: "Travel Agent",
                subtitle:
                    "Book for clients and earn high commissions on every trip.",
                icon: Icons.business_center_rounded,
                onTap: () => _handleSelection('agent'),
                isPrimary: true,
              ),

              const SizedBox(height: 20),

              // Customer Selection Card
              _buildSelectionCard(
                title: "Passenger",
                subtitle:
                    "Quick booking for personal trips with affordable rates.",
                icon: Icons.person_rounded,
                onTap: () => _handleSelection('customer'),
                isPrimary: false,
              ),

              const Spacer(),
              Center(
                child: Text(
                  "You can change this later in settings",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPrimary ? darkCharcoal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPrimary ? darkCharcoal : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? primaryAmber.withOpacity(0.2)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPrimary ? primaryAmber : surfaceGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isPrimary ? Colors.white : darkCharcoal,
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPrimary ? Colors.white : darkCharcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isPrimary ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isPrimary ? primaryAmber : Colors.grey,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 80, color: Colors.red.shade300),
            const SizedBox(height: 20),
            Text(
              "No Internet Connection",
              style: GoogleFonts.poppins(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Please check your network settings and try again.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                setState(() => isChecking = true);
                checkConnection();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryAmber,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Retry"),
            )
          ],
        ),
      ),
    );
  }
}
