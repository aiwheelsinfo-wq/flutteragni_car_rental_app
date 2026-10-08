import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:agni_car_rental/config/api_config.dart';

class TripFeedbackDialog extends StatefulWidget {
  final String bookingId;
  final String? driverName;
  final String? carType;
  final String? customerPhone;
  final int? initialRating;
  final String? initialTags;
  final String? initialComment;

  const TripFeedbackDialog({
    Key? key,
    required this.bookingId,
    this.driverName,
    this.carType,
    this.customerPhone,
    this.initialRating,
    this.initialTags,
    this.initialComment,
  }) : super(key: key);

  static Future<bool?> show(
    BuildContext context, {
    required String bookingId,
    String? driverName,
    String? carType,
    String? customerPhone,
    int? initialRating,
    String? initialTags,
    String? initialComment,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TripFeedbackDialog(
        bookingId: bookingId,
        driverName: driverName,
        carType: carType,
        customerPhone: customerPhone,
        initialRating: initialRating,
        initialTags: initialTags,
        initialComment: initialComment,
      ),
    );
  }

  @override
  State<TripFeedbackDialog> createState() => _TripFeedbackDialogState();
}

class _TripFeedbackDialogState extends State<TripFeedbackDialog> {
  int _selectedRating = 5;
  final List<String> _selectedTags = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialRating != null && widget.initialRating! >= 1 && widget.initialRating! <= 5) {
      _selectedRating = widget.initialRating!;
    }
    if (widget.initialTags != null && widget.initialTags!.trim().isNotEmpty) {
      final tags = widget.initialTags!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      _selectedTags.addAll(tags);
    }
    if (widget.initialComment != null && widget.initialComment!.trim().isNotEmpty) {
      _commentController.text = widget.initialComment!.trim();
    }
  }

  final List<String> _positiveTags = [
    '✨ Clean Car',
    '👔 Professional Driver',
    '⏱️ On-Time Pickup',
    '❄️ Great AC',
    '🛣️ Smooth Driving',
    '💬 Polite & Helpful',
  ];

  final List<String> _criticalTags = [
    '⚠️ Rash Driving',
    '⏱️ Late Pickup',
    '🧹 Unclean Car',
    '❄️ AC Issue',
    '🗣️ Rude Behavior',
    '💰 Route / Fare Issue',
  ];

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return '😞 Poor Experience';
      case 2:
        return '😕 Could be better';
      case 3:
        return '🙂 Average Ride';
      case 4:
        return '👍 Very Good!';
      case 5:
      default:
        return '🌟 Exceptional & Perfect!';
    }
  }

  Color _getRatingColor(int rating) {
    if (rating >= 4) return const Color(0xFFD97706);
    if (rating == 3) return Colors.amber.shade700;
    return Colors.red.shade600;
  }

  Future<void> _submitFeedback() async {
    setState(() => _isSubmitting = true);
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/submit_trip_review.php");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'booking_id': widget.bookingId,
          'rating': _selectedRating,
          'tags': _selectedTags.join(', '),
          'review_text': _commentController.text.trim(),
          'customer_number': widget.customerPhone ?? '',
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true || data['status'] == 'success') {
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Thank you! Your rating has been submitted.",
                    style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade600,
            content: Text(
              data['message'] ?? 'Could not submit review',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade600,
          content: Text(
            'Failed to connect to review service. Please try again.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final tags = _selectedRating >= 4 ? _positiveTags : _criticalTags;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.initialRating != null ? "Edit Your Review" : "Rate Your Journey",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Booking #${widget.bookingId}",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Driver & Vehicle Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFFFB300).withOpacity(0.2),
                    child: const Icon(Icons.person_pin_rounded, color: Color(0xFFD97706)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.driverName ?? "Assigned Driver",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          widget.carType ?? "Rentox Cab Service",
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "COMPLETED",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Star Rating Display
            Center(
              child: Text(
                "How was your overall experience?",
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                final isSelected = starNumber <= _selectedRating;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = starNumber;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedScale(
                      scale: isSelected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 38,
                        color: isSelected ? const Color(0xFFFFB300) : Colors.grey.shade300,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),

            // Rating Label Text
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _getRatingLabel(_selectedRating),
                  key: ValueKey<int>(_selectedRating),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _getRatingColor(_selectedRating),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Quick Tags Section
            Text(
              _selectedRating >= 4 ? "What made it great?" : "What could be improved?",
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(
                    tag,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF1A1A1A) : Colors.grey.shade700,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFFD54F),
                  backgroundColor: Colors.grey.shade50,
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFFFB300) : Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  showCheckmark: false,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Optional Feedback TextField
            Text(
              "Additional Comments (Optional)",
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 6),

            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 300,
              style: GoogleFonts.poppins(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: "Share more details about your trip...",
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),

            // Submit Button
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: const Color(0xFF1A1A1A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A1A1A)),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            widget.initialRating != null ? "Update Review" : "Submit Review",
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
