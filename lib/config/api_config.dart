class ApiConfig {
  static const String baseUrl = "https://agnicarrental.com/2025";
  static const bool useLiveRazorpay = false; // toggle this for live/test
  static const String razorpayTestKey = "rzp_test_GIqSfPJk12gAgz";
  static const String razorpayLiveKey = "rzp_live_q9eMvidQ7LrwVQ";
  static const String razorpayKey = useLiveRazorpay ? razorpayLiveKey : razorpayTestKey;
  static const String clientKey = "rentox_m_app_sec_2025_9847267465";

  static Map<String, String> defaultHeaders({String? token}) {
    final headers = <String, String>{
      'X-Rentox-Client-Key': clientKey,
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}

