import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_place/google_place.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart'; // Added for location detection
import 'package:agni_car_rental/config/api_config.dart';
import 'BookingCustomerMessagePage.dart';
import 'RazorpayPaymentPage.dart';

// --- MODELS ---
class Car {
  final String name;
  final double base;
  final double extraKMAmount;
  final double extraHoursAmount;
  final double packageKm;
  final double packageHours;
  final double driverRate;
  final double agni_share;
  final double discountedPrice;
  final double discountPercentage;

  Car({
    required this.name,
    required this.base,
    required this.extraKMAmount,
    required this.extraHoursAmount,
    required this.packageKm,
    required this.packageHours,
    required this.driverRate,
    required this.agni_share,
    required this.discountedPrice,
    required this.discountPercentage,
  });

  factory Car.fromJson(Map<String, dynamic> json) {
    return Car(
      name: json['carType']?.toString() ?? '',
      base: double.tryParse(json['baseAmount']?.toString() ?? '0') ?? 0,
      extraKMAmount:
          double.tryParse(json['extraKMAmount']?.toString() ?? '0') ?? 0,
      extraHoursAmount:
          double.tryParse(json['extraHoursAmount']?.toString() ?? '0') ?? 0,
      packageKm: double.tryParse(json['packageKm']?.toString() ?? '0') ?? 0,
      packageHours:
          double.tryParse(json['packageHours']?.toString() ?? '0') ?? 0,
      driverRate: double.tryParse(json['driverRate']?.toString() ?? '0') ?? 0,
      agni_share: double.tryParse(json['agni_share']?.toString() ?? '0') ?? 0,
      discountedPrice:
          double.tryParse(json['discounted_price']?.toString() ?? '0') ?? 0,
      discountPercentage:
          double.tryParse(json['discount_percentage']?.toString() ?? '0') ?? 0,
    );
  }
}

class LocalDutyBookingForm extends StatefulWidget {
  final String fromLocation;
  const LocalDutyBookingForm({required this.fromLocation});

  @override
  _LocalDutyBookingFormState createState() => _LocalDutyBookingFormState();
}

class _LocalDutyBookingFormState extends State<LocalDutyBookingForm> {
  // Controllers
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController timeController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController pincodeController = TextEditingController();
  final TextEditingController commissionController = TextEditingController();
  final TextEditingController customerNumberController =
      TextEditingController();
  final TextEditingController gstNumberController = TextEditingController();
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController businessAddressController =
      TextEditingController();
  final TextEditingController businessPincodeController =
      TextEditingController();

  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  List<Car> cars = [];
  Car? selectedCar;
  bool isLoading = true;
  bool showGSTField = false;
  bool isSubmitting = false;

  String? userType;
  String? savedNumber;
  String apiKey = "";
  List<AutocompletePrediction> predictions = [];
  late GooglePlace _googlePlace;

  String? selectedPlaceId;
  String? fromLat;
  String? fromLng;

  // Theme Colors
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color lightAmber = const Color(0xFFFFF8E1);
  final Color darkText = const Color(0xFF2D2D2D);

  @override
  void initState() {
    super.initState();
    fetchApiKey();
    fetchCars();
    commissionController.addListener(() {
      if (mounted) setState(() {});
    });
    // Initialize with passed location, otherwise it will be updated by getCurrentLocation
    if (widget.fromLocation.isNotEmpty) {
      locationController.text = widget.fromLocation;
    }
  }

  // --- LOGIC METHODS ---

  Future<void> fetchApiKey() async {
    try {
      final response = await http.get(Uri.parse(
          'https://agnicarrental.com/api_key/api.php?token=mySecretToken123'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => apiKey = data['apiKey'] ?? '');

        // If no location was passed from previous screen, get current location
        if (widget.fromLocation.isEmpty) {
          _getCurrentLocation();
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // Detects the user's current location and converts to address name
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Call Google Geocoding API to get address string
      final String url =
          "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey";

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          setState(() {
            locationController.text = data['results'][0]['formatted_address'];
            fromLat = position.latitude.toString();
            fromLng = position.longitude.toString();
          });
        }
      }
    } catch (e) {
      debugPrint("Auto Location Error: $e");
    }
  }

  Future<void> fetchCars() async {
    userType = await secureStorage.read(key: 'userType');
    savedNumber = await secureStorage.read(key: 'phone_number');
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/selectCarCostList.php?tripType=Local-Duty'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          cars = data.map((item) => Car.fromJson(item)).toList();
          if (cars.isNotEmpty) selectedCar = cars.first;
          isLoading = false;
        });
        if (savedNumber != null) fetchCustomerData(savedNumber!);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  // [Rest of the helper logic methods remain identical to your original code]
  Future<void> fetchCustomerData(String phoneNumber) async {
    if (phoneNumber.length != 10) return;
    final url = Uri.parse(
        '${ApiConfig.baseUrl}/get_customer_data.php?phone_number=$phoneNumber');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success') {
          final user = jsonData['user'];
          setState(() {
            customerNumberController.text = user['phone_number'] ?? '';
            nameController.text = user['name'] ?? '';
            emailController.text = user['email'] ?? '';
            cityController.text = user['city'] ?? '';
            pincodeController.text = user['pincode'].toString();
          });
        }
      }
    } catch (_) {}
  }

  void _getLocationSuggestions(String input) async {
    selectedPlaceId = null;
    if (apiKey.isEmpty || input.trim().isEmpty) {
      setState(() => predictions = []);
      return;
    }
    _googlePlace = GooglePlace(apiKey);
    final result = await _googlePlace.autocomplete.get(input);
    if (result != null && result.predictions != null) {
      setState(() => predictions = result.predictions!);
    }
  }

  void _submitForm() async {
    if (locationController.text.trim().isEmpty ||
        dateController.text.trim().isEmpty ||
        timeController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty) {
      _showSnack("Please fill all required fields");
      return;
    }

    setState(() => isSubmitting = true);

    try {
      String? lat = fromLat;
      String? lng = fromLng;

      // If coordinates aren't already stored (from auto-location), geocode manually
      if (lat == null || lng == null) {
        if (selectedPlaceId != null && apiKey.isNotEmpty) {
          _googlePlace = GooglePlace(apiKey);
          final details = await _googlePlace.details.get(selectedPlaceId!);
          lat = details?.result?.geometry?.location?.lat?.toString();
          lng = details?.result?.geometry?.location?.lng?.toString();
        } else {
          final geocodeUrl = Uri.parse(
              'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(locationController.text)}&key=$apiKey');
          final geoResp = await http.get(geocodeUrl);
          if (geoResp.statusCode == 200) {
            final geoJson = json.decode(geoResp.body);
            if (geoJson['status'] == 'OK') {
              lat = geoJson['results'][0]['geometry']['location']['lat']
                  .toString();
              lng = geoJson['results'][0]['geometry']['location']['lng']
                  .toString();
            }
          }
        }
      }

      if (lat == null || lng == null) {
        _showSnack("Unable to get coordinates");
        setState(() => isSubmitting = false);
        return;
      }

      String formattedTime = "";
      if (selectedTime != null) {
        formattedTime =
            "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}";
      }

      double basePrice = selectedCar?.base ?? 0.0;
      double agentCommission = double.tryParse(commissionController.text) ?? 0.0;
      double totalAmt = basePrice + agentCommission;

      final data = {
        'trip_type': 'Local-Duty',
        'from_address': locationController.text,
        'fromLat': lat,
        'fromLng': lng,
        'date': selectedDate?.toIso8601String() ?? '',
        'tripTime': formattedTime,
        'car_type': selectedCar?.name ?? '',
        'name': nameController.text,
        'email': emailController.text,
        'city': cityController.text,
        'pincode': pincodeController.text,
        'userNumber': savedNumber,
        'agent_commission': commissionController.text,
        'customer_mob': customerNumberController.text,
        'user_type': userType,
        'total_amount': totalAmt.toString(),
        'vendor_amount': (selectedCar?.driverRate ?? 0).toString(),
        'agni_amount': (selectedCar?.agni_share ?? 0).toString(),
        'payment_type': 'Advance',
        'gst': showGSTField.toString(),
        'gst_number': gstNumberController.text,
        'business_name': businessNameController.text,
        'business_address': businessAddressController.text,
        'business_pincode': businessPincodeController.text,
      };

      final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/saveBooking.php'),
          body: data);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData["success"] == true) {
          String createdBookingId = responseData["booking_id"]?.toString() ?? '';
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => RazorpayPaymentPage(
                        bookingId: createdBookingId,
                        amount: 250.0,
                        isFullPay: false,
                      )));
        } else {
          _showSnack("Booking failed. Try again.");
        }
      } else {
        _showSnack("Booking failed. Try again.");
      }
    } catch (e) {
      _showSnack("An error occurred");
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  // --- UI COMPONENTS (UI logic unchanged as requested) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 244, 241),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: darkText, size: 20),
            onPressed: () => Navigator.pop(context)),
        title: Text("Local Duty Booking",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 18, color: darkText)),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryAmber))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("1. Route Details"),
                  _buildLocationSearch(),
                  const SizedBox(height: 25),
                  _buildSectionHeader("2. Schedule Pickup"),
                  _buildDateTimePicker(),
                  const SizedBox(height: 25),
                  if (userType == 'agent') ...[
                    _buildSectionHeader("3. Commission Details"),
                    _buildModernField(
                        controller: commissionController,
                        label: "Agent Commission",
                        icon: Icons.money,
                        isNumber: true),
                    const SizedBox(height: 25),
                  ],
                  _buildSectionHeader("3. Fleet Selection"),
                  _buildCarDropdown(),
                  if (selectedCar != null) _buildFareBreakdown(),
                  const SizedBox(height: 25),
                  _buildSectionHeader("4. Customer Information"),
                  _buildContactForm(),
                  const SizedBox(height: 25),
                  _buildGSTSection(),
                  const SizedBox(height: 40),
                  _buildConfirmButton(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.bold, color: darkText)),
    );
  }

  Widget _buildLocationSearch() {
    return Container(
      decoration: _cardBoxDecoration(),
      child: Column(
        children: [
          TextField(
            controller: locationController,
            onChanged: _getLocationSuggestions,
            decoration: _inputDecoration("Pickup Address", Icons.my_location),
          ),
          if (predictions.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: predictions.length,
              itemBuilder: (context, index) => ListTile(
                leading: const Icon(Icons.place, color: Colors.grey),
                title: Text(predictions[index].description ?? '',
                    style: const TextStyle(fontSize: 13)),
                onTap: () {
                  locationController.text =
                      predictions[index].description ?? '';
                  selectedPlaceId = predictions[index].placeId;
                  FocusScope.of(context).unfocus();
                  setState(() => predictions = []);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Container(
      decoration: _cardBoxDecoration(),
      child: Column(
        children: [
          _buildModernField(
            controller: dateController,
            label: "Travel Date",
            icon: Icons.calendar_today_rounded,
            readOnly: true,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2101),
                builder: (context, child) => Theme(
                    data: ThemeData.light().copyWith(
                        colorScheme: ColorScheme.light(primary: primaryAmber)),
                    child: child!),
              );
              if (picked != null) {
                setState(() {
                  selectedDate = picked;
                  dateController.text = DateFormat('dd-MM-yyyy').format(picked);
                });
              }
            },
          ),
          const Divider(height: 1),
          _buildModernField(
            controller: timeController,
            label: "Pickup Time",
            icon: Icons.access_time_filled_rounded,
            readOnly: true,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
                initialEntryMode: TimePickerEntryMode.dial,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: false),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFFFFB300),
                      ),
                      timePickerTheme: TimePickerThemeData(
                        dialHandColor: const Color(0xFFFFB300),
                        dialBackgroundColor: const Color(0xFFFFF8E1),
                        hourMinuteColor: const Color(0xFFFFB300),
                        hourMinuteTextColor: Colors.white,
                        dayPeriodColor: MaterialStateColor.resolveWith(
                            (states) =>
                                states.contains(MaterialState.selected)
                                    ? const Color(0xFF00BCD4)
                                    : Colors.white),
                        dayPeriodTextColor: MaterialStateColor.resolveWith(
                            (states) =>
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
              if (picked != null) {
                final now = DateTime.now();
                DateTime selectedDT = selectedDate != null
                    ? DateTime(selectedDate!.year, selectedDate!.month,
                        selectedDate!.day, picked.hour, picked.minute)
                    : DateTime(now.year, now.month, now.day, picked.hour,
                        picked.minute);

                if (selectedDT.difference(now).inMinutes < 120) {
                  _showSnack("Pickup must be at least 2 hours from now");
                  return;
                }
                setState(() {
                  selectedTime = picked;
                  timeController.text =
                      DateFormat('hh:mm a').format(selectedDT);
                });
              }
            },
          ),
          _buildSmartTip(
              "Advance bookings must be made at least 2 hours prior."),
        ],
      ),
    );
  }

  Widget _buildCarDropdown() {
    return Container(
      decoration: _cardBoxDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonFormField<Car>(
        value: selectedCar,
        decoration: const InputDecoration(border: InputBorder.none),
        items: cars
            .map((car) => DropdownMenuItem<Car>(
                  value: car,
                  child: Text(car.name.toUpperCase(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ))
            .toList(),
        onChanged: (val) => setState(() => selectedCar = val),
      ),
    );
  }

  Widget _buildFareBreakdown() {
    final double originalPrice = selectedCar!.discountedPrice;
    final double agentCommission = double.tryParse(commissionController.text) ?? 0.0;
    final double finalPrice = selectedCar!.base + agentCommission;
    final double savings = originalPrice - selectedCar!.base;
    final bool hasDiscount = savings > 0;

    return Container(
      margin: const EdgeInsets.only(top: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryAmber.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: lightAmber.withOpacity(0.4),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Package Fare",
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("₹${finalPrice.toStringAsFixed(0)}",
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: darkText)),
                        if (hasDiscount) ...[
                          const SizedBox(width: 8),
                          Text("₹${originalPrice.toStringAsFixed(0)}",
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough)),
                        ]
                      ],
                    ),
                  ],
                ),
                if (hasDiscount)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text("SAVED ₹${savings.toStringAsFixed(0)}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10)),
                        Text(
                            "${selectedCar!.discountPercentage.toStringAsFixed(0)}% OFF",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _fareRowDetail(Icons.inventory_2_outlined, "Included Package",
                    "${selectedCar!.packageHours.toStringAsFixed(0)} Hrs / ${selectedCar!.packageKm.toStringAsFixed(0)} Km"),
                const Divider(height: 24),
                _fareRowDetail(Icons.speed, "Extra KM Charge",
                    "₹${selectedCar!.extraKMAmount.toStringAsFixed(0)} / km"),
                const Divider(height: 24),
                _fareRowDetail(Icons.more_time, "Extra Hr Charge",
                    "₹${selectedCar!.extraHoursAmount.toStringAsFixed(0)} / hr"),
                const Divider(height: 24),
                _fareRowDetail(Icons.verified_user_outlined, "Driver Allowance",
                    "Included",
                    isGreen: true),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Text(
              "* Tolls, Parking & State Tax extra as per actual receipts.",
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade800,
                  fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fareRowDetail(IconData icon, String label, String value,
      {bool isGreen = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryAmber),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color:
                    isGreen ? Colors.green.shade700 : const Color(0xFF2D2D2D))),
      ],
    );
  }

  Widget _buildContactForm() {
    return Container(
      decoration: _cardBoxDecoration(),
      child: Column(
        children: [
          if (userType == 'agent') ...[
            _buildModernField(
                controller: customerNumberController,
                label: "Customer Number",
                icon: Icons.phone_android,
                isNumber: true,
                length: 10),
            const Divider(height: 1),
          ],
          _buildModernField(
              controller: nameController,
              label: "Full Name",
              icon: Icons.person_outline),
          const Divider(height: 1),
          _buildModernField(
              controller: emailController,
              label: "Email Address",
              icon: Icons.alternate_email),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                  child: _buildModernField(
                      controller: cityController,
                      label: "City",
                      icon: Icons.location_city)),
              const VerticalDivider(width: 1),
              Expanded(
                  child: _buildModernField(
                      controller: pincodeController,
                      label: "Pincode",
                      icon: Icons.pin_drop,
                      isNumber: true,
                      length: 6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGSTSection() {
    return Column(
      children: [
        SwitchListTile(
          value: showGSTField,
          activeColor: primaryAmber,
          title: Text("Enable GST Invoice",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          onChanged: (v) => setState(() => showGSTField = v),
        ),
        if (showGSTField)
          Container(
            decoration: _cardBoxDecoration(),
            child: Column(
              children: [
                _buildModernField(
                    controller: gstNumberController,
                    label: "GST Number",
                    icon: Icons.receipt_long,
                    length: 15),
                const Divider(height: 1),
                _buildModernField(
                    controller: businessNameController,
                    label: "Business Name",
                    icon: Icons.business),
                const Divider(height: 1),
                _buildModernField(
                    controller: businessAddressController,
                    label: "Business Address",
                    icon: Icons.map),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: darkText,
          foregroundColor: primaryAmber,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 5,
        ),
        child: isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("PAY ADVANCE ₹250",
                      style: TextStyle(
                          fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(width: 10),
                  Icon(Icons.arrow_forward, color: primaryAmber),
                ],
              ),
      ),
    );
  }

  BoxDecoration _cardBoxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.grey.shade100),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4))
      ],
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      prefixIcon: Icon(icon, color: primaryAmber, size: 20),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.all(18),
    );
  }

  Widget _buildModernField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      bool readOnly = false,
      VoidCallback? onTap,
      bool isNumber = false,
      int? length}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLength: length,
      decoration: _inputDecoration(label, icon).copyWith(counterText: ""),
    );
  }

  Widget _buildSmartTip(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: lightAmber,
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18))),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: primaryAmber),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 11, fontStyle: FontStyle.italic))),
        ],
      ),
    );
  }
}
