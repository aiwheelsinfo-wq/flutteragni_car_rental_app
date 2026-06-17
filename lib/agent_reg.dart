import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

// Assuming this exists in your project
import 'package:agni_car_rental/config/api_config.dart';
import 'bottom_nav_bar.dart';
import 'agent_page.dart';

class AgentRegistrationPage extends StatefulWidget {
  const AgentRegistrationPage({Key? key}) : super(key: key);

  @override
  _AgentRegistrationPageState createState() => _AgentRegistrationPageState();
}

class _AgentRegistrationPageState extends State<AgentRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  // Pro Theme Colors
  static const Color primaryAmber = Color(0xFFFFB300);
  static const Color accentYellow = Color(0xFFFFD54F);
  static const Color darkCharcoal = Color(0xFF1A1A1A);
  static const Color surfaceGrey = Color(0xFFF8F9FA);

  late TextEditingController agencyNameController;
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController cityController;
  late TextEditingController pincodeController;

  String? phoneNumber;
  bool isLoading = false;
  bool isFetching = true;

  @override
  void initState() {
    super.initState();
    agencyNameController = TextEditingController();
    nameController = TextEditingController();
    emailController = TextEditingController();
    cityController = TextEditingController();
    pincodeController = TextEditingController();

    fetchAgentDetails();
  }

  Future<void> fetchAgentDetails() async {
    phoneNumber = await storage.read(key: "phone_number");
    if (phoneNumber == null) return;

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/get_customer_data.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'phone_number': phoneNumber}),
      );

      final result = jsonDecode(response.body);
      if (result['status'] == 'success') {
        final data = result['user'];
        String cleanVal(dynamic val, {bool isPincode = false}) {
          if (val == null) return '';
          final s = val.toString().trim();
          if (s.toLowerCase() == 'not filled') return '';
          if (isPincode && s == '0') return '';
          return s;
        }
        setState(() {
          agencyNameController.text = cleanVal(data['agency_name']);
          nameController.text = cleanVal(data['name']);
          emailController.text = cleanVal(data['email']);
          cityController.text = cleanVal(data['city']);
          pincodeController.text = cleanVal(data['pincode'], isPincode: true);
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    } finally {
      setState(() => isFetching = false);
    }
  }

  Future<void> saveAgent() async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      phoneNumber = await storage.read(key: "phone_number");

      try {
        final response = await http.post(
          Uri.parse("${ApiConfig.baseUrl}/customer_reg.php"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            'phone_number': phoneNumber,
            'agency_name': agencyNameController.text,
            'name': nameController.text,
            'email': emailController.text,
            'city': cityController.text,
            'pincode': pincodeController.text,
          }),
        );

        final result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          _showSnackBar('Profile Updated Successfully', Colors.green);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => BottomNavBar()),
          );
        } else {
          _showSnackBar(result['message'] ?? 'Update Failed', Colors.redAccent);
        }
      } catch (e) {
        _showSnackBar('Network connection error', Colors.redAccent);
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _handleBack() async {
    await storage.delete(key: 'phone_number');
    await storage.delete(key: 'userType');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AgentQuestionPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: darkCharcoal, size: 20),
            onPressed: _handleBack,
          ),
        title: Text(
          "Agent Profile",
          style: GoogleFonts.poppins(
              color: darkCharcoal, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: isFetching
          ? const Center(child: CircularProgressIndicator(color: primaryAmber))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 30),
                    _buildTextField(
                      controller: agencyNameController,
                      label: "Agency Name",
                      hint: "Not Filled",
                      icon: Icons.business_rounded,
                      helper:
                          "This name will appear on your customer's invoices.",
                    ),
                    _buildTextField(
                      controller: nameController,
                      label: "Contact Person Name",
                      hint: "Not Filled",
                      icon: Icons.person_outline_rounded,
                    ),
                    _buildTextField(
                      controller: emailController,
                      label: "Business Email",
                      hint: "Not Filled",
                      icon: Icons.alternate_email_rounded,
                      isEmail: true,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: cityController,
                            label: "City",
                            hint: "Not Filled",
                            icon: Icons.location_city_rounded,
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildTextField(
                            controller: pincodeController,
                            label: "Pincode",
                            hint: "Not Filled",
                            icon: Icons.pin_drop_rounded,
                            isNum: true,
                            maxLength: 6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _buildSaveButton(),
                    const SizedBox(height: 20),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Complete Your Business Profile",
          style: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.bold, color: darkCharcoal),
        ),
        const SizedBox(height: 8),
        Text(
          "Set up your agency details to start booking trips and earning commissions.",
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? helper,
    bool isEmail = false,
    bool isNum = false,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            maxLength: maxLength,
            keyboardType: isEmail
                ? TextInputType.emailAddress
                : (isNum ? TextInputType.number : TextInputType.text),
            inputFormatters:
                isNum ? [FilteringTextInputFormatter.digitsOnly] : [],
            style:
                GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(icon, color: primaryAmber, size: 20),
              filled: true,
              fillColor: surfaceGrey,
              counterText: "",
              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
              floatingLabelStyle: const TextStyle(color: primaryAmber),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: primaryAmber, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return "Required";
              if (isEmail &&
                  !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$').hasMatch(value))
                return "Invalid Email";
              if (maxLength != null && value.length != maxLength)
                return "Must be $maxLength digits";
              return null;
            },
          ),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(helper,
                  style: GoogleFonts.poppins(
                      fontSize: 11, color: Colors.grey[500])),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : saveAgent,
        style: ElevatedButton.styleFrom(
          backgroundColor: darkCharcoal,
          foregroundColor: primaryAmber,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: primaryAmber)
            : Text(
                "SAVE PROFILE",
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1),
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accentYellow.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: primaryAmber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Your information is securely encrypted and used only for business verifications.",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    agencyNameController.dispose();
    nameController.dispose();
    emailController.dispose();
    cityController.dispose();
    pincodeController.dispose();
    super.dispose();
  }
}
