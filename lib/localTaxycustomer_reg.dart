import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

// Assuming this exists in your project
import 'package:agni_car_rental/config/api_config.dart';
import 'bookingStatusPage.dart';

class CustomerRegistrationPage extends StatefulWidget {
  final Map<String, dynamic>? bookingData;

  const CustomerRegistrationPage({Key? key, this.bookingData})
      : super(key: key);

  @override
  _CustomerRegistrationPageState createState() =>
      _CustomerRegistrationPageState();
}

class _CustomerRegistrationPageState extends State<CustomerRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  // Theme Colors
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color darkCharcoal = Color(0xFF1A1A1A);
  static const Color surfaceGrey = Color(0xFFF8F9FA);

  late TextEditingController booking_numberController = TextEditingController();
  late TextEditingController nameController = TextEditingController();
  late TextEditingController emailController = TextEditingController();
  late TextEditingController cityController = TextEditingController();
  late TextEditingController pincodeController = TextEditingController();

  bool isLoading = false;
  String? storedNumber;

  @override
  void initState() {
    super.initState();
    _getPhoneNumber();
  }

  Future<void> _getPhoneNumber() async {
    storedNumber = await secureStorage.read(key: "phone_number");
    if (storedNumber != null) {
      booking_numberController.text = storedNumber!;
      _checkBookingNumberMatch(storedNumber!);
    }
  }

  Future<void> _checkBookingNumberMatch(String id) async {
    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/get_customer_data.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'phone_number': id}),
      );

      dynamic result = jsonDecode(response.body);
      if (result['status'] == 'success' && result['user'] != null) {
        String cleanVal(dynamic val, {bool isPincode = false}) {
          if (val == null) return '';
          final s = val.toString().trim();
          if (s.toLowerCase() == 'not filled') return '';
          if (isPincode && s == '0') return '';
          return s;
        }
        setState(() {
          nameController.text = cleanVal(result['user']['name']);
          emailController.text = cleanVal(result['user']['email']);
          cityController.text = cleanVal(result['user']['city']);
          pincodeController.text = cleanVal(result['user']['pincode'], isPincode: true);
        });
      }
    } catch (e) {
      debugPrint("Auto-fill error: $e");
    }
  }

  Future<void> saveCustomerAndBooking() async {
    if (_formKey.currentState!.validate()) {
      bool isConfirmed = await _showConfirmationDialog();
      if (!isConfirmed) return;

      setState(() => isLoading = true);

      Map<String, dynamic> combinedData = {
        'booking_number': booking_numberController.text,
        'phone_number': storedNumber ?? booking_numberController.text,
        'name': nameController.text,
        'email': emailController.text,
        'city': cityController.text,
        'pincode': pincodeController.text,
        'from_address': widget.bookingData?['from_address'],
        'to_address': widget.bookingData?['to_address'],
        'car_type': widget.bookingData?['car_type'],
        'total_amount': widget.bookingData?['total_amount'],
        'distance': widget.bookingData?['distance'],
      };

      try {
        final response = await http.post(
          Uri.parse(
              "${ApiConfig.baseUrl}/save_Local_taxi_booking_and_customer.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(combinedData),
        );

        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          _showSuccessDialog();
        } else {
          _showError(result['message']);
        }
      } catch (e) {
        _showError("Network connection error");
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  Future<bool> _showConfirmationDialog() async {
    bool isChecked = false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text("Confirm Your Trip",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      "By confirming, you agree to our fair usage policy and driver guidelines.",
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    value: isChecked,
                    activeColor: primaryAmber,
                    onChanged: (v) => setDialogState(() => isChecked = v!),
                    title: Text("I agree to the T&C",
                        style: GoogleFonts.poppins(fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                  )
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("CANCEL",
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed:
                      isChecked ? () => Navigator.pop(context, true) : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: darkCharcoal,
                      foregroundColor: primaryAmber),
                  child: const Text("CONFIRM"),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check, size: 50, color: Colors.white)),
              const SizedBox(height: 20),
              Text("Booking Confirmed!",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 10),
              Text("Your taxi is on its way. You can track your status now.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.grey)),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => BookingStatusPage())),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: darkCharcoal,
                      foregroundColor: primaryAmber,
                      padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: const Text("VIEW STATUS"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 241, 236, 226),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 241, 236, 226),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: darkCharcoal),
            onPressed: () => Navigator.pop(context)),
        title: Text("Confirm Booking",
            style: GoogleFonts.poppins(
                color: darkCharcoal,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBookingDetailsTicket(),
              const SizedBox(height: 30),
              _buildSectionLabel("PERSONAL DETAILS"),
              _buildModernField(
                controller: booking_numberController,
                label: "Mobile Number",
                icon: Icons.phone_android,
                isNum: true,
                maxLength: 10,
                onChanged: (v) {
                  if (v.length == 10) _checkBookingNumberMatch(v);
                },
              ),
              _buildModernField(
                  controller: nameController,
                  label: "Full Name",
                  icon: Icons.person_outline),
              _buildModernField(
                  controller: emailController,
                  label: "Email Address",
                  icon: Icons.alternate_email,
                  isEmail: true),
              Row(
                children: [
                  Expanded(
                      child: _buildModernField(
                          controller: cityController,
                          label: "City",
                          icon: Icons.location_city)),
                  const SizedBox(width: 15),
                  Expanded(
                      child: _buildModernField(
                          controller: pincodeController,
                          label: "Pincode",
                          icon: Icons.pin_drop_outlined,
                          isNum: true,
                          maxLength: 6)),
                ],
              ),
              const SizedBox(height: 30),
              _buildSubmitButton(),
              const SizedBox(height: 20),
              _buildSafetyNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingDetailsTicket() {
    if (widget.bookingData == null) return const SizedBox.shrink();

    // Extract data safely
    String carType =
        widget.bookingData!['car_type']?.toString().toUpperCase() ?? 'N/A';
    String totalAmount = widget.bookingData!['total_amount']?.toString() ?? '0';
    String distance = widget.bookingData!['distance']?.toString() ?? '0';

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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(carType,
                      style: GoogleFonts.poppins(
                          color: primaryAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  // DISTANCE BADGE
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.straighten,
                            color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Text("$distance KM ",
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              Text("₹$totalAmount",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22)),
            ],
          ),
          const Divider(color: Colors.white24, height: 30),
          _buildTicketRow(
              Icons.circle, widget.bookingData!['from_address'], primaryAmber),
          const Padding(
              padding: EdgeInsets.only(left: 7),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child:
                      Icon(Icons.more_vert, color: Colors.white24, size: 15))),
          _buildTicketRow(Icons.location_on, widget.bookingData!['to_address'],
              Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildTicketRow(IconData icon, String text, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 15),
        Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 13))),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 1.2)),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNum = false,
    bool isEmail = false,
    int? maxLength,
    Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        maxLength: maxLength,
        keyboardType: isNum
            ? TextInputType.number
            : (isEmail ? TextInputType.emailAddress : TextInputType.text),
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primaryAmber, size: 20),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          filled: true,
          fillColor: surfaceGrey,
          counterText: "",
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: primaryAmber, width: 1.5)),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return "Required";
          if (isEmail && !v.contains("@")) return "Invalid Email";
          if (maxLength != null && v.length != maxLength)
            return "Invalid Length";
          return null;
        },
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : saveCustomerAndBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: darkCharcoal,
          foregroundColor: primaryAmber,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: primaryAmber)
            : Text("CONFIRM BOOKING",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildSafetyNote() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.1))),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(
                  "Your details are safe with us. Our drivers are verified for your security.",
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.green[700]))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    booking_numberController.dispose();
    nameController.dispose();
    emailController.dispose();
    cityController.dispose();
    pincodeController.dispose();
    super.dispose();
  }
}
