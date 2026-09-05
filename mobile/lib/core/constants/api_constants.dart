import 'dart:io';

class ApiConstants {
  // Default to localhost for iOS Simulator or 10.0.2.2 for Android Emulator.
  // Can also be overridden at build time via --dart-define=ZIVA_API_URL=https://...
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('ZIVA_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3001';
    } else {
      return 'http://localhost:3001';
    }
  }

  // Endpoints
  static const String healthEndpoint = '/api/health';
  static const String ratesEndpoint = '/api/rates';
  static const String accountsEndpoint = '/api/accounts';
  static const String transactionsEndpoint = '/api/transactions';
  static const String budgetsEndpoint = '/api/budgets';
  static const String burnRateEndpoint = '/api/burn-rate';
  static const String taxScheduleEndpoint = '/api/tax-schedule';
  static const String analyticsSummaryEndpoint = '/api/analytics/summary';
  static const String copilotChatEndpoint = '/api/copilot/chat';
}
