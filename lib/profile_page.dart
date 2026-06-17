import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agni_car_rental/config/api_config.dart';
import 'package:agni_car_rental/agent_page.dart';

class UserProfilePage extends StatefulWidget {
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? user;
  bool isLoading = true;
  String? error;

  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  String? savedNumber;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  // --- Theme Logic Remains Same ---
  Map<String, dynamic> getBadgeTheme(String badge) {
    switch (badge.toLowerCase()) {
      case 'gold':
        return {
          'primary': const Color(0xFFFF8F00),
          'secondary': const Color(0xFFFFD54F),
          'text': const Color(0xFF4E342E),
          'gradient': [const Color(0xFFFF8F00), const Color(0xFFFFD54F)],
          'iconBg': const Color(0xFFFFF3E0),
        };
      case 'silver':
        return {
          'primary': const Color(0xFF607D8B),
          'secondary': const Color(0xFFCFD8DC),
          'text': const Color(0xFF263238),
          'gradient': [const Color(0xFF455A64), const Color(0xFFB0BEC5)],
          'iconBg': const Color(0xFFECEFF1),
        };
      case 'green':
        return {
          'primary': const Color(0xFF2E7D32),
          'secondary': const Color(0xFF81C784),
          'text': const Color(0xFF1B5E20),
          'gradient': [const Color(0xFF1B5E20), const Color(0xFF4CAF50)],
          'iconBg': const Color(0xFFE8F5E9),
        };
      default:
        return {
          'primary': Colors.blueGrey,
          'secondary': Colors.grey,
          'text': Colors.black87,
          'gradient': [Colors.blueGrey, Colors.grey],
          'iconBg': Colors.grey.shade100,
        };
    }
  }

  Future<void> fetchUserData() async {
    try {
      savedNumber = await secureStorage.read(key: 'phone_number');
      final url = Uri.parse(
          '${ApiConfig.baseUrl}/get_customer_data.php?phone_number=$savedNumber');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          setState(() {
            user = jsonData['user'];
            isLoading = false;
          });
        } else {
          setState(() {
            error = "User not found";
            isLoading = false;
          });
        }
      } else {
        setState(() {
          error = "Failed to fetch data";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Connection error";
        isLoading = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await secureStorage.delete(key: 'phone_number');
    if (mounted) {
      // Close the confirmation dialog
      Navigator.of(context).pop();
      // Redirect to the onboarding/selection page and clear the navigation stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AgentQuestionPage()),
        (route) => false,
      );
    }
  }

  String cleanDisplayVal(dynamic val, {String fallback = 'N/A'}) {
    if (val == null) return fallback;
    final s = val.toString().trim();
    if (s.toLowerCase() == 'not filled' || s.isEmpty) return fallback;
    return s;
  }

  String _buildLocationString(dynamic city, dynamic pincode) {
    final cleanCity = city != null && city.toString().trim().toLowerCase() != 'not filled' ? city.toString().trim() : '';
    final cleanPincode = pincode != null && pincode.toString().trim().toLowerCase() != 'not filled' ? pincode.toString().trim() : '';
    if (cleanCity.isEmpty && cleanPincode.isEmpty) return 'N/A';
    if (cleanCity.isEmpty) return cleanPincode;
    if (cleanPincode.isEmpty) return cleanCity;
    return "$cleanCity, $cleanPincode";
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    const Color bgCream = Color(0xFFFDFDFD);

    if (isLoading) {
      return const Scaffold(
        backgroundColor: bgCream,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final badgeString = user?['badge'] ?? 'default';
    final theme = getBadgeTheme(badgeString);

    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        title: Text("Profile",
            style: GoogleFonts.poppins(
                color: theme['text'],
                fontWeight: FontWeight.bold,
                fontSize: size.width * 0.045)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: theme['primary']),
            onPressed: () => _showLogoutDialog(theme),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildMembershipCard(badgeString, theme, size),
              const SizedBox(height: 30),
              _buildSectionTitle("Contact Details", theme),
              const SizedBox(height: 15),
              _buildInfoTile(Icons.phone_android, "Mobile",
                  cleanDisplayVal(user!['phone_number']), theme),
              _buildInfoTile(Icons.alternate_email, "Email",
                  cleanDisplayVal(user!['email']), theme),
              _buildInfoTile(Icons.map_outlined, "Location",
                  _buildLocationString(user!['city'], user!['pincode']), theme),
              const SizedBox(height: 30),
              _buildSectionTitle("Tier Benefits", theme),
              const SizedBox(height: 15),
              _buildBenefitsGrid(badgeString, theme, size),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipCard(
      String badge, Map<String, dynamic> theme, Size size) {
    return AspectRatio(
      aspectRatio: 1.8, // Maintains a pro shape across all devices
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme['gradient'],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size.width * 0.06),
          boxShadow: [
            BoxShadow(
              color: (theme['primary'] as Color).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -size.width * 0.05,
              top: -size.width * 0.05,
              child: Icon(Icons.shield,
                  size: size.width * 0.35,
                  color: Colors.white.withOpacity(0.1)),
            ),
            Padding(
              padding: EdgeInsets.all(size.width * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${badge.toUpperCase()} TIER",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: size.width * 0.025,
                              letterSpacing: 1.2),
                        ),
                      ),
                      Icon(Icons.verified_user,
                          color: Colors.white, size: size.width * 0.07),
                    ],
                  ),
                  Flexible(
                    child: Text(
                      user!['name']?.toUpperCase() ?? 'CUSTOMER',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: size.width * 0.055,
                          fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Map<String, dynamic> theme) {
    return Text(title,
        style: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.bold, color: theme['text']));
  }

  Widget _buildInfoTile(
      IconData icon, String label, String value, Map<String, dynamic> theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: theme['iconBg'],
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: theme['primary'], size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            // Key fix: Allows text to wrap or truncate instead of overflowing
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                Text(value,
                    style: GoogleFonts.poppins(
                        color: theme['text'],
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBenefitsGrid(
      String badge, Map<String, dynamic> theme, Size size) {
    final benefits = [
      {"name": "Priority Support", "icon": Icons.headset_mic},
      {"name": "Extra Spin", "icon": Icons.casino},
      {"name": "Coupons", "icon": Icons.local_offer},
      {"name": "Free Delivery", "icon": Icons.delivery_dining},
      {"name": "Special Offers", "icon": Icons.star},
      {"name": "Exclusive Events", "icon": Icons.event},
      {"name": "Loyalty Points", "icon": Icons.wallet_giftcard},
      {"name": "Premium Lounge", "icon": Icons.chair},
      {"name": "Gift Vouchers", "icon": Icons.card_giftcard},
      {"name": "Rewards", "icon": Icons.celebration},
    ];

    int activeCount = (badge.toLowerCase() == 'gold')
        ? 10
        : (badge.toLowerCase() == 'silver')
            ? 6
            : 4;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            size.width > 600 ? 3 : 2, // Responsive columns for tablets
        childAspectRatio:
            size.width < 360 ? 2.2 : 2.8, // Adjust ratio for very small screens
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: benefits.length,
      itemBuilder: (context, index) {
        bool isActive = index < activeCount;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isActive
                    ? (theme['primary'] as Color).withOpacity(0.2)
                    : Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(benefits[index]['icon'] as IconData,
                  size: 14,
                  color: isActive ? theme['primary'] : Colors.grey.shade400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  benefits[index]['name'] as String,
                  style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive ? theme['text'] : Colors.grey.shade400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog(Map<String, dynamic> theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to exit?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("No", style: TextStyle(color: theme['text']))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: theme['primary'],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _handleLogout,
            child: const Text("Yes, Logout"),
          ),
        ],
      ),
    );
  }
}
