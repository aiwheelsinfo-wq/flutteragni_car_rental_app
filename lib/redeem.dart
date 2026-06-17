import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:agni_car_rental/config/api_config.dart';
import 'spinner.dart';
import 'pointcount.dart';

class RedeemPage extends StatefulWidget {
  const RedeemPage({super.key});

  @override
  State<RedeemPage> createState() => _RedeemPageState();
}

class _RedeemPageState extends State<RedeemPage> {
  final TextEditingController _customerIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  // Theme Palette
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color secondaryYellow = const Color(0xFFFFD54F);
  final Color darkCharcoal = const Color(0xFF1A1A1A);
  final Color surfaceGrey = const Color(0xFFF8F9FA);

  bool isSubmitting = false;
  bool isLoadingHistory = true;
  int userPoints = 0;
  List<dynamic> redeemHistory = [];

  // Withdraw config
  int minWithdrawAmount = 0;
  bool withdrawEnabled = false;
  bool redeemButtonEnabled = false;
  String redeemButtonText = "Redeem Now";

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _fetchWithdrawConfig(),
      _fetchRedeemHistory(),
      fetchUserPoints(),
    ]);
  }

  Future<void> _fetchWithdrawConfig() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/withdraw_limit.php'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          minWithdrawAmount = data['withdrawLimit']['max'] ?? 0;
          withdrawEnabled = data['withdrawLimit']['status'] ?? false;
          redeemButtonText = data['redeemButtonText']['text'] ?? "Redeem Now";
          redeemButtonEnabled = data['redeemButtonText']['status'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Config Error: $e");
    }
  }

  Future<void> fetchUserPoints() async {
    final savedNumber = await secureStorage.read(key: 'phone_number');
    if (savedNumber == null) return;
    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/get_customer_data.php?phone_number=$savedNumber'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['status'] == 'success') {
          setState(() => userPoints = jsonData['user']['reward_point'] ?? 0);
        }
      }
    } catch (e) {
      debugPrint("Points Error: $e");
    }
  }

  Future<void> _fetchRedeemHistory() async {
    setState(() => isLoadingHistory = true);
    final phoneNumber = await secureStorage.read(key: 'phone_number');
    if (phoneNumber == null) return;

    try {
      final response = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}/redeem_amount_request.php?phone_number=$phoneNumber'));
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        setState(() => redeemHistory = data['data']);
      }
    } catch (e) {
      debugPrint("History Error: $e");
    } finally {
      setState(() => isLoadingHistory = false);
    }
  }

  Future<void> _redeemAmount() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;

    if (userPoints < amount) {
      _showCustomSnackBar("Insufficient points balance", Colors.redAccent);
      return;
    }

    setState(() => isSubmitting = true);
    final phoneNumber = await secureStorage.read(key: 'phone_number');
    final customerId = _customerIdController.text.trim();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/redeem_amount_request.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone_number": phoneNumber,
          "payment_id": customerId,
          "amount": amount,
        }),
      );
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        _showCustomSnackBar(
            data['message'] ?? "Request Sent Successfully!", Colors.green);
        _customerIdController.clear();
        _amountController.clear();
        _loadAllData();
      } else {
        _showCustomSnackBar(
            data['message'] ?? "Redeem Failed", Colors.redAccent);
      }
    } catch (e) {
      _showCustomSnackBar("Submission error", Colors.redAccent);
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _showCustomSnackBar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceGrey,
      appBar: AppBar(
        backgroundColor: darkCharcoal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Wallet & Redeem",
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildBalanceCard(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (withdrawEnabled) _buildRedeemForm(),
                  const SizedBox(height: 25),
                  _buildHistoryHeader(),
                  const SizedBox(height: 10),
                  _buildHistoryList(),
                  const SizedBox(height: 20),
                  _buildWithdrawGuidelines(),
                ],
              ),
            ),
          ),
          if (redeemButtonEnabled) _buildRedeemButton(),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: BoxDecoration(
        color: darkCharcoal,
        borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [primaryAmber, secondaryYellow]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: primaryAmber.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 10))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("AVAILABLE BALANCE",
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                        letterSpacing: 1.1)),
                const SizedBox(height: 5),
                Text("$userPoints Points",
                    style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: darkCharcoal)),
              ],
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => SpinGamePage(
                          userId: 0, onPointsWon: (p) => fetchUserPoints()))),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle),
                child:
                    const Icon(Icons.add_task, color: Colors.black87, size: 28),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRedeemForm() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
          _buildTextField(
            controller: _customerIdController,
            label: "UPI ID / Mobile Number",
            hint: "example@upi",
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 15),
          _buildTextField(
            controller: _amountController,
            label: "Redeem Amount",
            hint: "Min ₹$minWithdrawAmount",
            icon: Icons.currency_rupee_rounded,
            isNumber: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required String hint,
      required IconData icon,
      bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryAmber, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: primaryAmber, width: 1.5)),
        labelStyle: TextStyle(color: Colors.grey.shade600),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return "Field Required";
        if (isNumber) {
          final amt = int.tryParse(value);
          if (amt == null) return "Invalid Number";
          if (amt < minWithdrawAmount)
            return "Minimum ₹$minWithdrawAmount required";
        }
        return null;
      },
    );
  }

  Widget _buildHistoryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Payment History",
            style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: darkCharcoal)),
        IconButton(
            onPressed: _fetchRedeemHistory,
            icon: Icon(Icons.refresh, size: 20, color: primaryAmber)),
      ],
    );
  }

  Widget _buildHistoryList() {
    if (isLoadingHistory)
      return const Center(child: CircularProgressIndicator());
    if (redeemHistory.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Icon(Icons.history_toggle_off,
                color: Colors.grey.shade300, size: 50),
            const SizedBox(height: 10),
            Text("No transactions yet",
                style: GoogleFonts.poppins(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: redeemHistory.length,
      itemBuilder: (context, index) {
        final item = redeemHistory[index];
        final status = item['status'].toString().toLowerCase();
        Color statusColor = primaryAmber;
        if (status == 'completed' || status == 'success')
          statusColor = Colors.green;
        if (status == 'rejected') statusColor = Colors.redAccent;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 5,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(Icons.payment, color: statusColor, size: 20),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("₹${item['amount']}",
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(item['payment_id'],
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(item['status'].toString().toUpperCase(),
                        style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: statusColor)),
                  ),
                  const SizedBox(height: 5),
                  Text(item['date'],
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildWithdrawGuidelines() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: secondaryYellow.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: secondaryYellow.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: primaryAmber),
              const SizedBox(width: 8),
              Text("Withdrawal Info",
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          _bulletPoint("Redemption requests are processed within 24-48 hours."),
          _bulletPoint("Ensure your UPI ID or Mobile number is correct."),
          _bulletPoint(
              "Min conversion: 1 Point = ₹1 (or as per current policy)."),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 11, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildRedeemButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ],
      ),
      child: ElevatedButton(
        onPressed: isSubmitting ? null : _redeemAmount,
        style: ElevatedButton.styleFrom(
          backgroundColor: darkCharcoal,
          foregroundColor: primaryAmber,
          minimumSize: const Size(double.infinity, 55),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(redeemButtonText.toUpperCase(),
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
    );
  }
}
