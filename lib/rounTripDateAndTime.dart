import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'roundTripCarSelection.dart';

class RoundTripDateAndTime extends StatefulWidget {
  final String from;
  final String to;
  final double distanceInKm;

  const RoundTripDateAndTime({
    Key? key,
    required this.from,
    required this.to,
    required this.distanceInKm,
  }) : super(key: key);

  @override
  _RoundTripDateAndTimeState createState() => _RoundTripDateAndTimeState();
}

class _RoundTripDateAndTimeState extends State<RoundTripDateAndTime> {
  // Theme Colors
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentYellow = Color(0xFFFFD54F);
  static const Color darkCharcoal = Color(0xFF1A1A1A);
  static const Color surfaceGrey = Color(0xFFF5F5F5);

  DateTime? departureDate;
  TimeOfDay? departureTime;
  DateTime? returnDate;
  TimeOfDay? returnTime;

  // Logic: Calculate Trip Duration in Days
  String get tripDuration {
    if (departureDate != null && returnDate != null) {
      final difference = returnDate!.difference(departureDate!).inDays;
      return "${difference == 0 ? 1 : difference + 1} Day Trip";
    }
    return "Select dates";
  }

  void pickDate(bool isDeparture) async {
    DateTime now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: isDeparture ? now : (departureDate ?? now),
      firstDate: isDeparture ? now : (departureDate ?? now),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: primaryAmber),
        ),
        child: child!,
      ),
    );

    if (date != null) {
      setState(() {
        if (isDeparture) {
          departureDate = date;
          returnDate = null;
          returnTime = null;
        } else {
          returnDate = date;
        }
      });
    }
  }

  void pickTime(bool isDeparture) async {
    if (isDeparture) {
      if (departureDate == null) {
        _showError("Please select departure date first.");
        return;
      }
    } else {
      if (departureDate == null || departureTime == null) {
        _showError("Select departure first.");
        return;
      }
      if (returnDate == null) {
        _showError("Please select return date first.");
        return;
      }
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: primaryAmber),
            timePickerTheme: TimePickerThemeData(
              dialHandColor: primaryAmber,
              dialBackgroundColor: const Color(0xFFFFF8E1),
              hourMinuteColor: primaryAmber,
              hourMinuteTextColor: Colors.white,
              dayPeriodColor: MaterialStateColor.resolveWith((states) =>
                  states.contains(MaterialState.selected)
                      ? const Color(0xFF00BCD4)
                      : Colors.white),
              dayPeriodTextColor: MaterialStateColor.resolveWith((states) =>
                  states.contains(MaterialState.selected)
                      ? Colors.white
                      : Colors.black87),
              dayPeriodBorderSide:
                  const BorderSide(color: Colors.black26, width: 1),
            ),
          ),
          child: child!,
        ),
      ),
    );

    if (time != null) {
      final now = DateTime.now();
      if (isDeparture) {
        final pickedDateTime = DateTime(
          departureDate!.year,
          departureDate!.month,
          departureDate!.day,
          time.hour,
          time.minute,
        );

        if (pickedDateTime.isBefore(now.add(const Duration(hours: 3)))) {
          _showError('Departure must be at least 3 hours from now.');
          return;
        }
        setState(() {
          departureTime = time;
          returnDate = null;
          returnTime = null;
        });
      } else {
        final returnDateTime = DateTime(
          returnDate!.year,
          returnDate!.month,
          returnDate!.day,
          time.hour,
          time.minute,
        );

        final departureDateTime = DateTime(
          departureDate!.year,
          departureDate!.month,
          departureDate!.day,
          departureTime!.hour,
          departureTime!.minute,
        );

        if (!returnDateTime.isAfter(departureDateTime)) {
          _showError("Return must be after departure.");
          return;
        }
        setState(() => returnTime = time);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  String formatDate(DateTime? date) =>
      date == null ? "Date" : DateFormat('dd MMM, yyyy').format(date);

  String formatTime(TimeOfDay? time) {
    if (time == null) return "Time";
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm a').format(dt);
  }

  void submit() {
    if (departureDate == null ||
        departureTime == null ||
        returnDate == null ||
        returnTime == null) {
      _showError("Please complete all date and time selections.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Roundtripcarselection(),
        settings: RouteSettings(
          arguments: {
            'from': widget.from,
            'to': widget.to,
            'departure_date': formatDate(departureDate),
            'departure_time': formatTime(departureTime),
            'return_date': formatDate(returnDate),
            'return_time': formatTime(returnTime),
            'distance': widget.distanceInKm,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: darkCharcoal, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Trip Schedule",
          style: GoogleFonts.poppins(
              color: darkCharcoal, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildJourneyCard(),
                  const SizedBox(height: 30),
                  _buildSectionHeader(
                      "DEPARTURE DETAILS", Icons.flight_takeoff),
                  _buildDateTimeRow(
                    onDateTap: () => pickDate(true),
                    onTimeTap: () => pickTime(true),
                    dateVal: formatDate(departureDate),
                    timeVal: formatTime(departureTime),
                    isSelected: departureDate != null,
                  ),
                  const SizedBox(height: 30),
                  _buildSectionHeader("RETURN DETAILS", Icons.flight_land),
                  _buildDateTimeRow(
                    onDateTap: () => pickDate(false),
                    onTimeTap: () => pickTime(false),
                    dateVal: formatDate(returnDate),
                    timeVal: formatTime(returnTime),
                    isSelected: returnDate != null,
                  ),
                  const SizedBox(height: 40),
                  if (returnDate != null) _buildDurationBadge(),
                ],
              ),
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildJourneyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkCharcoal,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: primaryAmber.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Icon(Icons.radio_button_checked, color: primaryAmber, size: 18),
              Container(height: 30, width: 1, color: Colors.white38),
              Icon(Icons.location_on, color: accentYellow, size: 18),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.from,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 25),
                Text(widget.to,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text("${widget.distanceInKm.toStringAsFixed(0)}",
                    style: GoogleFonts.poppins(
                        color: primaryAmber,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                Text("KM",
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 10)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildDateTimeRow({
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
    required String dateVal,
    required String timeVal,
    required bool isSelected,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildPickerBox(
            icon: Icons.calendar_month_rounded,
            label: dateVal,
            onTap: onDateTap,
            active: dateVal != "Date",
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _buildPickerBox(
            icon: Icons.access_time_filled_rounded,
            label: timeVal,
            onTap: onTimeTap,
            active: timeVal != "Time",
          ),
        ),
      ],
    );
  }

  Widget _buildPickerBox(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      required bool active}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : surfaceGrey,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: active ? primaryAmber : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? primaryAmber : Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    color: active ? darkCharcoal : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationBadge() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
            color: const Color.fromARGB(150, 255, 243, 134),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentYellow)),
        child: Text(tripDuration,
            style: GoogleFonts.poppins(
                color: darkCharcoal,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ),
    );
  }

  Widget _buildBottomAction() {
    bool isReady = departureDate != null &&
        returnDate != null &&
        departureTime != null &&
        returnTime != null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: isReady ? darkCharcoal : Colors.grey[300],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text(
            "Find Available Cars",
            style: GoogleFonts.poppins(
                color: isReady ? primaryAmber : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ),
      ),
    );
  }
}
