import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:agni_car_rental/config/api_config.dart';
import 'BookingCustomerMessagePage.dart';

class ShowBillPage extends StatefulWidget {
  final String carType;
  final int distance;
  final double baseCharge;
  final double driverTa;
  final double tollCharge;
  final double totalAmount;
  final String fromAddress;
  final String toAddress;
  final String date;
  final String tripTime;
  final double commission;
  final double partPay;
  final String bookingId;

  ShowBillPage({
    required this.carType,
    required this.distance,
    required this.baseCharge,
    required this.driverTa,
    required this.tollCharge,
    required this.totalAmount,
    required this.fromAddress,
    required this.toAddress,
    required this.date,
    required this.tripTime,
    required this.commission,
    required this.partPay,
    required this.bookingId,
  });

  @override
  _ShowBillPageState createState() => _ShowBillPageState();
}

class _ShowBillPageState extends State<ShowBillPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController customerMobController = TextEditingController();
  final TextEditingController gstController = TextEditingController();
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController businessAddressController =
      TextEditingController();
  final TextEditingController businessPincodeController =
      TextEditingController();

  String? savedNumber;
  bool _isWaiting = false;
  bool _showGSTField = false;
  String? userType;

  // Theme Colors
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color secondaryAmber = const Color(0xFFFFD54F);
  final Color darkText = const Color(0xFF1A1A1A);
  final Color softAmberBg = const Color(0xFFFFFBF0);

  @override
  void initState() {
    super.initState();
    startPage();
    setupMobileNumberListener(customerMobController);
  }

  void setupMobileNumberListener(TextEditingController controller) {
    controller.addListener(() {
      if (controller.text.length == 1 || controller.text.length == 9) {
        nameController.clear();
        emailController.clear();
        pincodeController.clear();
        cityController.clear();
      }
      if (controller.text.isEmpty && savedNumber != null) {
        _loadPhoneNumber(savedNumber!);
      }
      if (controller.text.length == 10) {
        _loadPhoneNumber(customerMobController.text);
      }
    });
  }

  Future<void> startPage() async {
    savedNumber = await secureStorage.read(key: 'phone_number');
    userType = await secureStorage.read(key: "userType");
    if (savedNumber != null) {
      _loadPhoneNumber(savedNumber!);
    }
  }

  Future<void> _loadPhoneNumber(String phone) async {
    var url = Uri.parse("${ApiConfig.baseUrl}/get_customer_data.php");
    var response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"phone_number": phone}),
    );

    var responseData = json.decode(response.body);

    if (responseData['status'] == 'success') {
      var user = responseData['user'];
      String cleanVal(dynamic val, {bool isPincode = false}) {
        if (val == null) return '';
        final s = val.toString().trim();
        if (s.toLowerCase() == 'not filled') return '';
        if (isPincode && s == '0') return '';
        return s;
      }
      setState(() {
        customerMobController.text = cleanVal(user['phone_number']);
        nameController.text = cleanVal(user['name']);
        emailController.text = cleanVal(user['email']);
        pincodeController.text = cleanVal(user['pincode'], isPincode: true);
        cityController.text = cleanVal(user['city']);
      });
    }
  }

  Future<void> _submitBooking() async {
    setState(() => _isWaiting = true);
    double vendorAmount = widget.totalAmount - widget.partPay;

    var url = Uri.parse("${ApiConfig.baseUrl}/saveBooking.php");
    try {
      var response = await http.post(url, body: {
        'trip_type': 'One-way',
        "car_type": widget.carType,
        "from_address": widget.fromAddress,
        "to_address": widget.toAddress,
        "distance": widget.distance.toString(),
        "date": widget.date,
        "tripTime": widget.tripTime,
        "name": nameController.text,
        "email": emailController.text,
        "userNumber": savedNumber,
        "pincode": pincodeController.text,
        "base_charge": widget.baseCharge.toString(),
        "driver_ta": widget.driverTa.toString(),
        "toll_charge": widget.tollCharge.toString(),
        "total_amount": widget.totalAmount.toString(),
        "payment_type": "Confirm",
        "agent_commission": widget.commission.toString(),
        "city": cityController.text,
        "agni_amount": widget.partPay.toString(),
        "vendor_amount": vendorAmount.toString(),
        "user_type": userType,
        "customer_mob": customerMobController.text,
        'gst': _showGSTField.toString(),
        'gst_number': gstController.text,
        'business_name': businessNameController.text,
        'business_address': businessAddressController.text,
        'business_pincode': businessPincodeController.text,
        'bookingId': widget.bookingId,
      });

      var responseData = json.decode(response.body);

      if (responseData["success"] == true) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => BookingCustomerMessagePage()));
      } else {
        throw Exception();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Booking Failed! Please try again."),
          backgroundColor: Colors.red));
    } finally {
      setState(() => _isWaiting = false);
    }
  }

  void _showBookingConfirmationDialog() {
    if (!_formKey.currentState!.validate()) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("Confirm Ride",
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Are you sure you want to book this ${widget.carType} trip?",
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text("Review Info"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _submitBooking();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryAmber,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Yes, Book Now",
                        style: TextStyle(color: Colors.black)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softAmberBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("CHECKOUT",
            style: GoogleFonts.poppins(
                color: darkText,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 16)),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: darkText, size: 20),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTripSummaryCard(),
              const SizedBox(height: 25),
              Text("Personal Details",
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              if (userType == 'agent') ...[
                _buildModernTextField(
                    controller: customerMobController,
                    label: "Customer Mobile",
                    icon: Icons.phone_android,
                    isNumber: true,
                    length: 10),
                const SizedBox(height: 12),
              ],
              _buildModernTextField(
                  controller: nameController,
                  label: "Full Name",
                  icon: Icons.person_outline),
              const SizedBox(height: 12),
              _buildModernTextField(
                  controller: emailController,
                  label: "Email Address",
                  icon: Icons.email_outlined,
                  isEmail: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildModernTextField(
                          controller: cityController,
                          label: "City",
                          icon: Icons.location_city)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildModernTextField(
                          controller: pincodeController,
                          label: "Pincode",
                          icon: Icons.pin_drop,
                          isNumber: true,
                          length: 6)),
                ],
              ),
              const SizedBox(height: 20),
              _buildGSTSection(),
              const SizedBox(height: 30),
              _isWaiting
                  ? const Center(child: CircularProgressIndicator())
                  : _buildConfirmButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: darkText,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.carType.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                Text("${widget.distance} KM",
                    style: TextStyle(
                        color: primaryAmber, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildRouteTimeline(widget.fromAddress, widget.toAddress),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider()),
                Row(
                  children: [
                    _infoBadge(Icons.calendar_today_outlined, widget.date),
                    const SizedBox(width: 10),
                    _infoBadge(Icons.access_time, widget.tripTime),
                  ],
                ),
                const SizedBox(height: 20),
                _buildFareRow("Base Fare",
                    widget.totalAmount - widget.tollCharge - widget.driverTa),
                _buildFareRow("Driver Allowance", widget.driverTa),
                _buildFareRow("Toll Charges (Included)", widget.tollCharge),
                const Divider(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total Amount",
                        style: GoogleFonts.poppins(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("₹${widget.totalAmount.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.green[700])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimeline(String from, String to) {
    return Row(
      children: [
        Column(
          children: [
            Icon(Icons.radio_button_checked, color: primaryAmber, size: 18),
            Container(width: 2, height: 30, color: Colors.grey[200]),
            const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(from,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 25),
              Text(to,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFareRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text("₹${amount.toStringAsFixed(0)}",
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _infoBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: softAmberBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primaryAmber.withOpacity(0.3))),
      child: Row(
        children: [
          Icon(icon, size: 14, color: primaryAmber),
          const SizedBox(width: 6),
          Text(text,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildModernTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      bool isNumber = false,
      int? length,
      bool isEmail = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLength: length,
        validator: (value) {
          if (value == null || value.isEmpty) return 'Enter $label';
          if (isEmail &&
              !RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(value))
            return 'Invalid Email';
          if (isNumber && length != null && value.length != length)
            return 'Must be $length digits';
          return null;
        },
        decoration: InputDecoration(
          counterText: "",
          prefixIcon: Icon(icon, color: primaryAmber, size: 20),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildGSTSection() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          CheckboxListTile(
            title: const Text("Include GST for Business",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text("Add details for tax invoice",
                style: TextStyle(fontSize: 12)),
            activeColor: primaryAmber,
            value: _showGSTField,
            onChanged: (v) => setState(() => _showGSTField = v!),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          if (_showGSTField)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildModernTextField(
                      controller: gstController,
                      label: "GST Number",
                      icon: Icons.receipt,
                      length: 15),
                  const SizedBox(height: 12),
                  _buildModernTextField(
                      controller: businessNameController,
                      label: "Business Name",
                      icon: Icons.business),
                  const SizedBox(height: 12),
                  _buildModernTextField(
                      controller: businessAddressController,
                      label: "Business Address",
                      icon: Icons.map),
                  const SizedBox(height: 12),
                  _buildModernTextField(
                      controller: businessPincodeController,
                      label: "Business Pincode",
                      icon: Icons.pin_drop,
                      isNumber: true,
                      length: 6),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _showBookingConfirmationDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAmber,
          foregroundColor: Colors.black,
          elevation: 5,
          shadowColor: primaryAmber.withOpacity(0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("CONFIRM BOOKING",
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1)),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }
}
