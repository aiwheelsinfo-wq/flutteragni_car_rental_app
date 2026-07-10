import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:agni_car_rental/config/api_config.dart';
import 'BookingCustomerMessagePage.dart';
import 'RazorpayPaymentPage.dart';

class RoundTripShowBill extends StatefulWidget {
  final String from;
  final String to;
  final String departureDate;
  final String departureTime;
  final String returnDate;
  final String returnTime;
  final String selectedCar;
  final double kmPerDay;
  final double kmRate;
  final double driverAllowance;
  final double gstPercent;

  const RoundTripShowBill({
    Key? key,
    required this.from,
    required this.to,
    required this.departureDate,
    required this.departureTime,
    required this.returnDate,
    required this.returnTime,
    required this.selectedCar,
    required this.kmPerDay,
    required this.kmRate,
    required this.driverAllowance,
    required this.gstPercent,
  }) : super(key: key);

  @override
  _RoundTripShowBillState createState() => _RoundTripShowBillState();
}

class _RoundTripShowBillState extends State<RoundTripShowBill> {
  // Theme Colors
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentYellow = Color(0xFFFFD54F);
  static const Color darkCharcoal = Color(0xFF1A1A1A);
  static const Color surfaceGrey = Color(0xFFF5F5F5);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController commissionController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController customerMobController = TextEditingController();
  final FlutterSecureStorage secureStorage = FlutterSecureStorage();
  final TextEditingController gstController = TextEditingController();
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController businessAddressController =
      TextEditingController();
  final TextEditingController businessPincodeController =
      TextEditingController();

  String? userType;
  String? savedNumber;
  bool _showGSTField = false;
  bool _isLoading = false;
  double _commissionRatePerKm = 0.0;

  double _calculateAgentCommission() {
    int days = _calculateDays();
    return _commissionRatePerKm * 300 * days;
  }

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
        _loadUserData(savedNumber!);
      }
      if (controller.text.length == 10) {
        _loadUserData(customerMobController.text);
      }
    });
  }

  Future<void> startPage() async {
    savedNumber = await secureStorage.read(key: 'phone_number');
    String? type = await secureStorage.read(key: "userType");
    setState(() {
      userType = type;
    });
    if (savedNumber != null) _loadUserData(savedNumber!);
  }

  Future<void> _loadUserData(String number) async {
    try {
      var url = Uri.parse(
          "${ApiConfig.baseUrl}/roundTrip_user_data_fetching.php");
      var response = await http.post(url, body: {'userNumber': number});
      var data = json.decode(response.body);

      if (data['success'] == true && data['data'] != null) {
        String cleanVal(dynamic val, {bool isPincode = false}) {
          if (val == null) return '';
          final s = val.toString().trim();
          if (s.toLowerCase() == 'not filled') return '';
          if (isPincode && s == '0') return '';
          return s;
        }
        setState(() {
          if (customerMobController.text != data['data']['phone_number']) {
            customerMobController.text = cleanVal(data['data']['phone_number']);
          }
          nameController.text = cleanVal(data['data']['name']);
          emailController.text = cleanVal(data['data']['email']);
          cityController.text = cleanVal(data['data']['city']);
          pincodeController.text = cleanVal(data['data']['pincode'], isPincode: true);
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  String _formatDateForApi(String dateStr, String timeStr) {
    try {
      // Input: "EEE, MMM d, yyyy" + "hh:mm a"
      DateTime parsed =
          DateFormat('EEE, MMM d, yyyy h:mm a').parse('$dateStr $timeStr');
      return DateFormat('dd MMM yyyy').format(parsed);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _submitBooking(double amount) async {
    setState(() => _isLoading = true);

    // Convert 12h to 24h for API
    String formatTo24(String time) =>
        DateFormat("HH:mm").format(DateFormat("hh:mm a").parse(time));

    double dailyLimit = widget.kmPerDay;
    int days = _calculateDays();
    double baseAdvance = dailyLimit * 2 * days;
    double calculatedCommission = _calculateAgentCommission();
    double totalAdvance = baseAdvance + calculatedCommission;

    try {
      var url = Uri.parse("${ApiConfig.baseUrl}/saveBooking.php");
      var response = await http.post(url, body: {
        'trip_type': 'Round-Trip',
        "car_type": widget.selectedCar,
        "from_address": widget.from,
        "to_address": widget.to,
        "date": _formatDateForApi(widget.departureDate, widget.departureTime),
        "tripTime": formatTo24(widget.departureTime),
        "return_date": _formatDateForApi(widget.returnDate, widget.returnTime),
        "return_time": formatTo24(widget.returnTime),
        "name": nameController.text,
        "email": emailController.text,
        "userNumber": savedNumber ?? customerMobController.text,
        "city": cityController.text,
        "pincode": pincodeController.text,
        "agent_commission": calculatedCommission.toStringAsFixed(2),
        "payment_type": "Advance",
        'gst': _showGSTField.toString(),
        'gst_number': gstController.text,
        'business_name': businessNameController.text,
        'business_address': businessAddressController.text,
        'business_pincode': businessPincodeController.text,
        'total_amount': totalAdvance.toStringAsFixed(2),
        'agni_amount': (baseAdvance * 0.10).toStringAsFixed(2),
        'vendor_amount': (baseAdvance * 0.90).toStringAsFixed(2),
      });

      var res = json.decode(response.body);
      if (res["success"] == true) {
        String createdBookingId = res["booking_id"]?.toString() ?? '';
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => RazorpayPaymentPage(
                      bookingId: createdBookingId,
                      amount: baseAdvance,
                      isFullPay: false,
                    )));
      } else {
        _showSnackBar(
            "Booking Failed: ${res['error'] ?? 'Unknown error'}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Connection error. Please try again.", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  int _calculateDays() {
    try {
      DateTime dep = DateFormat('dd MMM, yyyy').parse(widget.departureDate);
      DateTime ret = DateFormat('dd MMM, yyyy').parse(widget.returnDate);
      int days = ret.difference(dep).inDays + 1;
      return days <= 0 ? 1 : days;
    } catch (_) {
      try {
        DateTime dep = DateFormat('EEE, MMM d, yyyy').parse(widget.departureDate);
        DateTime ret = DateFormat('EEE, MMM d, yyyy').parse(widget.returnDate);
        int days = ret.difference(dep).inDays + 1;
        return days <= 0 ? 1 : days;
      } catch (e) {
        return 1;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 241, 239, 235),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: darkCharcoal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: primaryAmber, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Booking Summary",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildJourneyCard(),
                    _buildAdvancePaymentBreakdownCard(),
                    const SizedBox(height: 25),
                    _buildSectionLabel("TRAVELER INFORMATION"),
                    if (userType == 'agent') ...[
                      _buildTextField(customerMobController, "Customer Mobile",
                          Icons.phone_android,
                          maxLength: 10, isNum: true),
                    ],
                    _buildTextField(
                        nameController, "Full Name", Icons.person_outline),
                    _buildTextField(
                        emailController, "Email Address", Icons.alternate_email,
                        isEmail: true),
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField(
                                cityController, "City", Icons.location_city)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildTextField(pincodeController, "Pincode",
                                Icons.pin_drop_outlined,
                                maxLength: 6, isNum: true)),
                      ],
                    ),
                    if (userType == "agent")
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: DropdownButtonFormField<double>(
                          value: _commissionRatePerKm,
                          dropdownColor: Colors.white,
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                          decoration: InputDecoration(
                            labelText: "Agent Commission (₹/KM)",
                            labelStyle: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
                            prefixIcon: const Icon(Icons.payments_outlined, color: primaryAmber, size: 20),
                            filled: true,
                            fillColor: surfaceGrey,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: primaryAmber, width: 1.5)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0.0, child: Text("₹0 / KM (No Commission)")),
                            DropdownMenuItem(value: 1.0, child: Text("₹1 / KM")),
                            DropdownMenuItem(value: 2.0, child: Text("₹2 / KM")),
                            DropdownMenuItem(value: 3.0, child: Text("₹3 / KM")),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _commissionRatePerKm = val ?? 0.0;
                              double calculated = _calculateAgentCommission();
                              commissionController.text = calculated.toStringAsFixed(0);
                            });
                          },
                        ),
                      ),

                    const SizedBox(height: 10),
                    _buildGSTToggle(),
                    if (_showGSTField) ...[
                      const SizedBox(height: 15),
                      _buildSectionLabel("BUSINESS DETAILS (GST)"),
                      _buildTextField(
                          gstController, "GST Number", Icons.receipt_long,
                          maxLength: 15),
                      _buildTextField(businessNameController, "Business Name",
                          Icons.business),
                      _buildTextField(businessAddressController,
                          "Business Address", Icons.map_outlined),
                      _buildTextField(businessPincodeController,
                          "Business Pincode", Icons.pin_drop,
                          maxLength: 6, isNum: true),
                    ],
                    const SizedBox(height: 100), // Space for bottom button
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomAction(),
    );
  }

  Widget _buildJourneyCard() {
    int days = _calculateDays();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkCharcoal,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: primaryAmber.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.selectedCar.toUpperCase(),
                  style: GoogleFonts.poppins(
                      color: primaryAmber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: primaryAmber,
                    borderRadius: BorderRadius.circular(8)),
                child: Text("$days DAYS TRIP",
                    style: GoogleFonts.poppins(
                        color: darkCharcoal,
                        fontWeight: FontWeight.bold,
                        fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Column(
                children: [
                  Icon(Icons.radio_button_checked,
                      color: primaryAmber, size: 16),
                  Container(height: 40, width: 1, color: Colors.white38),
                  Icon(Icons.location_on, color: Colors.redAccent, size: 16),
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
                    Text("${widget.departureDate} @ ${widget.departureTime}",
                        style: GoogleFonts.poppins(
                            color: Colors.white60, fontSize: 11)),
                    const SizedBox(height: 25),
                    Text(widget.to,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text("${widget.returnDate} @ ${widget.returnTime}",
                        style: GoogleFonts.poppins(
                            color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, top: 10),
      child: Text(text,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
              letterSpacing: 1.1)),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {int? maxLength, bool isNum = false, bool isEmail = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        keyboardType: isNum
            ? TextInputType.number
            : (isEmail ? TextInputType.emailAddress : TextInputType.text),
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13),
          prefixIcon: Icon(icon, color: primaryAmber, size: 20),
          filled: true,
          fillColor: surfaceGrey,
          counterText: "",
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: primaryAmber, width: 1.5)),
          floatingLabelStyle: const TextStyle(color: primaryAmber),
        ),
        validator: (value) {
          if ((value == null || value.isEmpty) &&
              label != "Your Commission (₹)") return "$label is required";
          if (isEmail &&
              !RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
                  .hasMatch(value!)) return "Invalid email";
          if (maxLength != null && value!.length != maxLength)
            return "Must be $maxLength characters";
          return null;
        },
      ),
    );
  }

  Widget _buildGSTToggle() {
    return InkWell(
      onTap: () => setState(() => _showGSTField = !_showGSTField),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _showGSTField,
                onChanged: (v) => setState(() => _showGSTField = v!),
                activeColor: primaryAmber,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 10),
            Text("I have a GST number for this booking",
                style: GoogleFonts.poppins(fontSize: 13, color: darkCharcoal)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    double dailyLimit = widget.kmPerDay;
    int days = _calculateDays();
    double baseAdvance = dailyLimit * 2 * days;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 230, 224, 213),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (_formKey.currentState!.validate()) {
                    _submitBooking(0); // Pass necessary amount if required
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: darkCharcoal,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: primaryAmber, strokeWidth: 2))
              : Text("CONFIRM & PAY ADVANCE: ₹${baseAdvance.toStringAsFixed(0)}",
                  style: GoogleFonts.poppins(
                      color: primaryAmber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildAdvancePaymentBreakdownCard() {
    double dailyLimit = widget.kmPerDay;
    int days = _calculateDays();
    double baseAdvance = dailyLimit * 2 * days;
    double calculatedCommission = _calculateAgentCommission();

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ADVANCE PAYMENT BREAKDOWN",
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: Colors.amber[900],
            ),
          ),
          const SizedBox(height: 15),
          _buildBreakdownRow("Trip Type", "Round Trip"),
          const Divider(height: 16),
          _buildBreakdownRow("Number of Days", "$days Days"),
          const Divider(height: 16),
          _buildBreakdownRow("Daily KM Limit", "${widget.kmPerDay.toStringAsFixed(0)} KM/day",
              subtitle: "(₹${widget.kmRate.toStringAsFixed(0)}/KM rate applies to actual KM)"),
          const Divider(height: 16),
          _buildBreakdownRow("Base Advance Fare", "₹${baseAdvance.toStringAsFixed(0)}"),
          if (userType == "agent") ...[
            const Divider(height: 16),
            _buildBreakdownRow(
              "Agent Commission",
              "₹${calculatedCommission.toStringAsFixed(0)}",
              subtitle: "(₹${_commissionRatePerKm.toStringAsFixed(0)}/KM x 300 KM/day x $days days)",
            ),
          ],
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Total Advance Payable Now",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "₹${baseAdvance.toStringAsFixed(0)}",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "*Remaining balance will be calculated after trip completion by the driver based on actual running KM.",
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {String? subtitle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
