class ApiConfig {
  static const String baseUrl = "https://agnicarrental.com/2025";
  static const bool useLiveRazorpay = false; // toggle this for live/test
  static const String razorpayTestKey = "rzp_test_GIqSfPJk12gAgz";
  static const String razorpayLiveKey = "rzp_live_q9eMvidQ7LrwVQ";
  static const String razorpayKey = useLiveRazorpay ? razorpayLiveKey : razorpayTestKey;
}
