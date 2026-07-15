import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:package_info_plus/package_info_plus.dart';

// --- Internal Imports ---
import 'package:agni_car_rental/config/api_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'OneWayRegistration.dart';
import 'localDutyReg.dart';
import 'local_taxi.dart';
import 'roundTripRegistration.dart';
import 'spinner.dart';
import 'pointcount.dart';
import 'services/boundary_service.dart';

/// =========================
/// NOTIFICATION SERVICE
/// =========================
class InAppNotificationService {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    String? imageUrl,
    VoidCallback? onTap,
  }) {
    // Replace existing instead of blocking
    _dismiss();

    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) {
      // retry once after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final retry = Overlay.of(context, rootOverlay: true);
        if (retry != null) {
          _insert(retry, title, message, imageUrl, onTap);
        } else {
          debugPrint("Overlay not ready (retry failed)");
        }
      });
      return;
    }

    _insert(overlay, title, message, imageUrl, onTap);
  }

  static void _insert(OverlayState overlay, String title, String message,
      String? imageUrl, VoidCallback? onTap) {
    _entry = OverlayEntry(
      builder: (context) => _NotificationBanner(
        title: title,
        message: message,
        imageUrl: imageUrl,
        onDismiss: _dismiss,
        onTap: onTap,
      ),
    );

    overlay.insert(_entry!);

    _timer = Timer(const Duration(seconds: 5), () {
      _dismiss();
    });
  }

  static void _dismiss() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
  }
}

/// =========================
/// NOTIFICATION UI
/// =========================
class _NotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final String? imageUrl;
  final VoidCallback onDismiss;
  final VoidCallback? onTap;

  const _NotificationBanner({
    required this.title,
    required this.message,
    this.imageUrl,
    required this.onDismiss,
    this.onTap,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose(); // 🔴 FIX: avoid leak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Push down to avoid system-notification mimic
      top: MediaQuery.of(context).padding.top + 40,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              widget.onDismiss();
              widget.onTap?.call();
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                  )
                ],
              ),
              child: Row(
                children: [
                  if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrl!,
                        width: 45,
                        height: 45,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Agni Customer",
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(widget.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(widget.message,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onDismiss,
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =========================
/// LIFECYCLE
/// =========================
class LifecycleService with WidgetsBindingObserver {
  final VoidCallback onResume;
  LifecycleService({required this.onResume});

  void init() => WidgetsBinding.instance.addObserver(this);
  void dispose() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

/// =========================
/// MODELS
/// =========================
class TextItem {
  final String text;
  final bool status;

  TextItem({required this.text, required this.status});

  factory TextItem.fromJson(Map<String, dynamic> json) =>
      TextItem(text: json['text'], status: json['status']);
}

class SpinnerContent {
  final String title;
  final List<TextItem> texts;
  final int availableSpin;

  SpinnerContent({
    required this.title,
    required this.texts,
    required this.availableSpin,
  });

  factory SpinnerContent.fromJson(Map<String, dynamic> json) {
    var list = json['texts'] as List;
    return SpinnerContent(
      title: json['title'],
      texts: list.map((e) => TextItem.fromJson(e)).toList(),
      availableSpin: json['available_spin'] ?? 0,
    );
  }
}

/// =========================
/// MAIN PAGE
/// =========================
class TripSelectionPage extends StatefulWidget {
  @override
  State<TripSelectionPage> createState() => _TripSelectionPageState();
}

class _TripSelectionPageState extends State<TripSelectionPage> {
  final Color primaryAmber = const Color(0xFFFFB300);
  final Color bgCream = const Color(0xFFF8F9FA);
  final Color textDark = const Color(0xFF1A1A2E);
  final Color cardBg = const Color(0xFFFFFFFF);

  int userPoints = 0;
  SpinnerContent? spinnerContent;
  bool isSpinnerVisible = false;

  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  late LifecycleService lifecycle;

  DateTime? lastNotificationFetch;
  bool _isInsideBoundary = false;
  bool _isCheckingLocation = true;

  final List<String> imageUrls = [
    'https://agnicarrental.com/driver2025/add/add1.webp',
    'https://agnicarrental.com/driver2025/add/add2.webp',
    'https://agnicarrental.com/driver2025/add/add3.webp',
    'https://agnicarrental.com/driver2025/add/add4.webp',
  ];

  @override
  void initState() {
    super.initState();

    fetchUserPoints();
    fetchSpinnerContent();
    checkForUpdate();
    _checkCurrentLocationBoundary();

    lifecycle = LifecycleService(onResume: checkNotification);
    lifecycle.init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkNotification();
    });
  }

  Future<void> _checkCurrentLocationBoundary() async {
    setState(() => _isCheckingLocation = true);
    try {
      final boundaryService = BoundaryService();
      await boundaryService.fetchCityBoundaries();

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low);
        
        final detected = boundaryService.detectCity(
          LatLng(position.latitude, position.longitude),
          "",
        );
        setState(() {
          _isInsideBoundary = (detected != null);
          _isCheckingLocation = false;
        });
      } else {
        setState(() {
          _isInsideBoundary = false;
          _isCheckingLocation = false;
        });
      }
    } catch (e) {
      debugPrint("Error checking location boundary: $e");
      setState(() {
        _isInsideBoundary = false;
        _isCheckingLocation = false;
      });
    }
  }

  @override
  void dispose() {
    lifecycle.dispose();
    super.dispose();
  }

  /// =========================
  /// NOTIFICATION API
  /// =========================
  Future<void> checkNotification() async {
    try {
      if (lastNotificationFetch != null &&
          DateTime.now().difference(lastNotificationFetch!) <
              const Duration(minutes: 5)) {
        return;
      }

      final phone = await secureStorage.read(key: 'phone_number');
      if (phone == null) return;

      final res = await http
          .get(Uri.parse(
              "${ApiConfig.baseUrl}/customer_pop_up.php?phone_number=$phone"))
          .timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) {
        debugPrint("Notification API failed: ${res.statusCode}");
        return;
      }

      dynamic data;
      try {
        data = jsonDecode(res.body);
        print("Notification Response ${data}");
      } catch (_) {
        debugPrint("Invalid JSON");
        return;
      }

      if (data["success"] == true && data["notification"] != null) {
        final notif = data["notification"];

        // final String id = notif["id"]?.toString() ?? "0";
        // final bool showOnce = notif["showOnce"] ?? false;

        // if (showOnce) {
        //   final lastId = await secureStorage.read(key: "last_notification_id");
        //   if (lastId == id) return;

        //   await secureStorage.write(key: "last_notification_id", value: id);
        // }

        if (mounted) {
          InAppNotificationService.show(
            context,
            title: notif["title"] ?? "",
            message: notif["message"] ?? "",
            imageUrl: notif["imageUrl"] ?? "",
            onTap: () {
              // TODO: deep link / navigate
            },
          );
        }

        lastNotificationFetch = DateTime.now();
      }
    } catch (e) {
      debugPrint("Notification Error: $e");
    }
  }

  /// =========================
  /// DATA
  /// =========================
  Future<void> fetchUserPoints() async {
    final phone = await secureStorage.read(key: 'phone_number');
    if (phone == null) return;

    final res = await http.get(Uri.parse(
        '${ApiConfig.baseUrl}/get_customer_data.php?phone_number=$phone'));

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data['status'] == 'success') {
        setState(() => userPoints = data['user']['reward_point'] ?? 0);
      }
    }
  }

  Future<void> fetchSpinnerContent() async {
    final phone = await secureStorage.read(key: 'phone_number');
    if (phone == null) return;

    final res = await http.get(Uri.parse(
        '${ApiConfig.baseUrl}/spinner_content.php?phone_number=$phone'));

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      setState(() {
        spinnerContent = SpinnerContent.fromJson(data);
        isSpinnerVisible = data['spinnerCardStatus'] ?? false;
      });
    }
  }

  /// =========================
  /// UPDATE CHECK
  /// =========================
  void checkForUpdate() async {
    final res = await http.get(Uri.parse(
        "https://agnicarrental.com/driver2025/getAppVersion.php?appName=Agni Customer"));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      final info = await PackageInfo.fromPlatform();
      int current = int.tryParse(info.buildNumber) ?? 0;
      int latest = int.tryParse(data['latest_version']) ?? 0;

      if (latest > current) {
        _showUpdatePopup(data['update_url']);
      }
    }
  }

  void _showUpdatePopup(String url) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Update Available",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Please update for better experience"),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Later"),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text("Update"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _openSpinGame() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpinGamePage(
          userId: 1, // 🔴 replace with real user id
          onPointsWon: (p) => setState(() => userPoints += p),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: bgCream,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── Hero Header ───
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar: logo + location badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Image.asset('assets/home.png', height: 30),
                          _buildLocationBadge(),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Greeting
                      Text(
                        'Hello there! 👋',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white60,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Where would you like\nto go today?',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Amber accent line
                      Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: primaryAmber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Section Title ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Text(
                'Choose Your Ride',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ),
          ),

          // ─── Service Cards Grid ───
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.95,
              children: [
                _buildServiceCard(
                  icon: Icons.near_me_rounded,
                  title: 'One Way',
                  subtitle: 'Outstation',
                  gradientColors: [const Color(0xFF4776E6), const Color(0xFF8E54E9)],
                  isAvailable: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FromToMapScreen()),
                  ),
                ),
                _buildServiceCard(
                  icon: Icons.sync_alt_rounded,
                  title: 'Round Trip',
                  subtitle: 'Outstation',
                  gradientColors: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
                  isAvailable: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RoundTripFromToMapScreen()),
                  ),
                ),
                _buildServiceCard(
                  icon: Icons.timer_rounded,
                  title: 'Local Duty',
                  subtitle: '8hr / 80km',
                  gradientColors: _isInsideBoundary
                      ? [const Color(0xFFFF8008), const Color(0xFFFFC837)]
                      : [const Color(0xFF9E9E9E), const Color(0xFFBDBDBD)],
                  isAvailable: _isInsideBoundary,
                  onTap: () {
                    if (_isInsideBoundary) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocalDutyBookingForm(fromLocation: ''),
                        ),
                      );
                    } else {
                      _showServiceDisabledDialog(context, 'Local Duty');
                    }
                  },
                ),
                _buildServiceCard(
                  icon: Icons.local_taxi_rounded,
                  title: 'Local Cab',
                  subtitle: 'Quick Ride',
                  gradientColors: _isInsideBoundary
                      ? [const Color(0xFF7B2FF7), const Color(0xFFF107A3)]
                      : [const Color(0xFF9E9E9E), const Color(0xFFBDBDBD)],
                  isAvailable: _isInsideBoundary,
                  onTap: () {
                    if (_isInsideBoundary) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LocalTaxi()),
                      );
                    } else {
                      _showServiceDisabledDialog(context, 'Local Cab');
                    }
                  },
                ),
              ],
            ),
          ),

          // ─── Info Banner ───
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryAmber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.info_outline_rounded,
                          color: primaryAmber, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Local Services',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: textDark,
                            ),
                          ),
                          Text(
                            _isCheckingLocation
                                ? 'Checking your location...'
                                : _isInsideBoundary
                                    ? 'Local Cab & Duty available in your area'
                                    : 'Local services not available in your current area',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  Widget _buildLocationBadge() {
    if (_isCheckingLocation) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Colors.white70),
            ),
            const SizedBox(width: 6),
            Text('Locating...',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: Colors.white70)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isInsideBoundary
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isInsideBoundary
              ? Colors.greenAccent.withOpacity(0.5)
              : Colors.redAccent.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_rounded,
            size: 12,
            color:
                _isInsideBoundary ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 4),
          Text(
            _isInsideBoundary ? 'In Service Area' : 'Outside Area',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _isInsideBoundary
                  ? Colors.greenAccent
                  : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required bool isAvailable,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(isAvailable ? 0.18 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container with gradient
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isAvailable
                        ? gradientColors
                        : [Colors.grey.shade300, Colors.grey.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: isAvailable
                      ? [
                          BoxShadow(
                            color: gradientColors[0].withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const Spacer(),
              // Title
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isAvailable ? textDark : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 2),
              // Subtitle with dot indicator
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? gradientColors[0]
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isAvailable
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [primaryAmber, const Color(0xFFFFD54F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: primaryAmber.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("REWARDS PROGRAM",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
              Icon(Icons.stars_rounded,
                  color: Colors.white.withOpacity(0.8), size: 24),
            ],
          ),
          const SizedBox(height: 12),
          AutoSizeText(spinnerContent?.title ?? "Spin & Win Points",
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
              maxLines: 1),
          if (spinnerContent != null)
            SpinnerTextSlider(
                texts: spinnerContent!.texts.where((t) => t.status).toList()),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Available Spins: ${spinnerContent?.availableSpin ?? 0}",
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
              ElevatedButton(
                onPressed: _openSpinGame,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryAmber,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text("SPIN NOW",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          )
        ],
      ),
    );
  }

  // legacy method kept for reference
  Widget _buildServiceTile(IconData icon, String title, String sub, Color tint,
      Color iconCol, VoidCallback onTap) {
    return _buildServiceCard(
      icon: icon,
      title: title,
      subtitle: sub,
      gradientColors: [iconCol, iconCol.withOpacity(0.7)],
      isAvailable: true,
      onTap: onTap,
    );
  }

  void _showServiceDisabledDialog(BuildContext context, String serviceName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "Service Not Available",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          content: Text(
            "You are outside the boundary. Local Cab/Duty is not available in this location. Please choose One-Way or Round-Trip instead.",
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              child: Text(
                "OK",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryAmber),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

// --- Text Slider Widget ---
class SpinnerTextSlider extends StatefulWidget {
  final List<TextItem> texts;
  const SpinnerTextSlider({required this.texts});
  @override
  State<SpinnerTextSlider> createState() => _SpinnerTextSliderState();
}

class _SpinnerTextSliderState extends State<SpinnerTextSlider> {
  final PageController _pc = PageController();
  int _curr = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.texts.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (t) {
        if (_pc.hasClients) {
          _curr = (_curr + 1) % widget.texts.length;
          _pc.animateToPage(_curr,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.texts.isEmpty) return const SizedBox.shrink();
    return SizedBox(
        height: 20,
        child: PageView.builder(
          controller: _pc,
          itemCount: widget.texts.length,
          itemBuilder: (_, i) => Text(widget.texts[i].text,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ));
  }
}
