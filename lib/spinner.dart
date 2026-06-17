import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:http/http.dart' as http;
import 'package:confetti/confetti.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:agni_car_rental/config/api_config.dart';
import 'redeem.dart';

class SpinnerData {
  final String numberOfSpinsText;
  final bool numberOfSpinsStatus;
  final bool spinnerStatus;
  final int minWinLimit;
  final int maxWinLimit;
  final List<int> spinnerWheel;
  final String withdrawText;
  final bool withdrawStatus;

  SpinnerData({
    required this.numberOfSpinsText,
    required this.numberOfSpinsStatus,
    required this.spinnerStatus,
    required this.minWinLimit,
    required this.maxWinLimit,
    required this.spinnerWheel,
    required this.withdrawText,
    required this.withdrawStatus,
  });

  factory SpinnerData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return SpinnerData(
        numberOfSpinsText: '',
        numberOfSpinsStatus: false,
        spinnerStatus: false,
        minWinLimit: 0,
        maxWinLimit: 0,
        spinnerWheel: [0],
        withdrawText: 'Redeem',
        withdrawStatus: false,
      );
    }
    return SpinnerData(
      numberOfSpinsText: json['numberOfSpinsText']?['text'] ?? '',
      numberOfSpinsStatus: json['numberOfSpinsText']?['status'] ?? false,
      spinnerStatus: json['spinnerStatus'] ?? false,
      minWinLimit: json['winLimit']?['min'] ?? 0,
      maxWinLimit: json['winLimit']?['max'] ?? 0,
      spinnerWheel: (json['spinnerWheel'] as List<dynamic>?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .toList() ??
          [0],
      withdrawText: json['withdrawText']?['text'] ?? 'Redeem',
      withdrawStatus: json['withdrawText']?['status'] ?? false,
    );
  }
}

class SpinGamePage extends StatefulWidget {
  final int userId;
  final Function(int) onPointsWon;

  const SpinGamePage({
    super.key,
    required this.userId,
    required this.onPointsWon,
  });

  @override
  State<SpinGamePage> createState() => _SpinGamePageState();
}

class _SpinGamePageState extends State<SpinGamePage> {
  final StreamController<int> controller = StreamController<int>();
  late ConfettiController _confettiController;
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  final Color primaryAmber = const Color(0xFFFFB300);
  final Color secondaryYellow = const Color(0xFFFFD54F);
  final Color darkCanvas = const Color(0xFF1A1A1A);
  final Color lightGold = const Color(0xFFFFE082);

  Map<String, dynamic>? user;
  SpinnerData? spinnerData;

  bool isLoading = true;
  bool isSpinning = false;
  int remainingSpins = 0;
  int currentPoints = 0;
  String? savedNumber;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _initData();
  }

  // Combined initialization to prevent partial loading errors
  Future<void> _initData() async {
    setState(() => isLoading = true);
    await Future.wait([
      fetchUserData(),
      fetchSpinnerSettings(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  @override
  void dispose() {
    controller.close();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> fetchUserData() async {
    try {
      savedNumber = await secureStorage.read(key: 'phone_number');
      if (savedNumber == null) return;

      final url = Uri.parse(
          '${ApiConfig.baseUrl}/get_customer_data.php?phone_number=$savedNumber');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['status'] == 'success' && jsonData['user'] != null) {
          user = jsonData['user'];
          remainingSpins =
              int.tryParse(user!['available_spin'].toString()) ?? 0;
          currentPoints = int.tryParse(user!['reward_point'].toString()) ?? 0;
        }
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> fetchSpinnerSettings() async {
    try {
      final url =
          Uri.parse('${ApiConfig.baseUrl}/spinner_numbers.php');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        spinnerData = SpinnerData.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching spinner settings: $e');
    }
  }

  void spinWheel() {
    if (isSpinning ||
        remainingSpins <= 0 ||
        spinnerData == null ||
        spinnerData!.spinnerWheel.isEmpty) return;

    setState(() {
      isSpinning = true;
      remainingSpins -= 1;
    });

    final validNumbers = spinnerData!.spinnerWheel
        .where((num) =>
            num >= spinnerData!.minWinLimit && num <= spinnerData!.maxWinLimit)
        .toList();

    final wheelNumbers =
        validNumbers.isNotEmpty ? validNumbers : spinnerData!.spinnerWheel;
    final stop = wheelNumbers[Random().nextInt(wheelNumbers.length)];
    final stopIndex = spinnerData!.spinnerWheel.indexOf(stop);

    controller.add(stopIndex);

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        currentPoints += stop;
        isSpinning = false;
      });

      _sendPointsToApi(stop);
      widget.onPointsWon(stop);
      _showCongratsDialog(stop);
    });
  }

  Future<void> _sendPointsToApi(int points) async {
    if (savedNumber == null) return;
    try {
      await http.put(
        Uri.parse("${ApiConfig.baseUrl}/spinner_update.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone_number": savedNumber, "reward_point": points}),
      );
    } catch (e) {
      debugPrint("API Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("LUCKY SPINNER",
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Handling null data state before rendering
    if (isLoading || spinnerData == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.amber));
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 30),
            _buildWheelSection(),
            const SizedBox(height: 40),
            _buildSpinButton(),
            const SizedBox(height: 16),
            if (spinnerData?.withdrawStatus ?? false) _buildRedeemButton(),
            const SizedBox(height: 30),
            _buildInstructions(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("YOUR BALANCE",
                  style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("$currentPoints PTS",
                  style: GoogleFonts.poppins(
                      color: primaryAmber,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: primaryAmber, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.refresh, size: 14, color: Colors.black),
                const SizedBox(width: 4),
                Text("$remainingSpins LEFT",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWheelSection() {
    final double size = MediaQuery.of(context).size.width * 0.85;
    // Fallback if list is empty to prevent FortuneWheel error
    final wheelItems = spinnerData?.spinnerWheel ?? [0];

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size + 20,
          height: size + 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: primaryAmber.withOpacity(0.2), width: 8),
          ),
        ),
        SizedBox(
          width: size,
          height: size,
          child: FortuneWheel(
            selected: controller.stream,
            animateFirst: false,
            indicators: [
              FortuneIndicator(
                alignment: Alignment.topCenter,
                child:
                    TriangleIndicator(color: lightGold, width: 30, height: 30),
              ),
            ],
            items: List.generate(wheelItems.length, (i) {
              return FortuneItem(
                child: Text(wheelItems[i].toString()),
                style: FortuneItemStyle(
                  color: i % 2 == 0 ? primaryAmber : secondaryYellow,
                  borderColor: darkCanvas,
                  borderWidth: 2,
                  textStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: darkCanvas,
                  ),
                ),
              );
            }),
          ),
        ),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)
            ],
            border: Border.all(color: darkCanvas, width: 3),
          ),
          child: const Icon(Icons.flash_on, color: Color(0xFFFF8F00)),
        ),
      ],
    );
  }

  Widget _buildSpinButton() {
    bool canSpin = remainingSpins > 0 && !isSpinning;
    return GestureDetector(
      onTap: canSpin ? spinWheel : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: canSpin
              ? LinearGradient(colors: [primaryAmber, secondaryYellow])
              : const LinearGradient(colors: [Colors.grey, Color(0xFF424242)]),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          isSpinning
              ? "SPINNING..."
              : (remainingSpins > 0 ? "SPIN NOW" : "OUT OF SPINS"),
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800, fontSize: 18, color: darkCanvas),
        ),
      ),
    );
  }

  Widget _buildRedeemButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const RedeemPage())),
        child: Text(
          spinnerData?.withdrawText ?? "Redeem",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text("HOW IT WORKS",
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          _instructionStep(
              "1", "Spin the wheel to earn points based on your luck."),
          _instructionStep(
              "2", "Points are automatically added to your wallet."),
          _instructionStep(
              "3", "Redeem points for real discounts on Agni Car Rental."),
        ],
      ),
    );
  }

  Widget _instructionStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$num. ",
              style: const TextStyle(
                  color: Colors.amber, fontWeight: FontWeight.bold)),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 12))),
        ],
      ),
    );
  }

  void _showCongratsDialog(int points) {
    _confettiController.play();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                colors: const [Colors.amber, Colors.orange, Colors.yellow],
              ),
              const Icon(Icons.stars_rounded, size: 80, color: Colors.amber),
              const SizedBox(height: 16),
              Text("JACKPOT!",
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: darkCanvas)),
              Text("You just earned $points POINTS",
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkCanvas,
                    foregroundColor: primaryAmber,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    _confettiController.stop();
                    Navigator.pop(context);
                  },
                  child: const Text("COLLECT NOW"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
