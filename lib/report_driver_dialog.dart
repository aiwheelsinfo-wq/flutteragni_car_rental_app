import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:agni_car_rental/config/api_config.dart';

class ReportDriverDialog extends StatefulWidget {
  final String bookingId;
  final String? driverName;
  final String? driverId;
  final String? customerPhone;

  const ReportDriverDialog({
    Key? key,
    required this.bookingId,
    this.driverName,
    this.driverId,
    this.customerPhone,
  }) : super(key: key);

  static Future<bool?> show(
    BuildContext context, {
    required String bookingId,
    String? driverName,
    String? driverId,
    String? customerPhone,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReportDriverDialog(
        bookingId: bookingId,
        driverName: driverName,
        driverId: driverId,
        customerPhone: customerPhone,
      ),
    );
  }

  @override
  State<ReportDriverDialog> createState() => _ReportDriverDialogState();
}

class _ReportDriverDialogState extends State<ReportDriverDialog> {
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  String _selectedCategory = 'Reckless Driving / Overspeeding';
  String _selectedSeverity = 'High';
  String? _validationError;

  final List<Map<String, String>> _categories = [
    {
      'id': 'Reckless Driving / Overspeeding',
      'label': 'Reckless Driving / Speeding',
      'icon': '🚗',
      'defaultSeverity': 'High',
    },
    {
      'id': 'Unprofessional or Abusive Behavior',
      'label': 'Rude / Abusive Behavior',
      'icon': '🗣️',
      'defaultSeverity': 'High',
    },
    {
      'id': 'Overcharging / Demanding Extra Cash',
      'label': 'Demanding Extra Cash',
      'icon': '💵',
      'defaultSeverity': 'Medium',
    },
    {
      'id': 'AC Refused / Poor Car Condition',
      'label': 'Refused AC / Dirty Cab',
      'icon': '❄️',
      'defaultSeverity': 'Low',
    },
    {
      'id': 'Route Deviation / Unauthorized Stops',
      'label': 'Route Detour / Unwanted Stops',
      'icon': '🗺️',
      'defaultSeverity': 'Medium',
    },
    {
      'id': 'Safety or Harassment Concern',
      'label': 'Safety Hazard / Harassment',
      'icon': '🚨',
      'defaultSeverity': 'Critical',
    },
    {
      'id': 'Other Disturbance',
      'label': 'Other Trip Dispute',
      'icon': '⚠️',
      'defaultSeverity': 'Medium',
    },
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final details = _detailsController.text.trim();
    if (details.isEmpty) {
      setState(() {
        _validationError = "Please explain what happened before submitting.";
      });
      return;
    } else {
      setState(() {
        _validationError = null;
      });
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/submit_incident_report.php");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "booking_id": widget.bookingId,
          "customer_phone": widget.customerPhone ?? '',
          "driver_id": widget.driverId ?? '',
          "driver_name": widget.driverName ?? '',
          "incident_type": _selectedCategory,
          "severity": _selectedSeverity,
          "description": details,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        if (!mounted) return;
        Navigator.pop(context, true);

        // Show ticket confirmation dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Colors.green, size: 28),
                const SizedBox(width: 8),
                Text(
                  "Report Filed",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(
                    "Ticket #${data['ticket_no'] ?? 'SUBMITTED'}",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Your safety complaint has been routed to Rentox Fleet Compliance. Our team will review the trip and take disciplinary action against the driver.",
                  style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  "OK",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: Colors.black87),
                ),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Failed to submit report."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Network error. Please check connection."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Report Driver or Trip",
                        style: GoogleFonts.poppins(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        "Trip #${widget.bookingId}${widget.driverName != null ? ' · Driver: ${widget.driverName}' : ''}",
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Emergency Helpline Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emergency_outlined, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Immediate safety danger? Dial 112 for Police assistance.",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Category Selection
            Text(
              "What went wrong?",
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat['icon'] ?? '', style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        cat['label'] ?? '',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF991B1B) : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFFEE2E2),
                  backgroundColor: const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFFEF4444) : Colors.grey.shade300,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = cat['id']!;
                        _selectedSeverity = cat['defaultSeverity'] ?? 'Medium';
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Severity selector
            Text(
              "Severity Level",
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Low', 'Medium', 'High', 'Critical'].map((level) {
                final isSelected = _selectedSeverity == level;
                Color activeColor;
                if (level == 'Critical') {
                  activeColor = const Color(0xFFDC2626);
                } else if (level == 'High') {
                  activeColor = const Color(0xFFF59E0B);
                } else if (level == 'Medium') {
                  activeColor = const Color(0xFF2563EB);
                } else {
                  activeColor = Colors.grey.shade700;
                }

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      onTap: () => setState(() => _selectedSeverity = level),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? activeColor.withOpacity(0.12) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? activeColor : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          level,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? activeColor : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Details input
            Text(
              "Explain What Happened",
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _detailsController,
              maxLines: 4,
              onChanged: (text) {
                if (_validationError != null && text.trim().isNotEmpty) {
                  setState(() {
                    _validationError = null;
                  });
                }
              },
              style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.black87),
              decoration: InputDecoration(
                hintText: "Please describe what happened in detail (e.g., driver drove dangerously fast, demanded ₹500 extra, refused to turn on AC)...",
                hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: Colors.grey.shade400),
                filled: true,
                fillColor: _validationError != null ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                errorText: _validationError,
                errorStyle: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFDC2626),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _validationError != null ? const Color(0xFFDC2626) : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _validationError != null ? const Color(0xFFDC2626) : Colors.grey.shade300,
                    width: _validationError != null ? 1.5 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: _validationError != null ? const Color(0xFFDC2626) : Colors.redAccent,
                    width: 1.5,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.report_problem_rounded, size: 18),
                label: Text(
                  _isSubmitting ? "Submitting Report..." : "Submit Incident Report",
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
