import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CancellationSuccessPage extends StatelessWidget {
  final String bookingId;
  final double advancePaid;
  final double cancellationCharge;
  final double refundAmount;
  final String refundStatus;
  final bool isLocalTaxi;

  const CancellationSuccessPage({
    super.key,
    required this.bookingId,
    required this.advancePaid,
    required this.cancellationCharge,
    required this.refundAmount,
    required this.refundStatus,
    this.isLocalTaxi = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Success Animation Circle
              TweenAnimationBuilder(
                duration: const Duration(milliseconds: 600),
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2E7D32),
                        size: 64,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                "Booking Cancelled",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF263238),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Booking ID: #$bookingId",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 32),
              // Refund Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "REFUND SUMMARY",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[400],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildRow("Advance Paid", "₹${advancePaid.toStringAsFixed(0)}", false),
                    const SizedBox(height: 12),
                    _buildRow("Cancellation Charge", "₹${cancellationCharge.toStringAsFixed(0)}", false, valueColor: Colors.red[700]),
                    const Divider(height: 24, thickness: 0.5),
                    _buildRow("Refund Amount", "₹${refundAmount.toStringAsFixed(0)}", true, valueColor: const Color(0xFF2E7D32)),
                    if (!isLocalTaxi) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                refundAmount > 0
                                    ? "Refund of ₹${refundAmount.toStringAsFixed(0)} will be processed within 3–7 business days."
                                    : "Cancellation charges equal the paid advance amount. No refund is due.",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLocalTaxi
                            ? Colors.green.shade50.withOpacity(0.3)
                            : Colors.amber.shade50.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLocalTaxi ? Colors.green.shade200 : Colors.amber.shade200,
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.policy_outlined,
                                size: 14,
                                color: isLocalTaxi ? Colors.green.shade900 : Colors.amber.shade900,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "CANCELLATION POLICY REFERENCE",
                                style: GoogleFonts.poppins(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isLocalTaxi ? Colors.green.shade900 : Colors.amber.shade900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 12, thickness: 0.5),
                          isLocalTaxi
                              ? Text(
                                  "Free Cancellation - You can cancel your Local Taxi booking anytime before the trip starts with no cancellation fee.",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                )
                              : Column(
                                  children: [
                                    _buildPolicyRuleRow("More than 48 Hours", "100% Refund", isGreen: true),
                                    _buildPolicyRuleRow("24–48 Hours", "75% Refund"),
                                    _buildPolicyRuleRow("12–24 Hours", "50% Refund"),
                                    _buildPolicyRuleRow("6–12 Hours", "25% Refund"),
                                    _buildPolicyRuleRow("Less than 6 Hours", "No Refund", isRed: true),
                                  ],
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Done Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB300),
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "BACK TO TRIP STATUS",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isHighlight, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isHighlight ? 14 : 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? Colors.black87 : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: isHighlight ? 18 : 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyRuleRow(String timing, String refund, {bool isGreen = false, bool isRed = false}) {
    Color valColor = Colors.black87;
    if (isGreen) valColor = const Color(0xFF2E7D32);
    if (isRed) valColor = const Color(0xFFC62828);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            timing,
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              Text(
                "→  ",
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.bold),
              ),
              Text(
                refund,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: valColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
