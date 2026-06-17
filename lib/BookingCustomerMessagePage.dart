import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Add to pubspec.yaml
import 'bookingStatusPage.dart';
import 'bottom_nav_bar.dart'; // Assuming this is your home wrapper

class BookingCustomerMessagePage extends StatelessWidget {
  const BookingCustomerMessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Professional Amber Theme Palette
    const Color primaryAmber = Color(0xFFFFB300);
    const Color darkText = Color(0xFF2D2D2D);
    const Color secondaryBg = Color(0xFFFFF9E7);

    return Scaffold(
      backgroundColor: primaryAmber,
      body: Stack(
        children: [
          // 1. Bottom White Sheet for clean UI
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Animated-like Success Icon Section
                  _buildSuccessIllustration(primaryAmber),

                  const SizedBox(height: 30),

                  // Text Content
                  Text(
                    "Booking Confirmed!",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    "Your journey has been successfully booked. Your travel assistant is assigning the best driver for you.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),

                  const Spacer(),

                  // 3. Informational Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: secondaryBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primaryAmber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: primaryAmber),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            "You can track your driver and get contact details in the activity section.",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.brown.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 4. Action Buttons
                  _buildActionButton(
                    context,
                    label: "Check Ride Status",
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => BookingStatusPage()),
                    ),
                    color: darkText,
                    textColor: primaryAmber,
                  ),

                  const SizedBox(height: 15),

                  TextButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => BottomNavBar()),
                      (route) => false,
                    ),
                    child: Text(
                      "Back to Home",
                      style: GoogleFonts.poppins(
                        color: darkText.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessIllustration(Color amber) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 140,
          width: 140,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          height: 110,
          width: 110,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 5),
              )
            ],
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 70,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required String label,
      required VoidCallback onPressed,
      required Color color,
      required Color textColor}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
