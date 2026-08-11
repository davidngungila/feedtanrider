class AppConfig {
  static const String baseUrl = 'https://www.feedtanstore.com/api';
  // Use for local testing:
  // static const String baseUrl = 'http://10.0.2.2:8000/api'; // Android emulator
  // static const String baseUrl = 'http://localhost:8000/api'; // iOS simulator

  // Temporary: Firebase (push notifications) is disabled until
  // android/app/google-services.json is added. Flip to true to re-enable.
  static const bool firebaseEnabled = false;

  // Store pickup point (used to draw the route from store to customer).
  static const double storeLat = -3.3869;
  static const double storeLng = 36.6883;

  // How often (seconds) to poll for new dispatch requests / orders.
  static const int pollingIntervalSeconds = 15;

  // How often (seconds) to report location to the backend.
  static const int locationReportSeconds = 20;
}
