import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'CarSelectionPage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:agni_car_rental/config/api_config.dart';

class OneWayDateAndTime extends StatefulWidget {
  final String from;
  final String to;

  const OneWayDateAndTime({
    required this.from,
    required this.to,
  });

  @override
  _OneWayDateAndTimeState createState() => _OneWayDateAndTimeState();
}

class _OneWayDateAndTimeState extends State<OneWayDateAndTime> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  String? savedNumber;
  String? bookingId;
  String apiKey = "";

  // Theme Colors
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color accentYellow = const Color(0xFFFFD54F);
  final Color bgLight = const Color(0xFFFBFBFA);
  final Color charcoal = const Color(0xFF2D2D2D);

  @override
  void initState() {
    super.initState();
    fetchApiKey();
  }

  // --- LOGIC METHODS (Preserved) ---

  Future<void> fetchApiKey() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://agnicarrental.com/api_key/api.php?token=mySecretToken123'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          apiKey = data['apiKey'];
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> saveBookingData({
    required String from,
    required String to,
    required String date,
    required String time,
  }) async {
    savedNumber = await secureStorage.read(key: 'phone_number');
    if (savedNumber == null) return;

    final uri = Uri.parse('${ApiConfig.baseUrl}/saveOneWayTemp.php');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'from': from,
        'to': to,
        'date': date,
        'time': time,
        'savedNumber': savedNumber!,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['booking_id'] != null) {
        setState(() {
          bookingId = data['booking_id'].toString();
        });
      }
    }
  }

  Future<Map<String, double>?> getCoordinates(String address) async {
    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        final location = data['results'][0]['geometry']['location'];
        return {"lat": location['lat'], "lng": location['lng']};
      }
    }
    return null;
  }

  void pickDate() async {
    DateTime now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
              primary: primaryAmber,
              onPrimary: Colors.white,
              onSurface: charcoal),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => selectedDate = date);
  }

  void pickTime() async {
    if (selectedDate == null) {
      _showError("Please select a date first");
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryAmber,
              onSurface: charcoal,
            ),
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
      final pickedDateTime = DateTime(selectedDate!.year, selectedDate!.month,
          selectedDate!.day, time.hour, time.minute);
      if (pickedDateTime.difference(DateTime.now()).inHours < 5) {
        _showError("Pickup must be at least 5 hours from now");
        return;
      }
      setState(() => selectedTime = time);
    }
  }

  void submit() async {
    if (selectedDate == null || selectedTime == null) {
      _showError("Please select both date and time");
      return;
    }

    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);
    final now = DateTime.now();
    final selectedDT = DateTime(selectedDate!.year, selectedDate!.month,
        selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
    String formattedTime = DateFormat('hh:mm a').format(selectedDT);

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.amber)));

    await saveBookingData(
        from: widget.from,
        to: widget.to,
        date: formattedDate,
        time: formattedTime);
    final fromCoords = await getCoordinates(widget.from);
    final toCoords = await getCoordinates(widget.to);

    Navigator.pop(context); // Close loading

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarSelectionPage(),
        settings: RouteSettings(
          arguments: {
            'from': widget.from,
            'to': widget.to,
            'date': formattedDate,
            'time': formattedTime,
            'booking_id': bookingId,
            'fromLat': fromCoords?['lat'],
            'fromLng': fromCoords?['lng'],
            'toLat': toCoords?['lat'],
            'toLng': toCoords?['lng'],
          },
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating));
  }

  // --- UI COMPONENTS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("Trip Schedule",
            style: GoogleFonts.poppins(
                color: charcoal, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: charcoal, size: 20),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTripSummaryCard(),
                  const SizedBox(height: 30),
                  Text("When do you need the car?",
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: charcoal)),
                  const SizedBox(height: 15),
                  _buildPickerTile(
                    title: "Travel Date",
                    value: selectedDate == null
                        ? "Choose Date"
                        : DateFormat('EEE, MMM d, yyyy').format(selectedDate!),
                    icon: Icons.calendar_month_rounded,
                    onTap: pickDate,
                    isSelected: selectedDate != null,
                  ),
                  const SizedBox(height: 15),
                  _buildPickerTile(
                    title: "Pickup Time",
                    value: selectedTime == null
                        ? "Choose Time"
                        : selectedTime!.format(context),
                    icon: Icons.access_time_filled_rounded,
                    onTap: pickTime,
                    isSelected: selectedTime != null,
                  ),
                  const SizedBox(height: 40),
                  _buildInfoBox(),
                ],
              ),
            ),
          ),
          _buildFooterButton(),
        ],
      ),
    );
  }

  Widget _buildTripSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Icon(Icons.radio_button_checked, color: primaryAmber, size: 20),
              Container(width: 2, height: 30, color: Colors.grey.shade300),
              const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.from,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 25),
                Text(widget.to,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerTile(
      {required String title,
      required String value,
      required IconData icon,
      required VoidCallback onTap,
      required bool isSelected}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? primaryAmber : Colors.grey.shade200,
              width: 2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: isSelected ? primaryAmber.withOpacity(0.1) : bgLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon,
                  color: isSelected ? primaryAmber : Colors.grey.shade400),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500)),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? charcoal : Colors.grey.shade400)),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: primaryAmber.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryAmber.withOpacity(0.1))),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: primaryAmber, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Note: For immediate bookings, pickup must be at least 5 hours from current time.",
              style: GoogleFonts.poppins(
                  fontSize: 12, color: charcoal.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryAmber,
            foregroundColor: charcoal,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text("Select Car",
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
