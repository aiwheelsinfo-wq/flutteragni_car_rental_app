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
  final Color bgCream = const Color(0xFFFEFBF3);
  final Color textDark = const Color(0xFF2D2D2D);

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
    return Scaffold(
      backgroundColor: bgCream,
      appBar: AppBar(
        backgroundColor: bgCream,
        elevation: 0,
        centerTitle: false,
        title: Image.asset('assets/home.png', height: 28),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Greeting Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hello there!",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Where would you like to go?",
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Premium Promotional Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF263238), Color(0xFF37474F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryAmber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: primaryAmber.withOpacity(0.4), width: 1),
                            ),
                            child: Text(
                              "RENTAL PREMIER",
                              style: TextStyle(
                                color: primaryAmber,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Your Premium Ride Awaits",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Book a safe, sanitized, and professional chauffeur-driven cab with Rentox.",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_car_filled_rounded,
                        color: primaryAmber,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Grid of Services
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.95,
              children: [
                _buildServiceTile(
                  icon: Icons.near_me_rounded,
                  title: 'One Way',
                  sub: 'Outstation Pick',
                  badgeText: 'Outstation',
                  baseColor: Colors.blue,
                  isEnabled: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FromToMapScreen()),
                  ),
                ),
                _buildServiceTile(
                  icon: Icons.sync_alt_rounded,
                  title: 'Round Trip',
                  sub: 'Outstation Return',
                  badgeText: 'Multi-Day',
                  baseColor: Colors.green,
                  isEnabled: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RoundTripFromToMapScreen()),
                  ),
                ),
                _buildServiceTile(
                  icon: Icons.timer_rounded,
                  title: 'Local Duty',
                  sub: '8hr / 80km package',
                  badgeText: 'Hourly',
                  baseColor: Colors.orange,
                  isEnabled: _isInsideBoundary,
                  onTap: () {
                    if (_isInsideBoundary) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocalDutyBookingForm(fromLocation: ''),
                        ),
                      );
                    } else {
                      _showServiceDisabledDialog(context, "Local Duty");
                    }
                  },
                ),
                _buildServiceTile(
                  icon: Icons.local_taxi_rounded,
                  title: 'Local Cab',
                  sub: 'Point to point ride',
                  badgeText: 'Quick Cab',
                  baseColor: Colors.purple,
                  isEnabled: _isInsideBoundary,
                  onTap: () {
                    if (_isInsideBoundary) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LocalTaxi()),
                      );
                    } else {
                      _showServiceDisabledDialog(context, "Local Cab");
                    }
                  },
                ),
              ],
            ),
          ),

          // 4. Location Status Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Builder(
                builder: (context) {
                  if (_isCheckingLocation) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Verifying your location boundary...",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (_isInsideBoundary) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: Colors.green[800], size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Location verified: Local Cab & Duty active",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.amber[800], size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Outside Local Zone: Outstation trips only",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
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

  Widget _buildServiceTile({
    required IconData icon,
    required String title,
    required String sub,
    required String badgeText,
    required Color baseColor,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    final Color tint = baseColor.withOpacity(0.08);
    final Color iconCol = isEnabled ? baseColor : Colors.grey;
    final Color titleCol = isEnabled ? textDark : Colors.grey[600]!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey[100],
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isEnabled ? baseColor.withOpacity(0.15) : Colors.grey.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: baseColor.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isEnabled ? baseColor.withOpacity(0.12) : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: isEnabled ? baseColor : Colors.grey[700],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconCol, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: titleCol,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isEnabled ? Colors.grey[500] : Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
