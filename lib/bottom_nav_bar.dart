import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'TripSelectionPage.dart';
import 'bookingStatusPage.dart';
import 'profile_page.dart';
import 'AgentEarningsPage.dart';

class BottomNavBar extends StatefulWidget {
  @override
  _BottomNavBarState createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  String? userType;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserType();
  }

  Future<void> _loadUserType() async {
    try {
      String? type = await secureStorage.read(key: 'userType');
      setState(() {
        userType = type;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error reading userType: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  List<Widget> _getPages() {
    if (userType == 'agent') {
      return [
        TripSelectionPage(),
        BookingStatusPage(),
        const AgentEarningsPage(),
        UserProfilePage()
      ];
    } else {
      return [
        TripSelectionPage(),
        BookingStatusPage(),
        UserProfilePage()
      ];
    }
  }

  // --- Soft Amber Palette ---
  final Color navBackground = const Color(0xFFFFF9E7); // Very soft cream-amber
  final Color activeAccent = const Color(0xFFFF8F00); // Deep warm amber
  final Color inactiveColor = const Color(0xFFA89A7B); // Muted sandy taupe

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    final pages = _getPages();
    if (_selectedIndex >= pages.length) {
      _selectedIndex = 0;
    }

    return Scaffold(
      // IndexedStack preserves the state/scroll of your pages
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBackground,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: BottomNavigationBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              selectedItemColor: activeAccent,
              unselectedItemColor: inactiveColor,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              selectedLabelStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              items: [
                BottomNavigationBarItem(
                  icon: _buildIcon(Icons.home_outlined, Icons.home_rounded, 0),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: _buildIcon(Icons.receipt_long_outlined,
                      Icons.receipt_long_rounded, 1),
                  label: 'My Trips',
                ),
                if (userType == 'agent')
                  BottomNavigationBarItem(
                    icon: _buildIcon(Icons.account_balance_wallet_outlined,
                        Icons.account_balance_wallet_rounded, 2),
                    label: 'Earnings',
                  ),
                BottomNavigationBarItem(
                  icon: _buildIcon(
                      Icons.person_outline_rounded, Icons.person_rounded, userType == 'agent' ? 3 : 2),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(IconData outline, IconData filled, int index) {
    bool isSelected = _selectedIndex == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        // Soft pill-shaped background for the active item
        color: isSelected ? activeAccent.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        isSelected ? filled : outline,
        size: 24,
      ),
    );
  }
}
